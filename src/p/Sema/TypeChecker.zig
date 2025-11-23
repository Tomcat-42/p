const std = @import("std");
const fmt = std.fmt;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const dupe = @import("util").dupe;
const move = @import("util").move;
const p = @import("p");
const Sema = p.Sema;
const Error = p.common.Error;

sema: *Sema,

pub fn init(sema: *Sema) @This() {
    return .{ .sema = sema };
}

pub fn visitor(this: *const @This()) Sema.Visitor {
    return .{
        .ptr = @constCast(this),
        .vtable = &.{
            .visit_program = visit_program,
            .visit_decl = visit_decl,
            .visit_obj_decl = visit_obj_decl,
            .visit_fn_decl = visit_fn_decl,
            .visit_var_decl = visit_var_decl,
            .visit_stmt = visit_stmt,
            .visit_if_stmt = visit_if_stmt,
            .visit_while_stmt = visit_while_stmt,
            .visit_for_stmt = visit_for_stmt,
            .visit_expr = visit_expr,
            .visit_unary_expr = visit_unary_expr,
            .visit_binary_expr = visit_binary_expr,
            .visit_assign_expr = visit_assign_expr,
            .visit_property_expr = visit_property_expr,
            .visit_call_expr = visit_call_expr,
        },
    };
}

inline fn bind_or_handle_error(this: *const @This(), allocator: Allocator, name: []const u8, value: Sema.Type) !?void {
    const scope = this.sema.scopes.getLastOrNull() orelse return null;

    const res = try scope.bind(allocator, name, value);
    if (res == null) try this.sema.errors.append(allocator, .{
        .message = try fmt.allocPrint(
            allocator,
            "Name '{s}' is already defined in this scope",
            .{name},
        ),
    });

    return res;
}

inline fn lookup_or_handle_error(this: *const @This(), allocator: Allocator, name: []const u8) !?Sema.Type {
    const scope = this.sema.scopes.getLastOrNull() orelse return null;

    const value = scope.lookup(name);
    if (value == null) try this.sema.errors.append(allocator, .{
        .message = try fmt.allocPrint(
            allocator,
            "Name '{s}' is not defined yet",
            .{name},
        ),
    });

    return value;
}

fn visit_program(this: *anyopaque, allocator: Allocator, program: *Sema.Program) anyerror!?*anyopaque {
    const ty: *const @This() = @ptrCast(@alignCast(this));

    program.scope.parent = ty.sema.scopes.getLastOrNull();
    try ty.sema.scopes.append(allocator, &program.scope);

    for (program.decls) |*decl| if (try decl.visit(allocator, ty.visitor()) == null)
        return null;

    _ = ty.sema.scopes.pop();

    return @ptrCast(@constCast(&{}));
}

fn visit_decl(this: *anyopaque, allocator: Allocator, decl: *Sema.Decl) anyerror!?*anyopaque {
    const ty: *const @This() = @ptrCast(@alignCast(this));

    return switch (decl.*) {
        inline else => |*d| d.visit(allocator, ty.visitor()),
    };
}

fn visit_obj_decl(this: *anyopaque, allocator: Allocator, obj_decl: *Sema.ObjDecl) anyerror!?*anyopaque {
    const ty: *const @This() = @ptrCast(@alignCast(this));

    try ty.bind_or_handle_error(allocator, obj_decl.name, .object) orelse
        return null;

    const parent = if (obj_decl.parent) |parent|
        try ty.lookup_or_handle_error(allocator, parent) orelse
            return null
    else
        null;
    _ = parent; // TODO: Handle parent

    return obj_decl.body.visit(allocator, ty.visitor());
}

fn visit_fn_decl(this: *anyopaque, allocator: Allocator, fn_decl: *Sema.FnDecl) anyerror!?*anyopaque {
    const ty: *const @This() = @ptrCast(@alignCast(this));

    try ty.bind_or_handle_error(allocator, fn_decl.name, .function) orelse
        return null;

    for (fn_decl.params) |param|
        try fn_decl.body.scope.bind(allocator, param, .any) orelse
            return null;

    return fn_decl.body.visit(allocator, ty.visitor());
}

fn visit_var_decl(this: *anyopaque, allocator: Allocator, var_decl: *Sema.VarDecl) anyerror!?*anyopaque {
    const ty: *const @This() = @ptrCast(@alignCast(this));

    const value_type: Sema.Type = if (var_decl.init) |*init_expr| blk: {
        const expr_type = try move(
            Sema.Type,
            allocator,
            @ptrCast(@alignCast(try init_expr.visit(allocator, ty.visitor()) orelse return null)),
        );
        break :blk expr_type;
    } else .nil;

    try ty.bind_or_handle_error(allocator, var_decl.name, value_type) orelse
        return null;

    return @ptrCast(@constCast(&{}));
}

