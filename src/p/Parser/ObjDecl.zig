const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const ObjDeclExtends = Parser.ObjDeclExtends;
const Block = Parser.Block;
const Visitor = Parser.Visitor;
const Token = p.Tokenizer.Token;
const TreeFormatter = p.common.TreeFormatter;

object: Token,
id: Token,
extends: ?ObjDeclExtends,
body: Block,

pub fn parse(parser: *Parser) !?@This() {
    const object = try parser.match(parser.allocator, .consume, .{.object}) orelse return null;
    const id = try parser.match(parser.allocator, .consume, .{.identifier}) orelse return null;
    const extends = if (parser.tokens.match(.peek, .{.extends})) |_|
        try ObjDeclExtends.parse(parser) orelse return null
    else
        null;
    const body = try Block.parse(parser) orelse return null;

    return .{
        .object = object,
        .id = id,
        .extends = extends,
        .body = body,
    };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    if (this.extends) |*extends| extends.deinit(allocator);
    this.body.deinit(allocator);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_obj_decl)).@"fn".return_type.? {
    return visitor.visit_obj_decl(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
