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
const TreeFormatter = p.common.TreeFormatter;
const Token = p.Tokenizer.Token;

@"fn": Token,
id: Token,
@"(": Token,
params: []const FnParam,
@")": Token,
body: Block,

pub fn parse(parser: *Parser) !?@This() {
    const @"fn" = try parser.match(parser.allocator, .consume, .{.@"fn"}) orelse return null;
    const id = try parser.match(parser.allocator, .consume, .{.identifier}) orelse return null;
    const @"(" = try parser.match(parser.allocator, .consume, .{.@"("}) orelse return null;

    var params: ArrayList(FnParam) = .empty;
    errdefer params.deinit(parser.allocator);

    while (parser.tokens.match(.peek, .{.identifier})) |lookahead| switch (lookahead.tag) {
        .identifier => try params.append(
            parser.allocator,
            try FnParam.parse(parser) orelse return null,
        ),
        else => break,
    };

    const @")" = try parser.match(parser.allocator, .consume, .{.@")"}) orelse return null;
    const body = try Block.parse(parser) orelse return null;

    return .{
        .@"fn" = @"fn",
        .id = id,
        .@"(" = @"(",
        .params = try params.toOwnedSlice(parser.allocator),
        .@")" = @")",
        .body = body,
    };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    allocator.free(this.params);
    this.body.deinit(allocator);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitFnDecl)).@"fn".return_type.? {
    return visitor.visitFnDecl(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
