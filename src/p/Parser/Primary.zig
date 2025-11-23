const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const PrimaryGroupExpr = Parser.GroupExpr;
const Visitor = Parser.Visitor;
const TreeFormatter = p.common.TreeFormatter;
const Token = p.Tokenizer.Token;

pub const Primary = union(enum) {
    true: Token,
    false: Token,
    nil: Token,
    this: Token,
    number: Token,
    string: Token,
    id: Token,
    group_expr: PrimaryGroupExpr,
    proto: Token,

    pub fn parse(parser: *Parser) !?@This() {
        const lookahead = try parser.match(
            parser.allocator,
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
            },
        ) orelse return null;

        return switch (lookahead.tag) {
            .true => .{ .true = parser.tokens.next().? },
            .false => .{ .false = parser.tokens.next().? },
            .nil => .{ .nil = parser.tokens.next().? },
            .this => .{ .this = parser.tokens.next().? },
            .number => .{ .number = parser.tokens.next().? },
            .string => .{ .string = parser.tokens.next().? },
            .identifier => .{ .id = parser.tokens.next().? },
            .@"(" => .{ .group_expr = try PrimaryGroupExpr.parse(parser) orelse return null },
            .proto => .{ .proto = parser.tokens.next().? },
            else => unreachable,
        };
    }

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        switch (this.*) {
            .group_expr => |*group_expr| group_expr.deinit(allocator),
            else => {},
        }
    }

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_primary)).@"fn".return_type.? {
        return visitor.visit_primary(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};
