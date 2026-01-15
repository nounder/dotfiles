---
name: zig
description: Use when writing Zig code. Contains Zig 0.15 API changes and patterns.
---

# Zig 0.15 API Reference

## CRITICAL: API Changes from 0.14

### ArrayList -> ArrayListUnmanaged

```zig
// OLD (0.14)
var list = std.ArrayList(T).init(allocator);
defer list.deinit();
try list.append(item);

// NEW (0.15)
var list = std.ArrayListUnmanaged(T){};
defer list.deinit(allocator);
try list.append(allocator, item);
```

### stdout/stderr

```zig
// OLD (0.14)
const stdout = std.io.getStdOut().writer();
try stdout.print("{s}\n", .{msg});

// NEW (0.15)
const stdout = std.fs.File.stdout();
try stdout.writeAll(msg);
try stdout.writeAll("\n");

// For formatted output, use bufPrint
var buf: [256]u8 = undefined;
const line = try std.fmt.bufPrint(&buf, "{d}: {s}\n", .{num, str});
try stdout.writeAll(line);
```

### File writer

```zig
// OLD (0.14)
const file = try std.fs.createFileAbsolute(path, .{});
var writer = file.writer();
try writer.print("{s}\n", .{data});

// NEW (0.15)
const file = try std.fs.createFileAbsolute(path, .{});
var buf: [4096]u8 = undefined;
const line = try std.fmt.bufPrint(&buf, "{s}\n", .{data});
try file.writeAll(line);
```

### No bufferedReader

```zig
// OLD (0.14)
var buf_reader = std.io.bufferedReader(file.reader());
var reader = buf_reader.reader();
while (reader.readUntilDelimiterOrEof(&buf, '\n')) |line| { ... }

// NEW (0.15) - Read whole file, split manually
var buf: [65536]u8 = undefined;
const len = try file.readAll(&buf);
var it = std.mem.splitScalar(u8, buf[0..len], '\n');
while (it.next()) |line| { ... }
```

## Common Patterns

### Reading a file

```zig
fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    var buf: [4096]u8 = undefined;
    const len = try file.readAll(&buf);
    if (len == 0) return error.EmptyFile;

    // Trim trailing newlines
    var end = len;
    while (end > 0 and (buf[end - 1] == '\n' or buf[end - 1] == '\r')) end -= 1;

    const result = try allocator.alloc(u8, end);
    @memcpy(result, buf[0..end]);
    return result;
}
```

### Environment variables

```zig
const home = std.posix.getenv("HOME") orelse return error.NoHome;
const pwd = std.posix.getenv("PWD") orelse ".";
```

### Path operations

```zig
const path = try std.fs.path.join(allocator, &.{ dir, filename });
defer allocator.free(path);

const parent = std.fs.path.dirname(path);
const basename = std.fs.path.basename(path);
const resolved = try std.fs.path.resolve(allocator, &.{ base, relative });
```

### Check if path is directory

```zig
fn isDirectory(path: []const u8) bool {
    const stat = std.fs.cwd().statFile(path) catch return false;
    return stat.kind == .directory;
}
```

### Command line args

```zig
const args = try std.process.argsAlloc(allocator);
defer std.process.argsFree(allocator, args);
// args[0] is program name, args[1..] are arguments
```

### String operations

```zig
// Check prefix
if (std.mem.startsWith(u8, str, "prefix")) { ... }

// Split
var it = std.mem.splitScalar(u8, str, '|');
while (it.next()) |part| { ... }

// Index of
if (std.mem.indexOf(u8, haystack, needle)) |pos| { ... }

// Equal
if (std.mem.eql(u8, a, b)) { ... }

// To lowercase (in place with buffer)
var buf: [256]u8 = undefined;
for (str, 0..) |c, i| buf[i] = std.ascii.toLower(c);
const lower = buf[0..str.len];
```

### Timestamps

```zig
const now = std.time.timestamp(); // i64 seconds since epoch
```

### Sorting

```zig
const Context = struct { now: i64 };
const ctx = Context{ .now = std.time.timestamp() };

std.mem.sort(T, items, ctx, struct {
    fn lessThan(c: Context, a: T, b: T) bool {
        return a.value < b.value;
    }
}.lessThan);
```

## Build Commands

```bash
# Debug build
zig build-exe src/main.zig

# Release build (small)
zig build-exe src/main.zig -O ReleaseSmall -fstrip -fsingle-threaded --name output

# Clean artifacts
rm -f output.o
```
