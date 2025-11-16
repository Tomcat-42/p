const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const p = @import("p");
const Parser = p.Parser;
const Stmt = Parser.Stmt;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;
const Token = p.Tokenizer.Token;

@"{": Token,
stmts: []const Stmt,
@"}": Token,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const @"{" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"{"}) orelse return null;

    var stmts: ArrayList(Stmt) = .empty;
    defer stmts.deinit(allocator);
    while (try Stmt.parse(parser, allocator)) |stmt|
        try stmts.append(allocator, stmt);

    const @"}" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"}"}) orelse return null;

    return .{
        .@"{" = @"{",
        .stmts = try stmts.toOwnedSlice(allocator),
        .@"}" = @"}",
    };
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitBlock)).@"fn".return_type.? {
    return visitor.visitBlock(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
