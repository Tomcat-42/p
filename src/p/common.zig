const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const Io = std.Io;

const p = @import("p");
const Tokenizer = p.Tokenizer;
const Token = Tokenizer.Token;
const util = @import("util");
const color = util.color;

pub const Span = struct { begin: usize = 0, end: usize = 0 };

pub const Location = struct {
    line: usize,
    column: usize,

    pub fn fromSpan(src: []const u8, span: Span) @This() {
        const line = mem.count(u8, src[0..span.begin], '\n') + 1;
        const last_newline_idx = mem.findLast(u8, src[0..span.begin], '\n');
        const line_start_pos = if (last_newline_idx) |idx| idx + 1 else 0;
        const column = (span.begin - line_start_pos) + 1;

        return .{ .line = line, .column = column };
    }
};

// TODO: Include Location
pub const Error = struct {
    message: []const u8,
    span: Span,

    pub fn init(message: []const u8, span: Span) !@This() {
        return .{ .message = message, .span = span };
    }

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        allocator.free(this.message);
    }
};

pub fn TreeFormatter(T: type) type {
    return struct {
        depth: usize = 0,
        data: *const T,

        fn hasFormat(comptime FieldType: type) bool {
            const info = @typeInfo(FieldType);
            switch (info) {
                .pointer => |ptr| {
                    if (ptr.size == .one) {
                        return hasFormat(ptr.child);
                    }
                    return false;
                },
                .@"struct", .@"union", .@"enum" => return @hasDecl(FieldType, "format"),
                else => return false,
            }
        }

        fn printIndent(writer: *Io.Writer, depth: usize) !void {
            for (0..depth) |_| try writer.print(color.SEP, .{});
        }

        fn printBaseValue(writer: *Io.Writer, field_name: []const u8, value: anytype, depth: usize) !void {
            const ValueType = @TypeOf(value);
            const info = @typeInfo(ValueType);

            switch (info) {
                .int, .comptime_int => {
                    try printIndent(writer, depth);
                    try writer.print("{s}{s}{s}({s}{d}{s})\n", .{ color.FG.YELLOW, field_name, color.RESET, color.FG.GREEN, value, color.RESET });
                },
                .float, .comptime_float => {
                    try printIndent(writer, depth);
                    try writer.print("{s}{s}{s}({s}{d}{s})\n", .{ color.FG.YELLOW, field_name, color.RESET, color.FG.GREEN, value, color.RESET });
                },
                .bool => {
                    try printIndent(writer, depth);
                    try writer.print("{s}{s}{s}({s}{}{s})\n", .{ color.FG.YELLOW, field_name, color.RESET, color.FG.GREEN, value, color.RESET });
                },
                .@"enum" => {
                    try printIndent(writer, depth);
                    try writer.print("{s}{s}{s}({s}{s}{s})\n", .{ color.FG.YELLOW, field_name, color.RESET, color.FG.MAGENTA, @tagName(value), color.RESET });
                },
                .void => {
                    try printIndent(writer, depth);
                    try writer.print("{s}{s}{s}\n", .{ color.FG.YELLOW, field_name, color.RESET });
                },
                .pointer => |ptr| {
                    if (ptr.size == .slice and ptr.child == u8) {
                        try printIndent(writer, depth);
                        try writer.print("{s}{s}{s}: {s}\"{s}\"{s}\n", .{ color.FG.YELLOW, field_name, color.RESET, color.FG.CYAN, value, color.RESET });
                    }
                },
                else => {},
            }
        }

        pub fn format(this: @This(), writer: *Io.Writer) Io.Writer.Error!void {
            const depth = this.depth;

            try printIndent(writer, depth);
            try writer.print("{s}{s}{s}\n", .{ color.FG.BLUE, @typeName(T), color.RESET });

            switch (@typeInfo(T)) {
                .@"struct" => |s| inline for (s.fields) |field| switch (@typeInfo(field.type)) {
                    .pointer => |ptr| switch (ptr.size) {
                        .one => {
                            if (comptime hasFormat(field.type)) {
                                try writer.print("{f}", .{@field(this.data, field.name).format(depth + 1)});
                            }
                        },
                        .slice => {
                            const slice_val = @field(this.data, field.name);
                            if (ptr.child == u8) {
                                try printBaseValue(writer, field.name, slice_val, depth + 1);
                            } else {
                                // Check if it's a slice of strings ([][]const u8)
                                const is_string_slice = blk: {
                                    const child_info = @typeInfo(ptr.child);
                                    if (child_info == .pointer) {
                                        if (child_info.pointer.size == .slice and child_info.pointer.child == u8) {
                                            break :blk true;
                                        }
                                    }
                                    break :blk false;
                                };

                                if (is_string_slice) {
                                    try printIndent(writer, depth + 1);
                                    try writer.print("{s}{s}{s}: [", .{ color.FG.YELLOW, field.name, color.RESET });
                                    for (slice_val, 0..) |str, i| {
                                        if (i > 0) try writer.print(", ", .{});
                                        try writer.print("{s}\"{s}\"{s}", .{ color.FG.CYAN, str, color.RESET });
                                    }
                                    try writer.print("]\n", .{});
                                } else {
                                    for (slice_val) |f| {
                                        if (comptime hasFormat(@TypeOf(f))) {
                                            try writer.print("{f}", .{f.format(depth + 1)});
                                        }
                                    }
                                }
                            }
                        },
                        else => for (@field(this.data, field.name)) |f| {
                            if (comptime hasFormat(@TypeOf(f))) {
                                try writer.print("{f}", .{f.format(depth + 1)});
                            }
                        },
                    },
                    .optional => if (@field(this.data, field.name)) |f| {
                        const FieldType = @TypeOf(f);
                        const field_info = @typeInfo(FieldType);

                        if (comptime mem.find(u8, @typeName(FieldType), "Box")) |_| {
                            if (comptime hasFormat(@TypeOf(@field(f, "value")))) {
                                try writer.print("{f}", .{@field(f, "value").format(depth + 1)});
                            }
                        } else if (field_info == .@"union") {
                            // Handle optional unions
                            switch (f) {
                                inline else => |union_val| {
                                    if (comptime hasFormat(@TypeOf(union_val))) {
                                        try writer.print("{f}", .{union_val.format(depth + 1)});
                                    } else {
                                        try printBaseValue(writer, field.name, union_val, depth + 1);
                                    }
                                },
                            }
                        } else {
                            if (comptime hasFormat(FieldType)) {
                                try writer.print("{f}", .{f.format(depth + 1)});
                            } else {
                                try printBaseValue(writer, field.name, f, depth + 1);
                            }
                        }
                    },
                    else => {
                        const field_val = @field(this.data, field.name);
                        if (comptime mem.find(u8, @typeName(field.type), "Box")) |_| {
                            if (comptime hasFormat(@TypeOf(@field(field_val, "value")))) {
                                try writer.print("{f}", .{@field(field_val, "value").format(depth + 1)});
                            }
                        } else {
                            if (comptime hasFormat(field.type)) {
                                try writer.print("{f}", .{field_val.format(depth + 1)});
                            } else {
                                try printBaseValue(writer, field.name, field_val, depth + 1);
                            }
                        }
                    },
                },
                .@"union" => |_| switch (this.data.*) {
                    inline else => |f| {
                        if (comptime mem.find(u8, @typeName(@TypeOf(f)), "Box")) |_| {
                            if (comptime hasFormat(@TypeOf(@field(f, "value")))) {
                                try writer.print("{f}", .{@field(f, "value").format(depth + 1)});
                            }
                        } else {
                            if (comptime hasFormat(@TypeOf(f))) {
                                try writer.print("{f}", .{f.format(depth + 1)});
                            } else {
                                try printBaseValue(writer, @tagName(this.data.*), f, depth + 1);
                            }
                        }
                    },
                },
                else => @compileError("TreeFormatter only supports structs and tagged unions"),
            }
        }
    };
}
