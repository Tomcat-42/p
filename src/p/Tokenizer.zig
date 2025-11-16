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

const util = @import("util.zig");
const term = util.term;

const Tokenizer = @This();

src: []const u8,
pos: usize = 0,

pub fn init(src: []const u8) Tokenizer {
    return .{ .src = src };
}

pub fn reset(this: *Tokenizer) void {
    this.pos = 0;
}

pub fn next(this: *Tokenizer) ?Token {
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
        '/' => if (this.nextChar()) |char| switch (char) {
            '*' => this.commentMulti(),
            '/' => this.commentSingle(),
            else => this.token(.@"/"),
        } else this.token(.@"/"),
        '*' => this.token(.@"*"),
        '!' => if (this.nextChar() != null and this.nextChar().? == '=') this.token(.@"!=") else this.token(.@"!"),
        '=' => if (this.nextChar() != null and this.nextChar().? == '=') this.token(.@"==") else this.token(.@"="),
        '>' => if (this.nextChar() != null and this.nextChar().? == '=') this.token(.@">=") else this.token(.@">"),
        '<' => if (this.nextChar() != null and this.nextChar().? == '=') this.token(.@"<=") else this.token(.@"<"),
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

pub fn peek(this: *Tokenizer) ?Token {
    const old = this.pos;
    defer this.pos = old;

    return this.next();
}

pub fn expect(this: *@This(), comptime expected: anytype) ?Token {
    assert(@typeInfo(@TypeOf(expected)) == .@"struct");

    const tok = this.peek() orelse return null;
    inline for (expected) |e| switch (tok.tag) {
        e => return this.next(),
        else => {},
    };

    return null;
}

pub fn sync(this: *@This(), expected: anytype) ?Token {
    return token: while (this.peek()) |_| {
        if (this.expect(expected)) |t| break :token t;
        _ = this.next();
    } else null;
}

pub fn collect(this: *@This(), allocator: Allocator) ![]const Token {
    var tokens = try ArrayList(Token).initCapacity(allocator, 1024);
    errdefer tokens.deinit(allocator);

    while (this.next()) |tok| try tokens.append(allocator, tok);
    return tokens.toOwnedSlice(allocator);
}

fn token(this: *const @This(), comptime tag: Token.Tag) Token {
    const size = @tagName(tag).len;
    return .{
        .tag = tag,
        .value = this.src[this.pos .. this.pos + size],
        .span = .{
            .start = this.pos,
            .end = this.pos + size,
        },
    };
}

fn nextChar(this: *Tokenizer) ?u8 {
    return if (this.pos + 1 >= this.src.len) return null else this.src[this.pos + 1];
}

fn number(this: *Tokenizer) Token {
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
        .span = .{ .start = this.pos, .end = idx },
    };
}

fn string(this: *Tokenizer) ?Token {
    const begin = this.pos;

    this.pos += 1;
    while (this.pos < this.src.len) : (this.pos += 1) if (this.src[this.pos] == '"') {
        const end = this.pos;
        return .{
            .tag = .string,
            .value = this.src[begin .. end + 1],
            .span = .{ .start = begin, .end = end + 1 },
        };
    };

    return null;
}

fn keywordOrIdentifier(this: *Tokenizer) Token {
    var idx = this.pos;
    defer this.pos = idx - 1;

    while (idx < this.src.len and
        (ascii.isAlphanumeric(this.src[idx]) or this.src[idx] == '_')) : (idx += 1)
    {}

    return .{
        .value = this.src[this.pos..idx],
        .tag = if (KEYWORDS.get(this.src[this.pos..idx])) |kw| kw else .identifier,
        .span = .{ .start = this.pos, .end = idx },
    };
}

fn skipWhitespace(this: *Tokenizer) void {
    while (this.pos < this.src.len and
        ascii.isWhitespace(this.src[this.pos])) : (this.pos += 1)
    {}
}

