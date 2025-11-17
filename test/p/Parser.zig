const std = @import("std");
const testing = std.testing;
const expectEqualDeep = testing.expectEqualDeep;
const allocator = testing.allocator;

const p = @import("p");
const Tokenizer = p.Tokenizer;
const Parser = p.Parser;
const FnDecl = Parser.FnDecl;
const ObjDecl = Parser.ObjDecl;
const Block = Parser.Block;
const Call = Parser.Call;

fn assertCorrectParsing(T: type, src: []const u8, expected: ?T) !void {
    std.debug.print("[src]\n{s}\n", .{src});

    var tokens: Tokenizer = .init(src);
    var parser: Parser = .init(&tokens);
    defer parser.deinit(allocator);

    var actual = try T.parse(&parser, allocator);
    defer if (actual) |*a| a.deinit(allocator);

    std.debug.print("[parsed]\n", .{});
    if (actual) |a| std.debug.print("{f}", .{a.format(0)});
    std.debug.print("\n", .{});

    try expectEqualDeep(expected, actual);
    try expectEqualDeep(null, parser.getErrors());
}

test FnDecl {
    try assertCorrectParsing(
        FnDecl,
        \\fn foo() {}
    ,
        .{
            .@"fn" = .{
                .tag = .@"fn",
                .value = "fn",
                .span = .{ .begin = 0, .end = 2 },
            },
            .id = .{
                .tag = .identifier,
                .value = "foo",
                .span = .{ .begin = 3, .end = 6 },
            },
            .@"(" = .{
                .tag = .@"(",
                .value = "(",
                .span = .{ .begin = 6, .end = 7 },
            },
            .params = &.{},
            .@")" = .{
                .tag = .@")",
                .value = ")",
                .span = .{ .begin = 7, .end = 8 },
            },
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
        },
    );
}

test ObjDecl {
    try assertCorrectParsing(
        ObjDecl,
        \\object T {}
    ,
        .{
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
        },
    );

    try assertCorrectParsing(
        ObjDecl,
        \\object T extends U {}
    ,
        .{
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
            .extends = .{
                .extends = .{
                    .tag = .extends,
                    .value = "extends",
                    .span = .{ .begin = 9, .end = 16 },
                },
                .id = .{
                    .tag = .identifier,
                    .value = "U",
                    .span = .{ .begin = 17, .end = 18 },
                },
            },
            .body = .{
                .@"{" = .{
                    .tag = .@"{",
                    .value = "{",
                    .span = .{ .begin = 19, .end = 20 },
                },
                .stmts = &.{},
                .@"}" = .{
                    .tag = .@"}",
                    .value = "}",
                    .span = .{ .begin = 20, .end = 21 },
                },
            },
        },
    );
}

test Call {
    try assertCorrectParsing(
        Call,
        \\proto()
    ,
    null
    );
}
