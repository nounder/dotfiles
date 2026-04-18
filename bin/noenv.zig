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
const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const arena = init.arena.allocator();
    const io = init.io;
    const env = init.environ_map;

    const args = try init.minimal.args.toSlice(arena);

    var stdout_buf: [8192]u8 = undefined;
    var stdout_w = Io.File.stdout().writer(io, &stdout_buf);
    const stdout: *Io.Writer = &stdout_w.interface;
    defer stdout.flush() catch {};

    var stderr_buf: [4096]u8 = undefined;
    var stderr_w = Io.File.stderr().writer(io, &stderr_buf);
    const stderr: *Io.Writer = &stderr_w.interface;
    defer stderr.flush() catch {};

    const pwd = env.get("PWD") orelse ".";

    if (args.len > 1) {
        const cmd = args[1];
        if (std.mem.eql(u8, cmd, "hook")) {
            try processEnvrc(gpa, io, env, pwd, stdout, stderr, true);
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

    try processEnvrc(gpa, io, env, pwd, stdout, stderr, false);
}

fn watchedFilesChanged(allocator: std.mem.Allocator, io: Io, env: *std.process.Environ.Map, envrc_path: []const u8) bool {
    const prev_watch = env.get("NOENV_WATCH") orelse return false;
    if (prev_watch.len == 0) return false;

    var it = std.mem.splitScalar(u8, prev_watch, '|');
    while (it.next()) |entry| {
        if (entry.len == 0) continue;
        const sep = std.mem.lastIndexOf(u8, entry, ":") orelse continue;
        const path = entry[0..sep];
        const mtime_str = entry[sep + 1 ..];
        const stored_mtime = std.fmt.parseInt(i128, mtime_str, 10) catch continue;

        const current_mtime = getFileMtime(allocator, io, path, envrc_path) orelse continue;
        if (current_mtime != stored_mtime) return true;
    }

    return false;
}

fn getFileMtime(allocator: std.mem.Allocator, io: Io, path: []const u8, envrc_path: []const u8) ?i128 {
    if (std.mem.startsWith(u8, path, "dir:")) {
        return getDirMaxMtime(allocator, io, path[4..], envrc_path);
    }

    var full_path: []const u8 = path;
    var need_free = false;

    if (path.len > 0 and path[0] != '/') {
        const envrc_dir = std.fs.path.dirname(envrc_path) orelse return null;
        full_path = std.fs.path.join(allocator, &.{ envrc_dir, path }) catch return null;
        need_free = true;
    }
    defer if (need_free) allocator.free(full_path);

    const stat = Io.Dir.cwd().statFile(io, full_path, .{}) catch return null;
    return @intCast(stat.mtime.nanoseconds);
}

fn getDirMaxMtime(allocator: std.mem.Allocator, io: Io, path: []const u8, envrc_path: []const u8) ?i128 {
    var full_path: []const u8 = path;
    var need_free = false;

    if (path.len > 0 and path[0] != '/') {
        const envrc_dir = std.fs.path.dirname(envrc_path) orelse return null;
        full_path = std.fs.path.join(allocator, &.{ envrc_dir, path }) catch return null;
        need_free = true;
    }
    defer if (need_free) allocator.free(full_path);

    var max_mtime: i128 = 0;

    const dir_stat = Io.Dir.cwd().statFile(io, full_path, .{}) catch return null;
    max_mtime = @intCast(dir_stat.mtime.nanoseconds);

    var dir = Io.Dir.openDirAbsolute(io, full_path, .{ .iterate = true }) catch return max_mtime;
    defer dir.close(io);

    var walker = dir.walk(allocator) catch return max_mtime;
    defer walker.deinit();

    while (walker.next(io) catch null) |entry| {
        if (entry.kind == .file) {
            const file_path = std.fs.path.join(allocator, &.{ full_path, entry.path }) catch continue;
            defer allocator.free(file_path);

            const stat = Io.Dir.cwd().statFile(io, file_path, .{}) catch continue;
            const m: i128 = @intCast(stat.mtime.nanoseconds);
            if (m > max_mtime) {
                max_mtime = m;
            }
        }
    }

    return max_mtime;
}

fn processEnvrc(allocator: std.mem.Allocator, io: Io, env: *std.process.Environ.Map, pwd: []const u8, stdout: *Io.Writer, stderr: *Io.Writer, hook_mode: bool) !void {
    var env_files: std.ArrayListUnmanaged([]const u8) = .empty;
    defer {
        for (env_files.items) |f| allocator.free(f);
        env_files.deinit(allocator);
    }

    var envrc_path: ?[]const u8 = null;
    defer if (envrc_path) |p| allocator.free(p);

    var current = try allocator.dupe(u8, pwd);
    var path_stack: std.ArrayListUnmanaged([]const u8) = .empty;
    defer path_stack.deinit(allocator);

    while (true) {
        try path_stack.append(allocator, current);

        if (envrc_path == null) {
            const envrc = try std.fs.path.join(allocator, &.{ current, ".envrc" });
            if (fileExists(io, envrc)) {
                envrc_path = envrc;
            } else {
                allocator.free(envrc);
            }
        }

        const parent = std.fs.path.dirname(current) orelse break;
        if (std.mem.eql(u8, parent, current)) break;
        current = try allocator.dupe(u8, parent);
    }

    var i: usize = path_stack.items.len;
    while (i > 0) {
        i -= 1;
        const dir = path_stack.items[i];

        const env_path = try std.fs.path.join(allocator, &.{ dir, ".env" });
        if (fileExists(io, env_path)) {
            try env_files.append(allocator, env_path);
        } else {
            allocator.free(env_path);
        }
    }

    for (path_stack.items) |p| allocator.free(p);

    if (env_files.items.len == 0 and envrc_path == null) {
        try unsetPreviousVars(env, stdout, stderr);
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

    const prev_dir = env.get("NOENV_DIR");
    if (prev_dir != null and std.mem.eql(u8, prev_dir.?, scope_dir)) {
        const check_path = envrc_path orelse if (env_files.items.len > 0) env_files.items[env_files.items.len - 1] else null;
        if (check_path) |cp| {
            if (!watchedFilesChanged(allocator, io, env, cp)) {
                return;
            }
        }
        try unsetPreviousVars(env, stdout, stderr);
    } else if (prev_dir != null) {
        try unsetPreviousVars(env, stdout, stderr);
    }

    var ctx = EnvContext.init(allocator, io, env);
    defer ctx.deinit();
    ctx.base_dir = pwd;

    for (env_files.items) |env_path| {
        ctx.loadDotenvFile(env_path) catch {};
        try ctx.watch_files.append(allocator, try allocator.dupe(u8, env_path));
    }

    if (envrc_path) |ep| {
        const envrc_dir = std.fs.path.dirname(ep) orelse pwd;
        ctx.base_dir = envrc_dir;
        ctx.executeEnvrcOnly(ep) catch {
            try stderr.writeAll("noenv: error processing .envrc\n");
        };
    }

    if (env_files.items.len > 0 or envrc_path != null) {
        try ctx.outputExports(allocator, stdout, stderr, scope_dir);
    }
}

fn unsetPreviousVars(env: *std.process.Environ.Map, stdout: *Io.Writer, stderr: *Io.Writer) !void {
    const prev_vars = env.get("NOENV_VARS") orelse return;
    const prev_dir = env.get("NOENV_DIR");
    const prev_path_adds = env.get("NOENV_PATH_ADDS");

    if (prev_vars.len == 0 and (prev_path_adds == null or prev_path_adds.?.len == 0)) return;

    var removed: std.ArrayListUnmanaged([]const u8) = .empty;
    defer removed.deinit(std.heap.page_allocator);

    if (prev_path_adds) |path_adds| {
        if (path_adds.len > 0) {
            var var_it = std.mem.splitScalar(u8, path_adds, ';');
            while (var_it.next()) |var_entry| {
                if (var_entry.len == 0) continue;
                const eq_pos = std.mem.indexOf(u8, var_entry, "=") orelse continue;
                const var_name = var_entry[0..eq_pos];
                const paths_to_remove = var_entry[eq_pos + 1 ..];

                const current_value = env.get(var_name) orelse continue;

                var new_value: std.ArrayListUnmanaged(u8) = .empty;
                defer new_value.deinit(std.heap.page_allocator);

                var path_it = std.mem.splitScalar(u8, current_value, ':');
                var first = true;
                while (path_it.next()) |path_segment| {
                    if (path_segment.len == 0) continue;

                    var should_remove = false;
                    var remove_it = std.mem.splitScalar(u8, paths_to_remove, ',');
                    while (remove_it.next()) |to_remove| {
                        if (std.mem.eql(u8, path_segment, to_remove)) {
                            should_remove = true;
                            break;
                        }
                    }

                    if (!should_remove) {
                        if (!first) new_value.append(std.heap.page_allocator, ':') catch {};
                        new_value.appendSlice(std.heap.page_allocator, path_segment) catch {};
                        first = false;
                    }
                }

                try stdout.writeAll("export ");
                try stdout.writeAll(var_name);
                try stdout.writeAll("='");
                try stdout.writeAll(new_value.items);
                try stdout.writeAll("';\n");

                removed.append(std.heap.page_allocator, var_name) catch {};
            }
        }
    }

    var it = std.mem.splitScalar(u8, prev_vars, ':');
    while (it.next()) |var_name| {
        if (var_name.len == 0) continue;
        try stdout.writeAll("unset ");
        try stdout.writeAll(var_name);
        try stdout.writeAll(";\n");
        removed.append(std.heap.page_allocator, var_name) catch {};
    }

    try stdout.writeAll("unset NOENV_VARS;\n");
    try stdout.writeAll("unset NOENV_DIR;\n");
    try stdout.writeAll("unset NOENV_WATCH;\n");
    try stdout.writeAll("unset NOENV_PATH_ADDS;\n");

    if (removed.items.len > 0) {
        stderr.writeAll("noenv: ") catch {};
        if (prev_dir) |dir| {
            stderr.writeAll("~") catch {};
            const home = env.get("HOME") orelse "";
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
    io: Io,
    sys_env: *std.process.Environ.Map,
    env: std.StringHashMapUnmanaged([]const u8),
    exports: std.StringHashMapUnmanaged([]const u8),
    watch_files: std.ArrayListUnmanaged([]const u8),
    path_adds: std.StringHashMapUnmanaged(std.ArrayListUnmanaged([]const u8)),
    base_dir: []const u8,

    fn init(allocator: std.mem.Allocator, io: Io, sys_env: *std.process.Environ.Map) EnvContext {
        return .{
            .allocator = allocator,
            .io = io,
            .sys_env = sys_env,
            .env = .empty,
            .exports = .empty,
            .watch_files = .empty,
            .path_adds = .empty,
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

        var path_it = self.path_adds.iterator();
        while (path_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            for (entry.value_ptr.items) |p| {
                self.allocator.free(p);
            }
            entry.value_ptr.deinit(self.allocator);
        }
        self.path_adds.deinit(self.allocator);
    }

    fn executeEnvrcOnly(self: *EnvContext, path: []const u8) anyerror!void {
        const content = try readFile(self.allocator, self.io, path);
        defer self.allocator.free(content);

        try self.watch_files.append(self.allocator, try self.allocator.dupe(u8, path));

        var lines = std.mem.splitScalar(u8, content, '\n');
        var stderr_buf: [4096]u8 = undefined;
        var stderr_w = Io.File.stderr().writer(self.io, &stderr_buf);
        const stderr: *Io.Writer = &stderr_w.interface;
        defer stderr.flush() catch {};

        while (lines.next()) |line| {
            self.executeLine(line) catch |err| {
                const trimmed = std.mem.trim(u8, line, " \t\r");
                if (trimmed.len == 0) continue;
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

    fn executeEnvrc(self: *EnvContext, path: []const u8, dir: []const u8) anyerror!void {
        self.base_dir = dir;
        try self.executeEnvrcOnly(path);
    }

    fn loadDotenvFile(self: *EnvContext, path: []const u8) !void {
        const content = try readFile(self.allocator, self.io, path);
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
        const line = std.mem.trim(u8, raw_line, " \t\r");

        if (line.len == 0 or line[0] == '#') return;

        if (std.mem.startsWith(u8, line, "export ")) {
            const rest = std.mem.trim(u8, line[7..], " \t");
            try self.handleExport(rest);
            return;
        }

        if (std.mem.indexOf(u8, line, "=")) |eq_pos| {
            const before_eq = line[0..eq_pos];
            if (std.mem.indexOfAny(u8, before_eq, " \t") == null and isValidVarName(before_eq)) {
                try self.handleExport(line);
                return;
            }
        }

        var parts: std.ArrayListUnmanaged([]const u8) = .empty;
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
            try self.watchDir(cmd_args);
        } else {
            return error.UnknownCommand;
        }
    }

    fn handleExport(self: *EnvContext, assignment: []const u8) !void {
        const eq_pos = std.mem.indexOf(u8, assignment, "=") orelse return;
        const name = assignment[0..eq_pos];
        var value = assignment[eq_pos + 1 ..];

        if (value.len >= 2) {
            if ((value[0] == '"' and value[value.len - 1] == '"') or
                (value[0] == '\'' and value[value.len - 1] == '\''))
            {
                value = value[1 .. value.len - 1];
            }
        }

        const expanded = try self.expandVars(value);
        defer if (expanded.ptr != value.ptr) self.allocator.free(expanded);

        const name_dup = try self.allocator.dupe(u8, name);
        const value_dup = try self.allocator.dupe(u8, expanded);

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
        var result: std.ArrayListUnmanaged(u8) = .empty;
        defer result.deinit(self.allocator);

        var i: usize = 0;
        while (i < value.len) {
            if (value[i] == '$') {
                if (i + 1 < value.len and value[i + 1] == '{') {
                    if (std.mem.indexOfPos(u8, value, i + 2, "}")) |end| {
                        const var_name = value[i + 2 .. end];
                        const var_value = self.getVar(var_name);
                        try result.appendSlice(self.allocator, var_value);
                        i = end + 1;
                        continue;
                    }
                } else if (i + 1 < value.len) {
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
        if (self.env.get(name)) |v| return v;
        return self.sys_env.get(name) orelse "";
    }

    fn pathAdd(self: *EnvContext, var_name: []const u8, paths: []const []const u8) !void {
        if (paths.len == 0) return;

        const current = self.getVar(var_name);

        var new_path: std.ArrayListUnmanaged(u8) = .empty;
        defer new_path.deinit(self.allocator);

        const gop = try self.path_adds.getOrPut(self.allocator, var_name);
        if (!gop.found_existing) {
            gop.key_ptr.* = try self.allocator.dupe(u8, var_name);
            gop.value_ptr.* = .empty;
        }

        for (paths) |p| {
            const expanded = try self.expandPath(p);
            const expanded_owned = if (expanded.ptr != p.ptr) expanded else try self.allocator.dupe(u8, expanded);

            try gop.value_ptr.append(self.allocator, expanded_owned);

            if (new_path.items.len > 0) try new_path.append(self.allocator, ':');
            try new_path.appendSlice(self.allocator, expanded_owned);
        }

        if (current.len > 0) {
            try new_path.append(self.allocator, ':');
            try new_path.appendSlice(self.allocator, current);
        }

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
        if (path.len == 0) return path;

        if (path[0] == '/') return path;

        if (path[0] == '~') {
            const home = self.sys_env.get("HOME") orelse return path;
            const result = try self.allocator.alloc(u8, home.len + path.len - 1);
            @memcpy(result[0..home.len], home);
            @memcpy(result[home.len..], path[1..]);
            return result;
        }

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
        const current = try self.allocator.dupe(u8, self.base_dir);
        defer self.allocator.free(current);

        const parent = std.fs.path.dirname(current) orelse return error.NotFound;
        var search_dir = try self.allocator.dupe(u8, parent);
        defer self.allocator.free(search_dir);

        while (true) {
            const envrc_path = try std.fs.path.join(self.allocator, &.{ search_dir, ".envrc" });
            defer self.allocator.free(envrc_path);

            if (fileExists(self.io, envrc_path)) {
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

        const content = try readFile(self.allocator, self.io, full_path);
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

        const version = getPythonVersion(self.allocator, self.io, python_cmd) catch "3";
        defer self.allocator.free(version);

        const venv_name = try std.fmt.allocPrint(self.allocator, "python-{s}", .{version});
        defer self.allocator.free(venv_name);

        const direnv_dir = try std.fs.path.join(self.allocator, &.{ self.base_dir, ".direnv" });
        defer self.allocator.free(direnv_dir);

        const venv_path = try std.fs.path.join(self.allocator, &.{ direnv_dir, venv_name });
        defer self.allocator.free(venv_path);

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

        const bin_path = try std.fs.path.join(self.allocator, &.{ venv_path, "bin" });
        defer self.allocator.free(bin_path);

        var paths = [_][]const u8{bin_path};
        try self.pathAdd("PATH", &paths);

        const name2 = try self.allocator.dupe(u8, "PYTHONHOME");
        const value2 = try self.allocator.dupe(u8, "");
        if (self.exports.fetchRemove("PYTHONHOME")) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
        try self.exports.put(self.allocator, name2, value2);
    }

    fn layoutNode(self: *EnvContext) !void {
        const bin_path = try std.fs.path.join(self.allocator, &.{ self.base_dir, "node_modules", ".bin" });
        defer self.allocator.free(bin_path);

        var paths = [_][]const u8{bin_path};
        try self.pathAdd("PATH", &paths);
    }

    fn layoutGo(self: *EnvContext) !void {
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

        const bin_path = try std.fs.path.join(self.allocator, &.{ go_path, "bin" });
        defer self.allocator.free(bin_path);

        var paths = [_][]const u8{bin_path};
        try self.pathAdd("PATH", &paths);
    }

    fn layoutRuby(self: *EnvContext) !void {
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

        const bin_path = try std.fs.path.join(self.allocator, &.{ gem_home, "bin" });
        defer self.allocator.free(bin_path);

        var paths = [_][]const u8{bin_path};
        try self.pathAdd("PATH", &paths);
    }

    fn layoutPipenv(self: *EnvContext) !void {
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

        var empty: [0][]const u8 = .{};
        try self.layoutPython(&empty);
    }

    fn layoutPoetry(self: *EnvContext) !void {
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
        const nvmrc_path = try std.fs.path.join(self.allocator, &.{ self.base_dir, ".nvmrc" });
        defer self.allocator.free(nvmrc_path);

        const version = readFile(self.allocator, self.io, nvmrc_path) catch return;
        defer self.allocator.free(version);

        const trimmed = std.mem.trim(u8, version, " \t\r\n");

        const home = self.sys_env.get("HOME") orelse return;

        const nvm_path = try std.fmt.allocPrint(self.allocator, "{s}/.nvm/versions/node/v{s}/bin", .{ home, trimmed });
        defer self.allocator.free(nvm_path);

        if (fileExists(self.io, nvm_path)) {
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
        const home = self.sys_env.get("HOME") orelse return;

        const nvm_path = try std.fmt.allocPrint(self.allocator, "{s}/.nvm/versions/node/v{s}/bin", .{ home, version });
        defer self.allocator.free(nvm_path);

        if (fileExists(self.io, nvm_path)) {
            var paths = [_][]const u8{nvm_path};
            try self.pathAdd("PATH", &paths);
        }
    }

    fn watchDir(self: *EnvContext, args: []const []const u8) !void {
        for (args) |dir_path| {
            const marker = try std.fmt.allocPrint(self.allocator, "dir:{s}", .{dir_path});
            try self.watch_files.append(self.allocator, marker);
        }
    }

    fn outputExports(self: *EnvContext, allocator: std.mem.Allocator, writer: *Io.Writer, stderr: *Io.Writer, envrc_dir: []const u8) !void {
        var added: std.ArrayListUnmanaged([]const u8) = .empty;
        defer added.deinit(allocator);
        var tracked_vars: std.ArrayListUnmanaged(u8) = .empty;
        defer tracked_vars.deinit(allocator);
        var tracked_path_adds: std.ArrayListUnmanaged(u8) = .empty;
        defer tracked_path_adds.deinit(allocator);

        var it = self.exports.iterator();
        while (it.next()) |entry| {
            const key = entry.key_ptr.*;
            const value = entry.value_ptr.*;

            const is_path_var = self.path_adds.contains(key);

            if (value.len == 0) {
                try writer.writeAll("unset ");
                try writer.writeAll(key);
                try writer.writeAll(";\n");
            } else {
                if (!is_path_var) {
                    if (tracked_vars.items.len > 0) try tracked_vars.append(allocator, ':');
                    try tracked_vars.appendSlice(allocator, key);
                }

                const current = self.sys_env.get(key);
                if (current == null or !std.mem.eql(u8, current.?, value)) {
                    try added.append(allocator, key);
                }

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

        var path_it = self.path_adds.iterator();
        while (path_it.next()) |entry| {
            const var_name = entry.key_ptr.*;
            const paths = entry.value_ptr.items;

            if (paths.len == 0) continue;

            if (tracked_path_adds.items.len > 0) try tracked_path_adds.append(allocator, ';');
            try tracked_path_adds.appendSlice(allocator, var_name);
            try tracked_path_adds.append(allocator, '=');

            for (paths, 0..) |p, i| {
                if (i > 0) try tracked_path_adds.append(allocator, ',');
                try tracked_path_adds.appendSlice(allocator, p);
            }
        }

        try writer.writeAll("export NOENV_VARS='");
        try writer.writeAll(tracked_vars.items);
        try writer.writeAll("';\n");
        try writer.writeAll("export NOENV_PATH_ADDS='");
        try writer.writeAll(tracked_path_adds.items);
        try writer.writeAll("';\n");
        try writer.writeAll("export NOENV_DIR='");
        try writer.writeAll(envrc_dir);
        try writer.writeAll("';\n");

        var watch_str: std.ArrayListUnmanaged(u8) = .empty;
        defer watch_str.deinit(allocator);

        var seen: std.StringHashMapUnmanaged(void) = .empty;
        defer seen.deinit(allocator);

        for (self.watch_files.items) |f| {
            const is_dir = std.mem.startsWith(u8, f, "dir:");
            const path_part = if (is_dir) f[4..] else f;

            const full_path = self.expandPath(path_part) catch continue;
            defer if (full_path.ptr != path_part.ptr) self.allocator.free(full_path);

            if (seen.contains(full_path)) continue;
            seen.put(allocator, full_path, {}) catch continue;

            const mtime = if (is_dir)
                getDirMaxMtime(allocator, self.io, full_path, full_path)
            else
                getFileMtime(allocator, self.io, full_path, full_path);

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

        if (added.items.len > 0) {
            const home = self.sys_env.get("HOME") orelse "";
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

fn readFile(allocator: std.mem.Allocator, io: Io, path: []const u8) ![]u8 {
    const file = try Io.Dir.openFileAbsolute(io, path, .{});
    defer file.close(io);

    const stat = try file.stat(io);
    if (stat.size > 1024 * 1024) return error.FileTooLarge;

    const size: usize = @intCast(stat.size);
    const content = try allocator.alloc(u8, size);
    errdefer allocator.free(content);

    var fr = file.reader(io, &.{});
    var dst = [_][]u8{content};
    var total: usize = 0;
    while (total < size) {
        const n = fr.interface.readSliceShort(content[total..]) catch |err| switch (err) {
            error.ReadFailed => return fr.err.?,
        };
        if (n == 0) break;
        total += n;
    }
    _ = &dst;

    if (total != size) {
        const shrunk = try allocator.realloc(content, total);
        return trimTrailingNewlines(allocator, shrunk);
    }

    return trimTrailingNewlines(allocator, content);
}

fn trimTrailingNewlines(allocator: std.mem.Allocator, content: []u8) ![]u8 {
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

fn fileExists(io: Io, path: []const u8) bool {
    Io.Dir.accessAbsolute(io, path, .{}) catch return false;
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

fn getPythonVersion(allocator: std.mem.Allocator, io: Io, python_cmd: []const u8) ![]u8 {
    const result = std.process.run(allocator, io, .{
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
