const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const ExprStmt = Parser.ExprStmt;
const ForStmt = Parser.ForStmt;
const IfStmt = Parser.IfStmt;
const PrintStmt = Parser.PrintStmt;
const ReturnStmt = Parser.ReturnStmt;
const WhileStmt = Parser.WhileStmt;
const Block = Parser.Block;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;

pub const Stmt = union(enum) {
    expr_stmt: ExprStmt,
    for_stmt: ForStmt,
    if_stmt: IfStmt,
    print_stmt: PrintStmt,
    return_stmt: ReturnStmt,
    while_stmt: WhileStmt,
    block: Block,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        return switch (try parser.tokens.peek() orelse return null) {
            .@"for" => .{ .for_stmt = try ForStmt.parse(parser, allocator) orelse return null },
            .@"if" => .{ .if_stmt = try IfStmt.parse(parser, allocator) orelse return null },
            .print => .{ .print_stmt = try PrintStmt.parse(parser, allocator) orelse return null },
            .@"return" => .{ .return_stmt = try ReturnStmt.parse(parser, allocator) orelse return null },
            .@"while" => .{ .while_stmt = try WhileStmt.parse(parser, allocator) orelse return null },
            .@"{" => .{ .block = try Block.parse(parser, allocator) orelse return null },
            else => .{ .expr_stmt = try ExprStmt.parse(parser, allocator) orelse return null },
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitStmt)).@"fn".return_type.? {
        return visitor.visitStmt(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
