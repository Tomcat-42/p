const std = @import("std");
const fmt = std.fmt;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const p = @import("p");
const Sema = p.Sema;
const Error = p.common.Error;

sema: *Sema,
scopes: ArrayList(*Sema.Scope) = .empty,

pub fn init(sema: *Sema) @This() {
    return .{ .sema = sema };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.scopes.deinit(allocator);
}

pub fn visitor(this: *@This()) Sema.Visitor {
    return .{
        .ptr = this,
        .vtable = &.{
            .visit_program = visitProgram,
            .visit_decl = visitDecl,
            .visit_obj_decl = visitObjDecl,
            .visit_fn_decl = visitFnDecl,
            .visit_var_decl = visitVarDecl,
            .visit_stmt = visitStmt,
            .visit_if_stmt = visitIfStmt,
            .visit_while_stmt = visitWhileStmt,
            .visit_for_stmt = visitForStmt,
            .visit_expr = visitExpr,
            .visit_unary_expr = visitUnaryExpr,
            .visit_binary_expr = visitBinaryExpr,
            .visit_assign_expr = visitAssignExpr,
            .visit_property_expr = visitPropertyExpr,
            .visit_call_expr = visitCallExpr,
        },
    };
}

inline fn bind_or_handle_error(this: *@This(), name: []const u8, value: Sema.Value) ?void {
    _ = this;
    _ = name;
    _ = value;
    return {};
}

fn visitProgram(this: *anyopaque, program: *const Sema.Program) anyerror!?*anyopaque {
    _ = this;
    _ = program;
    return @ptrCast(@constCast(&{}));
}

fn visitDecl(this: *anyopaque, decl: *const Sema.Decl) anyerror!?*anyopaque {
    const ty: *@This() = @ptrCast(@alignCast(this));

    return switch (decl.*) {
        inline else => |*d| d.visit(ty.visitor()),
    };
}

fn visitObjDecl(this: *anyopaque, obj_decl: *const Sema.ObjDecl) anyerror!?*anyopaque {
    const ty: *@This() = @ptrCast(@alignCast(this));

    _ = ty;

    for (obj_decl.*.body.decls) |*decl| {
        _ = decl;
    }

    return null;
}

fn visitFnDecl(this: *anyopaque, fn_decl: *const Sema.FnDecl) anyerror!?*anyopaque {
    _ = this;
    _ = fn_decl;
    return null;
}

fn visitVarDecl(this: *anyopaque, var_decl: *const Sema.VarDecl) anyerror!?*anyopaque {
    _ = this;
    _ = var_decl;
    return null;
}

fn visitStmt(this: *anyopaque, stmt: *const Sema.Stmt) anyerror!?*anyopaque {
    _ = this;
    _ = stmt;
    return null;
}

fn visitIfStmt(this: *anyopaque, if_stmt: *const Sema.IfStmt) anyerror!?*anyopaque {
    _ = this;
    _ = if_stmt;
    return null;
}

fn visitWhileStmt(this: *anyopaque, while_stmt: *const Sema.WhileStmt) anyerror!?*anyopaque {
    _ = this;
    _ = while_stmt;
    return null;
}

fn visitForStmt(this: *anyopaque, for_stmt: *const Sema.ForStmt) anyerror!?*anyopaque {
    _ = this;
    _ = for_stmt;
    return null;
}

fn visitExpr(this: *anyopaque, expr: *const Sema.Expr) anyerror!?*anyopaque {
    _ = this;
    _ = expr;
    return null;
}

fn visitUnaryExpr(this: *anyopaque, unary_expr: *const Sema.UnaryExpr) anyerror!?*anyopaque {
    _ = this;
    _ = unary_expr;
    return null;
}

fn visitBinaryExpr(this: *anyopaque, binary_expr: *const Sema.BinaryExpr) anyerror!?*anyopaque {
    _ = this;
    _ = binary_expr;
    return null;
}

fn visitAssignExpr(this: *anyopaque, assign_expr: *const Sema.AssignExpr) anyerror!?*anyopaque {
    _ = this;
    _ = assign_expr;
    return null;
}

fn visitPropertyExpr(this: *anyopaque, property_expr: *const Sema.PropertyExpr) anyerror!?*anyopaque {
    _ = this;
    _ = property_expr;
    return null;
}

fn visitCallExpr(this: *anyopaque, call_expr: *const Sema.CallExpr) anyerror!?*anyopaque {
    _ = this;
    _ = call_expr;
    return null;
}
