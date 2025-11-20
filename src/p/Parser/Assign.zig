const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const Box = @import("util").Box;
const p = @import("p");
const Parser = p.Parser;
const AssignExpr = Parser.AssignExpr;
const LogicOr = Parser.LogicOr;
const Visitor = Parser.Visitor;
const MakeFormat = p.util.TreeFormatter;

logic_or: Box(LogicOr),
assign_expr: ?Box(AssignExpr) = null,

pub fn parse(parser: *Parser, allocator: Allocator) anyerror!?@This() {
    const logic_or: Box(LogicOr) = try .init(allocator, try LogicOr.parse(parser, allocator) orelse return null);
    const assign_expr: ?Box(AssignExpr) = if (parser.tokens.match(.peek, .{.@"="})) |_|
        try .init(allocator, try AssignExpr.parse(parser, allocator) orelse return null)
    else
        null;

    return .{ .logic_or = logic_or, .assign_expr = assign_expr };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.logic_or.deinit(allocator);
    if (this.assign_expr) |*assign_expr| assign_expr.deinit(allocator);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitAssign)).@"fn".return_type.? {
    return visitor.visitAssign(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
