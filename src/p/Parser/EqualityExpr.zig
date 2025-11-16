const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const EqualityOp = Parser.EqualityOp;
const Comparison = Parser.Comparison;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;

op: EqualityOp,
comparison: Comparison,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const op = try EqualityOp.parse(parser, allocator) orelse return null;
    const comparison = try Comparison.parse(parser, allocator) orelse return null;

    return .{ .op = op, .comparison = comparison };
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitEqualitySuffix)).@"fn".return_type.? {
    return visitor.visitEqualitySuffix(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
