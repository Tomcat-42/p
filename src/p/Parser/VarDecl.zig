const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const VarDeclInit = Parser.VarDeclInit;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;
const Token = p.Tokenizer.Token;

let: Token,
id: Token,
init: ?VarDeclInit,
@";": Token,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const let = try parser.expectOrHandleErrorAndSync(allocator, .{.let}) orelse return null;
    const id = try parser.expectOrHandleErrorAndSync(allocator, .{.identifier}) orelse return null;
    const initv: ?VarDeclInit = switch ((parser.tokens.peek() orelse return null).tag) {
        .@"=" => try VarDeclInit.parse(parser, allocator) orelse return null,
        else => null,
    };
    const @";" = try parser.expectOrHandleErrorAndSync(allocator, .{.@";"}) orelse return null;

    return .{
        .let = let,
        .id = id,
        .init = initv,
        .@";" = @";",
    };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    if (this.init) |*init| init.deinit(allocator);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitVarDecl)).@"fn".return_type.? {
    visitor.visitVarDecl(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
