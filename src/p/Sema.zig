const std = @import("std");
const fmt = std.fmt;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const move = @import("util").move;
const p = @import("p");
const Error = p.common.Error;
const TreeFormatter = p.common.TreeFormatter;
const Parser = p.Parser;

const AstBuilder = @import("Sema/AstBuilder.zig");
const TypeChecker = @import("Sema/TypeChecker.zig");

allocator: Allocator,
errors: ArrayList(Error) = .empty,

pub fn init(allocator: Allocator) @This() {
    return .{ .allocator = allocator };
}

pub fn analyze(this: *@This(), cst: Parser.Program) !?Program {
    var ast_builder: AstBuilder = .init(this);

    const ast = try move(
        Program,
        this.allocator,
        @ptrCast(@alignCast(try cst.visit(ast_builder.visitor()))),
    );

    return ast;
}

pub fn deinit(this: *@This()) void {
    this.errors.deinit(this.allocator);
}

pub fn errs(this: *@This()) ?[]const Error {
    if (this.errors.items.len == 0) return null;
    return this.errors.items;
}

pub const Visitor = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        visit_program: *const fn (this: *anyopaque, node: *const Program) anyerror!*anyopaque,

        visit_decl: *const fn (this: *anyopaque, node: *const Decl) anyerror!*anyopaque,
        visit_obj_decl: *const fn (this: *anyopaque, node: *const *ObjDecl) anyerror!*anyopaque,
        visit_fn_decl: *const fn (this: *anyopaque, node: *const *FnDecl) anyerror!*anyopaque,
        visit_var_decl: *const fn (this: *anyopaque, node: *const *VarDecl) anyerror!*anyopaque,

        visit_stmt: *const fn (this: *anyopaque, node: *const *Stmt) anyerror!*anyopaque,
        visit_if_stmt: *const fn (this: *anyopaque, node: *const *IfStmt) anyerror!*anyopaque,
        visit_while_stmt: *const fn (this: *anyopaque, node: *const *WhileStmt) anyerror!*anyopaque,
        visit_for_stmt: *const fn (this: *anyopaque, node: *const *ForStmt) anyerror!*anyopaque,

        visit_expr: *const fn (this: *anyopaque, node: *const *Expr) anyerror!*anyopaque,
        visit_unary_expr: *const fn (this: *anyopaque, node: *const *UnaryExpr) anyerror!*anyopaque,
        visit_binary_expr: *const fn (this: *anyopaque, node: *const *BinaryExpr) anyerror!*anyopaque,
        visit_assign_expr: *const fn (this: *anyopaque, node: *const *AssignExpr) anyerror!*anyopaque,
        visit_property_expr: *const fn (this: *anyopaque, node: *const *PropertyExpr) anyerror!*anyopaque,
        visit_call_expr: *const fn (this: *anyopaque, node: *const *CallExpr) anyerror!*anyopaque,
    };

    pub fn visitProgram(this: *@This(), node: *const Program) anyerror!*anyopaque {
        return this.vtable.visit_program(this.ptr, node);
    }

    pub fn visitDecl(this: *@This(), node: *const Decl) anyerror!*anyopaque {
        return this.vtable.visit_decl(this.ptr, node);
    }

    pub fn visitStmt(this: *@This(), node: *const *Stmt) anyerror!*anyopaque {
        return this.vtable.visit_stmt(this.ptr, node);
    }

    pub fn visitExpr(this: *@This(), node: *const *Expr) anyerror!*anyopaque {
        return this.vtable.visit_expr(this.ptr, node);
    }

    pub fn visitObjDecl(this: *@This(), node: *const *ObjDecl) anyerror!*anyopaque {
        return this.vtable.visit_obj_decl(this.ptr, node);
    }

    pub fn visitFnDecl(this: *@This(), node: *const *FnDecl) anyerror!*anyopaque {
        return this.vtable.visit_fn_decl(this.ptr, node);
    }

    pub fn visitVarDecl(this: *@This(), node: *const *VarDecl) anyerror!*anyopaque {
        return this.vtable.visit_var_decl(this.ptr, node);
    }

    pub fn visitIfStmt(this: *@This(), node: *const *IfStmt) anyerror!*anyopaque {
        return this.vtable.visit_if_stmt(this.ptr, node);
    }

    pub fn visitWhileStmt(this: *@This(), node: *const *WhileStmt) anyerror!*anyopaque {
        return this.vtable.visit_while_stmt(this.ptr, node);
    }

    pub fn visitForStmt(this: *@This(), node: *const *ForStmt) anyerror!*anyopaque {
        return this.vtable.visit_for_stmt(this.ptr, node);
    }

    pub fn visitUnaryExpr(this: *@This(), node: *const *UnaryExpr) anyerror!*anyopaque {
        return this.vtable.visit_unary_expr(this.ptr, node);
    }

    pub fn visitBinaryExpr(this: *@This(), node: *const *BinaryExpr) anyerror!*anyopaque {
        return this.vtable.visit_binary_expr(this.ptr, node);
    }

    pub fn visitAssignExpr(this: *@This(), node: *const *AssignExpr) anyerror!*anyopaque {
        return this.vtable.visit_assign_expr(this.ptr, node);
    }

    pub fn visitPropertyExpr(this: *@This(), node: *const *PropertyExpr) anyerror!*anyopaque {
        return this.vtable.visit_property_expr(this.ptr, node);
    }

    pub fn visitCallExpr(this: *@This(), node: *const *CallExpr) anyerror!*anyopaque {
        return this.vtable.visit_call_expr(this.ptr, node);
    }
};

