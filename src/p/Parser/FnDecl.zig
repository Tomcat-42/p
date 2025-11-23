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

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const @"fn" = try parser.match(allocator, .consume, .{.@"fn"}) orelse return null;
    const id = try parser.match(allocator, .consume, .{.identifier}) orelse return null;
    const @"(" = try parser.match(allocator, .consume, .{.@"("}) orelse return null;

    var params: ArrayList(FnParam) = .empty;
    errdefer params.deinit(allocator);

    while (parser.tokens.match(.peek, .{.identifier})) |lookahead| switch (lookahead.tag) {
        .identifier => try params.append(
            allocator,
            try FnParam.parse(parser, allocator) orelse return null,
        ),
        else => break,
    };

    const @")" = try parser.match(allocator, .consume, .{.@")"}) orelse return null;
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

pub fn deinit(this: *@This(), allocator: Allocator) void {
    allocator.free(this.params);
    this.body.deinit(allocator);
}

pub fn visit(this: *const @This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_fn_decl)).@"fn".return_type.? {
    return visitor.visit_fn_decl(allocator, this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
