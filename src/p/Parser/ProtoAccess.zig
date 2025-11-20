const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const Visitor = Parser.Visitor;
const MakeFormat = p.util.TreeFormatter;
const Token = p.Tokenizer.Token;

proto: Token,
@".": Token,
id: Token,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const proto = try parser.match(allocator, .consume, .{.identifier}) orelse return null;
    const @"." = try parser.match(allocator, .consume, .{.@"."}) orelse return null;
    const id = try parser.match(allocator, .consume, .{.identifier}) orelse return null;

    return .{ .proto = proto, .@"." = @".", .id = id };
}

pub fn deinit(_: *@This(), _: Allocator) void {}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitProtoAccess)).@"fn".return_type.? {
    return visitor.visitProtoAccess(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
