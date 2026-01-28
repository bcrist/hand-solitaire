const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "hand_solitaire",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .optimize = b.standardOptimizeOption(.{}),
            .target = b.standardTargetOptions(.{}),
        }),
    });

    b.installArtifact(exe);

    b.step("run", "run program").dependOn(&b.addRunArtifact(exe).step);
}
