///usr/bin/env zig run "$0" -- "$@"; exit
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.fs.File.stdout();

    // Get environment variables
    const home = std.posix.getenv("HOME") orelse "";
    const pwd = std.posix.getenv("PWD") orelse ".";
    const columns_str = std.posix.getenv("COLUMNS") orelse "80";
    const columns = std.fmt.parseInt(usize, columns_str, 10) catch 80;

    // Check if we're on a remote machine (SSH connection)
    const is_remote = std.posix.getenv("SSH_CONNECTION") != null;

    // Check if in git repo
    var repo: ?GitRepo = GitRepo.find(allocator, pwd) catch null;
    defer if (repo) |*r| r.deinit();

    const is_worktree = if (repo) |*r| r.isWorktree() catch false else false;
    const branch = if (repo) |*r| r.branch() catch null else null;
    defer if (branch) |b| allocator.free(b);

    // Start building prompt
    try stdout.writeAll(Color.bright_black);

    // Show hostname if remote
    if (is_remote) {
        const hostname = getHostname(allocator) catch "unknown";
        defer if (!std.mem.eql(u8, hostname, "unknown")) allocator.free(hostname);
        try stdout.writeAll(Icons.server);
        try stdout.writeAll(hostname);
        try stdout.writeAll(" ");
    }

    // Git icon (yellow)
    if (repo != null) {
        try stdout.writeAll(Color.yellow);
        try stdout.writeAll(if (is_worktree) Icons.worktree else Icons.folder);
        try stdout.writeAll(Color.bright_black);
    }

    // Path
    if (repo) |r| {
        var repo_path: []const u8 = r.root;

        // Worktree: show original repo path
        const common_dir = if (is_worktree) r.commonDir() catch null else null;
        defer if (common_dir) |cd| allocator.free(cd);
        if (common_dir) |cd| {
            if (std.fs.path.dirname(cd)) |dir| repo_path = dir;
        }

        // Replace home with ~
        const display_path = tildePath(allocator, repo_path, home) catch repo_path;
        defer if (display_path.ptr != repo_path.ptr) allocator.free(display_path);

        const parent = std.fs.path.dirname(display_path);
        const basename = std.fs.path.basename(display_path);

        // Print parent path
        if (parent) |p| {
            if (!std.mem.eql(u8, p, ".")) {
                try stdout.writeAll(p);
                try stdout.writeAll("/");
            }
        }

        // Print repo name in bold
        try stdout.writeAll(Color.bold);
        try stdout.writeAll(basename);
        try stdout.writeAll(Color.reset);
        try stdout.writeAll(Color.bright_black);

        // Print relative path from repo root
        if (pwd.len > r.root.len and std.mem.startsWith(u8, pwd, r.root)) {
            const rel_path = pwd[r.root.len..];
            if (rel_path.len > 0 and rel_path[0] == '/') {
                try stdout.writeAll(rel_path);
            }
        }
    } else {
        // Not in git repo
        const display_path = tildePath(allocator, pwd, home) catch pwd;
        defer if (display_path.ptr != pwd.ptr) allocator.free(display_path);
        try stdout.writeAll(display_path);
    }

    // Branch
    if (branch) |b| {
        const max_branch_len = if (columns > 13) columns - 13 else 20;
        try stdout.writeAll(" ");
        try stdout.writeAll(Color.yellow);
        try stdout.writeAll(Icons.branch);

        if (b.len > max_branch_len) {
            try stdout.writeAll(b[0 .. max_branch_len - 3]);
            try stdout.writeAll("...");
        } else {
            try stdout.writeAll(b);
        }
        try stdout.writeAll(Color.bright_black);
    }

    try stdout.writeAll(Color.reset);
    try stdout.writeAll("\n");

    // Prompt symbol
    try stdout.writeAll(Color.bold_red);
    try stdout.writeAll("$ ");
    try stdout.writeAll(Color.reset);
}

fn tildePath(allocator: std.mem.Allocator, path: []const u8, home: []const u8) ![]const u8 {
    if (home.len > 0 and std.mem.startsWith(u8, path, home)) {
        const result = try allocator.alloc(u8, 1 + path.len - home.len);
        result[0] = '~';
        @memcpy(result[1..], path[home.len..]);
        return result;
    }
    return path;
}

fn getHostname(allocator: std.mem.Allocator) ![]u8 {
    // Use HOSTNAME environment variable if present
    const hostname_str = if (std.posix.getenv("HOSTNAME")) |env_hostname|
        env_hostname
    else blk: {
        // Fallback to gethostname syscall
        var buf: [std.posix.HOST_NAME_MAX]u8 = undefined;
        const result = std.posix.gethostname(&buf) catch return error.CannotGetHostname;
        break :blk result;
    };

    // Remove .local or .lan suffix if present
    var end = hostname_str.len;
    if (std.mem.endsWith(u8, hostname_str, ".local")) {
        end = hostname_str.len - 6;
    } else if (std.mem.endsWith(u8, hostname_str, ".lan")) {
        end = hostname_str.len - 4;
    }

    return allocator.dupe(u8, hostname_str[0..end]);
}

