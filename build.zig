const std = @import("std");
const SemanticVersion = std.SemanticVersion;
const zon = std.zon;
const fs = std.fs;
const Build = std.Build;
const Step = Build.Step;
const Module = Build.Module;
const Import = Module.Import;
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{ .default_target = .{ .abi = .musl } });
    const optimize = b.standardOptimizeOption(.{});
    const manifest = try zon.parse.fromSliceAlloc(
        struct { version: []const u8 },
        b.allocator,
        @embedFile("build.zig.zon"),
        null,
        .{ .ignore_unknown_fields = true },
    );

    // Modules and Deps
    const p_mod = b.addModule("p", .{
        .root_source_file = b.path("src/p.zig"),
        .target = target,
        .optimize = optimize,
    });
    const pi_mod = b.createModule(.{
        .root_source_file = b.path("src/pi.zig"),
        .target = target,
        .optimize = optimize,
    });

    const isocline = b.dependency("isocline", .{
        .optimize = optimize,
        .target = target,
    });
    pi_mod.linkLibrary(isocline.artifact("isocline"));

    const p_deps: []const Import = &.{
        .{ .name = "manifest", .module = mod: {
            const opts = b.addOptions();
            opts.addOption(SemanticVersion, "version", try SemanticVersion.parse(manifest.version));
            break :mod opts.createModule();
        } },
        .{ .name = "p", .module = p_mod },
        .{ .name = "util", .module = b.dependency("util", .{ .optimize = optimize, .target = target }).module("util") },
    };
    const pi_deps: []const Import = &.{
        .{ .name = "p", .module = p_mod },
        .{ .name = "pi", .module = pi_mod },
        .{ .name = "util", .module = b.dependency("util", .{ .optimize = optimize, .target = target }).module("util") },
    };
    for (p_deps) |dep| p_mod.addImport(dep.name, dep.module);
    for (pi_deps) |dep| pi_mod.addImport(dep.name, dep.module);

    // Targets
    const p = b.addLibrary(.{
        .name = "p",
        .root_module = p_mod,
        .use_llvm = true,
    });
    const p_check = b.addLibrary(.{ .name = "pcheck", .root_module = p_mod });
    const p_tests = b.addTest(.{
        .name = "ptest",
        .use_llvm = true,
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/p.zig"),
            .imports = &.{.{ .name = "p", .module = p_mod }},
            .target = target,
            .optimize = optimize,
        }),
    });

    const pi = b.addExecutable(.{
        .name = "pi",
        .root_module = pi_mod,
        .use_llvm = true,
    });
    const pi_check = b.addLibrary(.{ .name = "picheck", .root_module = pi_mod });
    const pi_tests = b.addTest(.{
        .name = "pitest",
        .use_llvm = true,
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/pi.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "p", .module = pi_mod }},
        }),
    });

    // Install
    b.installArtifact(p);
    b.installArtifact(pi);
    b.installArtifact(p_tests); // Useful for debugging
    b.installArtifact(pi_tests); // "

    // Run
    const run_cmd = b.addRunArtifact(pi);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Test
    const run_p_unit_tests = b.addRunArtifact(p_tests);
    const run_pi_unit_tests = b.addRunArtifact(pi_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_p_unit_tests.step);
    test_step.dependOn(&run_pi_unit_tests.step);

    // Clean
    const clean_step = b.step("clean", "Remove build artifacts");
    clean_step.dependOn(&b.addRemoveDirTree(b.path(fs.path.basename(b.install_path))).step);
    if (builtin.os.tag != .windows)
        clean_step.dependOn(&b.addRemoveDirTree(b.path(".zig-cache")).step);

    // Check Step
    const check_step = b.step("check", "Check that the build artifacts are up-to-date");
    check_step.dependOn(&pi_check.step);
    check_step.dependOn(&p_check.step);
}
