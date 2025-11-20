const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const CallFn = Parser.CallFn;
const CallProperty = Parser.CallProperty;
const Visitor = Parser.Visitor;
const MakeFormat = p.util.TreeFormatter;

pub const CallExpr = union(enum) {
    call_fn: CallFn,
    call_property: CallProperty,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const lookahead = parser.tokens.peek() orelse return null;

        return switch (lookahead.tag) {
            .@"(" => .{ .call_fn = try CallFn.parse(parser, allocator) orelse return null },
            .@"." => .{ .call_property = try CallProperty.parse(parser, allocator) orelse return null },
            else => null,
        };
    }

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        switch (this.*) {
            inline else => |*call| call.deinit(allocator),
        }
    }

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitCallExpr)).@"fn".return_type.? {
        return visitor.visitCallExpr(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
