const std = @import("std");
const Io = std.Io;
const fmt = std.fmt;
const mem = std.mem;

const Span = @import("p").common.Span;
const util = @import("util");
const color = util.color;

const Token = @This();
tag: Tag,
span: Span = .{},
value: []const u8,

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
        for (0..depth) |_| try writer.print(color.SEP, .{});

        switch (this.token.tag) {
            .number,
            .string,
            => try writer.print("{s}Token{{.{t} = {s}{s}{s}}} <{d}, {d}>{s}\n", .{
                color.FG.MAGENTA ++ color.FG.EFFECT.ITALIC,
                this.token.tag,
                color.FG.WHITE ++ color.FG.EFFECT.UNDERLINE,
                this.token.value,
                color.FG.MAGENTA ++ color.FG.EFFECT.RESET.UNDERLINE,
                this.token.span.begin,
                this.token.span.end,
                color.RESET,
            }),
            .identifier => try writer.print("{s}Token{{.{t} = {s}{s}{s}}}<{d},{d}>{s}\n", .{
                color.FG.MAGENTA ++ color.FG.EFFECT.ITALIC,
                this.token.tag,
                color.FG.WHITE ++ color.FG.EFFECT.UNDERLINE,
                this.token.value,
                color.RESET ++ color.FG.MAGENTA ++ color.FG.EFFECT.ITALIC,
                this.token.span.begin,
                this.token.span.end,
                color.RESET,
            }),
            .comment => try writer.print("{s}Token{{.{t} = {s}{s}{s}}}<{d},{d}>{s}\n", .{
                color.FG.MAGENTA ++ color.FG.EFFECT.ITALIC,
                this.token.tag,
                color.FG.GREEN ++ color.FG.EFFECT.UNDERLINE,
                this.token.value,
                color.RESET ++ color.FG.MAGENTA ++ color.FG.EFFECT.ITALIC,
                this.token.span.begin,
                this.token.span.end,
                color.RESET,
            }),
            else => try writer.print("{s}Token.{t}<{d},{d}>{s}\n", .{
                color.FG.MAGENTA ++ color.FG.EFFECT.ITALIC,
                this.token.tag,
                this.token.span.begin,
                this.token.span.end,
                color.RESET,
            }),
        }
    }
};
