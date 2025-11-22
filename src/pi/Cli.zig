const std = @import("std");
const mem = std.mem;

const c = @cImport({
    @cInclude("isocline.h");
    @cInclude("stdlib.h");
    @cInclude("locale.h");
    @cInclude("string.h");
});

prompt: []const u8 = ">",

const KEYWORDS = [_][*c]const u8{
    "object",
    "extends",
    "fn",
    "let",
    "for",
    "if",
    "else",
    "print",
    "return",
    "while",
    "or",
    "and",
    "true",
    "false",
    "nil",
    "this",
    "proto",
    null,
};

pub fn init(prompt: []const u8) @This() {
    _ = c.setlocale(c.LC_ALL, "C.UTF-8");

    c.ic_style_def("kbd", "gray underline");
    c.ic_style_def("ic-prompt", "ansi-maroon");
    c.ic_printf(
        \\[b]P Language[/b] REPL:
        \\- Type 'exit' to quit. (or use [kbd]ctrl-d[/])
        \\- Press [kbd]F1[/] for help on editing commands.
        \\- Use [kbd]shift-tab[/] for multiline input. (or [kbd]ctrl-enter[/], or [kbd]ctrl-j[/])
        \\- Press [kbd]tab[/] for keyword completion.
        \\- Use [kbd]ctrl-r[/] to search the history.
        \\
        \\
    );

    _ = c.ic_set_history(".p_history", -1); // -1 uses default entry count (200)
    c.ic_set_default_completer(&completer, null);
    c.ic_set_default_highlighter(&highlighter, null);

    _ = c.ic_enable_auto_tab(true);
    _ = c.ic_enable_hint(true);

    return .{ .prompt = prompt };
}

pub fn read(this: *const @This(), allocator: mem.Allocator) !?[]const u8 {
    const data_c = c.ic_readline(@ptrCast(this.prompt)) orelse return null;
    defer c.free(data_c);

    const data = mem.span(data_c);
    if (mem.eql(u8, data, "exit")) return null;

    return try allocator.dupe(u8, data);
}

export fn word_completer(cenv: ?*c.ic_completion_env_t, word: [*c]const u8) void {
    _ = c.ic_add_completions(cenv, word, @ptrCast(@constCast(&KEYWORDS)));
}

export fn completer(cenv: ?*c.ic_completion_env_t, input: [*c]const u8) void {
    c.ic_complete_word(cenv, input, &word_completer, null);
}

export fn highlighter(henv: ?*c.ic_highlight_env_t, input: [*c]const u8, arg: ?*anyopaque) void {
    _ = arg;

    const len: c_long = @intCast(c.strlen(input));
    var i: c_long = 0;

    while (i < len) {
        var tlen: c_long = 0;

        tlen = c.ic_match_any_token(input, i, &c.ic_char_is_idletter, @ptrCast(@constCast(&KEYWORDS)));
        if (tlen > 0) {
            c.ic_highlight(henv, i, tlen, "keyword");
            i += tlen;
            continue;
        }

        tlen = c.ic_is_token(input, i, &c.ic_char_is_digit);
        if (tlen > 0) {
            if (i + tlen < len and input[@intCast(i + tlen)] == '.') {
                tlen += 1;
                const decimal_len = c.ic_is_token(input, i + tlen, &c.ic_char_is_digit);
                tlen += decimal_len;
            }
            c.ic_highlight(henv, i, tlen, "number");
            i += tlen;
            continue;
        }

        if (input[@intCast(i)] == '"') {
            tlen = 1;
            while (i + tlen < len and input[@intCast(i + tlen)] != '"') {
                tlen += 1;
            }
            if (i + tlen < len) tlen += 1; // Include closing quote
            c.ic_highlight(henv, i, tlen, "string");
            i += tlen;
            continue;
        }

        if (c.ic_starts_with(input + @as(usize, @intCast(i)), "//")) {
            tlen = 2;
            while (i + tlen < len and input[@intCast(i + tlen)] != '\n') {
                tlen += 1;
            }
            c.ic_highlight(henv, i, tlen, "comment");
            i += tlen;
            continue;
        }

        const ch = input[@intCast(i)];
        if (ch == '=' or ch == '!' or ch == '<' or ch == '>' or
            ch == '+' or ch == '-' or ch == '*' or ch == '/')
        {
            tlen = 1;
            if (i + 1 < len) {
                const next_ch = input[@intCast(i + 1)];
                if ((ch == '=' and next_ch == '=') or
                    (ch == '!' and next_ch == '=') or
                    (ch == '<' and next_ch == '=') or
                    (ch == '>' and next_ch == '='))
                {
                    tlen = 2;
                }
            }
            c.ic_highlight(henv, i, tlen, "type"); // Using "type" style for operators
            i += tlen;
            continue;
        }

        tlen = c.ic_is_token(input, i, &c.ic_char_is_idletter);
        if (tlen > 0) {
            c.ic_highlight(henv, i, tlen, null); // Default color for identifiers
            i += tlen;
            continue;
        }

        c.ic_highlight(henv, i, 1, null);
        i += 1;
    }
}
