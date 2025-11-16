const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const p = @import("p");
const Parser = p.Parser;
const Factor = Parser.Factor;
const TermExpr = Parser.TermExpr;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;

first: Factor,
suffixes: []const TermExpr,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const first = try Factor.parse(parser, allocator) orelse return null;

    var suffixes: ArrayList(TermExpr) = .empty;
    defer suffixes.deinit(allocator);
    while (try TermExpr.parse(parser, allocator)) |suffix|
        try suffixes.append(allocator, suffix);

    return .{
        .first = first,
        .suffixes = try suffixes.toOwnedSlice(allocator),
    };
}

pub fn visit(this: *const @This(), visitor: Visitor)  @typeInfo(@TypeOf(Visitor.visitTerm)).@"fn".return_type.? {
    return visitor.visitTerm(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
