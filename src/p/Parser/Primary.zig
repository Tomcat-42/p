const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const PrimaryGroupExpr = Parser.GroupExpr;
const PrimaryProtoAccess = Parser.ProtoAccess;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;
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
    proto_access: PrimaryProtoAccess,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        return switch (try parser.tokens.peek() orelse return null) {
            .true => .{ .true = parser.tokens.next().? },
            .false => .{ .false = parser.tokens.next().? },
            .nil => .{ .nil = parser.tokens.next().? },
            .this => .{ .this = parser.tokens.next().? },
            .number => .{ .number = parser.tokens.next().? },
            .string => .{ .string = parser.tokens.next().? },
            .identifier => .{ .id = parser.tokens.next().? },
            .@"(" => .{ .group_expr = try PrimaryGroupExpr.parse(parser, allocator) orelse return null },
            .proto => .{ .proto_access = try PrimaryProtoAccess.parse(parser, allocator) orelse return null },
            else => return null,
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitPrimary)).@"fn".return_type.?  {
        return visitor.visitPrimary(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