pub const Program = struct {
    decls: []Decl,

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        for (this.decls) |*decl| decl.deinit(allocator);
        allocator.free(this.decls);
    }

    pub fn visit(this: *const @This(), visitor: *Visitor) void {
        visitor.visitProgram(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};

pub const Decl = union(enum) {
    obj: ObjDecl,
    func: FnDecl,
    variable: VarDecl,
    stmt: Stmt,

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        switch (this.*) {
            inline else => |*decl| decl.deinit(allocator),
        }
    }

    pub fn visit(this: *const @This(), visitor: *Visitor) void {
        visitor.visitDecl(this.*);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};

pub const ObjDecl = struct {
    name: []const u8,
    parent: ?[]const u8,
    body: Program,

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        for (this.body.decls) |*decl| decl.deinit(allocator);
        allocator.free(this.body.decls);
    }

    pub fn visit(this: *const @This(), visitor: *Visitor) void {
        visitor.visitObjDecl(&this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};

pub const FnDecl = struct {
    name: []const u8,
    params: [][]const u8,
    body: Program,

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        allocator.free(this.params);
        for (this.body.decls) |*decl| decl.deinit(allocator);
        this.body.deinit(allocator);
    }

    pub fn visit(this: *const @This(), visitor: *Visitor) void {
        visitor.visitFnDecl(&this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};

pub const VarDecl = struct {
    name: []const u8,
    init: ?Expr,

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        if (this.init) |*init_expr| init_expr.deinit(allocator);
    }

    pub fn visit(this: *const @This(), visitor: *Visitor) void {
        visitor.visitVarDecl(&this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};

pub const Stmt = union(enum) {
    expr: Expr,
    @"if": IfStmt,
    @"while": WhileStmt,
    @"for": ForStmt,
    @"return": ?Expr,
    print: Expr,
    block: Program,

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        switch (this.*) {
            .@"return" => |*expr| if (expr.*) |*e| e.deinit(allocator),
            inline else => |*stmt| stmt.deinit(allocator),
        }
    }

    pub fn visit(this: *const @This(), visitor: *Visitor) void {
        visitor.visitStmt(&this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};

pub const IfStmt = struct {
    condition: *Expr,
    then_branch: *Stmt,
    else_branch: ?*Stmt,

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        this.condition.deinit(allocator);
        allocator.destroy(this.condition);

        this.then_branch.deinit(allocator);
        allocator.destroy(this.then_branch);

        if (this.else_branch) |else_branch| {
            else_branch.deinit(allocator);
            allocator.destroy(else_branch);
        }
    }

    pub fn visit(this: *const @This(), visitor: *Visitor) void {
        visitor.visitIfStmt(&this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};

pub const WhileStmt = struct {
    condition: *Expr,
    body: *Stmt,

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        this.condition.deinit(allocator);
        allocator.destroy(this.condition);

        this.body.deinit(allocator);
        allocator.destroy(this.body);
    }

    pub fn visit(this: *const @This(), visitor: *Visitor) void {
        visitor.visitWhileStmt(&this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};

pub const ForStmt = struct {
    pub const Init = union(enum) { variable: VarDecl, expr: Expr };

    init: ?Init,
    condition: ?*Expr,
    increment: ?*Expr,
    body: *Stmt,

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        if (this.init) |*init_value| switch (init_value.*) {
            inline else => |*i| i.deinit(allocator),
        };

        if (this.condition) |condition| {
            condition.deinit(allocator);
            allocator.destroy(condition);
        }

        if (this.increment) |increment| {
            increment.deinit(allocator);
            allocator.destroy(increment);
        }

        this.body.deinit(allocator);
        allocator.destroy(this.body);
    }

    pub fn visit(this: *const @This(), visitor: *Visitor) void {
        visitor.visitForStmt(&this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};

pub const Expr = union(enum) {
    nil,
    this,
    proto,
    bool: bool,
    number: f64,
    string: []const u8,
    identifier: []const u8,
    unary: UnaryExpr,
    binary: BinaryExpr,
    assign: AssignExpr,
    property: PropertyExpr,
    call: CallExpr,

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        switch (this.*) {
            .nil, .this, .proto, .bool, .number, .string, .identifier => {},
            .unary => |*unary| unary.deinit(allocator),
            .binary => |*binary| binary.deinit(allocator),
            .assign => |*assign| assign.deinit(allocator),
            .property => |*property| property.deinit(allocator),
            .call => |*call| call.deinit(allocator),
        }
    }

    pub fn visit(this: *const @This(), visitor: *Visitor) void {
        visitor.visitExpr(&this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};

pub const UnaryExpr = struct {
    pub const Op = enum { @"-", @"!" };

    op: Op,
    operand: *Expr,

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        this.operand.deinit(allocator);
        allocator.destroy(this.operand);
    }

    pub fn visit(this: *const @This(), visitor: *Visitor) void {
        visitor.visitUnaryExpr(&this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};

pub const BinaryExpr = struct {
    pub const Op = enum { @"/", @"*", @"-", @"+", @">", @">=", @"<", @"<=", @"==", @"!=", @"and", @"or" };

    left: *Expr,
    op: Op,
    right: *Expr,

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        this.left.deinit(allocator);
        allocator.destroy(this.left);

        this.right.deinit(allocator);
        allocator.destroy(this.right);
    }

    pub fn visit(this: *const @This(), visitor: *Visitor) void {
        visitor.visitBinaryExpr(&this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};

pub const AssignExpr = struct {
    target: *Expr,
    value: *Expr,

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        this.target.deinit(allocator);
        allocator.destroy(this.target);

        this.value.deinit(allocator);
        allocator.destroy(this.value);
    }

    pub fn visit(this: *const @This(), visitor: *Visitor) void {
        visitor.visitAssignExpr(&this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};

pub const PropertyExpr = struct {
    object: *Expr,
    name: []const u8,

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        this.object.deinit(allocator);
        allocator.destroy(this.object);
    }

    pub fn visit(this: *const @This(), visitor: *Visitor) void {
        visitor.visitPropertyExpr(&this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};

pub const CallExpr = struct {
    callee: *Expr,
    args: []*Expr,

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        this.callee.deinit(allocator);
        allocator.destroy(this.callee);
        for (this.args) |arg| {
            arg.deinit(allocator);
            allocator.destroy(arg);
        }

        allocator.free(this.args);
    }

    pub fn visit(this: *const @This(), visitor: *Visitor) void {
        visitor.visitCallExpr(&this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};
