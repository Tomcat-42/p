const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const p = @import("p");
const Parser = p.Parser;
const Program = Parser.Program;
const Visitor = Parser.Visitor;
const MakeFormat = p.util.TreeFormatter;
const Token = p.Tokenizer.Token;

@"{": Token,
program: Program,
@"}": Token,

pub fn parse(parser: *Parser, allocator: Allocator) anyerror!?@This() {
    const @"{" = try parser.match(allocator, .consume, .{.@"{"}) orelse return null;
    const program = try Program.parse(parser, allocator) orelse return null;
    const @"}" = try parser.match(allocator, .consume, .{.@"}"}) orelse return null;

    return .{
        .@"{" = @"{",
        .program = program,
        .@"}" = @"}",
    };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.program.deinit(allocator);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitBlock)).@"fn".return_type.? {
    return visitor.visitBlock(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
