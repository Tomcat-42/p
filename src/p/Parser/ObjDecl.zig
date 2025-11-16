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
const MakeFormat = Parser.MakeFormat;

object: Token,
id: Token,
extends: ?ObjDeclExtends,
body: Block,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const object = try parser.expectOrHandleErrorAndSync(allocator, .{.object}) orelse return null;
    const id = try parser.expectOrHandleErrorAndSync(allocator, .{.identifier}) orelse return null;
    const extends: ?ObjDeclExtends = switch ((parser.tokens.peek() orelse return null).tag) {
        .extends => try ObjDeclExtends.parse(parser, allocator) orelse return null,
        else => null,
    };
    const body = try Block.parse(parser, allocator) orelse return null;

    return .{
        .object = object,
        .id = id,
        .extends = extends,
        .body = body,
    };
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitObjDecl)).@"fn".return_type.? {
    return visitor.visitObjDecl(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
