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
const util = @import("util");

expr: Expr,
@";": Token,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    var expr = try Expr.parse(parser, allocator) orelse return null;
    errdefer expr.deinit(allocator);

    const @";" = try parser.match(allocator, .consume, .{.@";"}) orelse {
        expr.deinit(allocator);
        return null;
    };

    return .{
        .expr = expr,
        .@";" = @";",
    };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.expr.deinit(allocator);
}

pub fn visit(this: *const @This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_expr_stmt)).@"fn".return_type.? {
    return visitor.visit_expr_stmt(allocator, this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
