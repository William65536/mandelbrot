const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "mandelbrot",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();

    exe.addIncludePath(std.Build.LazyPath{ .path = "./include" });

    exe.addObjectFile(std.Build.LazyPath{ .path = "./lib/SetupAPI.lib" });
    exe.addObjectFile(std.Build.LazyPath{ .path = "./lib/OleAut32.lib" });
    exe.addObjectFile(std.Build.LazyPath{ .path = "./lib/Ole32.lib" });
    exe.addObjectFile(std.Build.LazyPath{ .path = "./lib/Imm32.lib" });
    exe.addObjectFile(std.Build.LazyPath{ .path = "./lib/Version.lib" });
    exe.addObjectFile(std.Build.LazyPath{ .path = "./lib/WinMM.lib" });
    exe.addObjectFile(std.Build.LazyPath{ .path = "./lib/Gdi32.lib" });
    exe.addObjectFile(std.Build.LazyPath{ .path = "./lib/SDL2.lib" });
    exe.addObjectFile(std.Build.LazyPath{ .path = "./lib/SDL2main.lib" });
    exe.addObjectFile(std.Build.LazyPath{ .path = "./lib/OpenCL.lib" });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
