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

pub fn parse(parser: *Parser) !?@This() {
    const @"=" = try parser.match(parser.allocator, .consume, .{.@"="}) orelse return null;
    const value = try Expr.parse(parser) orelse return null;

    return .{ .@"=" = @"=", .expr = value };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.expr.deinit(allocator);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_assign)).@"fn".return_type.? {
    return visitor.visit_assignExpr(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
