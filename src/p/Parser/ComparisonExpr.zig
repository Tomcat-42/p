const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

const p = @import("p");
const Parser = p.Parser;
const Term = Parser.Term;
const Visitor = Parser.Visitor;
const TreeFormatter = p.common.TreeFormatter;
const Token = p.Tokenizer.Token;

op: Token,
term: Term,

pub fn parse(parser: *Parser) !?@This() {
    const op = try parser.match(parser.allocator, .consume, .{ .@">", .@">=", .@"<", .@"<=" }) orelse return null;
    const term = try Term.parse(parser) orelse return null;

    return .{ .op = op, .term = term };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.term.deinit(allocator);
}

pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_comparisonSuffix)).@"fn".return_type.? {
    return visitor.visit_comparisonSuffix(this);
}

pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
    return .{ .data = .{ .depth = depth, .data = this } };
}

const Format = TreeFormatter(@This());
