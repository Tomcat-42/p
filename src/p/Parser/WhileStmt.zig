const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const Expr = Parser.Expr;
const Block = Parser.Block;
const Visitor = Parser.Visitor;
const TreeFormatter = p.common.TreeFormatter;
const Token = p.Tokenizer.Token;

@"while": Token,
@"(": Token,
cond: Expr,
@")": Token,
body: Block,

pub fn parse(parser: *Parser) anyerror!?@This() {
    const @"while" = try parser.match(parser.allocator, .consume, .{.@"while"}) orelse return null;
    const @"(" = try parser.match(parser.allocator, .consume, .{.@"("}) orelse return null;
    const cond = try Expr.parse(parser) orelse return null;
    const @")" = try parser.match(parser.allocator, .consume, .{.@")"}) orelse return null;
    const body = try Block.parse(parser) orelse return null;

    return .{
        .@"while" = @"while",
        .@"(" = @"(",
        .cond = cond,
        .@")" = @")",
        .body = body,
    };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.cond.deinit(allocator);
    this.body.deinit(allocator);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_while_stmt)).@"fn".return_type.? {
    return visitor.visit_while_stmt(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
