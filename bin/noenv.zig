///usr/bin/env zig run "$0" -- "$@"; exit
//
// noenv - a minimal direnv implementation in zig
// Reads .envrc files and outputs shell commands to set environment variables
//
// Usage:
//   eval "$(noenv)"           # Load .envrc in current directory
//   eval "$(noenv hook)"      # For shell prompt integration
//   noenv allow               # Mark current .envrc as trusted
//   noenv deny                # Remove trust for current .envrc
//
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const stdout = std.fs.File.stdout();
    const stderr = std.fs.File.stderr();

    const pwd = std.posix.getenv("PWD") orelse ".";

    if (args.len > 1) {
        const cmd = args[1];
        if (std.mem.eql(u8, cmd, "hook")) {
            // Hook mode - used in shell prompt (silent if no .envrc)
            try processEnvrc(allocator, pwd, stdout, stderr, true);
            return;
        } else if (std.mem.eql(u8, cmd, "-h") or std.mem.eql(u8, cmd, "--help")) {
            try stderr.writeAll(
                \\noenv - minimal direnv
                \\
                \\No shell execution. No whitelisting. No approvals.
                \\.envrc files are parsed, not executed. Only recognized
                \\commands produce output. Unknown lines are skipped.
                \\
                \\.env files auto-inherit from parent directories.
                \\.envrc files require explicit source_up (like direnv).
                \\
                \\Usage:
                \\  eval "$(noenv)"      Load .envrc/.env in current directory
                \\  eval "$(noenv hook)" For shell prompt integration
                \\
                \\Supported .envrc commands:
                \\  export VAR=value     Set environment variable
                \\  VAR=value            Set environment variable
                \\  PATH_add <path>      Prepend to PATH
                \\  path_add VAR <path>  Prepend to any variable
                \\  MANPATH_add <path>   Prepend to MANPATH
                \\  source_env <file>    Source another .envrc
                \\  source_up            Source .envrc from parent dirs
                \\  dotenv [file]        Load .env file
                \\  layout python [cmd]  Setup Python virtualenv
                \\  layout node          Setup node_modules/.bin
                \\  layout go            Setup GOPATH
                \\  use nvm              Load node version from .nvmrc
                \\  watch_file <path>    Reload when file changes
                \\  watch_dir <dir>      Reload when any file in dir changes
                \\
                \\Unrecognized lines are skipped with a warning.
                \\
            );
            return;
        }
    }

    // Default: process .envrc
    try processEnvrc(allocator, pwd, stdout, stderr, false);
}

fn watchedFilesChanged(allocator: std.mem.Allocator, envrc_path: []const u8) bool {
    const prev_watch = std.posix.getenv("NOENV_WATCH") orelse return false;
    if (prev_watch.len == 0) return false;

    // Format: path1:mtime1|path2:mtime2|...
    var it = std.mem.splitScalar(u8, prev_watch, '|');
    while (it.next()) |entry| {
        if (entry.len == 0) continue;
        const sep = std.mem.lastIndexOf(u8, entry, ":") orelse continue;
        const path = entry[0..sep];
        const mtime_str = entry[sep + 1 ..];
        const stored_mtime = std.fmt.parseInt(i128, mtime_str, 10) catch continue;

        // Get current mtime
        const current_mtime = getFileMtime(allocator, path, envrc_path) orelse continue;
        if (current_mtime != stored_mtime) return true;
    }

    return false;
}

fn getFileMtime(allocator: std.mem.Allocator, path: []const u8, envrc_path: []const u8) ?i128 {
    // Handle dir: prefix for watched directories
    if (std.mem.startsWith(u8, path, "dir:")) {
        return getDirMaxMtime(allocator, path[4..], envrc_path);
    }

    // Handle relative paths
    var full_path: []const u8 = path;
    var need_free = false;

    if (path.len > 0 and path[0] != '/') {
        const envrc_dir = std.fs.path.dirname(envrc_path) orelse return null;
        full_path = std.fs.path.join(allocator, &.{ envrc_dir, path }) catch return null;
        need_free = true;
    }
    defer if (need_free) allocator.free(full_path);

    const stat = std.fs.cwd().statFile(full_path) catch return null;
    return stat.mtime;
}

fn getDirMaxMtime(allocator: std.mem.Allocator, path: []const u8, envrc_path: []const u8) ?i128 {
    // Resolve relative path
    var full_path: []const u8 = path;
    var need_free = false;

    if (path.len > 0 and path[0] != '/') {
        const envrc_dir = std.fs.path.dirname(envrc_path) orelse return null;
        full_path = std.fs.path.join(allocator, &.{ envrc_dir, path }) catch return null;
        need_free = true;
    }
    defer if (need_free) allocator.free(full_path);

    var max_mtime: i128 = 0;

    // Get directory's own mtime
    const dir_stat = std.fs.cwd().statFile(full_path) catch return null;
    max_mtime = dir_stat.mtime;

    // Walk all files and find max mtime
    var dir = std.fs.openDirAbsolute(full_path, .{ .iterate = true }) catch return max_mtime;
    defer dir.close();

    var walker = dir.walk(allocator) catch return max_mtime;
    defer walker.deinit();

    while (walker.next() catch null) |entry| {
        if (entry.kind == .file) {
            const file_path = std.fs.path.join(allocator, &.{ full_path, entry.path }) catch continue;
            defer allocator.free(file_path);

            const stat = std.fs.cwd().statFile(file_path) catch continue;
            if (stat.mtime > max_mtime) {
                max_mtime = stat.mtime;
            }
        }
    }

    return max_mtime;
}

