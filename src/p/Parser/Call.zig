const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const p = @import("p");
const Parser = p.Parser;
const Primary = Parser.Primary;
const CallExpr = Parser.CallExpr;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;

primary: Primary,
calls: []CallExpr,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const primary = try Primary.parse(parser, allocator) orelse return null;

    var calls: ArrayList(CallExpr) = .empty;
    errdefer calls.deinit(allocator);

    while (parser.tokens.peek()) |token| switch (token.tag) {
        .@"(", .@"." => try calls.append(
            allocator,
            try CallExpr.parse(parser, allocator) orelse return null,
        ),
        else => break,
    };

    return .{
        .primary = primary,
        .calls = try calls.toOwnedSlice(allocator),
    };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.primary.deinit(allocator);
    for (this.calls) |*call| call.deinit(allocator);
    allocator.free(this.calls);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitCall)).@"fn".return_type.? {
    return visitor.visitCall(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
