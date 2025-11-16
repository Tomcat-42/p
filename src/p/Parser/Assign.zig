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

pub const Assign = union(enum) {
    assign_expr: *const AssignExpr,
    logic_or: *const LogicOr,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        if (try AssignExpr.parse(parser, allocator)) |expr|
            return .{ .assign_expr = try allocator.dupe(@This(), expr) };

        const logic_or = try LogicOr.parse(parser, allocator) orelse return null;
        return .{ .logic_or = try allocator.dupe(LogicOr, &logic_or) };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitAssign)).@"fn".return_type.? {
        return visitor.visitAssign(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
