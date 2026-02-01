///usr/bin/env zig run "$0" -- "$@"; exit
//
// nozo - a minimal z implementation in zig
// Implements zoxide's matching algorithm: https://github.com/ajeetdsouza/zoxide/wiki/Algorithm
// Uses ~/.z datafile format compatible with z.sh/z.lua
//
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const home = std.posix.getenv("HOME") orelse return error.NoHome;
    const datafile = try std.fs.path.join(allocator, &.{ home, ".z" });
    defer allocator.free(datafile);

    if (args.len < 2) {
        // No args - list all entries
        try listEntries(allocator, datafile, .frecent);
        return;
    }

    const cmd = args[1];

    if (std.mem.eql(u8, cmd, "--add")) {
        // Add directory to database
        if (args.len < 3) return;
        const path = args[2];
        if (std.mem.eql(u8, path, home)) return; // Skip home
        try addEntry(allocator, datafile, path);
    } else if (std.mem.eql(u8, cmd, "--complete")) {
        // Tab completion
        const query = if (args.len > 2) args[2] else "";
        try completeEntries(allocator, datafile, query);
    } else if (std.mem.eql(u8, cmd, "-l")) {
        // List mode
        const typ: SortType = if (args.len > 2 and std.mem.eql(u8, args[2], "-r"))
            .rank
        else if (args.len > 2 and std.mem.eql(u8, args[2], "-t"))
            .recent
        else
            .frecent;
        try listEntries(allocator, datafile, typ);
    } else if (std.mem.eql(u8, cmd, "-h")) {
        const stdout = std.fs.File.stdout();
        try stdout.writeAll("z [-h][-l][-r][-t] args\n");
    } else {
        // Jump mode - find best match
        var query_parts = std.ArrayListUnmanaged([]const u8){};
        defer query_parts.deinit(allocator);

        var sort_type: SortType = .frecent;
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (std.mem.eql(u8, arg, "-r")) {
                sort_type = .rank;
            } else if (std.mem.eql(u8, arg, "-t")) {
                sort_type = .recent;
            } else if (std.mem.eql(u8, arg, "--")) {
                // Everything after -- is query
                i += 1;
                while (i < args.len) : (i += 1) {
                    try query_parts.append(allocator, args[i]);
                }
            } else if (!std.mem.startsWith(u8, arg, "-")) {
                try query_parts.append(allocator, arg);
            }
        }

        // If last arg is a valid directory, just output it
        if (query_parts.items.len > 0) {
            const last = query_parts.items[query_parts.items.len - 1];
            if (isDirectory(last)) {
                const stdout = std.fs.File.stdout();
                try stdout.writeAll(last);
                try stdout.writeAll("\n");
                return;
            }
        }

        const target = try findBestMatch(allocator, datafile, query_parts.items, sort_type);
        defer if (target) |t| allocator.free(t);

        if (target) |t| {
            const stdout = std.fs.File.stdout();
            try stdout.writeAll(t);
            try stdout.writeAll("\n");
        } else {
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
            .recent => @as(f64, @floatFromInt(now - self.time)) * -1, // Negative so higher is better
        };
    }
};

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

fn readEntries(allocator: std.mem.Allocator, datafile: []const u8) !std.ArrayListUnmanaged(Entry) {
    var entries = std.ArrayListUnmanaged(Entry){};
    errdefer {
        for (entries.items) |e| allocator.free(e.path);
        entries.deinit(allocator);
    }

    const file = std.fs.openFileAbsolute(datafile, .{}) catch |err| {
        if (err == error.FileNotFound) return entries;
        return err;
    };
    defer file.close();

    // Read entire file
    var buf: [65536]u8 = undefined;
    const len = try file.readAll(&buf);
    if (len == 0) return entries;

    // Parse line by line
    var it = std.mem.splitScalar(u8, buf[0..len], '\n');
    while (it.next()) |line| {
        if (line.len == 0) continue;

        const entry = parseLine(allocator, line) catch continue;
        // Only include existing directories
        if (isDirectory(entry.path)) {
            try entries.append(allocator, entry);
        } else {
            allocator.free(entry.path);
        }
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

    var line_buf: [4096]u8 = undefined;
    for (entries) |e| {
        const line = std.fmt.bufPrint(&line_buf, "{s}|{d:.1}|{d}\n", .{ e.path, e.rank, e.time }) catch continue;
        try file.writeAll(line);
    }

    // Atomic rename
    std.fs.renameAbsolute(tmp_path, datafile) catch {
        // If rename fails, just delete temp
        std.fs.deleteFileAbsolute(tmp_path) catch {};
    };
}

fn addEntry(allocator: std.mem.Allocator, datafile: []const u8, path: []const u8) !void {
    const now = std.time.timestamp();

    var entries = try readEntries(allocator, datafile);
    defer {
        for (entries.items) |e| allocator.free(e.path);
        entries.deinit(allocator);
    }

    // Find existing or add new
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

    // Age entries if total rank > 1000
    var total_rank: f64 = 0;
    for (entries.items) |e| total_rank += e.rank;

    if (total_rank > 1000) {
        for (entries.items) |*e| e.rank *= 0.9;
    }

    try writeEntries(allocator, datafile, entries.items);
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

    // Last query term must match the last path component
    const last_query = query_parts[query_parts.len - 1];
    var last_query_buf: [256]u8 = undefined;
    const last_query_lower = toLower(&last_query_buf, last_query);

    // Find last path component
    const last_slash = std.mem.lastIndexOf(u8, path_lower, "/");
    const last_component = if (last_slash) |idx| path_lower[idx + 1 ..] else path_lower;

    // Last query must be found in last component
    if (std.mem.indexOf(u8, last_component, last_query_lower) == null) {
        return false;
    }

    // All terms must appear in order
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

fn findBestMatch(allocator: std.mem.Allocator, datafile: []const u8, query_parts: []const []const u8, sort_type: SortType) !?[]u8 {
    if (query_parts.len == 0) return null;

    var entries = try readEntries(allocator, datafile);
    defer {
        for (entries.items) |e| allocator.free(e.path);
        entries.deinit(allocator);
    }

    const now = std.time.timestamp();

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

fn listEntries(allocator: std.mem.Allocator, datafile: []const u8, sort_type: SortType) !void {
    var entries = try readEntries(allocator, datafile);
    defer {
        for (entries.items) |e| allocator.free(e.path);
        entries.deinit(allocator);
    }

    const now = std.time.timestamp();
    const stdout = std.fs.File.stdout();

    // Sort by score
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

    var buf: [256]u8 = undefined;
    for (entries.items) |e| {
        const line = std.fmt.bufPrint(&buf, "{d:>10.1} {s}\n", .{ e.score(now, sort_type), e.path }) catch continue;
        try stdout.writeAll(line);
    }
}

fn completeEntries(allocator: std.mem.Allocator, datafile: []const u8, query: []const u8) !void {
    var entries = try readEntries(allocator, datafile);
    defer {
        for (entries.items) |e| allocator.free(e.path);
        entries.deinit(allocator);
    }

    const stdout = std.fs.File.stdout();

    // Split query by spaces
    var query_parts = std.ArrayListUnmanaged([]const u8){};
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

fn isDirectory(path: []const u8) bool {
    const stat = std.fs.cwd().statFile(path) catch return false;
    return stat.kind == .directory;
}
