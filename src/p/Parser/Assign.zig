const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const AssignExpr = Parser.AssignExpr;
const LogicOr = Parser.LogicOr;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;
const util = @import("util");
const Box = util.Box;

pub const Assign = union(enum) {
    assign_expr: Box(AssignExpr),
    logic_or: Box(LogicOr),

    pub fn parse(parser: *Parser, allocator: Allocator) anyerror!?@This() {
        if (try AssignExpr.parse(parser, allocator)) |expr|
            return .{ .assign_expr = try .init(allocator, expr) };

        const logic_or = try LogicOr.parse(parser, allocator) orelse return null;
        return .{ .logic_or = try .init(allocator, logic_or) };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitAssign)).@"fn".return_type.? {
        return visitor.visitAssign(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