fn processEnvrc(allocator: std.mem.Allocator, pwd: []const u8, stdout: std.fs.File, stderr: std.fs.File, hook_mode: bool) !void {
    // Collect all .env files from root to pwd
    var env_files = std.ArrayListUnmanaged([]const u8){};
    defer {
        for (env_files.items) |f| allocator.free(f);
        env_files.deinit(allocator);
    }

    // Find nearest .envrc (direnv behavior - no auto-inherit)
    var envrc_path: ?[]const u8 = null;
    defer if (envrc_path) |p| allocator.free(p);

    // Walk from pwd up to root
    var current = try allocator.dupe(u8, pwd);
    var path_stack = std.ArrayListUnmanaged([]const u8){};
    defer path_stack.deinit(allocator);

    while (true) {
        try path_stack.append(allocator, current);

        // Check for .envrc (stop at first one found - nearest)
        if (envrc_path == null) {
            const envrc = try std.fs.path.join(allocator, &.{ current, ".envrc" });
            if (fileExists(envrc)) {
                envrc_path = envrc;
            } else {
                allocator.free(envrc);
            }
        }

        const parent = std.fs.path.dirname(current) orelse break;
        if (std.mem.eql(u8, parent, current)) break;
        current = try allocator.dupe(u8, parent);
    }

    // Collect .env files from root to pwd (auto-inherit)
    var i: usize = path_stack.items.len;
    while (i > 0) {
        i -= 1;
        const dir = path_stack.items[i];

        const env_path = try std.fs.path.join(allocator, &.{ dir, ".env" });
        if (fileExists(env_path)) {
            try env_files.append(allocator, env_path);
        } else {
            allocator.free(env_path);
        }
    }

    // Free path stack
    for (path_stack.items) |p| allocator.free(p);

    // Nothing found?
    if (env_files.items.len == 0 and envrc_path == null) {
        try unsetPreviousVars(stdout, stderr);
        if (!hook_mode) {
            try stderr.writeAll("noenv: no .envrc or .env found\n");
        }
        return;
    }

    const scope_dir = if (envrc_path) |ep|
        (std.fs.path.dirname(ep) orelse pwd)
    else if (env_files.items.len > 0)
        (std.fs.path.dirname(env_files.items[env_files.items.len - 1]) orelse pwd)
    else
        pwd;

    // Check if we're in the same environment scope as before
    const prev_dir = std.posix.getenv("NOENV_DIR");
    if (prev_dir != null and std.mem.eql(u8, prev_dir.?, scope_dir)) {
        // Same directory - check if watched files changed
        const check_path = envrc_path orelse if (env_files.items.len > 0) env_files.items[env_files.items.len - 1] else null;
        if (check_path) |cp| {
            if (!watchedFilesChanged(allocator, cp)) {
                return;
            }
        }
        // Files changed - unset and reload
        try unsetPreviousVars(stdout, stderr);
    } else if (prev_dir != null) {
        // Different directory - unset previous vars first
        try unsetPreviousVars(stdout, stderr);
    }

    // Create execution context
    var ctx = EnvContext.init(allocator);
    defer ctx.deinit();
    ctx.base_dir = pwd;

    // Load all .env files in order (parent to child - auto-inherit)
    for (env_files.items) |env_path| {
        ctx.loadDotenvFile(env_path) catch {};
        try ctx.watch_files.append(allocator, try allocator.dupe(u8, env_path));
    }

    // Load .envrc if present (no auto-inherit - use source_up explicitly)
    if (envrc_path) |ep| {
        const envrc_dir = std.fs.path.dirname(ep) orelse pwd;
        ctx.base_dir = envrc_dir;
        ctx.executeEnvrcOnly(ep) catch {
            try stderr.writeAll("noenv: error processing .envrc\n");
        };
    }

    // Output export commands
    if (env_files.items.len > 0 or envrc_path != null) {
        try ctx.outputExports(allocator, stdout, stderr, scope_dir);
    }
}

