const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Dependencies
    const lightmix = b.dependency("lightmix", .{ .with_debug_features = true });

    // Modules
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_mod.addImport("lightmix", lightmix.module("lightmix"));

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("lightmix", lightmix.module("lightmix"));
    exe_mod.addImport("lightmix_template", lib_mod);

    // Install
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "lightmix_template",
        .root_module = lib_mod,
    });
    lib.linkLibC();
    lib.linkSystemLibrary("portaudio-2.0");
    lib.linkSystemLibrary("sndfile");
    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "lightmix_template",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    // Run cmd
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Run step
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Unit tests
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Test step
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
