const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const Call = Parser.Call;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;
const Token = p.Tokenizer.Token;

call: Call,
@".": Token,
id: Token,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const call = try Call.parse(parser, allocator) orelse return null;
    const @"." = try parser.expectOrHandleErrorAndSync(allocator, .{.@"."}) orelse return null;
    const id = try parser.expectOrHandleErrorAndSync(allocator, .{.identifier}) orelse return null;

    return .{ .call = call, .@"." = @".", .id = id };
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitAssignTargetProperty)).@"fn".return_type.? {
    return visitor.visitAssignTargetProperty(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
