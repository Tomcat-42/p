const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const Expr = Parser.Expr;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;
const Token = p.Tokenizer.Token;

expr: Expr,
@",": ?Token,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const expr = try Expr.parse(parser, allocator) orelse return null;
    const @"," = parser.tokens.expect(.{.@","});

    return .{ .expr = expr, .@"," = @"," };
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitFnArg)).@"fn".return_type.? {
    return visitor.visitFnArg(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
