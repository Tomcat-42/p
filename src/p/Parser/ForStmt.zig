const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const ForInit = Parser.ForInit;
const ForCond = Parser.ForCond;
const ForInc = Parser.ForInc;
const Block = Parser.Block;
const Visitor = Parser.Visitor;
const TreeFormatter = p.common.TreeFormatter;
const Token = p.Tokenizer.Token;

@"for": Token,
@"(": Token,
init: ?ForInit,
cond: ?ForCond,
inc: ?ForInc,
@")": Token,
body: Block,

pub fn parse(parser: *Parser, allocator: Allocator) anyerror!?@This() {
    const @"for" = try parser.match(allocator, .consume, .{.@"for"}) orelse return null;
    const @"(" = try parser.match(allocator, .consume, .{.@"("}) orelse return null;

    const init = if (parser.tokens.match(.peek, .{ .let, .true, .false, .nil, .this, .number, .string, .identifier, .@"(", .proto, .@"!", .@"-", .@";" })) |_|
        try ForInit.parse(parser, allocator) orelse return null
    else
        null;

    const cond = if (parser.tokens.match(.peek, .{ .true, .false, .nil, .this, .number, .string, .identifier, .@"(", .proto, .@"!", .@"-", .@";" })) |_|
        try ForCond.parse(parser, allocator) orelse return null
    else
        null;

    const inc = if (parser.tokens.match(.peek, .{ .true, .false, .nil, .this, .number, .string, .identifier, .@"(", .proto, .@"!", .@"-" })) |_|
        try ForInc.parse(parser, allocator) orelse return null
    else
        null;

    const @")" = try parser.match(allocator, .consume, .{.@")"}) orelse return null;
    const body = try Block.parse(parser, allocator) orelse return null;

    return .{
        .@"for" = @"for",
        .@"(" = @"(",
        .init = init,
        .cond = cond,
        .inc = inc,
        .@")" = @")",
        .body = body,
    };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    if (this.init) |*init| init.deinit(allocator);
    if (this.cond) |*cond| cond.deinit(allocator);
    if (this.inc) |*inc| inc.deinit(allocator);
    this.body.deinit(allocator);
}

pub fn visit(this: *const @This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_for_stmt)).@"fn".return_type.? {
    return visitor.visit_for_stmt(allocator, this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
