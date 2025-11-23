const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const AssignExpr = Parser.AssignExpr;
const LogicOr = Parser.LogicOr;
const Visitor = Parser.Visitor;
const TreeFormatter = p.common.TreeFormatter;
const util = @import("util");

logic_or: *LogicOr,
assign_expr: ?*AssignExpr = null,

pub fn parse(parser: *Parser, allocator: Allocator) anyerror!?@This() {
    const logic_or = try LogicOr.parse(parser, allocator) orelse return null;
    const assign_expr: ?AssignExpr = if (parser.tokens.match(.peek, .{.@"="})) |_|
        try AssignExpr.parse(parser, allocator) orelse return null
    else
        null;

    return .{
        .logic_or = try util.dupe(LogicOr, allocator, logic_or),
        .assign_expr = if (assign_expr) |ae| try util.dupe(AssignExpr, allocator, ae) else null,
    };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.logic_or.deinit(allocator);
    allocator.destroy(this.logic_or);

    if (this.assign_expr) |assign_expr| {
        assign_expr.deinit(allocator);
        allocator.destroy(assign_expr);
    }
}

pub fn visit(this: *const @This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_assign)).@"fn".return_type.? {
    return visitor.visit_assign(allocator, this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
