const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const VarDecl = Parser.VarDecl;
const Expr = Parser.Expr;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;

pub const ForInit = union(enum) {
    var_decl: VarDecl,
    expr: Expr,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        return switch (try parser.tokens.peek() orelse return null) {
            .let => .{ .var_decl = try VarDecl.parse(parser, allocator) orelse return null },
            else => .{ .expr = try Expr.parse(parser, allocator) orelse return null },
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitForInit)).@"fn".return_type.? {
        return visitor.visitForInit(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
