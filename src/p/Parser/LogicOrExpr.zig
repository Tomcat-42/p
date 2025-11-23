const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const LogicAnd = Parser.LogicAnd;
const Visitor = Parser.Visitor;
const TreeFormatter = p.common.TreeFormatter;
const Token = p.Tokenizer.Token;

op: Token,
logic_and: LogicAnd,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const op = try parser.match(allocator, .consume, .{.@"and"}) orelse return null;
    const logic_and = try LogicAnd.parse(parser, allocator) orelse return null;

    return .{ .op = op, .logic_and = logic_and };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.logic_and.deinit(allocator);
}

pub fn visit(this: *const @This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_logic_orExpr)).@"fn".return_type.? {
    return visitor.visit_logic_orExpr(allocator, this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