fn unsetPreviousVars(stdout: std.fs.File, stderr: std.fs.File) !void {
    const prev_vars = std.posix.getenv("NOENV_VARS") orelse return;
    const prev_dir = std.posix.getenv("NOENV_DIR");

    if (prev_vars.len == 0) return;

    // Collect var names for summary
    var removed = std.ArrayListUnmanaged([]const u8){};
    defer removed.deinit(std.heap.page_allocator);

    // Unset each var
    var it = std.mem.splitScalar(u8, prev_vars, ':');
    while (it.next()) |var_name| {
        if (var_name.len == 0) continue;
        try stdout.writeAll("unset ");
        try stdout.writeAll(var_name);
        try stdout.writeAll(";\n");
        removed.append(std.heap.page_allocator, var_name) catch {};
    }

    // Clear tracking vars
    try stdout.writeAll("unset NOENV_VARS;\n");
    try stdout.writeAll("unset NOENV_DIR;\n");
    try stdout.writeAll("unset NOENV_WATCH;\n");

    // Print summary
    if (removed.items.len > 0) {
        stderr.writeAll("noenv: ") catch {};
        if (prev_dir) |dir| {
            stderr.writeAll("~") catch {};
            const home = std.posix.getenv("HOME") orelse "";
            if (home.len > 0 and std.mem.startsWith(u8, dir, home)) {
                stderr.writeAll(dir[home.len..]) catch {};
            } else {
                stderr.writeAll(dir) catch {};
            }
            stderr.writeAll(" ") catch {};
        }
        stderr.writeAll("\x1b[31m-") catch {};
        for (removed.items, 0..) |key, i| {
            if (i > 0) stderr.writeAll(" ") catch {};
            stderr.writeAll(key) catch {};
        }
        stderr.writeAll("\x1b[0m\n") catch {};
    }
}

