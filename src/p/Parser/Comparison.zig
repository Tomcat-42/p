const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const p = @import("p");
const Parser = p.Parser;
const Term = Parser.Term;
const ComparisonExpr = Parser.ComparisonExpr;
const Visitor = Parser.Visitor;
const TreeFormatter = p.common.TreeFormatter;

first: Term,
suffixes: []ComparisonExpr,

pub fn parse(parser: *Parser) !?@This() {
    const first = try Term.parse(parser) orelse return null;

    var suffixes: ArrayList(ComparisonExpr) = .empty;
    errdefer suffixes.deinit(parser.allocator);

    while (parser.tokens.peek()) |token| switch (token.tag) {
        .@">", .@">=", .@"<", .@"<=" => try suffixes.append(parser.allocator, try ComparisonExpr.parse(parser) orelse return null),
        else => break,
    };

    return .{
        .first = first,
        .suffixes = try suffixes.toOwnedSlice(parser.allocator),
    };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.first.deinit(allocator);
    for (this.suffixes) |*suffix| suffix.deinit(allocator);
    allocator.free(this.suffixes);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_comparison)).@"fn".return_type.? {
    return visitor.visit_comparison(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
