const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const Unary = Parser.Unary;
const Call = Parser.Call;
const Visitor = Parser.Visitor;
const MakeFormat = p.util.TreeFormatter;
const Token = p.Tokenizer.Token;

op: Token,
call: Unary,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const op = try parser.match(allocator, .consume, .{ .@"-", .@"!" }) orelse return null;
    const call = try Call.parse(parser, allocator) orelse return null;

    return .{ .op = op, .call = .{ .call = call } };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.call.deinit(allocator);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitUnaryExpr)).@"fn".return_type.? {
    return visitor.visitUnaryExpr(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
