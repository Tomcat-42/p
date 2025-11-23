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
const TreeFormatter = p.common.TreeFormatter;

primary: Primary,
calls: []CallExpr,

pub fn parse(parser: *Parser) !?@This() {
    const primary = try Primary.parse(parser) orelse return null;

    var calls: ArrayList(CallExpr) = .empty;
    errdefer calls.deinit(parser.allocator);

    while (parser.tokens.peek()) |token| switch (token.tag) {
        .@"(", .@"." => try calls.append(
            parser.allocator,
            try CallExpr.parse(parser) orelse return null,
        ),
        else => break,
    };

    return .{
        .primary = primary,
        .calls = try calls.toOwnedSlice(parser.allocator),
    };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.primary.deinit(allocator);
    for (this.calls) |*call| call.deinit(allocator);
    allocator.free(this.calls);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_call)).@"fn".return_type.? {
    return visitor.visit_call(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
