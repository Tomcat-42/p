const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const p = @import("p");
const Parser = p.Parser;
const FnArg = Parser.FnArg;
const Visitor = Parser.Visitor;
const TreeFormatter = p.common.TreeFormatter;
const Token = p.Tokenizer.Token;

@"(": Token,
args: []FnArg,
@")": Token,

pub fn parse(parser: *Parser) !?@This() {
    const @"(" = try parser.match(parser.allocator, .consume, .{.@"("}) orelse return null;

    var args: ArrayList(FnArg) = .empty;
    errdefer args.deinit(parser.allocator);

    while (parser.tokens.peek()) |lookahead| switch (lookahead.tag) {
        .true,
        .false,
        .nil,
        .this,
        .number,
        .string,
        .identifier,
        .@"(",
        .proto,
        .@"!",
        .@"-",
        => try args.append(
            parser.allocator,
            try FnArg.parse(parser) orelse return null,
        ),
        else => break,
    };

    const @")" = try parser.match(parser.allocator, .consume, .{.@")"}) orelse return null;

    return .{ .@"(" = @"(", .args = try args.toOwnedSlice(parser.allocator), .@")" = @")" };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    for (this.args) |*arg| arg.deinit(allocator);
    allocator.free(this.args);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitCallFn)).@"fn".return_type.? {
    return visitor.visitCallFn(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
