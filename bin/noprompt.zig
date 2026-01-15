///usr/bin/env zig run "$0" -- "$@"; exit
const std = @import("std");

// ANSI color codes
const Color = struct {
    // Reset
    const reset = "\x1b[0m";

    // Styles
    const bold = "\x1b[1m";
    const dim = "\x1b[2m";
    const italic = "\x1b[3m";
    const underline = "\x1b[4m";
    const blink = "\x1b[5m";
    const reverse = "\x1b[7m";
    const hidden = "\x1b[8m";
    const strikethrough = "\x1b[9m";

    // Regular colors
    const black = "\x1b[30m";
    const red = "\x1b[31m";
    const green = "\x1b[32m";
    const yellow = "\x1b[33m";
    const blue = "\x1b[34m";
    const magenta = "\x1b[35m";
    const cyan = "\x1b[36m";
    const white = "\x1b[37m";

    // Bright colors
    const bright_black = "\x1b[90m";
    const bright_red = "\x1b[91m";
    const bright_green = "\x1b[92m";
    const bright_yellow = "\x1b[93m";
    const bright_blue = "\x1b[94m";
    const bright_magenta = "\x1b[95m";
    const bright_cyan = "\x1b[96m";
    const bright_white = "\x1b[97m";

    // Background colors
    const bg_black = "\x1b[40m";
    const bg_red = "\x1b[41m";
    const bg_green = "\x1b[42m";
    const bg_yellow = "\x1b[43m";
    const bg_blue = "\x1b[44m";
    const bg_magenta = "\x1b[45m";
    const bg_cyan = "\x1b[46m";
    const bg_white = "\x1b[47m";

    // Bright background colors
    const bg_bright_black = "\x1b[100m";
    const bg_bright_red = "\x1b[101m";
    const bg_bright_green = "\x1b[102m";
    const bg_bright_yellow = "\x1b[103m";
    const bg_bright_blue = "\x1b[104m";
    const bg_bright_magenta = "\x1b[105m";
    const bg_bright_cyan = "\x1b[106m";
    const bg_bright_white = "\x1b[107m";

    // Combined styles
    const bold_red = "\x1b[1;31m";
    const bold_green = "\x1b[1;32m";
    const bold_yellow = "\x1b[1;33m";
    const bold_blue = "\x1b[1;34m";
    const bold_magenta = "\x1b[1;35m";
    const bold_cyan = "\x1b[1;36m";
    const bold_white = "\x1b[1;37m";
};

// Nerd font icons
const Icons = struct {
    const folder = "\u{F401} ";
    const worktree = "\u{F52E} ";
    const branch = "\u{F418} ";
};

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

    // Check if in git repo
    const git_root = getGitRoot(allocator) catch null;
    defer if (git_root) |r| allocator.free(r);

    const git_dir = getGitDir(allocator) catch null;
    defer if (git_dir) |d| allocator.free(d);

    const git_common_dir = getGitCommonDir(allocator) catch null;
    defer if (git_common_dir) |d| allocator.free(d);

    const is_worktree = if (git_dir != null and git_common_dir != null)
        !std.mem.eql(u8, git_dir.?, git_common_dir.?)
    else
        false;

    const branch = getGitBranch(allocator) catch null;
    defer if (branch) |b| allocator.free(b);

    // Start building prompt
    try stdout.writeAll("\n");
    try stdout.writeAll(Color.bright_black);

    // Git icon (yellow)
    if (git_dir != null) {
        try stdout.writeAll(Color.yellow);
        if (is_worktree) {
            try stdout.writeAll(Icons.worktree);
        } else {
            try stdout.writeAll(Icons.folder);
        }
        try stdout.writeAll(Color.bright_black);
    }

    // Path
    if (git_root) |root| {
        // In a git repo
        var repo_path: []const u8 = root;

        if (is_worktree and git_common_dir != null) {
            // Worktree: show original repo path
            if (std.fs.path.dirname(git_common_dir.?)) |dir| {
                repo_path = dir;
            }
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
        if (pwd.len > root.len and std.mem.startsWith(u8, pwd, root)) {
            const rel_path = pwd[root.len..];
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

fn runGitCommand(allocator: std.mem.Allocator, args: []const []const u8) ![]u8 {
    var child = std.process.Child.init(args, allocator);
    child.stderr_behavior = .Ignore;
    child.stdout_behavior = .Pipe;

    try child.spawn();

    const stdout_file = child.stdout.?;
    var output: [4096]u8 = undefined;
    const len = stdout_file.readAll(&output) catch 0;

    _ = try child.wait();

    if (len == 0) return error.NoOutput;

    // Find newline and trim
    var end = len;
    for (output[0..len], 0..) |c, i| {
        if (c == '\n') {
            end = i;
            break;
        }
    }

    const result = try allocator.alloc(u8, end);
    @memcpy(result, output[0..end]);
    return result;
}

fn getGitRoot(allocator: std.mem.Allocator) ![]u8 {
    return runGitCommand(allocator, &.{ "git", "rev-parse", "--show-toplevel" });
}

fn getGitDir(allocator: std.mem.Allocator) ![]u8 {
    const result = try runGitCommand(allocator, &.{ "git", "rev-parse", "--git-dir" });
    // Resolve to absolute path
    if (result.len > 0 and result[0] != '/') {
        const pwd = std.posix.getenv("PWD") orelse ".";
        const abs = try std.fs.path.resolve(allocator, &.{ pwd, result });
        allocator.free(result);
        return abs;
    }
    return result;
}

fn getGitCommonDir(allocator: std.mem.Allocator) ![]u8 {
    const result = try runGitCommand(allocator, &.{ "git", "rev-parse", "--git-common-dir" });
    // Resolve to absolute path
    if (result.len > 0 and result[0] != '/') {
        const pwd = std.posix.getenv("PWD") orelse ".";
        const abs = try std.fs.path.resolve(allocator, &.{ pwd, result });
        allocator.free(result);
        return abs;
    }
    return result;
}

fn getGitBranch(allocator: std.mem.Allocator) ![]u8 {
    return runGitCommand(allocator, &.{ "git", "branch", "--show-current" });
}
