const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const Expr = Parser.Expr;
const Visitor = Parser.Visitor;
const TreeFormatter = p.common.TreeFormatter;
const Token = p.Tokenizer.Token;

expr: Expr,
@",": ?Token,

pub fn parse(parser: *Parser, allocator: Allocator) anyerror!?@This() {
    const expr = try Expr.parse(parser, allocator) orelse return null;
    const @"," = parser.tokens.match(.consume, .{.@","});

    return .{ .expr = expr, .@"," = @"," };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.expr.deinit(allocator);
}

pub fn visit(this: *const @This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_fn_arg)).@"fn".return_type.? {
    return visitor.visit_fn_arg(allocator, this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
