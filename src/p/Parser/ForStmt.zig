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
cond: ?ForCond,
@";'": Token,
inc: ?ForInc,
@")": Token,
body: Block,

// TODO: Fix this shit
pub fn parse(parser: *Parser, allocator: Allocator) anyerror!?@This() {
    const @"for" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"for"}) orelse return null;
    const @"(" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"("}) orelse return null;

    const ini = try ForInit.parse(parser, allocator);

    const cond = try ForCond.parse(parser, allocator);
    const @";'" = try parser.expectOrHandleErrorAndSync(allocator, .{.@";"}) orelse return null;

    const inc = try ForInc.parse(parser, allocator);
    const @")" = try parser.expectOrHandleErrorAndSync(allocator, .{.@")"}) orelse return null;
    const body = try Block.parse(parser, allocator) orelse return null;

    return .{
        .@"for" = @"for",
        .@"(" = @"(",
        .init = ini,
        .cond = cond,
        .@";'" = @";'",
        .inc = inc,
        .@")" = @")",
        .body = body,
    };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    if (this.init) |*init| init.deinit(allocator);
    if (this.cond) |*cond| cond.deinit(allocator);
    if (this.inc) |*inc| inc.deinit(allocator);
    this.body.deinit(allocator);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitForStmt)).@"fn".return_type.? {
    return visitor.visitForStmt(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
