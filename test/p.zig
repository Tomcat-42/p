const std = @import("std");
const testing = std.testing;

pub const TokenizerTests = @import("p/Tokenizer.zig");
pub const ParserTests = @import("p/Parser.zig");

test {
    testing.refAllDeclsRecursive(@This());
}
