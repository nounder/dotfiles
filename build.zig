const std = @import("std");

const programs = .{ "noprompt", "noenv", "nohi", "nozo" };

const targets = .{
    .{ .arch = .aarch64, .os = .macos, .suffix = "darwin-arm64" },
    .{ .arch = .aarch64, .os = .linux, .suffix = "linux-arm64" },
    .{ .arch = .x86_64, .os = .linux, .suffix = "linux-amd64" },
};

pub fn build(b: *std.Build) void {
    inline for (programs) |prog| {
        const source = b.path("bin/" ++ prog ++ ".zig");
        inline for (targets) |t| {
            const exe = b.addExecutable(.{
                .name = prog ++ "-" ++ t.suffix,
                .root_module = b.createModule(.{
                    .root_source_file = source,
                    .target = b.resolveTargetQuery(.{
                        .cpu_arch = t.arch,
                        .os_tag = t.os,
                    }),
                    .optimize = .ReleaseSmall,
                    .strip = true,
                    .single_threaded = true,
                }),
            });
            const install = b.addInstallArtifact(exe, .{
                .dest_dir = .{ .override = .{ .custom = "../bin" } },
            });
            b.getInstallStep().dependOn(&install.step);
        }
    }
}
