const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const VarDecl = Parser.VarDecl;
const ExprStmt = Parser.ExprStmt;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;

pub const ForInit = union(enum) {
    var_decl: VarDecl,
    expr: ExprStmt,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const lookahead = try parser.checkOrHandleError(allocator, .{
            .let,
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
            .let => .{ .var_decl = try VarDecl.parse(parser, allocator) orelse return null },
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
            else => null,
        };
    }

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        switch (this.*) {
            inline else => |*init| init.deinit(allocator),
        }
    }

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitForInit)).@"fn".return_type.? {
        return visitor.visitForInit(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
