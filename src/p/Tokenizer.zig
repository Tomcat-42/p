const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Io = std.Io;
const assert = std.debug.assert;
const builtin = std.builtin;
const StaticStringMap = std.StaticStringMap;
const ascii = std.ascii;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

pub const Token = @import("Tokenizer/Token.zig");

src: []const u8,
pos: usize = 0,

pub fn init(src: []const u8) @This() {
    return .{ .src = src };
}

pub fn reset(this: *@This()) void {
    this.pos = 0;
}

pub fn next(this: *@This()) ?Token {
    if (this.pos >= this.src.len) return null;
    defer this.pos += 1;

    return dfa: switch (this.src[this.pos]) {
        '(' => this.token(.@"("),
        ')' => this.token(.@")"),
        '{' => this.token(.@"{"),
        '}' => this.token(.@"}"),
        ',' => this.token(.@","),
        '.' => this.token(.@"."),
        '-' => this.token(.@"-"),
        '+' => this.token(.@"+"),
        ';' => this.token(.@";"),
        '/' => if (this.check('*')) this.commentMulti() else if (this.check('/')) this.commentSingle() else this.token(.@"/"),
        '*' => this.token(.@"*"),
        '!' => if (this.check('=')) this.token(.@"!=") else this.token(.@"!"),
        '=' => if (this.check('=')) this.token(.@"==") else this.token(.@"="),
        '>' => if (this.check('=')) this.token(.@">=") else this.token(.@">"),
        '<' => if (this.check('=')) this.token(.@"<=") else this.token(.@"<"),
        '"' => this.string(),
        '0'...'9' => this.number(),
        '_', 'a'...'z', 'A'...'Z' => this.keywordOrIdentifier(),
        ' ', '\t'...'\r' => {
            this.skipWhitespace();
            continue :dfa this.src[this.pos];
        },
        else => this.token(.invalid),
    };
}

/// Peek at the next token without consuming it.
pub fn peek(this: *@This()) ?Token {
    const old = this.pos;
    defer this.pos = old;

    return this.next();
}

/// If the next token matches one of the expected tags, peek/consume and return it.
pub fn match(this: *@This(), comptime behaviour: enum { peek, consume }, comptime expected: anytype) ?Token {
    assert(@typeInfo(@TypeOf(expected)) == .@"struct");

    const t = this.peek() orelse return null;
    inline for (expected) |e| if (t.tag == e) return switch (behaviour) {
        .consume => this.next(),
        .peek => t,
    };

    return null;
}

pub fn sync(this: *@This(), comptime behaviour: @typeInfo(@TypeOf(match)).@"fn".params[1].type.?, expected: anytype) ?Token {
    return while (this.next()) |t| {
        if (this.match(.peek, expected) != null)
            break switch (behaviour) {
                .consume => this.next(),
                .peek => t,
            };
    } else null;
}

pub fn collect(this: *@This(), allocator: Allocator) ![]const Token {
    var tokens: ArrayList(Token) = .empty;
    errdefer tokens.deinit(allocator);

    try tokens.ensureTotalCapacity(allocator, this.src.len); // Worst case: every char is a token
    while (this.next()) |tok| tokens.appendAssumeCapacity(tok);

    return tokens.toOwnedSlice(allocator);
}

fn token(this: *const @This(), comptime tag: Token.Tag) Token {
    const size = @tagName(tag).len;

    return .{
        .tag = tag,
        .value = this.src[this.pos .. this.pos + size],
        .span = .{
            .begin = this.pos,
            .end = this.pos + size,
        },
    };
}

fn check(this: *@This(), char: u8) bool {
    return this.pos + 1 < this.src.len and this.src[this.pos + 1] == char;
}

fn number(this: *@This()) Token {
    var idx = this.pos;
    while (idx < this.src.len and
        ascii.isDigit(this.src[idx])) : (idx += 1)
    {}

    if (idx + 1 < this.src.len and this.src[idx] == '.' and
        ascii.isDigit(this.src[idx + 1]))
    {
        idx += 1;
        while (idx < this.src.len and
            ascii.isDigit(this.src[idx])) : (idx += 1)
        {}
    }

    defer this.pos = idx - 1;
    return .{
        .tag = .number,
        .value = this.src[this.pos..idx],
        .span = .{ .begin = this.pos, .end = idx },
    };
}

fn string(this: *@This()) ?Token {
    const begin = this.pos;

    this.pos += 1;
    while (this.pos < this.src.len) : (this.pos += 1) if (this.src[this.pos] == '"') {
        const end = this.pos;
        return .{
            .tag = .string,
            .value = this.src[begin .. end + 1],
            .span = .{ .begin = begin, .end = end + 1 },
        };
    };

    return null;
}

fn keywordOrIdentifier(this: *@This()) Token {
    var idx = this.pos;
    defer this.pos = idx - 1;

    while (idx < this.src.len and
        (ascii.isAlphanumeric(this.src[idx]) or this.src[idx] == '_')) : (idx += 1)
    {}

    return .{
        .value = this.src[this.pos..idx],
        .tag = if (KEYWORDS.get(this.src[this.pos..idx])) |kw| kw else .identifier,
        .span = .{ .begin = this.pos, .end = idx },
    };
}

fn skipWhitespace(this: *@This()) void {
    while (this.pos < this.src.len and ascii.isWhitespace(this.src[this.pos])) : (this.pos += 1) {}
}

fn commentSingle(this: *@This()) ?Token {
    const begin = this.pos;
    while (this.pos < this.src.len and this.src[this.pos] != '\n') : (this.pos += 1) {}
    const end = this.pos;

    return .{
        .tag = .comment,
        .value = this.src[begin..end],
        .span = .{ .begin = begin, .end = end },
    };
}

fn commentMulti(this: *@This()) ?Token {
    const begin = this.pos;
    this.pos += 2;
    var window = mem.window(u8, this.src[this.pos..], 2, 1);

    while (window.next()) |c| : (this.pos += 1) if (mem.eql(u8, c, "*/")) {
        this.pos += 2;
        const end = this.pos;

        return .{
            .tag = .comment,
            .span = .{ .begin = begin, .end = end },
            .value = this.src[begin..end],
        };
    };

    return null;
}

const KEYWORDS: StaticStringMap(Token.Tag) = .initComptime(.{
    .{ "and", .@"and" },
    .{ "object", .object },
    .{ "else", .@"else" },
    .{ "false", .false },
    .{ "fn", .@"fn" },
    .{ "for", .@"for" },
    .{ "if", .@"if" },
    .{ "nil", .nil },
    .{ "or", .@"or" },
    .{ "print", .print },
    .{ "return", .@"return" },
    .{ "proto", .proto },
    .{ "extends", .extends },
    .{ "this", .this },
    .{ "true", .true },
    .{ "let", .let },
    .{ "while", .@"while" },
});
