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

@"=": Token,
expr: Expr,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const @"=" = try parser.match(allocator, .consume, .{.@"="}) orelse return null;
    const value = try Expr.parse(parser, allocator) orelse return null;

    return .{ .@"=" = @"=", .expr = value };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.expr.deinit(allocator);
}

pub fn visit(this: *const @This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_assign_expr)).@"fn".return_type.? {
    return visitor.visit_assign_expr(allocator, this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
