const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const AssignTarget = Parser.AssignTarget;
const Assign = Parser.Assign;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;
const Token = p.Tokenizer.Token;

target: AssignTarget,
@"=": Token,
value: Assign,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const target = try AssignTarget.parse(parser, allocator) orelse return null;
    const @"=" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"="}) orelse return null;
    const value = try Assign.parse(parser, allocator) orelse return null;

    return .{ .target = target, .@"=" = @"=", .value = value };
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitAssign)).@"fn".return_type.? {
    return visitor.visitAssignExpr(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
