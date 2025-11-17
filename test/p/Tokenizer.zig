const std = @import("std");
const testing = std.testing;
const allocator = testing.allocator;
const expectEqualDeep = testing.expectEqualDeep;

const p = @import("p");
const Tokenizer = p.Tokenizer;
const Token = Tokenizer.Token;

fn assertCorrectTokenizing(src: []const u8, expected: []const Token) !void {
    var tokenizer: Tokenizer = .init(src);
    const actual = try tokenizer.collect(allocator);
    defer allocator.free(actual);
    std.debug.print("[src]\n{s}\n", .{src});
    std.debug.print("[tokens]\n", .{});
    for (actual) |token| std.debug.print("{f}", .{token.format(0)});
    std.debug.print("\n", .{});
    try expectEqualDeep(expected, actual);
}

test Token {
    try assertCorrectTokenizing(
        \\object T extends U {}
    ,
        &.{
            .{ .tag = .object, .value = "object", .span = .{ .begin = 0, .end = 6 } },
            .{ .tag = .identifier, .value = "T", .span = .{ .begin = 7, .end = 8 } },
            .{ .tag = .extends, .value = "extends", .span = .{ .begin = 9, .end = 16 } },
            .{ .tag = .identifier, .value = "U", .span = .{ .begin = 17, .end = 18 } },
            .{ .tag = .@"{", .value = "{", .span = .{ .begin = 19, .end = 20 } },
            .{ .tag = .@"}", .value = "}", .span = .{ .begin = 20, .end = 21 } },
        },
    );
}
