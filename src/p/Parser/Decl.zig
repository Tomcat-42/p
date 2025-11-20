const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const ObjDecl = Parser.ObjDecl;
const FnDecl = Parser.FnDecl;
const VarDecl = Parser.VarDecl;
const Stmt = Parser.Stmt;
const Visitor = Parser.Visitor;
const MakeFormat = p.util.TreeFormatter;

pub const Decl = union(enum) {
    ObjDecl: ObjDecl,
    FnDecl: FnDecl,
    VarDecl: VarDecl,
    Stmt: Stmt,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const lookahead = try parser.match(allocator, .peek, .{
            .object,
            .@"fn",
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
            .@"for",
            .@"if",
            .print,
            .@"return",
            .@"while",
            .@"{",
        }) orelse return null;

        return switch (lookahead.tag) {
            .object => .{ .ObjDecl = try ObjDecl.parse(parser, allocator) orelse return null },
            .@"fn" => .{ .FnDecl = try FnDecl.parse(parser, allocator) orelse return null },
            .let => .{ .VarDecl = try VarDecl.parse(parser, allocator) orelse return null },
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
            .@"for",
            .@"if",
            .print,
            .@"return",
            .@"while",
            .@"{",
            => .{ .Stmt = try Stmt.parse(parser, allocator) orelse return null },
            else => unreachable,
        };
    }

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        switch (this.*) {
            inline else => |*decl| decl.deinit(allocator),
        }
    }

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitDecl)).@"fn".return_type.? {
        return visitor.visitDecl(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