fn visit_stmt(this: *anyopaque, allocator: Allocator, stmt: *Sema.Stmt) anyerror!?*anyopaque {
    const ty: *const @This() = @ptrCast(@alignCast(this));

    return switch (stmt.*) {
        .expr => |*expr| expr: {
            _ = try move(
                Sema.Type,
                allocator,
                @ptrCast(@alignCast(try expr.visit(allocator, ty.visitor()) orelse return null)),
            );
            break :expr @ptrCast(@constCast(&{}));
        },
        .@"if" => |*if_stmt| if_stmt.visit(allocator, ty.visitor()),
        .@"while" => |*while_stmt| while_stmt.visit(allocator, ty.visitor()),
        .@"for" => |*for_stmt| for_stmt.visit(allocator, ty.visitor()),
        .@"return" => |*ret_expr| expr: {
            if (ret_expr.*) |*expr| _ = try move(
                Sema.Type,
                allocator,
                @ptrCast(@alignCast(try expr.visit(allocator, ty.visitor()) orelse return null)),
            );
            break :expr @ptrCast(@constCast(&{}));
        },
        .print => |*expr| expr.visit(allocator, ty.visitor()),
        .block => |*block| block.visit(allocator, ty.visitor()),
    };
}

fn visit_if_stmt(this: *anyopaque, allocator: Allocator, if_stmt: *Sema.IfStmt) anyerror!?*anyopaque {
    const ty: *const @This() = @ptrCast(@alignCast(this));

    _ = try move(
        Sema.Type,
        allocator,
        @ptrCast(@alignCast(try if_stmt.condition.visit(allocator, ty.visitor()) orelse return null)),
    );
    _ = try if_stmt.then_branch.visit(allocator, ty.visitor()) orelse return null;

    if (if_stmt.else_branch) |else_branch|
        _ = try else_branch.visit(allocator, ty.visitor()) orelse return null;

    return @ptrCast(@constCast(&{}));
}

fn visit_while_stmt(this: *anyopaque, allocator: Allocator, while_stmt: *Sema.WhileStmt) anyerror!?*anyopaque {
    const ty: *const @This() = @ptrCast(@alignCast(this));

    _ = try move(
        Sema.Type,
        allocator,
        @ptrCast(@alignCast(try while_stmt.condition.visit(allocator, ty.visitor()) orelse return null)),
    );
    _ = try while_stmt.body.visit(allocator, ty.visitor()) orelse return null;

    return @ptrCast(@constCast(&{}));
}

fn visit_for_stmt(this: *anyopaque, allocator: Allocator, for_stmt: *Sema.ForStmt) anyerror!?*anyopaque {
    const ty: *const @This() = @ptrCast(@alignCast(this));

    // Create a new scope for the for loop
    var scope: Sema.Scope = .{};
    defer scope.deinit(allocator);
    scope.parent = ty.sema.scopes.getLastOrNull();
    try ty.sema.scopes.append(allocator, &scope);
    defer _ = ty.sema.scopes.pop();

    if (for_stmt.init) |*init_value| switch (init_value.*) {
        .variable => |*var_decl| _ = try var_decl.visit(allocator, ty.visitor()) orelse return null,
        .expr => |*expr| _ = try move(
            Sema.Type,
            allocator,
            @ptrCast(@alignCast(try expr.visit(allocator, ty.visitor()) orelse return null)),
        ),
    };

    if (for_stmt.condition) |condition| _ = try move(
        Sema.Type,
        allocator,
        @ptrCast(@alignCast(try condition.visit(allocator, ty.visitor()) orelse return null)),
    );

    if (for_stmt.increment) |increment| _ = try move(
        Sema.Type,
        allocator,
        @ptrCast(@alignCast(try increment.visit(allocator, ty.visitor()) orelse return null)),
    );

    _ = try for_stmt.body.visit(allocator, ty.visitor()) orelse return null;

    return @ptrCast(@constCast(&{}));
}

fn visit_expr(this: *anyopaque, allocator: Allocator, expr: *Sema.Expr) anyerror!?*anyopaque {
    const ty: *const @This() = @ptrCast(@alignCast(this));

    return switch (expr.*) {
        .nil => try dupe(Sema.Type, allocator, .nil),
        .this => try dupe(Sema.Type, allocator, .object),
        .proto => try dupe(Sema.Type, allocator, .object),
        .bool => try dupe(Sema.Type, allocator, .bool),
        .number => try dupe(Sema.Type, allocator, .number),
        .string => try dupe(Sema.Type, allocator, .string),
        .identifier => |name| try dupe(
            Sema.Type,
            allocator,
            try ty.lookup_or_handle_error(allocator, name) orelse return null,
        ),
        inline else => |*e| e.visit(allocator, ty.visitor()),
    };
}

