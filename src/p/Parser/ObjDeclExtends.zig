const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const Visitor = Parser.Visitor;
const TreeFormatter = p.common.TreeFormatter;
const Token = p.Tokenizer.Token;

extends: Token,
id: Token,

pub fn parse(parser: *Parser) !?@This() {
    const extends = try parser.match(parser.allocator, .consume, .{.extends}) orelse return null;
    const id = try parser.match(parser.allocator, .consume, .{.identifier}) orelse return null;

    return .{ .extends = extends, .id = id };
}

pub fn deinit(_: *@This(), _: Allocator) void {}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_obj_declExtends)).@"fn".return_type.? {
    visitor.visit_obj_declExtends(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
