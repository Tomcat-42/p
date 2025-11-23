const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const VarDeclInit = Parser.VarDeclInit;
const Visitor = Parser.Visitor;
const TreeFormatter = p.common.TreeFormatter;
const Token = p.Tokenizer.Token;

let: Token,
id: Token,
init: ?VarDeclInit,
@";": Token,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const let = try parser.match(allocator, .consume, .{.let}) orelse return null;
    const id = try parser.match(allocator, .consume, .{.identifier}) orelse return null;
    const init: ?VarDeclInit = init: {
        const lookahead = parser.tokens.match(.peek, .{.@"="}) orelse break :init null;
        break :init switch (lookahead.tag) {
            .@"=" => try VarDeclInit.parse(parser, allocator) orelse return null,
            else => unreachable,
        };
    };
    const @";" = try parser.match(allocator, .consume, .{.@";"}) orelse return null;

    return .{
        .let = let,
        .id = id,
        .init = init,
        .@";" = @";",
    };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    if (this.init) |*init| init.deinit(allocator);
}

pub fn visit(this: *const @This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_var_decl)).@"fn".return_type.? {
    return visitor.visit_var_decl(allocator, this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
