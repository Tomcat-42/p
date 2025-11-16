const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const IfCond = Parser.IfCond;
const IfMainBranch = Parser.IfMainBranch;
const IfElseBranch = Parser.IfElseBranch;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;
const Token = p.Tokenizer.Token;

@"if": Token,
@"(": Token,
cond: IfCond,
@")": Token,
main_branch: IfMainBranch,
else_branch: ?IfElseBranch,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const @"if" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"if"}) orelse return null;
    const @"(" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"("}) orelse return null;
    const cond = try IfCond.parse(parser, allocator) orelse return null;
    const @")" = try parser.expectOrHandleErrorAndSync(allocator, .{.@")"}) orelse return null;
    const main_branch = try IfMainBranch.parse(parser, allocator) orelse return null;
    const else_branch = try IfElseBranch.parse(parser, allocator);

    return .{
        .@"if" = @"if",
        .@"(" = @"(",
        .cond = cond,
        .@")" = @")",
        .main_branch = main_branch,
        .else_branch = else_branch,
    };
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitIfStmt)).@"fn".return_type.? {
    return visitor.visitIfStmt(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
