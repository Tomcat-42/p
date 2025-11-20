const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const UnaryExpr = Parser.UnaryExpr;
const Call = Parser.Call;
const Visitor = Parser.Visitor;
const MakeFormat = p.util.TreeFormatter;
const util = @import("util");
const Box = util.Box;

pub const Unary = union(enum) {
    unary_expr: Box(UnaryExpr),
    call: Call,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const lookahead = try parser.match(allocator, .peek, .{
            .@"-",
            .@"!",
            .true,
            .false,
            .nil,
            .this,
            .number,
            .string,
            .identifier,
            .@"(",
            .proto,
        }) orelse return null;

        return switch (lookahead.tag) {
            .@"-", .@"!" => .{ .unary_expr = try .init(allocator, try UnaryExpr.parse(parser, allocator) orelse return null) },
            .true, .false, .nil, .this, .number, .string, .identifier, .@"(", .proto => .{ .call = try Call.parse(parser, allocator) orelse return null },
            else => unreachable,
        };
    }

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        switch (this.*) {
            .unary_expr => |box| {
                box.value.deinit(allocator);
                box.deinit(allocator);
            },
            .call => |call| call.deinit(allocator),
        }
    }

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitUnary)).@"fn".return_type.? {
        return visitor.visitUnary(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
