///usr/bin/env zig run "$0" -- "$@"; exit
//
// nohi - per-directory command history with frecency
// Stores history in ~/.nohi with format: PATH\tCMD\tRANK\tTIME\n
//
const std = @import("std");
const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const arena = init.arena.allocator();
    const io = init.io;
    const env = init.environ_map;

    const args = try init.minimal.args.toSlice(arena);

    const home = env.get("HOME") orelse return error.NoHome;
    const datafile = try std.fs.path.join(gpa, &.{ home, ".nohi" });
    defer gpa.free(datafile);

    var stdout_buf: [4096]u8 = undefined;
    var stdout_w = Io.File.stdout().writer(io, &stdout_buf);
    const stdout: *Io.Writer = &stdout_w.interface;
    defer stdout.flush() catch {};

    if (args.len < 2) {
        try printUsage(stdout);
        return;
    }

    const cmd = args[1];

    if (std.mem.eql(u8, cmd, "--add")) {
        if (args.len < 4) return;
        const path = args[2];
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
        try addEntry(gpa, io, datafile, path, cmd_buf[0..cmd_len]);
    } else if (std.mem.eql(u8, cmd, "--get")) {
        if (args.len < 3) return;
        var by_recent = false;
        var path_idx: usize = 2;
        if (std.mem.eql(u8, args[2], "--recent")) {
            by_recent = true;
            path_idx = 3;
            if (args.len < 4) return;
        }
        const path = args[path_idx];
        const now = nowSeconds(io);

        var result = try getHistory(gpa, io, datafile, path);
        defer result.deinit(gpa);

        if (by_recent) {
            std.mem.sort(Entry, result.matching.items, {}, struct {
                fn f(_: void, a: Entry, b: Entry) bool {
                    return a.time > b.time;
                }
            }.f);
        } else {
            std.mem.sort(Entry, result.matching.items, now, struct {
                fn f(n: i64, a: Entry, b: Entry) bool {
                    return a.frecent(n) > b.frecent(n);
                }
            }.f);
        }

        for (result.matching.items) |e| {
            try stdout.print("{s}\n", .{e.cmd});
        }
    } else if (std.mem.eql(u8, cmd, "--list")) {
        try listEntries(gpa, io, datafile, stdout);
    } else if (std.mem.eql(u8, cmd, "--prune")) {
        try pruneEntries(gpa, io, datafile, stdout);
    } else {
        try printUsage(stdout);
    }
}

fn nowSeconds(io: Io) i64 {
    return Io.Clock.real.now(io).toSeconds();
}

