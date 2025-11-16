const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const Stmt = Parser.Stmt;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;
const Token = p.Tokenizer.Token;

@"else": Token,
stmt: Stmt,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const @"else" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"else"}) orelse return null;
    const stmt = try Stmt.parse(parser, allocator) orelse return null;

    return .{ .@"else" = @"else", .stmt = stmt };
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitIfElseBranch)).@"fn".return_type.? {
    return visitor.visitIfElseBranch(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
