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

pub fn parse(parser: *Parser) anyerror!?@This() {
    const logic_or = try LogicOr.parse(parser) orelse return null;
    const assign_expr: ?AssignExpr = if (parser.tokens.match(.peek, .{.@"="})) |_|
        try AssignExpr.parse(parser) orelse return null
    else
        null;

    return .{
        .logic_or = try util.dupe(LogicOr, parser.allocator, logic_or),
        .assign_expr = if (assign_expr) |ae| try util.dupe(AssignExpr, parser.allocator, ae) else null,
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

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitAssign)).@"fn".return_type.? {
    return visitor.visitAssign(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
