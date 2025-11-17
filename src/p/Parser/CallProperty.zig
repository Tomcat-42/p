const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;
const Token = p.Tokenizer.Token;

@".": Token,
id: Token,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const @"." = try parser.expectOrHandleErrorAndSync(allocator, .{.@"."}) orelse return null;
    const id = try parser.expectOrHandleErrorAndSync(allocator, .{.identifier}) orelse return null;

    return .{ .@"." = @".", .id = id };
}

pub fn deinit(_: *@This(), _: Allocator) void {}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitCallProperty)).@"fn".return_type.? {
    return visitor.visitCallProperty(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
