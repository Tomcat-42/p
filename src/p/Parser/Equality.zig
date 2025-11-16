const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const p = @import("p");
const Parser = p.Parser;
const Comparison = Parser.Comparison;
const EqualityExpr = Parser.EqualityExpr;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;

first: Comparison,
suffixes: []const EqualityExpr,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const first = try Comparison.parse(parser, allocator) orelse return null;

    var suffixes: ArrayList(EqualityExpr) = .empty;
    defer suffixes.deinit(allocator);
    while (try EqualityExpr.parse(parser, allocator)) |suffix|
        try suffixes.append(allocator, suffix);

    return .{
        .first = first,
        .suffixes = try suffixes.toOwnedSlice(allocator),
    };
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitEquality)).@"fn".return_type.? {
    return visitor.visitEquality(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
