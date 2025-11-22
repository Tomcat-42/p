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
const TreeFormatter = p.common.TreeFormatter;

pub const Decl = union(enum) {
    obj_decl: ObjDecl,
    fn_decl: FnDecl,
    var_decl: VarDecl,
    stmt: Stmt,

    pub fn parse(parser: *Parser) !?@This() {
        const lookahead = try parser.match(parser.allocator, .peek, .{
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
            .object => .{ .obj_decl = try ObjDecl.parse(parser) orelse return null },
            .@"fn" => .{ .fn_decl = try FnDecl.parse(parser) orelse return null },
            .let => .{ .var_decl = try VarDecl.parse(parser) orelse return null },
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
            => .{ .stmt = try Stmt.parse(parser) orelse return null },
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

    const Format = TreeFormatter(@This());
};
