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

@"=": Token,
expr: Expr,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const @"=" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"="}) orelse return null;
    const expr = try Expr.parse(parser, allocator) orelse return null;

    return .{ .@"=" = @"=", .expr = &expr };
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitVarDeclInit)).@"fn".return_type.? {
    return visitor.visitVarDeclInit(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
