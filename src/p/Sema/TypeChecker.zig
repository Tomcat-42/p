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

pub fn visitor(ctx: *const @This()) Sema.Visitor {
    return .{
        .ptr = @constCast(ctx),
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

inline fn bind_or_handle_error(ctx: *const @This(), allocator: Allocator, name: []const u8, value: Sema.Type) !?void {
    const scope = ctx.sema.scopes.getLastOrNull() orelse return null;

    const res = try scope.bind(allocator, name, value);
    if (res == null) try ctx.sema.errors.append(allocator, .{
        .message = try fmt.allocPrint(
            allocator,
            "'{s}' is already defined in this scope",
            .{name},
        ),
    });

    return res;
}

inline fn lookup_or_handle_error(ctx: *const @This(), allocator: Allocator, name: []const u8) !?Sema.Type {
    const scope = ctx.sema.scopes.getLastOrNull() orelse return null;

    const value = scope.lookup(name);
    if (value == null) try ctx.sema.errors.append(allocator, .{
        .message = try fmt.allocPrint(
            allocator,
            "'{s}' is not defined yet",
            .{name},
        ),
    });

    return value;
}

inline fn push_scope(ctx: *const @This(), allocator: Allocator, scope: *Sema.Scope) !void {
    const curr = ctx.sema.scopes.getLastOrNull();
    scope.parent = curr;
    try ctx.sema.scopes.append(allocator, scope);
}

inline fn pop_scope(ctx: *const @This()) void {
    _ = ctx.sema.scopes.pop();
}

inline fn validate_condition_type(ctx: *const @This(), allocator: Allocator, condition_type: Sema.Type, context: []const u8) !?void {
    return switch (condition_type) {
        .bool, .any => {},
        else => {
            try ctx.sema.errors.append(allocator, .{
                .message = try fmt.allocPrint(
                    allocator,
                    "{s} condition must be of type 'bool' or 'any', got '{s}'",
                    .{ context, @tagName(condition_type) },
                ),
            });
            return null;
        },
    };
}

fn visit_program(ctx: *anyopaque, allocator: Allocator, program: *Sema.Program) anyerror!?*anyopaque {
    const this: *const @This() = @ptrCast(@alignCast(ctx));

    try this.push_scope(allocator, &program.scope);

    var has_error = false;
    for (program.decls) |*decl| {
        const result = try decl.visit(allocator, this.visitor());
        if (result == null) has_error = true;
    }

    this.pop_scope();
    if (has_error) return null;
    return @ptrCast(@constCast(&{}));
}

fn visit_decl(ctx: *anyopaque, allocator: Allocator, decl: *Sema.Decl) anyerror!?*anyopaque {
    const this: *const @This() = @ptrCast(@alignCast(ctx));

    return switch (decl.*) {
        inline else => |*d| d.visit(allocator, this.visitor()),
    };
}

fn visit_obj_decl(ctx: *anyopaque, allocator: Allocator, obj_decl: *Sema.ObjDecl) anyerror!?*anyopaque {
    const this: *const @This() = @ptrCast(@alignCast(ctx));

    const bind_result = try this.bind_or_handle_error(allocator, obj_decl.name, .object);

    const parent = if (obj_decl.parent) |parent|
        try this.lookup_or_handle_error(allocator, parent)
    else
        null;
    _ = parent; // TODO: Handle parent

    const body_result = try obj_decl.body.visit(allocator, this.visitor());

    if (bind_result == null or body_result == null) return null;
    return body_result;
}

fn visit_fn_decl(ctx: *anyopaque, allocator: Allocator, fn_decl: *Sema.FnDecl) anyerror!?*anyopaque {
    const this: *const @This() = @ptrCast(@alignCast(ctx));

    const bind_result = try this.bind_or_handle_error(allocator, fn_decl.name, .function);

    var params_ok = true;
    for (fn_decl.params) |param| {
        const param_result = try fn_decl.body.scope.bind(allocator, param, .any);
        if (param_result == null) params_ok = false;
    }

    const body_result = try fn_decl.body.visit(allocator, this.visitor());

    if (bind_result == null or !params_ok or body_result == null) return null;
    return body_result;
}

fn visit_var_decl(ctx: *anyopaque, allocator: Allocator, var_decl: *Sema.VarDecl) anyerror!?*anyopaque {
    const this: *const @This() = @ptrCast(@alignCast(ctx));

    var init_result: ?*anyopaque = @ptrCast(@constCast(&{}));
    const value_type: Sema.Type = if (var_decl.init) |*init_expr| blk: {
        init_result = try init_expr.visit(allocator, this.visitor());
        if (init_result) |result| {
            const expr_type = try move(Sema.Type, allocator, @ptrCast(@alignCast(result)));
            break :blk expr_type;
        } else {
            break :blk .nil;
        }
    } else .nil;

    const bind_result = try this.bind_or_handle_error(allocator, var_decl.name, value_type);

    if (init_result == null or bind_result == null) return null;
    return @ptrCast(@constCast(&{}));
}

fn visit_stmt(ctx: *anyopaque, allocator: Allocator, stmt: *Sema.Stmt) anyerror!?*anyopaque {
    const this: *const @This() = @ptrCast(@alignCast(ctx));

    return switch (stmt.*) {
        .expr => |*expr| expr: {
            const result = try expr.visit(allocator, this.visitor());
            if (result) |r| {
                _ = try move(Sema.Type, allocator, @ptrCast(@alignCast(r)));
            }
            if (result == null) break :expr null;
            break :expr @ptrCast(@constCast(&{}));
        },
        .@"if" => |*if_stmt| if_stmt.visit(allocator, this.visitor()),
        .@"while" => |*while_stmt| while_stmt.visit(allocator, this.visitor()),
        .@"for" => |*for_stmt| for_stmt.visit(allocator, this.visitor()),
        .@"return" => |*ret_expr| expr: {
            var result: ?*anyopaque = null;
            if (ret_expr.*) |*expr| {
                result = try expr.visit(allocator, this.visitor());
                if (result) |r| _ = try move(
                    Sema.Type,
                    allocator,
                    @ptrCast(@alignCast(r)),
                );
            }
            if (result == null) break :expr null;
            break :expr @ptrCast(@constCast(&{}));
        },
        .print => |*expr| expr: {
            const result = try expr.visit(allocator, this.visitor());
            if (result) |r| {
                _ = try move(Sema.Type, allocator, @ptrCast(@alignCast(r)));
            }
            if (result == null) break :expr null;
            break :expr @ptrCast(@constCast(&{}));
        },
        .block => |*block| block.visit(allocator, this.visitor()),
    };
}

fn visit_if_stmt(ctx: *anyopaque, allocator: Allocator, if_stmt: *Sema.IfStmt) anyerror!?*anyopaque {
    const this: *const @This() = @ptrCast(@alignCast(ctx));

    const condition_result = try if_stmt.condition.visit(allocator, this.visitor());
    var condition_valid: ?void = null;
    if (condition_result) |result| {
        const condition_type = try move(Sema.Type, allocator, @ptrCast(@alignCast(result)));
        condition_valid = try this.validate_condition_type(allocator, condition_type, "if");
    }

    const then_result = try if_stmt.then_branch.visit(allocator, this.visitor());

    const else_result = if (if_stmt.else_branch) |else_branch|
        try else_branch.visit(allocator, this.visitor())
    else
        @as(?*anyopaque, @ptrCast(@constCast(&{})));

    if (condition_result == null or condition_valid == null or then_result == null or else_result == null)
        return null;

    return @ptrCast(@constCast(&{}));
}

fn visit_while_stmt(ctx: *anyopaque, allocator: Allocator, while_stmt: *Sema.WhileStmt) anyerror!?*anyopaque {
    const this: *const @This() = @ptrCast(@alignCast(ctx));

    const condition_result = try while_stmt.condition.visit(allocator, this.visitor());
    var condition_valid: ?void = null;
    if (condition_result) |result| {
        const condition_type = try move(Sema.Type, allocator, @ptrCast(@alignCast(result)));
        condition_valid = try this.validate_condition_type(allocator, condition_type, "while");
    }

    const body_result = try while_stmt.body.visit(allocator, this.visitor());

    if (condition_result == null or condition_valid == null or body_result == null)
        return null;

    return @ptrCast(@constCast(&{}));
}

fn visit_for_stmt(ctx: *anyopaque, allocator: Allocator, for_stmt: *Sema.ForStmt) anyerror!?*anyopaque {
    const this: *const @This() = @ptrCast(@alignCast(ctx));
    try this.push_scope(allocator, &for_stmt.scope);

    var init_result: ?*anyopaque = @ptrCast(@constCast(&{}));
    if (for_stmt.init) |*init_value| switch (init_value.*) {
        .variable => |*var_decl| {
            init_result = try var_decl.visit(allocator, this.visitor());
        },
        .expr => |*expr| {
            const expr_result = try expr.visit(allocator, this.visitor());
            if (expr_result) |r| {
                _ = try move(Sema.Type, allocator, @ptrCast(@alignCast(r)));
            }
            init_result = expr_result;
        },
    };

    var condition_valid: ?void = {};
    if (for_stmt.condition) |*cond| {
        const condition_result = try cond.visit(allocator, this.visitor());
        if (condition_result) |result| {
            const condition_type = try move(Sema.Type, allocator, @ptrCast(@alignCast(result)));
            condition_valid = try this.validate_condition_type(allocator, condition_type, "for");
        } else {
            condition_valid = null;
        }
    }

    var increment_result: ?*anyopaque = @ptrCast(@constCast(&{}));
    if (for_stmt.increment) |*inc| {
        const inc_result = try inc.visit(allocator, this.visitor());
        if (inc_result) |r| {
            _ = try move(Sema.Type, allocator, @ptrCast(@alignCast(r)));
        }
        increment_result = inc_result;
    }

    const body_result = try for_stmt.body.visit(allocator, this.visitor());

    this.pop_scope();

    if (init_result == null or condition_valid == null or increment_result == null or body_result == null)
        return null;

    return @ptrCast(@constCast(&{}));
}

fn visit_expr(ctx: *anyopaque, allocator: Allocator, expr: *Sema.Expr) anyerror!?*anyopaque {
    const this: *const @This() = @ptrCast(@alignCast(ctx));

    return switch (expr.*) {
        .nil => try dupe(Sema.Type, allocator, .nil),
        .this => try dupe(Sema.Type, allocator, .object),
        .proto => try dupe(Sema.Type, allocator, .object),
        .bool => try dupe(Sema.Type, allocator, .bool),
        .number => try dupe(Sema.Type, allocator, .number),
        .string => try dupe(Sema.Type, allocator, .string),
        .identifier => |name| blk: {
            const lookup_result = try this.lookup_or_handle_error(allocator, name);
            if (lookup_result) |ty| {
                break :blk try dupe(Sema.Type, allocator, ty);
            } else {
                break :blk null;
            }
        },
        inline else => |*e| e.visit(allocator, this.visitor()),
    };
}

fn visit_unary_expr(ctx: *anyopaque, allocator: Allocator, unary_expr: *Sema.UnaryExpr) anyerror!?*anyopaque {
    const this: *const @This() = @ptrCast(@alignCast(ctx));

    const operand_result = try unary_expr.operand.visit(allocator, this.visitor());
    if (operand_result == null) return null;

    const operand_ty = try move(Sema.Type, allocator, @ptrCast(@alignCast(operand_result.?)));

    return switch (unary_expr.op) {
        .@"!" => switch (operand_ty) {
            .bool => try dupe(Sema.Type, allocator, .bool),
            else => {
                try this.sema.errors.append(allocator, .{
                    .message = try fmt.allocPrint(
                        allocator,
                        "Operator '!' requires operand of type 'bool', got {s}",
                        .{@tagName(operand_ty)},
                    ),
                });
                return null;
            },
        },
        .@"-" => switch (operand_ty) {
            .number => try dupe(Sema.Type, allocator, .number),
            else => {
                try this.sema.errors.append(allocator, .{
                    .message = try fmt.allocPrint(
                        allocator,
                        "Operator '-' requires operand of type 'number', got {s}",
                        .{@tagName(operand_ty)},
                    ),
                });
                return null;
            },
        },
    };
}

fn visit_binary_expr(ctx: *anyopaque, allocator: Allocator, binary_expr: *Sema.BinaryExpr) anyerror!?*anyopaque {
    const this: *const @This() = @ptrCast(@alignCast(ctx));

    const lhs_result = try binary_expr.left.visit(allocator, this.visitor());
    const op = binary_expr.op;
    const rhs_result = try binary_expr.right.visit(allocator, this.visitor());

    if (lhs_result == null or rhs_result == null) {
        if (lhs_result) |r| {
            _ = try move(Sema.Type, allocator, @ptrCast(@alignCast(r)));
        }
        if (rhs_result) |r| {
            _ = try move(Sema.Type, allocator, @ptrCast(@alignCast(r)));
        }
        return null;
    }

    const lhs_ty = try move(Sema.Type, allocator, @ptrCast(@alignCast(lhs_result.?)));
    const rhs_ty = try move(Sema.Type, allocator, @ptrCast(@alignCast(rhs_result.?)));

    return switch (op) {
        .@"+", .@"-", .@"*", .@"/" => {
            if (lhs_ty != .number or rhs_ty != .number) {
                try this.sema.errors.append(allocator, .{
                    .message = try fmt.allocPrint(
                        allocator,
                        "Operator '{s}' requires both operands to be of type 'number', got {s} and {s}",
                        .{ @tagName(op), @tagName(lhs_ty), @tagName(rhs_ty) },
                    ),
                });
                return null;
            }
            return try dupe(Sema.Type, allocator, .number);
        },
        .@"and", .@"or" => {
            if (lhs_ty != .bool or rhs_ty != .bool) {
                try this.sema.errors.append(allocator, .{
                    .message = try fmt.allocPrint(
                        allocator,
                        "Operator '{s}' requires both operands to be of type 'bool', got {s} and {s}",
                        .{ @tagName(op), @tagName(lhs_ty), @tagName(rhs_ty) },
                    ),
                });
                return null;
            }
            return try dupe(Sema.Type, allocator, .bool);
        },
        .@">", .@">=", .@"<", .@"<=" => {
            if (lhs_ty != .number or rhs_ty != .number) {
                try this.sema.errors.append(allocator, .{
                    .message = try fmt.allocPrint(
                        allocator,
                        "Operator '{s}' requires both operands to be of type 'number', got {s} and {s}",
                        .{ @tagName(op), @tagName(lhs_ty), @tagName(rhs_ty) },
                    ),
                });
                return null;
            }
            return try dupe(Sema.Type, allocator, .bool);
        },
        .@"==", .@"!=" => {
            if (lhs_ty != rhs_ty) {
                try this.sema.errors.append(allocator, .{
                    .message = try fmt.allocPrint(
                        allocator,
                        "Operator '{s}' requires both operands to be of the same type, got {s} and {s}",
                        .{ @tagName(op), @tagName(lhs_ty), @tagName(rhs_ty) },
                    ),
                });
                return null;
            }
            return try dupe(Sema.Type, allocator, lhs_ty);
        },
    };
}

fn visit_assign_expr(ctx: *anyopaque, allocator: Allocator, assign_expr: *Sema.AssignExpr) anyerror!?*anyopaque {
    const this: *const @This() = @ptrCast(@alignCast(ctx));

    const target_result = try assign_expr.target.visit(allocator, this.visitor());
    const value_result = try assign_expr.value.visit(allocator, this.visitor());

    if (target_result == null or value_result == null) {
        if (target_result) |r| {
            _ = try move(Sema.Type, allocator, @ptrCast(@alignCast(r)));
        }
        if (value_result) |r| {
            _ = try move(Sema.Type, allocator, @ptrCast(@alignCast(r)));
        }
        return null;
    }

    _ = try move(Sema.Type, allocator, @ptrCast(@alignCast(target_result.?)));
    const value_type = try move(Sema.Type, allocator, @ptrCast(@alignCast(value_result.?)));

    return try dupe(Sema.Type, allocator, value_type);
}

fn visit_property_expr(ctx: *anyopaque, allocator: Allocator, property_expr: *Sema.PropertyExpr) anyerror!?*anyopaque {
    const this: *const @This() = @ptrCast(@alignCast(ctx));

    const object_result = try property_expr.object.visit(allocator, this.visitor());
    if (object_result) |r| {
        _ = try move(Sema.Type, allocator, @ptrCast(@alignCast(r)));
    }
    if (object_result == null) return null;

    return try dupe(Sema.Type, allocator, .any);
}

fn visit_call_expr(ctx: *anyopaque, allocator: Allocator, call_expr: *Sema.CallExpr) anyerror!?*anyopaque {
    const this: *const @This() = @ptrCast(@alignCast(ctx));

    const callee_result = try call_expr.callee.visit(allocator, this.visitor());
    if (callee_result) |r| {
        _ = try move(Sema.Type, allocator, @ptrCast(@alignCast(r)));
    }

    var args_ok = true;
    for (call_expr.args) |*arg| {
        const arg_result = try arg.*.visit(allocator, this.visitor());
        if (arg_result) |r| {
            _ = try move(Sema.Type, allocator, @ptrCast(@alignCast(r)));
        }
        if (arg_result == null) args_ok = false;
    }

    if (callee_result == null or !args_ok) return null;

    return try dupe(Sema.Type, allocator, .any);
}
