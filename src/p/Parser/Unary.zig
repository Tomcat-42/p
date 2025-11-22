const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const UnaryExpr = Parser.UnaryExpr;
const Call = Parser.Call;
const Visitor = Parser.Visitor;
const TreeFormatter = p.common.TreeFormatter;
const util = @import("util");

pub const Unary = union(enum) {
    unary_expr: *UnaryExpr,
    call: Call,

    pub fn parse(parser: *Parser) !?@This() {
        const lookahead = try parser.match(parser.allocator, .peek, .{
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
            .@"-", .@"!" => .{ .unary_expr = try util.dupe(UnaryExpr, parser.allocator, try UnaryExpr.parse(parser) orelse return null) },
            .true, .false, .nil, .this, .number, .string, .identifier, .@"(", .proto => .{ .call = try Call.parse(parser) orelse return null },
            else => null,
        };
    }

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        switch (this.*) {
            .unary_expr => |ptr| {
                ptr.deinit(allocator);
                allocator.destroy(ptr);
            },
            .call => |*call| call.deinit(allocator),
        }
    }

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitUnary)).@"fn".return_type.? {
        return visitor.visitUnary(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};
