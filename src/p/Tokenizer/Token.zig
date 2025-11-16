const std = @import("std");
const Io = std.Io;
const fmt = std.fmt;
const mem = std.mem;

const util = @import("util");
const term = util.term;

const Token = @This();
tag: Tag,
span: Span = .{},
value: []const u8,

// [start, end)
pub const Span = struct {
    start: usize = 0,
    end: usize = 0,
};

pub const Location = struct {
    line: usize,
    column: usize,

    pub fn fromSourceSpan(src: []const u8, span: Span) @This() {
        const line = mem.count(u8, src[0..span.start], '\n') + 1;
        const last_newline_idx = mem.findLast(u8, src[0..span.start], '\n');
        const line_start_pos = if (last_newline_idx) |idx| idx + 1 else 0;
        const column = (span.start - line_start_pos) + 1;

        return .{ .line = line, .column = column };
    }
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
