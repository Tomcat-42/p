const std = @import("std");
const posix = std.posix;
const mem = std.mem;
const heap = std.heap;
const fs = std.fs;
const File = fs.File;
const Io = std.Io;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
var LOG_LEVEL = std.log.default_level;
const builtin = @import("builtin");

const p = @import("p");
const Tokenizer = p.Tokenizer;
const Parser = p.Parser;
const Sema = p.Sema;
const util = @import("util");
const color = util.color;
const getopt = util.getopt;
const err = util.err;

const Cli = @import("pi/Cli.zig");

pub const log = std.log.scoped(.pi);

const Repl = struct {
    cli: Cli = .{},

    fn reportErrors(_: *const @This(), errors: []const Parser.Error) !void {
        for (errors) |e| try stderr.print("{d}:{d} Error: {s}{s}{s}\n", .{
            e.span.begin,
            e.span.end,
            color.FG.RED,
            e.message,
            color.RESET,
        });

        try stderr.flush();
    }

    pub fn eval(this: *const @This(), allocator: Allocator, code: []const u8) !?[]const u8 {
        //NOTE: Only for debugging
        var tokens: Tokenizer = .init(code);
        while (tokens.next()) |tok|
            log.debug("\n{f}", .{tok.format(0)});

        var parser: Parser = .init(allocator, .init(code));
        defer parser.deinit();

        var cst = if (try parser.parse()) |cst| cst else {
            if (parser.errs()) |errors| try this.reportErrors(errors);
            return null;
        };
        defer cst.deinit(allocator);

        log.debug("\n{f}\n", .{cst.format(0)});

        var sema: Sema = .init(allocator);
        defer sema.deinit();

        var ast = if (try sema.analyze(cst)) |ast| ast else {
            if (sema.errs()) |errors| try this.reportErrors(errors);
            return null;
        };
        defer ast.deinit(allocator);

        log.debug("\n{f}\n", .{ast.format(0)});

        return null;
    }

    pub fn run(this: *const @This(), allocator: Allocator, _: Io) !void {
        while (try this.cli.read(allocator)) |input| {
            defer allocator.free(input);
            if (input.len == 0) continue;

            const value = try this.eval(allocator, input);
            try stdout.print("⇒ {?s}\n", .{value});
            try stdout.flush();
        }
    }
};

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    const allocator = switch (builtin.mode) {
        .Debug, .ReleaseSafe => debug_allocator.allocator(),
        else => heap.smp_allocator,
    };
    defer switch (builtin.mode) {
        .Debug, .ReleaseSafe => assert(debug_allocator.deinit() == .ok),
        else => {},
    };

    var threaded: Io.Threaded = .init(allocator);
    defer threaded.deinit();
    const io = threaded.io();

    var interpreter: Repl = .{ .cli = .init("p") };

    var opts: getopt = .init("i:hVv");
    while (opts.next() catch return opts.usage()) |opt| switch (opt) {
        'h' => return opts.usage(),
        'V' => return version(),
        'v' => LOG_LEVEL = .debug,
        else => unreachable,
    };

    if (opts.positionals()) |filenames| for (filenames) |filename| {
        const file = try fs.cwd().openFile(mem.span(filename), .{});
        defer file.close();

        var buffer: [BUFFER_SIZE]u8 = undefined;
        var fileReader = file.reader(io, &buffer);
        const reader = &fileReader.interface;

        while (try reader.takeDelimiter('\n')) |line| {
            const value = try interpreter.eval(allocator, line);
            try stdout.print("⇒ {?s}\n", .{value});
        }
        try stdout.flush();
    };

    return Repl.run(&interpreter, allocator, io);
}

fn version() !void {
    const v = p.manifest.version;
    stderr.print("v{d}.{d}.{d}\n", .{ v.major, v.minor, v.patch }) catch
        @panic("failed to print version");
    stderr.flush() catch @panic("failed to flush stderr");
}

const BUFFER_SIZE = 64 * 1024; // 64 KiB

var stdout_buffer: [BUFFER_SIZE]u8 = undefined;
var stdout_writer = File.stdout().writer(&stdout_buffer);
pub const stdout = &stdout_writer.interface;

var stderr_buffer: [BUFFER_SIZE]u8 = undefined;
var stderr_writer = File.stderr().writer(&stderr_buffer);
pub const stderr = &stderr_writer.interface;
