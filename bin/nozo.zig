///usr/bin/env zig run "$0" -- "$@"; exit
//
// nozo - a minimal z implementation in zig
// Implements zoxide's matching algorithm: https://github.com/ajeetdsouza/zoxide/wiki/Algorithm
// Uses ~/.z datafile format compatible with z.sh/z.lua
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
    const datafile = try std.fs.path.join(gpa, &.{ home, ".z" });
    defer gpa.free(datafile);

    var stdout_buf: [4096]u8 = undefined;
    var stdout_w = Io.File.stdout().writer(io, &stdout_buf);
    const stdout: *Io.Writer = &stdout_w.interface;
    defer stdout.flush() catch {};

    if (args.len < 2) {
        try listEntries(gpa, io, datafile, .frecent, stdout);
        return;
    }

    const cmd = args[1];

    if (std.mem.eql(u8, cmd, "--add")) {
        if (args.len < 3) return;
        const path = args[2];
        if (std.mem.eql(u8, path, home)) return;
        try addEntry(gpa, io, datafile, path);
    } else if (std.mem.eql(u8, cmd, "--complete")) {
        const query = if (args.len > 2) args[2] else "";
        try completeEntries(gpa, io, datafile, query, stdout);
    } else if (std.mem.eql(u8, cmd, "-l")) {
        const typ: SortType = if (args.len > 2 and std.mem.eql(u8, args[2], "-r"))
            .rank
        else if (args.len > 2 and std.mem.eql(u8, args[2], "-t"))
            .recent
        else
            .frecent;
        try listEntries(gpa, io, datafile, typ, stdout);
    } else if (std.mem.eql(u8, cmd, "-h")) {
        try stdout.writeAll("z [-h][-l][-r][-t] args\n");
    } else {
        var query_parts: std.ArrayListUnmanaged([]const u8) = .empty;
        defer query_parts.deinit(gpa);

        var sort_type: SortType = .frecent;
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (std.mem.eql(u8, arg, "-r")) {
                sort_type = .rank;
            } else if (std.mem.eql(u8, arg, "-t")) {
                sort_type = .recent;
            } else if (std.mem.eql(u8, arg, "--")) {
                i += 1;
                while (i < args.len) : (i += 1) {
                    try query_parts.append(gpa, args[i]);
                }
            } else if (!std.mem.startsWith(u8, arg, "-")) {
                try query_parts.append(gpa, arg);
            }
        }

        if (query_parts.items.len > 0) {
            const last = query_parts.items[query_parts.items.len - 1];
            if (isDirectory(io, last)) {
                try stdout.writeAll(last);
                try stdout.writeAll("\n");
                return;
            }
        }

        const target = try findBestMatch(gpa, io, datafile, query_parts.items, sort_type);
        defer if (target) |t| gpa.free(t);

        if (target) |t| {
            try stdout.writeAll(t);
            try stdout.writeAll("\n");
        } else {
            try stdout.flush();
            std.process.exit(1);
        }
    }
}

const SortType = enum { frecent, rank, recent };

const Entry = struct {
    path: []const u8,
    rank: f64,
    time: i64,

    fn frecent(self: Entry, now: i64) f64 {
        const dx = now - self.time;
        if (dx < 3600) return self.rank * 4;
        if (dx < 86400) return self.rank * 2;
        if (dx < 604800) return self.rank / 2;
        return self.rank / 4;
    }

    fn score(self: Entry, now: i64, sort_type: SortType) f64 {
        return switch (sort_type) {
            .frecent => self.frecent(now),
            .rank => self.rank,
            .recent => @as(f64, @floatFromInt(now - self.time)) * -1,
        };
    }
};

fn nowSeconds(io: Io) i64 {
    return Io.Clock.real.now(io).toSeconds();
}

fn parseLine(allocator: std.mem.Allocator, line: []const u8) !Entry {
    var it = std.mem.splitScalar(u8, line, '|');
    const path = it.next() orelse return error.InvalidLine;
    const rank_str = it.next() orelse return error.InvalidLine;
    const time_str = it.next() orelse return error.InvalidLine;

    return Entry{
        .path = try allocator.dupe(u8, path),
        .rank = std.fmt.parseFloat(f64, rank_str) catch 1,
        .time = std.fmt.parseInt(i64, time_str, 10) catch 0,
    };
}

fn readEntries(allocator: std.mem.Allocator, io: Io, datafile: []const u8) !std.ArrayListUnmanaged(Entry) {
    var entries: std.ArrayListUnmanaged(Entry) = .empty;
    errdefer {
        for (entries.items) |e| allocator.free(e.path);
        entries.deinit(allocator);
    }

    const file = Io.Dir.openFileAbsolute(io, datafile, .{}) catch |err| {
        if (err == error.FileNotFound) return entries;
        return err;
    };
    defer file.close(io);

    var buf: [65536]u8 = undefined;
    var fr = file.reader(io, &.{});
    const len = fr.interface.readSliceShort(&buf) catch |err| switch (err) {
        error.ReadFailed => return fr.err.?,
    };
    if (len == 0) return entries;

    var it = std.mem.splitScalar(u8, buf[0..len], '\n');
    while (it.next()) |line| {
        if (line.len == 0) continue;

        const entry = parseLine(allocator, line) catch continue;
        if (isDirectory(io, entry.path)) {
            try entries.append(allocator, entry);
        } else {
            allocator.free(entry.path);
        }
    }

    return entries;
}

