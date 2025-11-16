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
args: []const FnArg,
@")": Token,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const @"(" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"("}) orelse return null;

    var args: ArrayList(FnArg) = .empty;
    defer args.deinit(allocator);
    while (try FnArg.parse(parser, allocator)) |arg|
        try args.append(allocator, arg);

    const @")" = try parser.expectOrHandleErrorAndSync(allocator, .{.@")"}) orelse return null;

    return .{ .@"(" = @"(", .args = try args.toOwnedSlice(allocator), .@")" = @")" };
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitCallFn)).@"fn".return_type.? {
    return visitor.visitCallFn(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
