const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const p = @import("p");
const Parser = p.Parser;
const LogicAnd = Parser.LogicAnd;
const LogicOrSuffix = Parser.LogicOrExpr;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;

first: LogicAnd,
suffixes: []const LogicOrSuffix,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const first = try LogicAnd.parse(parser, allocator) orelse return null;

    var suffixes: ArrayList(LogicOrSuffix) = .empty;
    defer suffixes.deinit(allocator);
    while (try LogicOrSuffix.parse(parser, allocator)) |suffix|
        try suffixes.append(allocator, suffix);

    return .{
        .first = first,
        .suffixes = try suffixes.toOwnedSlice(allocator),
    };
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitLogicOr)).@"fn".return_type.? {
    return visitor.visitLogicOr(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
