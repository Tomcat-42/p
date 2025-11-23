const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const Expr = Parser.Expr;
const Visitor = Parser.Visitor;
const TreeFormatter = p.common.TreeFormatter;
const Token = p.Tokenizer.Token;

print: Token,
@"(": Token,
expr: Expr,
@")": Token,
@";": Token,

pub fn parse(parser: *Parser) !?@This() {
    const print = try parser.match(parser.allocator, .consume, .{.print}) orelse return null;
    const @"(" = try parser.match(parser.allocator, .consume, .{.@"("}) orelse return null;
    const expr = try Expr.parse(parser) orelse return null;
    const @")" = try parser.match(parser.allocator, .consume, .{.@")"}) orelse return null;
    const @";" = try parser.match(parser.allocator, .consume, .{.@";"}) orelse return null;

    return .{
        .print = print,
        .@"(" = @"(",
        .expr = expr,
        .@")" = @")",
        .@";" = @";",
    };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.expr.deinit(allocator);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_print_stmt)).@"fn".return_type.? {
    return visitor.visit_print_stmt(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
