const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const Expr = Parser.Expr;
const Block = Parser.Block;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;
const Token = p.Tokenizer.Token;

@"while": Token,
@"(": Token,
cond: Expr,
@")": Token,
body: Block,

pub fn parse(parser: *Parser, allocator: Allocator) anyerror!?@This() {
    const @"while" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"while"}) orelse return null;
    const @"(" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"("}) orelse return null;
    const cond = try Expr.parse(parser, allocator) orelse return null;
    const @")" = try parser.expectOrHandleErrorAndSync(allocator, .{.@")"}) orelse return null;
    const body = try Block.parse(parser, allocator) orelse return null;

    return .{
        .@"while" = @"while",
        .@"(" = @"(",
        .cond = cond,
        .@")" = @")",
        .body = body,
    };
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitWhileStmt)).@"fn".return_type.? {
    return visitor.visitWhileStmt(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
