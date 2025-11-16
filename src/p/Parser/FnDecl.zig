const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const p = @import("p");
const Parser = p.Parser;
const FnParam = Parser.FnParam;
const Block = Parser.Block;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;
const Token = p.Tokenizer.Token;

@"fn": Token,
id: Token,
@"(": Token,
params: []const FnParam,
@")": Token,
body: Block,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const @"fn" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"fn"}) orelse return null;
    const id = try parser.expectOrHandleErrorAndSync(allocator, .{.identifier}) orelse return null;
    const @"(" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"("}) orelse return null;

    var params: ArrayList(FnParam) = .empty;
    defer params.deinit(allocator);
    while (try FnParam.parse(parser, allocator)) |param|
        try params.append(allocator, param);

    const @")" = try parser.expectOrHandleErrorAndSync(allocator, .{.@")"}) orelse return null;
    const body = try Block.parse(parser, allocator) orelse return null;

    return .{
        .@"fn" = @"fn",
        .id = id,
        .@"(" = @"(",
        .params = try params.toOwnedSlice(allocator),
        .@")" = @")",
        .body = body,
    };
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitFnDecl)).@"fn".return_type.? {
    return visitor.visitFnDecl(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
