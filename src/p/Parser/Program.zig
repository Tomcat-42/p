const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const p = @import("p");
const Parser = p.Parser;
const Decl = Parser.Decl;
const Visitor = Parser.Visitor;
const MakeFormat = Parser.MakeFormat;

decls: []const Decl,

pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
    var decls: ArrayList(Decl) = .empty;
    defer decls.deinit(allocator);

    while (parser.tokens.peek() != null) if (try Decl.parse(parser, allocator)) |decl| {
        try decls.append(allocator, decl);
    };

    return .{ .decls = try decls.toOwnedSlice(allocator) };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    allocator.free(this.decls);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visitProgram)).@"fn".return_type.?  {
    return visitor.visitProgram(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = MakeFormat(@This());
