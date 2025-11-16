const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const AssignTargetProperty = Parser.AssignTargetProperty;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;
const Token = p.Tokenizer.Token;

pub const AssignTarget = union(enum) {
    prop: AssignTargetProperty,
    id: Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        return switch ((parser.tokens.peek() orelse return null).tag) {
            .identifier => .{ .id = parser.tokens.next().? },
            else => .{ .prop = try AssignTargetProperty.parse(parser, allocator) orelse return null },
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitAssignTarget)).@"fn".return_type.? {
        return visitor.visitAssignTarget(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
