const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const UnaryExpr = Parser.UnaryExpr;
const Call = Parser.Call;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;
const util = @import("util");
const Box = util.Box;

pub const Unary = union(enum) {
    unary_expr: Box(UnaryExpr),
    call: Call,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        return switch ((parser.tokens.peek() orelse return null).tag) {
            .@"-", .@"!" => .{ .unary_expr = try .init(allocator,try UnaryExpr.parse(parser, allocator) orelse return null) },
            else => .{ .call = try Call.parse(parser, allocator) orelse return null },
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitUnary)).@"fn".return_type.? {
        return visitor.visitUnary(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
