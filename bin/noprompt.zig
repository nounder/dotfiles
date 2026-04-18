///usr/bin/env zig run "$0" -- "$@"; exit
const std = @import("std");
const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    const env = init.environ_map;

    var stdout_buf: [4096]u8 = undefined;
    var stdout_w = Io.File.stdout().writer(io, &stdout_buf);
    const stdout: *Io.Writer = &stdout_w.interface;
    defer stdout.flush() catch {};

    const home = env.get("HOME") orelse "";
    const pwd = env.get("PWD") orelse ".";
    const columns_str = env.get("COLUMNS") orelse "80";
    const columns = std.fmt.parseInt(usize, columns_str, 10) catch 80;

    const is_remote = env.get("SSH_CONNECTION") != null;

    var repo: ?GitRepo = GitRepo.find(gpa, io, pwd) catch null;
    defer if (repo) |*r| r.deinit();

    const is_worktree = if (repo) |*r| r.isWorktree() catch false else false;
    const branch = if (repo) |*r| r.branch() catch null else null;
    defer if (branch) |b| gpa.free(b);

    try stdout.writeAll(Color.bright_black);

    if (is_remote) {
        const hostname = getHostname(gpa, env) catch "unknown";
        defer if (!std.mem.eql(u8, hostname, "unknown")) gpa.free(hostname);
        try stdout.writeAll(Icons.server);
        try stdout.writeAll(hostname);
        try stdout.writeAll(" ");
    }

    if (repo != null) {
        try stdout.writeAll(Color.yellow);
        try stdout.writeAll(if (is_worktree) Icons.worktree else Icons.folder);
        try stdout.writeAll(Color.bright_black);
    }

    if (repo) |r| {
        var repo_path: []const u8 = r.root;

        const common_dir = if (is_worktree) r.commonDir() catch null else null;
        defer if (common_dir) |cd| gpa.free(cd);
        if (common_dir) |cd| {
            if (std.fs.path.dirname(cd)) |dir| repo_path = dir;
        }

        const display_path = tildePath(gpa, repo_path, home) catch repo_path;
        defer if (display_path.ptr != repo_path.ptr) gpa.free(display_path);

        const parent = std.fs.path.dirname(display_path);
        const basename = std.fs.path.basename(display_path);

        if (parent) |p| {
            if (!std.mem.eql(u8, p, ".")) {
                try stdout.writeAll(p);
                try stdout.writeAll("/");
            }
        }

        try stdout.writeAll(Color.bold);
        try stdout.writeAll(basename);
        try stdout.writeAll(Color.reset);
        try stdout.writeAll(Color.bright_black);

        if (pwd.len > r.root.len and std.mem.startsWith(u8, pwd, r.root)) {
            const rel_path = pwd[r.root.len..];
            if (rel_path.len > 0 and rel_path[0] == '/') {
                try stdout.writeAll(rel_path);
            }
        }
    } else {
        const display_path = tildePath(gpa, pwd, home) catch pwd;
        defer if (display_path.ptr != pwd.ptr) gpa.free(display_path);
        try stdout.writeAll(display_path);
    }

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

fn getHostname(allocator: std.mem.Allocator, env: *std.process.Environ.Map) ![]u8 {
    const hostname_str = if (env.get("HOSTNAME")) |env_hostname|
        env_hostname
    else blk: {
        var buf: [std.posix.HOST_NAME_MAX]u8 = undefined;
        const result = std.posix.gethostname(&buf) catch return error.CannotGetHostname;
        break :blk result;
    };

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
    io: Io,
    git_dir: []u8,
    root: []u8,

    fn find(allocator: std.mem.Allocator, io: Io, start_path: []const u8) !GitRepo {
        var current = try allocator.dupe(u8, start_path);

        while (true) {
            const git_path = try std.fs.path.join(allocator, &.{ current, ".git" });
            defer allocator.free(git_path);

            const stat_result = Io.Dir.cwd().statFile(io, git_path, .{});
            if (stat_result) |stat| {
                if (stat.kind == .directory) {
                    return .{
                        .allocator = allocator,
                        .io = io,
                        .git_dir = try allocator.dupe(u8, git_path),
                        .root = current,
                    };
                } else if (stat.kind == .file) {
                    const content = try readFile(allocator, io, git_path);
                    defer allocator.free(content);

                    if (std.mem.startsWith(u8, content, "gitdir: ")) {
                        const gitdir_ref = content[8..];
                        const git_dir = if (gitdir_ref[0] != '/')
                            try std.fs.path.resolve(allocator, &.{ current, gitdir_ref })
                        else
                            try allocator.dupe(u8, gitdir_ref);
                        return .{ .allocator = allocator, .io = io, .git_dir = git_dir, .root = current };
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

        if (readFile(self.allocator, self.io, path)) |content| {
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

        const content = try readFile(self.allocator, self.io, path);
        defer self.allocator.free(content);

        if (std.mem.startsWith(u8, content, "ref: refs/heads/")) {
            return self.allocator.dupe(u8, content[16..]);
        } else if (std.mem.startsWith(u8, content, "ref: ")) {
            return self.allocator.dupe(u8, content[5..]);
        }
        return self.allocator.dupe(u8, content[0..@min(content.len, 7)]);
    }

    fn isWorktree(self: *const GitRepo) !bool {
        const common = try self.commonDir();
        defer self.allocator.free(common);
        return !std.mem.eql(u8, self.git_dir, common);
    }
};

fn readFile(allocator: std.mem.Allocator, io: Io, path: []const u8) ![]u8 {
    const file = try Io.Dir.openFileAbsolute(io, path, .{});
    defer file.close(io);

    var buf: [4096]u8 = undefined;
    var fr = file.reader(io, &.{});
    const len = fr.interface.readSliceShort(&buf) catch |err| switch (err) {
        error.ReadFailed => return fr.err.?,
    };
    if (len == 0) return error.NoOutput;

    var end = len;
    while (end > 0 and (buf[end - 1] == '\n' or buf[end - 1] == '\r')) end -= 1;

    const result = try allocator.alloc(u8, end);
    @memcpy(result, buf[0..end]);
    return result;
}

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