const GitRepo = struct {
    allocator: std.mem.Allocator,
    git_dir: []u8,
    root: []u8,

    fn find(allocator: std.mem.Allocator, start_path: []const u8) !GitRepo {
        var current = try allocator.dupe(u8, start_path);

        while (true) {
            const git_path = try std.fs.path.join(allocator, &.{ current, ".git" });
            defer allocator.free(git_path);

            const stat_result = std.fs.cwd().statFile(git_path);
            if (stat_result) |stat| {
                if (stat.kind == .directory) {
                    return .{
                        .allocator = allocator,
                        .git_dir = try allocator.dupe(u8, git_path),
                        .root = current,
                    };
                } else if (stat.kind == .file) {
                    // Worktree - .git is a file containing "gitdir: <path>"
                    const content = try readFile(allocator, git_path);
                    defer allocator.free(content);

                    if (std.mem.startsWith(u8, content, "gitdir: ")) {
                        const gitdir_ref = content[8..];
                        const git_dir = if (gitdir_ref[0] != '/')
                            try std.fs.path.resolve(allocator, &.{ current, gitdir_ref })
                        else
                            try allocator.dupe(u8, gitdir_ref);
                        return .{ .allocator = allocator, .git_dir = git_dir, .root = current };
                    }
                    allocator.free(current);
                    return error.InvalidGitFile;
                }
            } else |err| {
                if (err != error.FileNotFound) {
                    allocator.free(current);
                    return err;
                }
            }

            // Go up one directory
            const parent = std.fs.path.dirname(current) orelse {
                allocator.free(current);
                return error.NotGitRepo;
            };
            if (std.mem.eql(u8, parent, current)) {
                allocator.free(current);
                return error.NotGitRepo;
            }
            const new_current = try allocator.dupe(u8, parent);
            allocator.free(current);
            current = new_current;
        }
    }

    fn deinit(self: *GitRepo) void {
        self.allocator.free(self.git_dir);
        self.allocator.free(self.root);
    }

    fn commonDir(self: *const GitRepo) ![]u8 {
        const path = try std.fs.path.join(self.allocator, &.{ self.git_dir, "commondir" });
        defer self.allocator.free(path);

        if (readFile(self.allocator, path)) |content| {
            defer self.allocator.free(content);
            if (content[0] != '/') {
                return std.fs.path.resolve(self.allocator, &.{ self.git_dir, content });
            }
            return self.allocator.dupe(u8, content);
        } else |_| {
            return self.allocator.dupe(u8, self.git_dir);
        }
    }

    fn branch(self: *const GitRepo) ![]u8 {
        const path = try std.fs.path.join(self.allocator, &.{ self.git_dir, "HEAD" });
        defer self.allocator.free(path);

        const content = try readFile(self.allocator, path);
        defer self.allocator.free(content);

        if (std.mem.startsWith(u8, content, "ref: refs/heads/")) {
            return self.allocator.dupe(u8, content[16..]);
        } else if (std.mem.startsWith(u8, content, "ref: ")) {
            return self.allocator.dupe(u8, content[5..]);
        }
        // Detached HEAD - short hash
        return self.allocator.dupe(u8, content[0..@min(content.len, 7)]);
    }

    fn isWorktree(self: *const GitRepo) !bool {
        const common = try self.commonDir();
        defer self.allocator.free(common);
        return !std.mem.eql(u8, self.git_dir, common);
    }

    fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
        const file = try std.fs.openFileAbsolute(path, .{});
        defer file.close();

        var buf: [4096]u8 = undefined;
        const len = try file.readAll(&buf);
        if (len == 0) return error.NoOutput;

        var end = len;
        while (end > 0 and (buf[end - 1] == '\n' or buf[end - 1] == '\r')) end -= 1;

        const result = try allocator.alloc(u8, end);
        @memcpy(result, buf[0..end]);
        return result;
    }
};

const Color = struct {
    // Wrapped in \x01...\x02 so readline knows these bytes are invisible.
    // Without this, Ctrl+A miscalculates the start of input position.
    const reset = "\x01\x1b[0m\x02";
    const bold = "\x01\x1b[1m\x02";
    const yellow = "\x01\x1b[33m\x02";
    const green = "\x01\x1b[32m\x02";
    const bright_black = "\x01\x1b[90m\x02";
    const bold_red = "\x01\x1b[1;31m\x02";
};

const Icons = struct {
    const server = "\u{EB3A} ";
    const folder = "\u{F401} ";
    const worktree = "\u{F52E} ";
    const branch = "\u{F418} ";
};