fn visit_unary_expr(this: *anyopaque, allocator: Allocator, unary_expr: *Sema.UnaryExpr) anyerror!?*anyopaque {
    const ty: *const @This() = @ptrCast(@alignCast(this));

    const operand_ty = try move(
        Sema.Type,
        allocator,
        @ptrCast(@alignCast(try unary_expr.operand.visit(allocator, ty.visitor()) orelse return null)),
    );

    return ty: switch (unary_expr.op) {
        .@"!" => switch (operand_ty) {
            .bool => try dupe(Sema.Type, allocator, .bool),
            else => {
                try ty.sema.errors.append(allocator, .{
                    .message = try fmt.allocPrint(
                        allocator,
                        "Operator '!' requires operand of type 'bool', got {s}",
                        .{@tagName(operand_ty)},
                    ),
                });
                break :ty null;
            },
        },
        .@"-" => switch (operand_ty) {
            .number => try dupe(Sema.Type, allocator, .number),
            else => {
                try ty.sema.errors.append(allocator, .{
                    .message = try fmt.allocPrint(
                        allocator,
                        "Operator '-' requires operand of type 'number', got {s}",
                        .{@tagName(operand_ty)},
                    ),
                });
                break :ty null;
            },
        },
    };
}

fn visit_binary_expr(this: *anyopaque, allocator: Allocator, binary_expr: *Sema.BinaryExpr) anyerror!?*anyopaque {
    const ty: *const @This() = @ptrCast(@alignCast(this));

    const lhs_ty = try move(
        Sema.Type,
        allocator,
        @ptrCast(@alignCast(try binary_expr.left.visit(allocator, ty.visitor()) orelse return null)),
    );

    const op = binary_expr.op;

    const rhs_ty = try move(
        Sema.Type,
        allocator,
        @ptrCast(@alignCast(try binary_expr.right.visit(allocator, ty.visitor()) orelse return null)),
    );

    return ty: switch (op) {
        .@"+", .@"-", .@"*", .@"/" => {
            if (lhs_ty != .number or rhs_ty != .number) {
                try ty.sema.errors.append(allocator, .{
                    .message = try fmt.allocPrint(
                        allocator,
                        "Operator '{s}' requires both operands to be of type 'number', got {s} and {s}",
                        .{ @tagName(op), @tagName(lhs_ty), @tagName(rhs_ty) },
                    ),
                });
                break :ty null;
            }
            break :ty try dupe(Sema.Type, allocator, .number);
        },
        .@"and", .@"or" => {
            if (lhs_ty != .bool or rhs_ty != .bool) {
                try ty.sema.errors.append(allocator, .{
                    .message = try fmt.allocPrint(
                        allocator,
                        "Operator '{s}' requires both operands to be of type 'bool', got {s} and {s}",
                        .{ @tagName(op), @tagName(lhs_ty), @tagName(rhs_ty) },
                    ),
                });
                break :ty null;
            }
            break :ty try dupe(Sema.Type, allocator, .bool);
        },
        .@">", .@">=", .@"<", .@"<=" => {
            if (lhs_ty != .number or rhs_ty != .number) {
                try ty.sema.errors.append(allocator, .{
                    .message = try fmt.allocPrint(
                        allocator,
                        "Operator '{s}' requires both operands to be of type 'number', got {s} and {s}",
                        .{ @tagName(op), @tagName(lhs_ty), @tagName(rhs_ty) },
                    ),
                });
                break :ty null;
            }
            break :ty try dupe(Sema.Type, allocator, .bool);
        },
        .@"==", .@"!=" => {
            // Equality operators work on any types (weakly typed)
            break :ty try dupe(Sema.Type, allocator, .bool);
        },
    };
}

fn visit_assign_expr(this: *anyopaque, allocator: Allocator, assign_expr: *Sema.AssignExpr) anyerror!?*anyopaque {
    const ty: *const @This() = @ptrCast(@alignCast(this));

    _ = try move(
        Sema.Type,
        allocator,
        @ptrCast(@alignCast(try assign_expr.target.visit(allocator, ty.visitor()) orelse return null)),
    );

    const value_type = try move(
        Sema.Type,
        allocator,
        @ptrCast(@alignCast(try assign_expr.value.visit(allocator, ty.visitor()) orelse return null)),
    );

    return try dupe(Sema.Type, allocator, value_type);
}

fn visit_property_expr(this: *anyopaque, allocator: Allocator, property_expr: *Sema.PropertyExpr) anyerror!?*anyopaque {
    const ty: *const @This() = @ptrCast(@alignCast(this));

    _ = try property_expr.object.visit(allocator, ty.visitor()) orelse return null;

    return try dupe(Sema.Type, allocator, .any);
}

fn visit_call_expr(this: *anyopaque, allocator: Allocator, call_expr: *Sema.CallExpr) anyerror!?*anyopaque {
    const ty: *const @This() = @ptrCast(@alignCast(this));

    _ = try call_expr.callee.visit(allocator, ty.visitor()) orelse return null;
    for (call_expr.args) |*arg| _ = try arg.*.visit(allocator, ty.visitor()) orelse return null;

    return try dupe(Sema.Type, allocator, .any);
}
