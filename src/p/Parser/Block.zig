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
stmts: []Stmt,
@"}": Token,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const @"{" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"{"}) orelse return null;

    var stmts: ArrayList(Stmt) = .empty;
    errdefer stmts.deinit(allocator);

    while (parser.tokens.peek()) |token| switch (token.tag) {
        .true,
        .false,
        .nil,
        .this,
        .number,
        .string,
        .identifier,
        .@"(",
        .proto,
        .@"!",
        .@"-",
        .@"for",
        .@"if",
        .print,
        .@"return",
        .@"while",
        .@"{",
        => try stmts.append(
            allocator,
            try Stmt.parse(parser, allocator) orelse break,
        ),
        else => break,
    };

    const @"}" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"}"}) orelse return null;

    return .{
        .@"{" = @"{",
        .stmts = try stmts.toOwnedSlice(allocator),
        .@"}" = @"}",
    };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    for (this.stmts) |*stmt| stmt.deinit(allocator);
    allocator.free(this.stmts);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitBlock)).@"fn".return_type.? {
    return visitor.visitBlock(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
