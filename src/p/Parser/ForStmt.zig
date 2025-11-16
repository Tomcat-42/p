const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const ForInit = Parser.ForInit;
const ForCond = Parser.ForCond;
const ForInc = Parser.ForInc;
const Block = Parser.Block;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;
const Token = p.Tokenizer.Token;

@"for": Token,
@"(": Token,
init: ?ForInit,
@";": Token,
cond: ?ForCond,
@";'": Token,
inc: ?ForInc,
@")": Token,
body: Block,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const @"for" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"for"}) orelse return null;
    const @"(" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"("}) orelse return null;

    const initv = try ForInit.parse(parser, allocator);
    const @";" = try parser.expectOrHandleErrorAndSync(allocator, .{.@";"}) orelse return null;

    const cond = try ForCond.parse(parser, allocator);
    const @";'" = try parser.expectOrHandleErrorAndSync(allocator, .{.@";"}) orelse return null;

    const inc = try ForInc.parse(parser, allocator);
    const @")" = try parser.expectOrHandleErrorAndSync(allocator, .{.@")"}) orelse return null;
    const body = try Block.parse(parser, allocator) orelse return null;

    return .{
        .@"for" = @"for",
        .@"(" = @"(",
        .init = initv,
        .@";" = @";",
        .cond = cond,
        .@";'" = @";'",
        .inc = inc,
        .@")" = @")",
        .body = body,
    };
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitForStmt)).@"fn".return_type.? {
    return visitor.visitForStmt(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
