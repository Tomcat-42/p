const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const p = @import("p");
const Parser = p.Parser;
const LogicAnd = Parser.LogicAnd;
const LogicOrExpr = Parser.LogicOrExpr;
const Visitor = Parser.Visitor;
const TreeFormatter = p.common.TreeFormatter;

first: LogicAnd,
suffixes: []LogicOrExpr,

pub fn parse(parser: *Parser) !?@This() {
    const first = try LogicAnd.parse(parser) orelse return null;

    var suffixes: ArrayList(LogicOrExpr) = .empty;
    errdefer suffixes.deinit(parser.allocator);

    while (parser.tokens.peek()) |lookahead| switch (lookahead.tag) {
        .@"or" => try suffixes.append(parser.allocator, try LogicOrExpr.parse(parser) orelse return null),
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

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitLogicOr)).@"fn".return_type.? {
    return visitor.visitLogicOr(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
