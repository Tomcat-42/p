const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;
const Token = p.Tokenizer.Token;

extends: Token,
id: Token,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const extends = try parser.expectOrHandleErrorAndSync(allocator, .{.extends}) orelse return null;
    const id = try parser.expectOrHandleErrorAndSync(allocator, .{.identifier}) orelse return null;

    return .{ .extends = extends, .id = id };
}

pub fn deinit(_: *@This(), _: Allocator) void {}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitObjDeclExtends)).@"fn".return_type.?  {
    visitor.visitObjDeclExtends(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
