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

    // Build nom from $NOM_SRC (its own repo) for each target, then copy into bin/.
    // Steps are chained sequentially because nom writes to a single zig-out path —
    // running the per-target builds in parallel races and clobbers the artifact.
    if (b.graph.environ_map.get("NOM_SRC")) |nom_src| {
        var prev_step: ?*std.Build.Step = null;
        inline for (targets) |t| {
            const target_arg = b.fmt("-Dtarget={s}-{s}", .{
                @tagName(t.arch),
                @tagName(t.os),
            });
            const build_cmd = b.addSystemCommand(&.{
                "zig",                  "build",
                "-Doptimize=ReleaseFast", target_arg,
            });
            build_cmd.setCwd(.{ .cwd_relative = nom_src });

            const dest = b.fmt("bin/nom-{s}", .{t.suffix});
            const src = b.fmt("{s}/zig-out/bin/nom", .{nom_src});
            // `install` preserves macOS ad-hoc signature; `cp` can break it.
            const copy_cmd = b.addSystemCommand(&.{ "install", "-m", "755", src, dest });
            copy_cmd.step.dependOn(&build_cmd.step);
            if (prev_step) |p| build_cmd.step.dependOn(p);
            b.getInstallStep().dependOn(&copy_cmd.step);
            prev_step = &copy_cmd.step;
        }
    }
}
