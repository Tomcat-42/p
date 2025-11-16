const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const P = @import("../Parser.zig");
const Parser = P.Parser;
const FactorOp = P.FactorOp;
const Unary = P.Unary;
const Visitor = P.Visitor;
const MakeFormat = P.MakeFormat;

op: FactorOp,
unary: Unary,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const op = try FactorOp.parse(parser, allocator) orelse return null;
    const unary = try Unary.parse(parser, allocator) orelse return null;

    return .{ .op = op, .unary = unary };
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitFactorSuffix)).@"fn".return_type.? {
    return visitor.visitFactorSuffix(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
