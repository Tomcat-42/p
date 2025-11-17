const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const p = @import("p");
const Parser = p.Parser;
const Equality = Parser.Equality;
const LogicAndExpr = Parser.LogicAndExpr;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;

first: Equality,
suffixes: []const LogicAndExpr,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const first = try Equality.parse(parser, allocator) orelse return null;

    var suffixes: ArrayList(LogicAndExpr) = .empty;
    errdefer suffixes.deinit(allocator);

    while (parser.tokens.peek()) |token| switch (token.tag) {
        .@"and" => try suffixes.append(allocator, try LogicAndExpr.parse(parser, allocator) orelse return null),
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

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitLogicAnd)).@"fn".return_type.? {
    return visitor.visitLogicAnd(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
