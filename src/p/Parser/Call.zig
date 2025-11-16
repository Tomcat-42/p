const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const p = @import("p");
const Parser = p.Parser;
const Primary = Parser.Primary;
const CallSuffix = Parser.CallExpr;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;

primary: Primary,
calls: []const CallSuffix,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const primary = try Primary.parse(parser, allocator) orelse return null;

    var calls: ArrayList(CallSuffix) = .empty;
    defer calls.deinit(allocator);
    while (try CallSuffix.parse(parser, allocator)) |suffix|
        try calls.append(allocator, suffix);

    return .{
        .primary = primary,
        .calls = try calls.toOwnedSlice(allocator),
    };
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitCall)).@"fn".return_type.? {
    return visitor.visitCall(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
