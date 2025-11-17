const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const Assign = Parser.Assign;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;
const Token = p.Tokenizer.Token;

@"=": Token,
value: Assign,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const @"=" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"="}) orelse return null;
    const value = try Assign.parse(parser, allocator) orelse return null;

    return .{ .@"=" = @"=", .value = value };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.target.deinit(allocator);
    this.value.deinit(allocator);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitAssign)).@"fn".return_type.? {
    return visitor.visitAssignExpr(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
