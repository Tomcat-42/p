const p = @import("p");
const Sema = p.Sema;

sema: *Sema,

pub fn init(sema: *Sema) @This() {
    return .{ .sema = sema };
}

pub fn visitor(this: *@This()) Sema.Visitor {
    return .{
        .ptr = this,
        .vtable = .{
            .visitProgram = visitProgram,
            .visitDecl = visitDecl,
            .visitObjDecl = visitObjDecl,
            .visitFnDecl = visitFnDecl,
            .visitVarDecl = visitVarDecl,
            .visitStmt = visitStmt,
            .visitIfStmt = visitIfStmt,
            .visitWhileStmt = visitWhileStmt,
            .visitForStmt = visitForStmt,
            .visitExpr = visitExpr,
            .visitUnaryExpr = visitUnaryExpr,
            .visitBinaryExpr = visitBinaryExpr,
            .visitAssignExpr = visitAssignExpr,
            .visitPropertyExpr = visitPropertyExpr,
            .visitCallExpr = visitCallExpr,
        },
    };
}

fn visitProgram(this: *@This(), program: *Sema.Program) anyerror!*anyopaque {
    _ = this; // autofix
    _ = program; // autofix
    return null;
}

fn visitDecl(this: *@This(), decl: *Sema.Decl) anyerror!*anyopaque {
    _ = this; // autofix
    _ = decl; // autofix
    return null;
}

fn visitObjDecl(this: *@This(), obj_decl: *Sema.ObjDecl) anyerror!*anyopaque {
    _ = this; // autofix
    _ = obj_decl; // autofix
    return null;
}

fn visitFnDecl(this: *@This(), fn_decl: *Sema.FnDecl) anyerror!*anyopaque {
    _ = this; // autofix
    _ = fn_decl; // autofix
    return null;
}

fn visitVarDecl(this: *@This(), var_decl: *Sema.VarDecl) anyerror!*anyopaque {
    _ = this; // autofix
    _ = var_decl; // autofix
    return null;
}

fn visitStmt(this: *@This(), stmt: *Sema.Stmt) anyerror!*anyopaque {
    _ = this; // autofix
    _ = stmt; // autofix
    return null;
}

fn visitIfStmt(this: *@This(), if_stmt: *Sema.IfStmt) anyerror!*anyopaque {
    _ = this; // autofix
    _ = if_stmt; // autofix
    return null;
}

fn visitWhileStmt(this: *@This(), while_stmt: *Sema.WhileStmt) anyerror!*anyopaque {
    _ = this; // autofix
    _ = while_stmt; // autofix
    return null;
}

fn visitForStmt(this: *@This(), for_stmt: *Sema.ForStmt) anyerror!*anyopaque {
    _ = this; // autofix
    _ = for_stmt; // autofix
    return null;
}

fn visitExpr(this: *@This(), expr: *Sema.Expr) anyerror!*anyopaque {
    _ = this; // autofix
    _ = expr; // autofix
    return null;
}

fn visitUnaryExpr(this: *@This(), unary_expr: *Sema.UnaryExpr) anyerror!*anyopaque {
    _ = this; // autofix
    _ = unary_expr; // autofix
    return null;
}

fn visitBinaryExpr(this: *@This(), binary_expr: *Sema.BinaryExpr) anyerror!*anyopaque {
    _ = this; // autofix
    _ = binary_expr; // autofix
    return null;
}

fn visitAssignExpr(this: *@This(), assign_expr: *Sema.AssignExpr) anyerror!*anyopaque {
    _ = this; // autofix
    _ = assign_expr; // autofix
    return null;
}

fn visitPropertyExpr(this: *@This(), property_expr: *Sema.PropertyExpr) anyerror!*anyopaque {
    _ = this; // autofix
    _ = property_expr; // autofix
    return null;
}

fn visitCallExpr(this: *@This(), call_expr: *Sema.CallExpr) anyerror!*anyopaque {
    _ = this; // autofix
    _ = call_expr; // autofix
    return null;
}
