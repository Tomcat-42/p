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
const TreeFormatter = p.common.TreeFormatter;
const Token = p.Tokenizer.Token;

@"if": Token,
@"(": Token,
cond: IfCond,
@")": Token,
main_branch: IfMainBranch,
else_branch: ?IfElseBranch,

pub fn parse(parser: *Parser) anyerror!?@This() {
    const @"if" = try parser.match(parser.allocator, .consume, .{.@"if"}) orelse return null;
    const @"(" = try parser.match(parser.allocator, .consume, .{.@"("}) orelse return null;
    const cond = try IfCond.parse(parser) orelse return null;
    const @")" = try parser.match(parser.allocator, .consume, .{.@")"}) orelse return null;
    const main_branch = try IfMainBranch.parse(parser) orelse return null;
    const else_branch = if (parser.tokens.match(.peek, .{.@"else"})) |_|
        try IfElseBranch.parse(parser) orelse return null
    else
        null;

    return .{
        .@"if" = @"if",
        .@"(" = @"(",
        .cond = cond,
        .@")" = @")",
        .main_branch = main_branch,
        .else_branch = else_branch,
    };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.cond.deinit(allocator);
    this.main_branch.deinit(allocator);
    if (this.else_branch) |*branch| branch.deinit(allocator);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_if_stmt)).@"fn".return_type.? {
    return visitor.visit_if_stmt(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
