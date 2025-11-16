const std = @import("std");
const testing = std.testing;
const expectEqualDeep = testing.expectEqualDeep;
const allocator = testing.allocator;

const p = @import("p");
const Tokenizer = p.Tokenizer;
const Parser = p.Parser;
const ObjDecl = Parser.ObjDecl;
const Block = Parser.Block;

test ObjDecl {
    const src =
        \\object T {}
    ;
    var tokens: Tokenizer = .init(src);
    var parser: Parser = .init(&tokens);
    defer parser.deinit(allocator);

    const expected: ObjDecl = .{
        .object = .{
            .tag = .object,
            .value = "object",
            .span = .{ .begin = 0, .end = 6 },
        },
        .id = .{
            .tag = .identifier,
            .value = "T",
            .span = .{ .begin = 7, .end = 8 },
        },
        .extends = null,
        .body = .{
            .@"{" = .{
                .tag = .@"{",
                .value = "{",
                .span = .{ .begin = 9, .end = 10 },
            },
            .stmts = &.{},
            .@"}" = .{
                .tag = .@"}",
                .value = "}",
                .span = .{ .begin = 10, .end = 11 },
            },
        },
    };

    const actual = try ObjDecl.parse(&parser, allocator);
    try expectEqualDeep(expected, actual);
}
