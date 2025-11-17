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
const util = @import("util");
const Box = util.Box;

pub const Stmt = union(enum) {
    expr_stmt: Box(ExprStmt),
    for_stmt: Box(ForStmt),
    if_stmt: Box(IfStmt),
    print_stmt: Box(PrintStmt),
    return_stmt: Box(ReturnStmt),
    while_stmt: Box(WhileStmt),
    block: Box(Block),

    pub fn parse(parser: *Parser, allocator: Allocator) anyerror!?@This() {
        const lookahead = try parser.checkOrHandleError(allocator, .{
            .@"for",
            .@"if",
            .print,
            .@"return",
            .@"while",
            .@"{",
            .true,
            .false,
            .nil,
            .this,
            .number,
            .string,
            .identifier,
            .@"(",
            .proto,
            .@"!",
            .@"-",
        }) orelse return null;

        return switch (lookahead.tag) {
            .@"for" => .{ .for_stmt = try .init(allocator, try ForStmt.parse(parser, allocator) orelse return null) },
            .@"if" => .{ .if_stmt = try .init(allocator, try IfStmt.parse(parser, allocator) orelse return null) },
            .print => .{ .print_stmt = try .init(allocator, try PrintStmt.parse(parser, allocator) orelse return null) },
            .@"return" => .{ .return_stmt = try .init(allocator, try ReturnStmt.parse(parser, allocator) orelse return null) },
            .@"while" => .{ .while_stmt = try .init(allocator, try WhileStmt.parse(parser, allocator) orelse return null) },
            .@"{" => .{ .block = try .init(allocator, try Block.parse(parser, allocator) orelse return null) },
            .true,
            .false,
            .nil,
            .this,
            .number,
            .string,
            .identifier,
            .@"(",
            .proto,
            .@"!",
            .@"-",
            => .{ .expr_stmt = try .init(allocator, try ExprStmt.parse(parser, allocator) orelse return null) },
            else => null,
        };
    }

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        switch (this.*) {
            inline else => |box| {
                box.value.deinit(allocator);
                box.deinit(allocator);
            },
        }
    }

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitStmt)).@"fn".return_type.? {
        return visitor.visitStmt(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
