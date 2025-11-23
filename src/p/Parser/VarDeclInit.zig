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
    const expr = try Expr.parse(parser) orelse return null;

    return .{ .@"=" = @"=", .expr = expr };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.expr.deinit(allocator);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_var_declInit)).@"fn".return_type.? {
    return visitor.visit_var_declInit(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
