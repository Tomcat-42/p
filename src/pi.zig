const std = @import("std");
const posix = std.posix;
const mem = std.mem;
const heap = std.heap;
const fs = std.fs;
const File = fs.File;
const Io = std.Io;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const builtin = @import("builtin");

const p = @import("p");
const Tokenizer = p.Tokenizer;
const Parser = p.Parser;
const util = @import("util");
const color = util.color;
const getopt = util.getopt;
const err = util.err;

const Repl = struct {
    prompt: []const u8 = color.FG.GREEN ++ "p> " ++ color.RESET,

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

    pub fn eval(this: *const @This(), allocator: Allocator, code: []const u8) !void {
        var tokens: Tokenizer = .init(code);
        while (tokens.next()) |tok| std.debug.print("{f}", .{tok.format(0)});
        tokens.reset();

        var parser: Parser = .init(&tokens);
        defer parser.deinit(allocator);

        const parseTree = try parser.parse(allocator);
        if (parseTree) |cst| try stdout.print("{f}\n", .{cst.format(0)});

        if (parser.errs()) |errors| try this.reportErrors(errors);
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

    var interpreter: Repl = .{};

    var opts = getopt.init("i:hv");
    while (opts.next() catch return opts.usage()) |opt| switch (opt) {
        'h' => return opts.usage(),
        'v' => return version(),
        else => unreachable,
    };

    if (opts.positionals()) |filenames| for (filenames) |filename| {
        const file = try fs.cwd().openFile(mem.span(filename), .{});
        defer file.close();

        var buffer: [BUFFER_SIZE]u8 = undefined;
        var fileReader = file.reader(io, &buffer);
        const reader = &fileReader.interface;

        while (try reader.takeDelimiter('\n')) |line| try interpreter.eval(allocator, line);
    };

    var stdin_buffer: [BUFFER_SIZE]u8 = undefined;
    var stdin_reader = File.stdin().reader(io, &stdin_buffer);
    const stdin = &stdin_reader.interface;

    while (true) {
        try stdout.print("{s}", .{interpreter.prompt});
        try stdout.flush();

        const line = try stdin.takeDelimiter('\n') orelse break;
        try interpreter.eval(allocator, line);
    }
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