fn writeEntries(io: Io, datafile: []const u8, entries: []const Entry) !void {
    var tmp_buf: [4096]u8 = undefined;
    const tmp_path = try std.fmt.bufPrint(&tmp_buf, "{s}.{d}", .{ datafile, nowSeconds(io) });

    const file = try Io.Dir.createFileAbsolute(io, tmp_path, .{});
    defer file.close(io);

    var write_buf: [4096]u8 = undefined;
    var fw = file.writer(io, &write_buf);
    const w: *Io.Writer = &fw.interface;

    for (entries) |e| {
        w.print("{s}|{d:.1}|{d}\n", .{ e.path, e.rank, e.time }) catch continue;
    }
    try w.flush();

    Io.Dir.renameAbsolute(tmp_path, datafile, io) catch {
        Io.Dir.deleteFileAbsolute(io, tmp_path) catch {};
    };
}

fn addEntry(allocator: std.mem.Allocator, io: Io, datafile: []const u8, path: []const u8) !void {
    const now = nowSeconds(io);

    var entries = try readEntries(allocator, io, datafile);
    defer {
        for (entries.items) |e| allocator.free(e.path);
        entries.deinit(allocator);
    }

    var found = false;
    for (entries.items) |*e| {
        if (std.mem.eql(u8, e.path, path)) {
            e.rank += 1;
            e.time = now;
            found = true;
            break;
        }
    }

    if (!found) {
        try entries.append(allocator, .{
            .path = try allocator.dupe(u8, path),
            .rank = 1,
            .time = now,
        });
    }

    var total_rank: f64 = 0;
    for (entries.items) |e| total_rank += e.rank;

    if (total_rank > 1000) {
        for (entries.items) |*e| e.rank *= 0.9;
    }

    try writeEntries(io, datafile, entries.items);
}

fn toLower(buf: []u8, str: []const u8) []const u8 {
    if (str.len > buf.len) return str;
    for (str, 0..) |c, i| buf[i] = std.ascii.toLower(c);
    return buf[0..str.len];
}

fn matchesQuery(path: []const u8, query_parts: []const []const u8) bool {
    if (query_parts.len == 0) return true;

    var path_buf: [4096]u8 = undefined;
    const path_lower = toLower(&path_buf, path);

    const last_query = query_parts[query_parts.len - 1];
    var last_query_buf: [256]u8 = undefined;
    const last_query_lower = toLower(&last_query_buf, last_query);

    const last_slash = std.mem.lastIndexOf(u8, path_lower, "/");
    const last_component = if (last_slash) |idx| path_lower[idx + 1 ..] else path_lower;

    if (std.mem.indexOf(u8, last_component, last_query_lower) == null) {
        return false;
    }

    var search_start: usize = 0;
    for (query_parts) |q| {
        var q_buf: [256]u8 = undefined;
        const q_lower = toLower(&q_buf, q);

        if (std.mem.indexOfPos(u8, path_lower, search_start, q_lower)) |idx| {
            search_start = idx + q_lower.len;
        } else {
            return false;
        }
    }

    return true;
}

fn findBestMatch(allocator: std.mem.Allocator, io: Io, datafile: []const u8, query_parts: []const []const u8, sort_type: SortType) !?[]u8 {
    if (query_parts.len == 0) return null;

    var entries = try readEntries(allocator, io, datafile);
    defer {
        for (entries.items) |e| allocator.free(e.path);
        entries.deinit(allocator);
    }

    const now = nowSeconds(io);

    var best_path: ?[]const u8 = null;
    var best_score: f64 = -std.math.inf(f64);

    for (entries.items) |e| {
        if (!matchesQuery(e.path, query_parts)) continue;

        const s = e.score(now, sort_type);
        if (s > best_score) {
            best_score = s;
            best_path = e.path;
        }
    }

    if (best_path) |p| {
        return try allocator.dupe(u8, p);
    }
    return null;
}

fn listEntries(allocator: std.mem.Allocator, io: Io, datafile: []const u8, sort_type: SortType, stdout: *Io.Writer) !void {
    var entries = try readEntries(allocator, io, datafile);
    defer {
        for (entries.items) |e| allocator.free(e.path);
        entries.deinit(allocator);
    }

    const now = nowSeconds(io);

    const SortContext = struct {
        now: i64,
        sort_type: SortType,
    };
    const ctx = SortContext{ .now = now, .sort_type = sort_type };

    std.mem.sort(Entry, entries.items, ctx, struct {
        fn lessThan(c: SortContext, a: Entry, b: Entry) bool {
            return a.score(c.now, c.sort_type) < b.score(c.now, c.sort_type);
        }
    }.lessThan);

    for (entries.items) |e| {
        try stdout.print("{d:>10.1} {s}\n", .{ e.score(now, sort_type), e.path });
    }
}

fn completeEntries(allocator: std.mem.Allocator, io: Io, datafile: []const u8, query: []const u8, stdout: *Io.Writer) !void {
    var entries = try readEntries(allocator, io, datafile);
    defer {
        for (entries.items) |e| allocator.free(e.path);
        entries.deinit(allocator);
    }

    var query_parts: std.ArrayListUnmanaged([]const u8) = .empty;
    defer query_parts.deinit(allocator);

    var it = std.mem.splitScalar(u8, query, ' ');
    while (it.next()) |part| {
        if (part.len > 0) try query_parts.append(allocator, part);
    }

    for (entries.items) |e| {
        if (query_parts.items.len == 0 or matchesQuery(e.path, query_parts.items)) {
            try stdout.writeAll(e.path);
            try stdout.writeAll("\n");
        }
    }
}

fn isDirectory(io: Io, path: []const u8) bool {
    const stat = Io.Dir.cwd().statFile(io, path, .{}) catch return false;
    return stat.kind == .directory;
}
