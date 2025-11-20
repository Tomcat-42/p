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
const MakeFormat = p.util.TreeFormatter;

first: Factor,
suffixes: []const TermExpr,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const first = try Factor.parse(parser, allocator) orelse return null;

    var suffixes: ArrayList(TermExpr) = .empty;
    errdefer suffixes.deinit(allocator);

    while (parser.tokens.peek()) |token| switch (token.tag) {
        .@"-", .@"+" => try suffixes.append(allocator, try TermExpr.parse(parser, allocator) orelse return null),
        else => break,
    };

    return .{
        .first = first,
        .suffixes = try suffixes.toOwnedSlice(allocator),
    };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.first.deinit(allocator);
    for (this.suffixes) |suffix| suffix.deinit(allocator);
    allocator.free(this.suffixes);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitTerm)).@"fn".return_type.? {
    return visitor.visitTerm(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
