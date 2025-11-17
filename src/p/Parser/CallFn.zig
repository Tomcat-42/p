const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const p = @import("p");
const Parser = p.Parser;
const FnArg = Parser.FnArg;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;
const Token = p.Tokenizer.Token;

@"(": Token,
args: []FnArg,
@")": Token,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const @"(" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"("}) orelse return null;

    var args: ArrayList(FnArg) = .empty;
    errdefer args.deinit(allocator);

    while (parser.tokens.peek()) |token| switch (token.tag) {
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
            allocator,
            try FnArg.parse(parser, allocator) orelse return null,
        ),
        else => break,
    };

    const @")" = try parser.expectOrHandleErrorAndSync(allocator, .{.@")"}) orelse return null;

    return .{ .@"(" = @"(", .args = try args.toOwnedSlice(allocator), .@")" = @")" };
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

const Format = MakeFormat(@This());