fn printUsage(stdout: *Io.Writer) !void {
    try stdout.writeAll(
        \\nohi - per-directory command history with frecency
        \\
        \\Usage:
        \\  nohi --add <path> <command>      Add command to history for path
        \\  nohi --get [--recent] <path>     Get history (frecency or recency order)
        \\  nohi --list                      List all entries
        \\  nohi --prune                     Remove entries for non-existent directories
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

fn readEntries(allocator: std.mem.Allocator, io: Io, datafile: []const u8) !std.ArrayListUnmanaged(Entry) {
    var entries: std.ArrayListUnmanaged(Entry) = .empty;
    errdefer {
        for (entries.items) |e| freeEntry(allocator, e);
        entries.deinit(allocator);
    }

    const file = Io.Dir.openFileAbsolute(io, datafile, .{}) catch |err| {
        if (err == error.FileNotFound) return entries;
        return err;
    };
    defer file.close(io);

    // Read entire file via allocating writer
    var aw: Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();
    var fr = file.reader(io, &.{});
    _ = fr.interface.streamRemaining(&aw.writer) catch |err| switch (err) {
        error.ReadFailed => return fr.err.?,
        else => |e| return e,
    };
    const content = aw.written();

    if (content.len == 0) return entries;

    var it = std.mem.splitScalar(u8, content, '\n');
    while (it.next()) |line| {
        if (line.len == 0) continue;
        const entry = parseLine(allocator, line) catch continue;
        try entries.append(allocator, entry);
    }

    return entries;
}

fn writeEntries(io: Io, datafile: []const u8, entries: []const Entry) !void {
    // Write to temp file first
    var tmp_buf: [4096]u8 = undefined;
    const tmp_path = try std.fmt.bufPrint(&tmp_buf, "{s}.{d}", .{ datafile, Io.Clock.real.now(io).toSeconds() });

    const file = try Io.Dir.createFileAbsolute(io, tmp_path, .{});
    defer file.close(io);

    var write_buf: [4096]u8 = undefined;
    var fw = file.writer(io, &write_buf);
    const w: *Io.Writer = &fw.interface;

    for (entries) |e| {
        w.print("{s}\t{s}\t{d:.1}\t{d}\n", .{ e.path, e.cmd, e.rank, e.time }) catch continue;
    }
    try w.flush();

    // Atomic rename
    Io.Dir.renameAbsolute(tmp_path, datafile, io) catch {
        Io.Dir.deleteFileAbsolute(io, tmp_path) catch {};
    };
}

fn addEntry(allocator: std.mem.Allocator, io: Io, datafile: []const u8, path: []const u8, cmd: []const u8) !void {
    if (cmd.len == 0) return;
    if (cmd[0] == ' ') return;

    const now = nowSeconds(io);

    var entries = try readEntries(allocator, io, datafile);
    defer {
        for (entries.items) |e| freeEntry(allocator, e);
        entries.deinit(allocator);
    }

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

    try writeEntries(io, datafile, entries.items);
}

const HistoryResult = struct {
    entries: std.ArrayListUnmanaged(Entry),
    matching: std.ArrayListUnmanaged(Entry),

    fn deinit(self: *HistoryResult, allocator: std.mem.Allocator) void {
        for (self.entries.items) |e| freeEntry(allocator, e);
        self.entries.deinit(allocator);
        self.matching.deinit(allocator);
    }
};

fn getHistory(allocator: std.mem.Allocator, io: Io, datafile: []const u8, path: []const u8) !HistoryResult {
    var entries = try readEntries(allocator, io, datafile);
    errdefer {
        for (entries.items) |e| freeEntry(allocator, e);
        entries.deinit(allocator);
    }

    var matching: std.ArrayListUnmanaged(Entry) = .empty;
    errdefer matching.deinit(allocator);

    var seen = std.StringHashMap(usize).init(allocator);
    defer seen.deinit();

    for (entries.items) |e| {
        const is_match = std.mem.eql(u8, e.path, path) or
            (std.mem.startsWith(u8, path, e.path) and
                path.len > e.path.len and
                path[e.path.len] == '/') or
            (std.mem.startsWith(u8, e.path, path) and
                e.path.len > path.len and
                e.path[path.len] == '/');
        if (is_match) {
            if (seen.get(e.cmd)) |idx| {
                if (e.time > matching.items[idx].time) {
                    matching.items[idx] = e;
                }
            } else {
                try seen.put(e.cmd, matching.items.len);
                try matching.append(allocator, e);
            }
        }
    }

    return .{ .entries = entries, .matching = matching };
}

fn listEntries(allocator: std.mem.Allocator, io: Io, datafile: []const u8, stdout: *Io.Writer) !void {
    var entries = try readEntries(allocator, io, datafile);
    defer {
        for (entries.items) |e| freeEntry(allocator, e);
        entries.deinit(allocator);
    }

    const now = nowSeconds(io);

    std.mem.sort(Entry, entries.items, now, struct {
        fn lessThan(n: i64, a: Entry, b: Entry) bool {
            return a.frecent(n) > b.frecent(n);
        }
    }.lessThan);

    for (entries.items) |e| {
        try stdout.print("{d:>8.1}  {s}  {s}\n", .{ e.frecent(now), e.path, e.cmd });
    }
}

fn pruneEntries(allocator: std.mem.Allocator, io: Io, datafile: []const u8, stdout: *Io.Writer) !void {
    var entries = try readEntries(allocator, io, datafile);
    defer {
        for (entries.items) |e| freeEntry(allocator, e);
        entries.deinit(allocator);
    }

    var removed: usize = 0;

    var i: usize = 0;
    while (i < entries.items.len) {
        const path = entries.items[i].path;
        const is_dir = blk: {
            const stat = Io.Dir.cwd().statFile(io, path, .{}) catch break :blk false;
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

    try writeEntries(io, datafile, entries.items);
    try stdout.print("Pruned {d} entries\n", .{removed});
}