fn commentSingle(this: *Tokenizer) ?Token {
    const begin = this.pos;

    while (this.pos < this.src.len and this.src[this.pos] != '\n') : (this.pos += 1) {}

    const end = this.pos;
    return .{
        .tag = .comment,
        .value = this.src[begin..end],
        .span = .{ .start = begin, .end = end },
    };
}

fn commentMulti(this: *Tokenizer) ?Token {
    const begin = this.pos;
    this.pos += 2;
    var window = mem.window(u8, this.src[this.pos..], 2, 1);

    while (window.next()) |c| : (this.pos += 1) if (mem.eql(u8, c, "*/")) {
        this.pos += 2;
        const end = this.pos;

        return .{
            .tag = .comment,
            .span = .{ .start = begin, .end = end },
            .value = this.src[begin..end],
        };
    };

    return null;
}

pub const Location = struct {
    line: usize,
    column: usize,

    pub fn fromSourceSpan(src: []const u8, span: Token.Span) @This() {
        const line = mem.count(u8, src[0..span.start], '\n') + 1;
        const last_newline_idx = mem.findLast(u8, src[0..span.start], '\n');
        const line_start_pos = if (last_newline_idx) |idx| idx + 1 else 0;
        const column = (span.start - line_start_pos) + 1;

        return .{ .line = line, .column = column };
    }
};

pub const Token = struct {
    tag: Tag,
    span: Span = .{},
    value: []const u8,

    // [start, end)
    pub const Span = struct {
        start: usize = 0,
        end: usize = 0,
    };

    pub const Tag = enum {
        @"(",
        @")",
        @"{",
        @"}",
        @",",
        @".",
        @"-",
        @"+",
        @";",
        @"/",
        @"*",
        @"!",
        @"!=",
        @"=",
        @"==",
        @">",
        @">=",
        @"<",
        @"<=",
        identifier,
        string,
        number,
        comment,
        @"and",
        object,
        @"else",
        false,
        @"fn",
        @"for",
        @"if",
        nil,
        @"or",
        print,
        @"return",
        proto,
        extends,
        this,
        true,
        let,
        @"while",
        invalid,
    };

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .token = this } };
    }

    const Format = struct {
        depth: usize = 0,
        token: *const Token,

        pub fn format(this: @This(), writer: *Io.Writer) Io.Writer.Error!void {
            const depth = this.depth;
            for (0..depth) |_| try writer.print(term.SEP, .{});

            switch (this.token.tag) {
                .number,
                .string,
                => try writer.print("{s}Token{{.{t} = {s}{s}{s}}}{s}\n", .{
                    term.FG.MAGENTA ++ term.FG.EFFECT.ITALIC,
                    this.token.tag,
                    term.FG.WHITE ++ term.FG.EFFECT.UNDERLINE,
                    this.token.value,
                    term.FG.MAGENTA ++ term.FG.EFFECT.RESET.UNDERLINE,
                    term.RESET,
                }),
                .identifier => try writer.print("{s}Token{{.{t} = {s}{s}{s}}}{s}\n", .{
                    term.FG.MAGENTA ++ term.FG.EFFECT.ITALIC,
                    this.token.tag,
                    term.FG.WHITE ++ term.FG.EFFECT.UNDERLINE,
                    this.token.value,
                    term.RESET ++ term.FG.MAGENTA ++ term.FG.EFFECT.ITALIC,
                    term.RESET,
                }),
                .comment => try writer.print("{s}Token{{.{t} = {s}{s}{s}}}{s}\n", .{
                    term.FG.MAGENTA ++ term.FG.EFFECT.ITALIC,
                    this.token.tag,
                    term.FG.GREEN ++ term.FG.EFFECT.UNDERLINE,
                    this.token.value,
                    term.RESET ++ term.FG.MAGENTA ++ term.FG.EFFECT.ITALIC,
                    term.RESET,
                }),
                else => try writer.print("{s}Token.{t}{s}\n", .{
                    term.FG.MAGENTA ++ term.FG.EFFECT.ITALIC,
                    this.token.tag,
                    term.RESET,
                }),
            }
        }
    };
};

const KEYWORDS = StaticStringMap(Token.Tag).initComptime(.{
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
