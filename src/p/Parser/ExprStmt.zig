const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const Expr = Parser.Expr;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;
const Token = p.Tokenizer.Token;
const util = @import("util");
const Box = util.Box;

expr: Box(Expr),
@";": Token,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const expr: Box(Expr) = try .init(allocator, try Expr.parse(parser, allocator) orelse return null);
    const @";" = try parser.expectOrHandleErrorAndSync(allocator, .{.@";"}) orelse return null;

    return .{ .expr = expr, .@";" = @";" };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.expr.deinit(allocator);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitExprStmt)).@"fn".return_type.? {
    return visitor.visitExprStmt(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
