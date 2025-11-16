const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const Equality = Parser.Equality;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;
const Token = p.Tokenizer.Token;

@"and": Token,
equality: Equality,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const @"and" = parser.expectOrHandleErrorAndSync(allocator, .{.@"and"});
    const equality = try Equality.parse(parser, allocator) orelse return null;

    return .{ .@"and" = @"and", .equality = equality };
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitLogicAndExpr)).@"fn".return_type.? {
    return visitor.visitLogicAndExpr(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
