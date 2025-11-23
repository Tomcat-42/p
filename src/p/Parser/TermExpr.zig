const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const Factor = Parser.Factor;
const Visitor = Parser.Visitor;
const TreeFormatter = p.common.TreeFormatter;
const Token = p.Tokenizer.Token;

op: Token,
factor: Factor,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const op = try parser.match(allocator, .consume, .{ .@"+", .@"-" }) orelse return null;
    const factor = try Factor.parse(parser, allocator) orelse return null;

    return .{ .op = op, .factor = factor };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.factor.deinit(allocator);
}

pub fn visit(this: *const @This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitExpr)).@"fn".return_type.? {
    return visitor.visit_termExpr(allocator, this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
