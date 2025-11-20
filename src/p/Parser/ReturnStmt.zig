const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const Expr = Parser.Expr;
const Visitor = Parser.Visitor;
const MakeFormat = p.util.TreeFormatter;
const Token = p.Tokenizer.Token;

@"return": Token,
expr: ?Expr,
@";": Token,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    const @"return" = try parser.match(allocator, .consume, .{.@"return"}) orelse return null;
    const expr = try Expr.parse(parser, allocator);
    const @";" = try parser.match(allocator, .consume, .{.@";"}) orelse return null;

    return .{
        .@"return" = @"return",
        .expr = expr,
        .@";" = @";",
    };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    if (this.expr) |*expr| expr.deinit(allocator);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitReturnStmt)).@"fn".return_type.? {
    return visitor.visitReturnStmt(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
