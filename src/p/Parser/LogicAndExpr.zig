const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const Equality = Parser.Equality;
const Visitor = Parser.Visitor;
const MakeFormat = p.util.TreeFormatter;
const Token = p.Tokenizer.Token;

@"and": Token,
equality: Equality,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const @"and" = try parser.match(allocator, .consume, .{.@"and"}) orelse return null;
    const equality = try Equality.parse(parser, allocator) orelse return null;

    return .{ .@"and" = @"and", .equality = equality };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.equality.deinit(allocator);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitLogicAndExpr)).@"fn".return_type.? {
    return visitor.visitLogicAndExpr(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
