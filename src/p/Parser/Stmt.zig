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
const TreeFormatter = p.common.TreeFormatter;
const util = @import("util");

pub const Stmt = union(enum) {
    expr_stmt: ExprStmt,
    for_stmt: ForStmt,
    if_stmt: *IfStmt,
    print_stmt: PrintStmt,
    return_stmt: ReturnStmt,
    while_stmt: WhileStmt,
    block: *Block,

    pub fn parse(parser: *Parser) anyerror!?@This() {
        const lookahead = try parser.match(
            parser.allocator,
            .peek,
            .{
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
            },
        ) orelse return null;

        return switch (lookahead.tag) {
            .@"for" => .{ .for_stmt = try ForStmt.parse(parser) orelse return null },
            .@"if" => .{ .if_stmt = try util.dupe(IfStmt, parser.allocator, try IfStmt.parse(parser) orelse return null) },
            .print => .{ .print_stmt = try PrintStmt.parse(parser) orelse return null },
            .@"return" => .{ .return_stmt = try ReturnStmt.parse(parser) orelse return null },
            .@"while" => .{ .while_stmt = try WhileStmt.parse(parser) orelse return null },
            .@"{" => .{ .block = try util.dupe(Block, parser.allocator, try Block.parse(parser) orelse return null) },
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
            => .{ .expr_stmt = try ExprStmt.parse(parser) orelse return null },
            else => unreachable,
        };
    }

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        switch (this.*) {
            .if_stmt => |ptr| {
                ptr.deinit(allocator);
                allocator.destroy(ptr);
            },
            .block => |ptr| {
                ptr.deinit(allocator);
                allocator.destroy(ptr);
            },
            inline else => |*stmt| stmt.deinit(allocator),
        }
    }

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_stmt)).@"fn".return_type.? {
        return visitor.visit_stmt(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};