const EnvContext = struct {
    allocator: std.mem.Allocator,
    env: std.StringHashMapUnmanaged([]const u8),
    exports: std.StringHashMapUnmanaged([]const u8),
    watch_files: std.ArrayListUnmanaged([]const u8),
    base_dir: []const u8,

    fn init(allocator: std.mem.Allocator) EnvContext {
        return .{
            .allocator = allocator,
            .env = std.StringHashMapUnmanaged([]const u8){},
            .exports = std.StringHashMapUnmanaged([]const u8){},
            .watch_files = std.ArrayListUnmanaged([]const u8){},
            .base_dir = "",
        };
    }

    fn deinit(self: *EnvContext) void {
        var env_it = self.env.iterator();
        while (env_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.env.deinit(self.allocator);

        var exp_it = self.exports.iterator();
        while (exp_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.exports.deinit(self.allocator);

        for (self.watch_files.items) |f| {
            self.allocator.free(f);
        }
        self.watch_files.deinit(self.allocator);
    }

    fn executeEnvrcOnly(self: *EnvContext, path: []const u8) anyerror!void {
        const content = try readFile(self.allocator, path);
        defer self.allocator.free(content);

        // Watch the .envrc file
        try self.watch_files.append(self.allocator, try self.allocator.dupe(u8, path));

        // Parse and execute .envrc line by line
        var lines = std.mem.splitScalar(u8, content, '\n');
        const stderr = std.fs.File.stderr();
        while (lines.next()) |line| {
            self.executeLine(line) catch |err| {
                const trimmed = std.mem.trim(u8, line, " \t\r");
                if (trimmed.len == 0) continue;
                // Warn about unparseable lines
                if (err == error.UnknownCommand) {
                    stderr.writeAll("noenv: skipping unrecognized: ") catch {};
                } else {
                    stderr.writeAll("noenv: error parsing: ") catch {};
                }
                stderr.writeAll(trimmed) catch {};
                stderr.writeAll("\n") catch {};
            };
        }
    }

    // Used by source_env and source_up
    fn executeEnvrc(self: *EnvContext, path: []const u8, dir: []const u8) anyerror!void {
        self.base_dir = dir;
        try self.executeEnvrcOnly(path);
    }

    fn loadDotenvFile(self: *EnvContext, path: []const u8) !void {
        const content = try readFile(self.allocator, path);
        defer self.allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |raw_line| {
            const line = std.mem.trim(u8, raw_line, " \t\r");
            if (line.len == 0 or line[0] == '#') continue;
            if (std.mem.indexOf(u8, line, "=")) |_| {
                try self.handleExport(line);
            }
        }
    }

    fn executeLine(self: *EnvContext, raw_line: []const u8) anyerror!void {
        // Trim whitespace
        const line = std.mem.trim(u8, raw_line, " \t\r");

        // Skip empty lines and comments
        if (line.len == 0 or line[0] == '#') return;

        // Handle export VAR=value
        if (std.mem.startsWith(u8, line, "export ")) {
            const rest = std.mem.trim(u8, line[7..], " \t");
            try self.handleExport(rest);
            return;
        }

        // Handle VAR=value (without export)
        if (std.mem.indexOf(u8, line, "=")) |eq_pos| {
            // Check if it looks like a variable assignment (no spaces before =)
            const before_eq = line[0..eq_pos];
            if (std.mem.indexOfAny(u8, before_eq, " \t") == null and isValidVarName(before_eq)) {
                try self.handleExport(line);
                return;
            }
        }

        // Parse command and arguments
        var parts = std.ArrayListUnmanaged([]const u8){};
        defer parts.deinit(self.allocator);

        var in_quote: ?u8 = null;
        var current_start: ?usize = null;
        var i: usize = 0;

        while (i < line.len) : (i += 1) {
            const c = line[i];

            if (in_quote) |q| {
                if (c == q) {
                    if (current_start) |start| {
                        try parts.append(self.allocator, line[start..i]);
                        current_start = null;
                    }
                    in_quote = null;
                }
            } else {
                if (c == '"' or c == '\'') {
                    in_quote = c;
                    current_start = i + 1;
                } else if (c == ' ' or c == '\t') {
                    if (current_start) |start| {
                        try parts.append(self.allocator, line[start..i]);
                        current_start = null;
                    }
                } else {
                    if (current_start == null) current_start = i;
                }
            }
        }
        if (current_start) |start| {
            try parts.append(self.allocator, line[start..]);
        }

        if (parts.items.len == 0) return;

        const cmd = parts.items[0];
        const cmd_args = parts.items[1..];

        // Dispatch commands
        if (std.mem.eql(u8, cmd, "PATH_add")) {
            try self.pathAdd("PATH", cmd_args);
        } else if (std.mem.eql(u8, cmd, "path_add")) {
            if (cmd_args.len >= 2) {
                try self.pathAdd(cmd_args[0], cmd_args[1..]);
            }
        } else if (std.mem.eql(u8, cmd, "MANPATH_add")) {
            try self.pathAdd("MANPATH", cmd_args);
        } else if (std.mem.eql(u8, cmd, "source_env")) {
            try self.sourceEnv(cmd_args);
        } else if (std.mem.eql(u8, cmd, "source_env_if_exists")) {
            self.sourceEnv(cmd_args) catch {};
        } else if (std.mem.eql(u8, cmd, "source_up")) {
            try self.sourceUp();
        } else if (std.mem.eql(u8, cmd, "source_up_if_exists")) {
            self.sourceUp() catch {};
        } else if (std.mem.eql(u8, cmd, "dotenv")) {
            try self.loadDotenv(cmd_args);
        } else if (std.mem.eql(u8, cmd, "dotenv_if_exists")) {
            self.loadDotenv(cmd_args) catch {};
        } else if (std.mem.eql(u8, cmd, "layout")) {
            try self.handleLayout(cmd_args);
        } else if (std.mem.eql(u8, cmd, "use")) {
            try self.handleUse(cmd_args);
        } else if (std.mem.eql(u8, cmd, "watch_file")) {
            for (cmd_args) |f| {
                try self.watch_files.append(self.allocator, try self.allocator.dupe(u8, f));
            }
        } else if (std.mem.eql(u8, cmd, "watch_dir")) {
            // Add directory and all files within recursively
            try self.watchDir(cmd_args);
        } else {
            // Unknown command - warn and skip
            return error.UnknownCommand;
        }
    }

    fn handleExport(self: *EnvContext, assignment: []const u8) !void {
        const eq_pos = std.mem.indexOf(u8, assignment, "=") orelse return;
        const name = assignment[0..eq_pos];
        var value = assignment[eq_pos + 1 ..];

        // Strip quotes
        if (value.len >= 2) {
            if ((value[0] == '"' and value[value.len - 1] == '"') or
                (value[0] == '\'' and value[value.len - 1] == '\''))
            {
                value = value[1 .. value.len - 1];
            }
        }

        // Expand $VAR and ${VAR} references
        const expanded = try self.expandVars(value);
        defer if (expanded.ptr != value.ptr) self.allocator.free(expanded);

        // Store in both env and exports
        const name_dup = try self.allocator.dupe(u8, name);
        const value_dup = try self.allocator.dupe(u8, expanded);

        // Free old values if they exist
        if (self.env.fetchRemove(name)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
        if (self.exports.fetchRemove(name)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }

        try self.env.put(self.allocator, name_dup, value_dup);
        const name_dup2 = try self.allocator.dupe(u8, name);
        const value_dup2 = try self.allocator.dupe(u8, expanded);
        try self.exports.put(self.allocator, name_dup2, value_dup2);
    }

    fn expandVars(self: *EnvContext, value: []const u8) ![]const u8 {
        var result = std.ArrayListUnmanaged(u8){};
        defer result.deinit(self.allocator);

        var i: usize = 0;
        while (i < value.len) {
            if (value[i] == '$') {
                if (i + 1 < value.len and value[i + 1] == '{') {
                    // ${VAR} syntax
                    if (std.mem.indexOfPos(u8, value, i + 2, "}")) |end| {
                        const var_name = value[i + 2 .. end];
                        const var_value = self.getVar(var_name);
                        try result.appendSlice(self.allocator, var_value);
                        i = end + 1;
                        continue;
                    }
                } else if (i + 1 < value.len) {
                    // $VAR syntax
                    var end = i + 1;
                    while (end < value.len and (std.ascii.isAlphanumeric(value[end]) or value[end] == '_')) {
                        end += 1;
                    }
                    if (end > i + 1) {
                        const var_name = value[i + 1 .. end];
                        const var_value = self.getVar(var_name);
                        try result.appendSlice(self.allocator, var_value);
                        i = end;
                        continue;
                    }
                }
            }
            try result.append(self.allocator, value[i]);
            i += 1;
        }

        return try result.toOwnedSlice(self.allocator);
    }

    fn getVar(self: *EnvContext, name: []const u8) []const u8 {
        // Check our local env first, then system env
        if (self.env.get(name)) |v| return v;
        return std.posix.getenv(name) orelse "";
    }

    fn pathAdd(self: *EnvContext, var_name: []const u8, paths: []const []const u8) !void {
        if (paths.len == 0) return;

        const current = self.getVar(var_name);

        // Build new path value
        var new_path = std.ArrayListUnmanaged(u8){};
        defer new_path.deinit(self.allocator);

        for (paths) |p| {
            const expanded = try self.expandPath(p);
            defer if (expanded.ptr != p.ptr) self.allocator.free(expanded);

            if (new_path.items.len > 0) try new_path.append(self.allocator, ':');
            try new_path.appendSlice(self.allocator, expanded);
        }

        if (current.len > 0) {
            try new_path.append(self.allocator, ':');
            try new_path.appendSlice(self.allocator, current);
        }

        // Create assignment
        const name_dup = try self.allocator.dupe(u8, var_name);
        const value_dup = try new_path.toOwnedSlice(self.allocator);

        if (self.env.fetchRemove(var_name)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
        if (self.exports.fetchRemove(var_name)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }

        try self.env.put(self.allocator, name_dup, value_dup);
        const name_dup2 = try self.allocator.dupe(u8, var_name);
        const value_dup2 = try self.allocator.dupe(u8, value_dup);
        try self.exports.put(self.allocator, name_dup2, value_dup2);
    }

    fn expandPath(self: *EnvContext, path: []const u8) ![]const u8 {
        // Handle relative paths
        if (path.len == 0) return path;

        if (path[0] == '/') return path;

        if (path[0] == '~') {
            const home = std.posix.getenv("HOME") orelse return path;
            const result = try self.allocator.alloc(u8, home.len + path.len - 1);
            @memcpy(result[0..home.len], home);
            @memcpy(result[home.len..], path[1..]);
            return result;
        }

        // Relative to base_dir
        return try std.fs.path.join(self.allocator, &.{ self.base_dir, path });
    }

    fn sourceEnv(self: *EnvContext, args: []const []const u8) !void {
        const path = if (args.len > 0) args[0] else ".envrc";
        const full_path = try self.expandPath(path);
        defer if (full_path.ptr != path.ptr) self.allocator.free(full_path);

        const dir = std.fs.path.dirname(full_path) orelse self.base_dir;
        try self.executeEnvrc(full_path, dir);
    }

    fn sourceUp(self: *EnvContext) !void {
        // Find .envrc in parent directories
        const current = try self.allocator.dupe(u8, self.base_dir);
        defer self.allocator.free(current);

        // Skip current directory
        const parent = std.fs.path.dirname(current) orelse return error.NotFound;
        var search_dir = try self.allocator.dupe(u8, parent);
        defer self.allocator.free(search_dir);

        while (true) {
            const envrc_path = try std.fs.path.join(self.allocator, &.{ search_dir, ".envrc" });
            defer self.allocator.free(envrc_path);

            if (fileExists(envrc_path)) {
                try self.executeEnvrc(envrc_path, search_dir);
                return;
            }

            const next_parent = std.fs.path.dirname(search_dir) orelse return error.NotFound;
            if (std.mem.eql(u8, next_parent, search_dir)) return error.NotFound;

            const new_dir = try self.allocator.dupe(u8, next_parent);
            self.allocator.free(search_dir);
            search_dir = new_dir;
        }
    }

    fn loadDotenv(self: *EnvContext, args: []const []const u8) !void {
        const path = if (args.len > 0) args[0] else ".env";
        const full_path = try self.expandPath(path);
        defer if (full_path.ptr != path.ptr) self.allocator.free(full_path);

        const content = try readFile(self.allocator, full_path);
        defer self.allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |raw_line| {
            const line = std.mem.trim(u8, raw_line, " \t\r");
            if (line.len == 0 or line[0] == '#') continue;

            // Parse KEY=VALUE
            if (std.mem.indexOf(u8, line, "=")) |_| {
                try self.handleExport(line);
            }
        }
    }

    fn handleLayout(self: *EnvContext, args: []const []const u8) !void {
        if (args.len == 0) return;

        const layout_type = args[0];

        if (std.mem.eql(u8, layout_type, "python") or std.mem.eql(u8, layout_type, "python3")) {
            try self.layoutPython(args[1..]);
        } else if (std.mem.eql(u8, layout_type, "node")) {
            try self.layoutNode();
        } else if (std.mem.eql(u8, layout_type, "go")) {
            try self.layoutGo();
        } else if (std.mem.eql(u8, layout_type, "ruby")) {
            try self.layoutRuby();
        } else if (std.mem.eql(u8, layout_type, "pipenv")) {
            try self.layoutPipenv();
        } else if (std.mem.eql(u8, layout_type, "poetry")) {
            try self.layoutPoetry();
        }
    }

    fn layoutPython(self: *EnvContext, args: []const []const u8) !void {
        const python_cmd = if (args.len > 0) args[0] else "python3";

        // Get python version
        const version = getPythonVersion(self.allocator, python_cmd) catch "3";
        defer self.allocator.free(version);

        // Create venv directory path
        const venv_name = try std.fmt.allocPrint(self.allocator, "python-{s}", .{version});
        defer self.allocator.free(venv_name);

        const direnv_dir = try std.fs.path.join(self.allocator, &.{ self.base_dir, ".direnv" });
        defer self.allocator.free(direnv_dir);

        const venv_path = try std.fs.path.join(self.allocator, &.{ direnv_dir, venv_name });
        defer self.allocator.free(venv_path);

        // Set VIRTUAL_ENV
        const name1 = try self.allocator.dupe(u8, "VIRTUAL_ENV");
        const value1 = try self.allocator.dupe(u8, venv_path);
        if (self.env.fetchRemove("VIRTUAL_ENV")) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
        try self.env.put(self.allocator, name1, value1);
        const name1b = try self.allocator.dupe(u8, "VIRTUAL_ENV");
        const value1b = try self.allocator.dupe(u8, venv_path);
        if (self.exports.fetchRemove("VIRTUAL_ENV")) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
        try self.exports.put(self.allocator, name1b, value1b);

        // Add venv/bin to PATH
        const bin_path = try std.fs.path.join(self.allocator, &.{ venv_path, "bin" });
        defer self.allocator.free(bin_path);

        var paths = [_][]const u8{bin_path};
        try self.pathAdd("PATH", &paths);

        // Unset PYTHONHOME
        const name2 = try self.allocator.dupe(u8, "PYTHONHOME");
        const value2 = try self.allocator.dupe(u8, "");
        if (self.exports.fetchRemove("PYTHONHOME")) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
        try self.exports.put(self.allocator, name2, value2);
    }

    fn layoutNode(self: *EnvContext) !void {
        // Add node_modules/.bin to PATH
        const bin_path = try std.fs.path.join(self.allocator, &.{ self.base_dir, "node_modules", ".bin" });
        defer self.allocator.free(bin_path);

        var paths = [_][]const u8{bin_path};
        try self.pathAdd("PATH", &paths);
    }

    fn layoutGo(self: *EnvContext) !void {
        // Set GOPATH to .direnv/go
        const go_path = try std.fs.path.join(self.allocator, &.{ self.base_dir, ".direnv", "go" });
        defer self.allocator.free(go_path);

        const name = try self.allocator.dupe(u8, "GOPATH");
        const value = try self.allocator.dupe(u8, go_path);
        if (self.env.fetchRemove("GOPATH")) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
        try self.env.put(self.allocator, name, value);
        const name2 = try self.allocator.dupe(u8, "GOPATH");
        const value2 = try self.allocator.dupe(u8, go_path);
        if (self.exports.fetchRemove("GOPATH")) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
        try self.exports.put(self.allocator, name2, value2);

        // Add GOPATH/bin to PATH
        const bin_path = try std.fs.path.join(self.allocator, &.{ go_path, "bin" });
        defer self.allocator.free(bin_path);

        var paths = [_][]const u8{bin_path};
        try self.pathAdd("PATH", &paths);
    }

    fn layoutRuby(self: *EnvContext) !void {
        // Set GEM_HOME
        const gem_home = try std.fs.path.join(self.allocator, &.{ self.base_dir, ".direnv", "ruby" });
        defer self.allocator.free(gem_home);

        const name = try self.allocator.dupe(u8, "GEM_HOME");
        const value = try self.allocator.dupe(u8, gem_home);
        if (self.env.fetchRemove("GEM_HOME")) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
        try self.env.put(self.allocator, name, value);
        const name2 = try self.allocator.dupe(u8, "GEM_HOME");
        const value2 = try self.allocator.dupe(u8, gem_home);
        if (self.exports.fetchRemove("GEM_HOME")) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
        try self.exports.put(self.allocator, name2, value2);

        // Add GEM_HOME/bin to PATH
        const bin_path = try std.fs.path.join(self.allocator, &.{ gem_home, "bin" });
        defer self.allocator.free(bin_path);

        var paths = [_][]const u8{bin_path};
        try self.pathAdd("PATH", &paths);
    }

    fn layoutPipenv(self: *EnvContext) !void {
        // Set PIPENV_PIPFILE
        const pipfile = try std.fs.path.join(self.allocator, &.{ self.base_dir, "Pipfile" });
        defer self.allocator.free(pipfile);

        const name = try self.allocator.dupe(u8, "PIPENV_PIPFILE");
        const value = try self.allocator.dupe(u8, pipfile);
        if (self.env.fetchRemove("PIPENV_PIPFILE")) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
        try self.env.put(self.allocator, name, value);
        const name2 = try self.allocator.dupe(u8, "PIPENV_PIPFILE");
        const value2 = try self.allocator.dupe(u8, pipfile);
        if (self.exports.fetchRemove("PIPENV_PIPFILE")) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
        try self.exports.put(self.allocator, name2, value2);

        // Also do python layout
        var empty: [0][]const u8 = .{};
        try self.layoutPython(&empty);
    }

    fn layoutPoetry(self: *EnvContext) !void {
        // Poetry uses its own venv management, but we can set up PATH
        const venv_path = try std.fs.path.join(self.allocator, &.{ self.base_dir, ".venv" });
        defer self.allocator.free(venv_path);

        const name = try self.allocator.dupe(u8, "VIRTUAL_ENV");
        const value = try self.allocator.dupe(u8, venv_path);
        if (self.env.fetchRemove("VIRTUAL_ENV")) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
        try self.env.put(self.allocator, name, value);
        const name2 = try self.allocator.dupe(u8, "VIRTUAL_ENV");
        const value2 = try self.allocator.dupe(u8, venv_path);
        if (self.exports.fetchRemove("VIRTUAL_ENV")) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
        try self.exports.put(self.allocator, name2, value2);

        const bin_path = try std.fs.path.join(self.allocator, &.{ venv_path, "bin" });
        defer self.allocator.free(bin_path);

        var paths = [_][]const u8{bin_path};
        try self.pathAdd("PATH", &paths);
    }

    fn handleUse(self: *EnvContext, args: []const []const u8) !void {
        if (args.len == 0) return;

        const use_type = args[0];

        if (std.mem.eql(u8, use_type, "nvm")) {
            try self.useNvm();
        } else if (std.mem.eql(u8, use_type, "node")) {
            try self.useNode(args[1..]);
        } else if (std.mem.eql(u8, use_type, "python")) {
            try self.layoutPython(args[1..]);
        }
    }

    fn useNvm(self: *EnvContext) !void {
        // Look for .nvmrc
        const nvmrc_path = try std.fs.path.join(self.allocator, &.{ self.base_dir, ".nvmrc" });
        defer self.allocator.free(nvmrc_path);

        const version = readFile(self.allocator, nvmrc_path) catch return;
        defer self.allocator.free(version);

        const trimmed = std.mem.trim(u8, version, " \t\r\n");

        // Try to find node in common locations
        const home = std.posix.getenv("HOME") orelse return;

        // Try ~/.nvm/versions/node/v{version}/bin
        const nvm_path = try std.fmt.allocPrint(self.allocator, "{s}/.nvm/versions/node/v{s}/bin", .{ home, trimmed });
        defer self.allocator.free(nvm_path);

        if (fileExists(nvm_path)) {
            var paths = [_][]const u8{nvm_path};
            try self.pathAdd("PATH", &paths);
        }
    }

    fn useNode(self: *EnvContext, args: []const []const u8) !void {
        if (args.len == 0) {
            try self.useNvm();
            return;
        }

        const version = args[0];
        const home = std.posix.getenv("HOME") orelse return;

        const nvm_path = try std.fmt.allocPrint(self.allocator, "{s}/.nvm/versions/node/v{s}/bin", .{ home, version });
        defer self.allocator.free(nvm_path);

        if (fileExists(nvm_path)) {
            var paths = [_][]const u8{nvm_path};
            try self.pathAdd("PATH", &paths);
        }
    }

    fn watchDir(self: *EnvContext, args: []const []const u8) !void {
        // For directories, we store a special entry "dir:<path>" and compute max mtime at check time
        for (args) |dir_path| {
            const marker = try std.fmt.allocPrint(self.allocator, "dir:{s}", .{dir_path});
            try self.watch_files.append(self.allocator, marker);
        }
    }

    fn outputExports(self: *EnvContext, allocator: std.mem.Allocator, writer: std.fs.File, stderr: std.fs.File, envrc_dir: []const u8) !void {
        // Collect added vars and build NOENV_VARS tracking string
        var added = std.ArrayListUnmanaged([]const u8){};
        defer added.deinit(allocator);
        var tracked_vars = std.ArrayListUnmanaged(u8){};
        defer tracked_vars.deinit(allocator);

        var it = self.exports.iterator();
        while (it.next()) |entry| {
            const key = entry.key_ptr.*;
            const value = entry.value_ptr.*;

            if (value.len == 0) {
                // Unset - don't track
                try writer.writeAll("unset ");
                try writer.writeAll(key);
                try writer.writeAll(";\n");
            } else {
                // Track this var
                if (tracked_vars.items.len > 0) try tracked_vars.append(allocator, ':');
                try tracked_vars.appendSlice(allocator, key);

                // Check if this is a new or changed value
                const current = std.posix.getenv(key);
                if (current == null or !std.mem.eql(u8, current.?, value)) {
                    try added.append(allocator, key);
                }

                // Export - escape single quotes in value
                try writer.writeAll("export ");
                try writer.writeAll(key);
                try writer.writeAll("='");
                for (value) |c| {
                    if (c == '\'') {
                        try writer.writeAll("'\\''");
                    } else {
                        try writer.writeAll(&[_]u8{c});
                    }
                }
                try writer.writeAll("';\n");
            }
        }

        // Export tracking vars
        try writer.writeAll("export NOENV_VARS='");
        try writer.writeAll(tracked_vars.items);
        try writer.writeAll("';\n");
        try writer.writeAll("export NOENV_DIR='");
        try writer.writeAll(envrc_dir);
        try writer.writeAll("';\n");

        // Build watch list with mtimes from watch_files (already includes .env and .envrc files)
        var watch_str = std.ArrayListUnmanaged(u8){};
        defer watch_str.deinit(allocator);

        // Track seen paths to avoid duplicates
        var seen = std.StringHashMapUnmanaged(void){};
        defer seen.deinit(allocator);

        // Add watched files (deduplicated)
        for (self.watch_files.items) |f| {
            // Handle dir: prefix specially
            const is_dir = std.mem.startsWith(u8, f, "dir:");
            const path_part = if (is_dir) f[4..] else f;

            const full_path = self.expandPath(path_part) catch continue;
            defer if (full_path.ptr != path_part.ptr) self.allocator.free(full_path);

            // Skip duplicates
            if (seen.contains(full_path)) continue;
            seen.put(allocator, full_path, {}) catch continue;

            // Get mtime (for dirs, use getDirMaxMtime)
            const mtime = if (is_dir)
                getDirMaxMtime(allocator, full_path, full_path)
            else
                getFileMtime(allocator, full_path, full_path);

            if (mtime) |m| {
                if (watch_str.items.len > 0) try watch_str.append(allocator, '|');
                var buf: [64]u8 = undefined;
                const mtime_str = std.fmt.bufPrint(&buf, "{d}", .{m}) catch continue;
                if (is_dir) {
                    try watch_str.appendSlice(allocator, "dir:");
                }
                try watch_str.appendSlice(allocator, full_path);
                try watch_str.append(allocator, ':');
                try watch_str.appendSlice(allocator, mtime_str);
            }
        }

        try writer.writeAll("export NOENV_WATCH='");
        try writer.writeAll(watch_str.items);
        try writer.writeAll("';\n");

        // Print summary to stderr
        if (added.items.len > 0) {
            const home = std.posix.getenv("HOME") orelse "";
            stderr.writeAll("noenv: ~") catch {};
            if (home.len > 0 and std.mem.startsWith(u8, envrc_dir, home)) {
                stderr.writeAll(envrc_dir[home.len..]) catch {};
            } else {
                stderr.writeAll(envrc_dir) catch {};
            }
            stderr.writeAll(" \x1b[32m+") catch {};
            for (added.items, 0..) |key, i| {
                if (i > 0) stderr.writeAll(" ") catch {};
                stderr.writeAll(key) catch {};
            }
            stderr.writeAll("\x1b[0m\n") catch {};
        }
    }
};

fn findEnvrc(allocator: std.mem.Allocator, start_path: []const u8) !?[]u8 {
    var current = try allocator.dupe(u8, start_path);

    while (true) {
        // Check for .envrc first
        const envrc_path = try std.fs.path.join(allocator, &.{ current, ".envrc" });
        if (fileExists(envrc_path)) {
            allocator.free(current);
            return envrc_path;
        }
        allocator.free(envrc_path);

        // Fall back to .env if no .envrc
        const env_path = try std.fs.path.join(allocator, &.{ current, ".env" });
        if (fileExists(env_path)) {
            allocator.free(current);
            return env_path;
        }
        allocator.free(env_path);

        const parent = std.fs.path.dirname(current) orelse {
            allocator.free(current);
            return null;
        };

        if (std.mem.eql(u8, parent, current)) {
            allocator.free(current);
            return null;
        }

        const new_current = try allocator.dupe(u8, parent);
        allocator.free(current);
        current = new_current;
    }
}

fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    const stat = try file.stat();
    if (stat.size > 1024 * 1024) return error.FileTooLarge; // 1MB limit

    const content = try allocator.alloc(u8, stat.size);
    errdefer allocator.free(content);

    const read = try file.readAll(content);
    if (read != stat.size) {
        allocator.free(content);
        return error.IncompleteRead;
    }

    // Trim trailing newlines
    var end = content.len;
    while (end > 0 and (content[end - 1] == '\n' or content[end - 1] == '\r')) {
        end -= 1;
    }

    if (end != content.len) {
        const trimmed = try allocator.dupe(u8, content[0..end]);
        allocator.free(content);
        return trimmed;
    }

    return content;
}

fn fileExists(path: []const u8) bool {
    std.fs.accessAbsolute(path, .{}) catch return false;
    return true;
}

fn isValidVarName(name: []const u8) bool {
    if (name.len == 0) return false;
    if (!std.ascii.isAlphabetic(name[0]) and name[0] != '_') return false;
    for (name[1..]) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_') return false;
    }
    return true;
}

fn getPythonVersion(allocator: std.mem.Allocator, python_cmd: []const u8) ![]u8 {
    // Try to run python --version
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ python_cmd, "-c", "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" },
    }) catch {
        return try allocator.dupe(u8, "3");
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const trimmed = std.mem.trim(u8, result.stdout, " \t\r\n");
    if (trimmed.len == 0) return try allocator.dupe(u8, "3");

    return try allocator.dupe(u8, trimmed);
}
