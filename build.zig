const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zurlcode_module = b.addModule("zurlcode", .{
        .root_source_file = b.path("src/zurlcode.zig"),
        .target = target,
        .optimize = optimize,
    });

    const docs_library = b.addLibrary(.{
        .name = "zurlcode",
        .root_module = zurlcode_module,
    });
    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs_library.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Generate native Zig API documentation");
    docs_step.dependOn(&install_docs.step);

    const test_step = b.step("test", "Run all tests");

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/urlcode_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    unit_tests.root_module.addImport("zurlcode", zurlcode_module);
    const run_unit_tests = b.addRunArtifact(unit_tests);
    test_step.dependOn(&run_unit_tests.step);

    b.default_step = test_step;
}
