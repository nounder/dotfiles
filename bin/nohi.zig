///usr/bin/env zig run "$0" -- "$@"; exit
//
// nohi - per-directory command history with frecency
// Stores history in ~/.nohi with format: PATH\tCMD\tRANK\tTIME\n
//
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const home = std.posix.getenv("HOME") orelse return error.NoHome;
    const datafile = try std.fs.path.join(allocator, &.{ home, ".nohi" });
    defer allocator.free(datafile);

    if (args.len < 2) {
        try printUsage();
        return;
    }

    const cmd = args[1];

    if (std.mem.eql(u8, cmd, "--add")) {
        // Add command: nohi --add <path> <command>
        if (args.len < 4) return;
        const path = args[2];
        // Join remaining args as the command
        var cmd_buf: [4096]u8 = undefined;
        var cmd_len: usize = 0;
        for (args[3..]) |arg| {
            if (cmd_len > 0) {
                cmd_buf[cmd_len] = ' ';
                cmd_len += 1;
            }
            if (cmd_len + arg.len > cmd_buf.len) break;
            @memcpy(cmd_buf[cmd_len..][0..arg.len], arg);
            cmd_len += arg.len;
        }
        try addEntry(allocator, datafile, path, cmd_buf[0..cmd_len]);
    } else if (std.mem.eql(u8, cmd, "--get")) {
        // Get history for path: nohi --get <path>
        if (args.len < 3) return;
        const path = args[2];
        try getHistory(allocator, datafile, path);
    } else if (std.mem.eql(u8, cmd, "--list")) {
        // List all entries
        try listEntries(allocator, datafile);
    } else if (std.mem.eql(u8, cmd, "--prune")) {
        // Remove entries for non-existent directories
        try pruneEntries(allocator, datafile);
    } else {
        try printUsage();
    }
}

fn printUsage() !void {
    const stdout = std.fs.File.stdout();
    try stdout.writeAll(
        \\nohi - per-directory command history with frecency
        \\
        \\Usage:
        \\  nohi --add <path> <command>   Add command to history for path
        \\  nohi --get <path>             Get history for path (sorted by frecency)
        \\  nohi --list                   List all entries
        \\  nohi --prune                  Remove entries for non-existent directories
        \\
    );
}

const Entry = struct {
    path: []const u8,
    cmd: []const u8,
    rank: f64,
    time: i64,

    fn frecent(self: Entry, now: i64) f64 {
        const dx = now - self.time;
        if (dx < 3600) return self.rank * 4; // Last hour
        if (dx < 86400) return self.rank * 2; // Last day
        if (dx < 604800) return self.rank / 2; // Last week
        return self.rank / 4;
    }
};

fn parseLine(allocator: std.mem.Allocator, line: []const u8) !Entry {
    var it = std.mem.splitScalar(u8, line, '\t');
    const path = it.next() orelse return error.InvalidLine;
    const cmd = it.next() orelse return error.InvalidLine;
    const rank_str = it.next() orelse return error.InvalidLine;
    const time_str = it.next() orelse return error.InvalidLine;

    return Entry{
        .path = try allocator.dupe(u8, path),
        .cmd = try allocator.dupe(u8, cmd),
        .rank = std.fmt.parseFloat(f64, rank_str) catch 1,
        .time = std.fmt.parseInt(i64, time_str, 10) catch 0,
    };
}

fn freeEntry(allocator: std.mem.Allocator, e: Entry) void {
    allocator.free(e.path);
    allocator.free(e.cmd);
}

fn readEntries(allocator: std.mem.Allocator, datafile: []const u8) !std.ArrayListUnmanaged(Entry) {
    var entries = std.ArrayListUnmanaged(Entry){};
    errdefer {
        for (entries.items) |e| freeEntry(allocator, e);
        entries.deinit(allocator);
    }

    const file = std.fs.openFileAbsolute(datafile, .{}) catch |err| {
        if (err == error.FileNotFound) return entries;
        return err;
    };
    defer file.close();

    // Read entire file
    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024); // 10MB max
    defer allocator.free(content);

    if (content.len == 0) return entries;

    // Parse line by line
    var it = std.mem.splitScalar(u8, content, '\n');
    while (it.next()) |line| {
        if (line.len == 0) continue;
        const entry = parseLine(allocator, line) catch continue;
        try entries.append(allocator, entry);
    }

    return entries;
}

fn writeEntries(allocator: std.mem.Allocator, datafile: []const u8, entries: []const Entry) !void {
    _ = allocator;
    // Write to temp file first
    var tmp_buf: [4096]u8 = undefined;
    const tmp_path = try std.fmt.bufPrint(&tmp_buf, "{s}.{d}", .{ datafile, std.time.timestamp() });

    const file = try std.fs.createFileAbsolute(tmp_path, .{});
    defer file.close();

    var line_buf: [8192]u8 = undefined;
    for (entries) |e| {
        const line = std.fmt.bufPrint(&line_buf, "{s}\t{s}\t{d:.1}\t{d}\n", .{ e.path, e.cmd, e.rank, e.time }) catch continue;
        try file.writeAll(line);
    }

    // Atomic rename
    std.fs.renameAbsolute(tmp_path, datafile) catch {
        std.fs.deleteFileAbsolute(tmp_path) catch {};
    };
}

