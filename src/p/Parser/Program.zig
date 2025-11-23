const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const p = @import("p");
const Parser = p.Parser;
const Decl = Parser.Decl;
const Visitor = Parser.Visitor;
const TreeFormatter = p.common.TreeFormatter;

decls: []Decl,

pub fn parse(parser: *Parser) !?@This() {
    var decls: ArrayList(Decl) = .empty;
    errdefer decls.deinit(parser.allocator);

    while (parser.tokens.peek()) |lookahead| switch (lookahead.tag) {
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
        => try decls.append(parser.allocator, try Decl.parse(parser) orelse return null),
        else => break,
    };

    return .{ .decls = try decls.toOwnedSlice(parser.allocator) };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    for (this.decls) |*decl| decl.deinit(allocator);
    allocator.free(this.decls);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_program)).@"fn".return_type.? {
    return visitor.visit_program(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
