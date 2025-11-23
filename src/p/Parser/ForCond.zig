const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const VarDecl = Parser.VarDecl;
const ExprStmt = Parser.ExprStmt;
const Visitor = Parser.Visitor;
const TreeFormatter = p.common.TreeFormatter;
const Token = p.Tokenizer.Token;

pub const ForCond = union(enum) {
    expr: ExprStmt,
    @";": Token, // Empty cond

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const lookahead = try parser.match(
            allocator,
            .peek,
            .{
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
                .@";",
            },
        ) orelse return null;

        return switch (lookahead.tag) {
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
            => .{ .expr = try ExprStmt.parse(parser, allocator) orelse return null },
            .@";" => .{ .@";" = parser.tokens.next().? },
            else => unreachable,
        };
    }

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        switch (this.*) {
            .@";" => {},
            inline else => |*init| init.deinit(allocator),
        }
    }

    pub fn visit(this: *const @This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_for_cond)).@"fn".return_type.? {
        return visitor.visit_for_cond(allocator, this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};
