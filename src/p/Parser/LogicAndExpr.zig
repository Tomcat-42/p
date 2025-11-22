const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const Equality = Parser.Equality;
const Visitor = Parser.Visitor;
const TreeFormatter = p.common.TreeFormatter;
const Token = p.Tokenizer.Token;

@"and": Token,
equality: Equality,

pub fn parse(parser: *Parser) !?@This() {
    const @"and" = try parser.match(parser.allocator, .consume, .{.@"and"}) orelse return null;
    const equality = try Equality.parse(parser) orelse return null;

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

const Format = TreeFormatter(@This());
