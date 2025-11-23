const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const Comparison = Parser.Comparison;
const Visitor = Parser.Visitor;
const TreeFormatter = p.common.TreeFormatter;
const Token = p.Tokenizer.Token;

op: Token,
comparison: Comparison,

pub fn parse(parser: *Parser) !?@This() {
    const op = try parser.match(parser.allocator, .consume, .{ .@"==", .@"!=" }) orelse return null;
    const comparison = try Comparison.parse(parser) orelse return null;

    return .{ .op = op, .comparison = comparison };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.comparison.deinit(allocator);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_equalitySuffix)).@"fn".return_type.? {
    return visitor.visit_equalitySuffix(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
