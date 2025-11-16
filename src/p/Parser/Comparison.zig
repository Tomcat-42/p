const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const p = @import("p");
const Parser = p.Parser;
const Term = Parser.Term;
const ComparisonSuffix = Parser.ComparisonExpr;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;

first: Term,
suffixes: []const ComparisonSuffix,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const first = try Term.parse(parser, allocator) orelse return null;

    var suffixes: ArrayList(ComparisonSuffix) = .empty;
    defer suffixes.deinit(allocator);
    while (try ComparisonSuffix.parse(parser, allocator)) |suffix|
        try suffixes.append(allocator, suffix);

    return .{
        .first = first,
        .suffixes = try suffixes.toOwnedSlice(allocator),
    };
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitComparison)).@"fn".return_type.? {
    return visitor.visitComparison(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