fn addEntry(allocator: std.mem.Allocator, datafile: []const u8, path: []const u8, cmd: []const u8) !void {
    // Skip empty commands or commands starting with space
    if (cmd.len == 0) return;
    if (cmd[0] == ' ') return;

    const now = std.time.timestamp();

    var entries = try readEntries(allocator, datafile);
    defer {
        for (entries.items) |e| freeEntry(allocator, e);
        entries.deinit(allocator);
    }

    // Find existing entry for same path+cmd or add new
    var found = false;
    for (entries.items) |*e| {
        if (std.mem.eql(u8, e.path, path) and std.mem.eql(u8, e.cmd, cmd)) {
            e.rank += 1;
            e.time = now;
            found = true;
            break;
        }
    }

    if (!found) {
        try entries.append(allocator, .{
            .path = try allocator.dupe(u8, path),
            .cmd = try allocator.dupe(u8, cmd),
            .rank = 1,
            .time = now,
        });
    }

    // Age entries if total rank > 10000
    var total_rank: f64 = 0;
    for (entries.items) |e| total_rank += e.rank;

    if (total_rank > 10000) {
        for (entries.items) |*e| e.rank *= 0.9;
        // Remove entries with rank < 0.1
        var i: usize = 0;
        while (i < entries.items.len) {
            if (entries.items[i].rank < 0.1) {
                freeEntry(allocator, entries.items[i]);
                _ = entries.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }

    try writeEntries(allocator, datafile, entries.items);
}

fn getHistory(allocator: std.mem.Allocator, datafile: []const u8, path: []const u8) !void {
    var entries = try readEntries(allocator, datafile);
    defer {
        for (entries.items) |e| freeEntry(allocator, e);
        entries.deinit(allocator);
    }

    const now = std.time.timestamp();
    const stdout = std.fs.File.stdout();

    // Filter to matching path (exact match or parent directories) and collect unique commands
    var matching = std.ArrayListUnmanaged(Entry){};
    defer matching.deinit(allocator);

    var seen = std.StringHashMap(void).init(allocator);
    defer seen.deinit();

    for (entries.items) |e| {
        // Match if entry path equals current path OR entry path is a parent of current path
        const is_match = std.mem.eql(u8, e.path, path) or
            (std.mem.startsWith(u8, path, e.path) and
            path.len > e.path.len and
            path[e.path.len] == '/');
        if (is_match) {
            // Dedupe by command
            if (!seen.contains(e.cmd)) {
                try seen.put(e.cmd, {});
                try matching.append(allocator, e);
            }
        }
    }

    // Sort by frecency (descending)
    std.mem.sort(Entry, matching.items, now, struct {
        fn lessThan(n: i64, a: Entry, b: Entry) bool {
            return a.frecent(n) > b.frecent(n);
        }
    }.lessThan);

    // Output commands only (for bash history -r)
    var buf: [4096]u8 = undefined;
    for (matching.items) |e| {
        const line = std.fmt.bufPrint(&buf, "{s}\n", .{e.cmd}) catch continue;
        try stdout.writeAll(line);
    }
}

fn listEntries(allocator: std.mem.Allocator, datafile: []const u8) !void {
    var entries = try readEntries(allocator, datafile);
    defer {
        for (entries.items) |e| freeEntry(allocator, e);
        entries.deinit(allocator);
    }

    const now = std.time.timestamp();
    const stdout = std.fs.File.stdout();

    // Sort by frecency (descending)
    std.mem.sort(Entry, entries.items, now, struct {
        fn lessThan(n: i64, a: Entry, b: Entry) bool {
            return a.frecent(n) > b.frecent(n);
        }
    }.lessThan);

    var buf: [8192]u8 = undefined;
    for (entries.items) |e| {
        const line = std.fmt.bufPrint(&buf, "{d:>8.1}  {s}  {s}\n", .{ e.frecent(now), e.path, e.cmd }) catch continue;
        try stdout.writeAll(line);
    }
}

fn pruneEntries(allocator: std.mem.Allocator, datafile: []const u8) !void {
    var entries = try readEntries(allocator, datafile);
    defer {
        for (entries.items) |e| freeEntry(allocator, e);
        entries.deinit(allocator);
    }

    const stdout = std.fs.File.stdout();
    var removed: usize = 0;

    // Remove entries for non-existent directories
    var i: usize = 0;
    while (i < entries.items.len) {
        const path = entries.items[i].path;
        const is_dir = blk: {
            const stat = std.fs.cwd().statFile(path) catch break :blk false;
            break :blk stat.kind == .directory;
        };

        if (!is_dir) {
            freeEntry(allocator, entries.items[i]);
            _ = entries.swapRemove(i);
            removed += 1;
        } else {
            i += 1;
        }
    }

    try writeEntries(allocator, datafile, entries.items);
    var buf: [64]u8 = undefined;
    const line = std.fmt.bufPrint(&buf, "Pruned {d} entries\n", .{removed}) catch return;
    try stdout.writeAll(line);
}
