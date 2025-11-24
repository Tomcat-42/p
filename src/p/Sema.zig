const std = @import("std");
const fmt = std.fmt;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMapUnmanaged = std.StringArrayHashMapUnmanaged;
const Io = std.Io;

const move = @import("util").move;
const p = @import("p");
const Error = p.common.Error;
const TreeFormatter = p.common.TreeFormatter;
const Parser = p.Parser;

const AstBuilder = @import("Sema/AstBuilder.zig");
const TypeChecker = @import("Sema/TypeChecker.zig");

errors: ArrayList(Error) = .empty,
scopes: ArrayList(*Scope) = .empty,

pub fn analyze(this: *@This(), allocator: Allocator, cst: Parser.Program) !?Program {
    const ast_builder: AstBuilder = .init(this);
    const ty: TypeChecker = .init(this);

    var ast = try move(
        Program,
        allocator,
        @ptrCast(@alignCast(try cst.visit(
            allocator,
            ast_builder.visitor(),
        ))),
    );

    _ = try ast.visit(allocator, ty.visitor()) orelse {
        ast.deinit(allocator);
        return null;
    };

    return ast;
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    for (this.errors.items) |*err| err.deinit(allocator);
    this.errors.deinit(allocator);
    this.scopes.deinit(allocator);
}

pub fn errs(this: *const @This()) ?[]const Error {
    if (this.errors.items.len == 0) return null;
    return this.errors.items;
}

pub const Type = enum { any, nil, bool, number, string, object, function };

pub const Scope = struct {
    parent: ?*@This() = null,
    bindings: StringHashMapUnmanaged(Type) = .empty,

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        this.bindings.deinit(allocator);
    }

    pub fn lookup(this: *@This(), name: []const u8) ?Type {
        var current: ?*@This() = this;
        return while (current) |scope| : (current = scope.parent) {
            if (scope.bindings.get(name)) |value|
                return value;
        } else null;
    }

    pub fn bind(this: *@This(), allocator: Allocator, name: []const u8, value: Type) !?void {
        const result = try this.bindings.getOrPut(allocator, name);
        if (result.found_existing) return null;
        result.value_ptr.* = value;
    }
};

pub const Program = struct {
    scope: Scope = .{},
    decls: []Decl,

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        this.scope.deinit(allocator);
        for (this.decls) |*decl| decl.deinit(allocator);
        allocator.free(this.decls);
    }

    pub fn visit(this: *const @This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_program)).@"fn".return_type.? {
        return visitor.visit_program(allocator, this);
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

    pub fn visit(this: *@This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_decl)).@"fn".return_type.? {
        return visitor.visit_decl(allocator, this);
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
        this.body.deinit(allocator);
    }

    pub fn visit(this: *@This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_obj_decl)).@"fn".return_type.? {
        return visitor.visit_obj_decl(allocator, this);
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
        this.body.deinit(allocator);
    }

    pub fn visit(this: *@This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_fn_decl)).@"fn".return_type.? {
        return visitor.visit_fn_decl(allocator, this);
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

    pub fn visit(this: *@This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_var_decl)).@"fn".return_type.? {
        return visitor.visit_var_decl(allocator, this);
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

    pub fn visit(this: *@This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_stmt)).@"fn".return_type.? {
        return visitor.visit_stmt(allocator, this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};

pub const IfStmt = struct {
    condition: Expr,
    then_branch: *Stmt,
    else_branch: ?*Stmt,

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        this.condition.deinit(allocator);

        this.then_branch.deinit(allocator);
        allocator.destroy(this.then_branch);

        if (this.else_branch) |else_branch| {
            else_branch.deinit(allocator);
            allocator.destroy(else_branch);
        }
    }

    pub fn visit(this: *@This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_if_stmt)).@"fn".return_type.? {
        return visitor.visit_if_stmt(allocator, this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};

pub const WhileStmt = struct {
    condition: Expr,
    body: *Stmt,

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        this.condition.deinit(allocator);

        this.body.deinit(allocator);
        allocator.destroy(this.body);
    }

    pub fn visit(this: *@This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_while_stmt)).@"fn".return_type.? {
        return visitor.visit_while_stmt(allocator, this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};

pub const ForStmt = struct {
    pub const Init = union(enum) { variable: VarDecl, expr: Expr };

    scope: Scope = .{},
    init: ?Init,
    condition: ?Expr,
    increment: ?Expr,
    body: *Stmt,

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        this.scope.deinit(allocator);
        if (this.init) |*init_value| switch (init_value.*) {
            inline else => |*i| i.deinit(allocator),
        };

        if (this.condition) |*condition| condition.deinit(allocator);
        if (this.increment) |*increment| increment.deinit(allocator);

        this.body.deinit(allocator);
        allocator.destroy(this.body);
    }

    pub fn visit(this: *@This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_for_stmt)).@"fn".return_type.? {
        return visitor.visit_for_stmt(allocator, this);
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

    pub fn visit(this: *@This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_expr)).@"fn".return_type.? {
        return visitor.visit_expr(allocator, this);
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

    pub fn visit(this: *@This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_unary_expr)).@"fn".return_type.? {
        return visitor.visit_unary_expr(allocator, this);
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

    pub fn visit(this: *@This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_binary_expr)).@"fn".return_type.? {
        return visitor.visit_binary_expr(allocator, this);
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

    pub fn visit(this: *@This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_assign_expr)).@"fn".return_type.? {
        return visitor.visit_assign_expr(allocator, this);
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

    pub fn visit(this: *@This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_property_expr)).@"fn".return_type.? {
        return visitor.visit_property_expr(allocator, this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};

pub const CallExpr = struct {
    callee: *Expr,
    args: []Expr,

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        this.callee.deinit(allocator);
        allocator.destroy(this.callee);
        for (this.args) |*arg| {
            arg.deinit(allocator);
        }

        allocator.free(this.args);
    }

    pub fn visit(this: *@This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_call_expr)).@"fn".return_type.? {
        return visitor.visit_call_expr(allocator, this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = TreeFormatter(@This());
};

pub const Visitor = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        visit_program: *const fn (_: *anyopaque, _: Allocator, _: *Program) anyerror!?*anyopaque,

        visit_decl: *const fn (_: *anyopaque, _: Allocator, _: *Decl) anyerror!?*anyopaque,
        visit_obj_decl: *const fn (_: *anyopaque, _: Allocator, _: *ObjDecl) anyerror!?*anyopaque,
        visit_fn_decl: *const fn (_: *anyopaque, _: Allocator, _: *FnDecl) anyerror!?*anyopaque,
        visit_var_decl: *const fn (_: *anyopaque, _: Allocator, _: *VarDecl) anyerror!?*anyopaque,

        visit_stmt: *const fn (_: *anyopaque, _: Allocator, _: *Stmt) anyerror!?*anyopaque,
        visit_if_stmt: *const fn (_: *anyopaque, _: Allocator, _: *IfStmt) anyerror!?*anyopaque,
        visit_while_stmt: *const fn (_: *anyopaque, _: Allocator, _: *WhileStmt) anyerror!?*anyopaque,
        visit_for_stmt: *const fn (_: *anyopaque, _: Allocator, _: *ForStmt) anyerror!?*anyopaque,

        visit_expr: *const fn (_: *anyopaque, _: Allocator, _: *Expr) anyerror!?*anyopaque,
        visit_unary_expr: *const fn (_: *anyopaque, _: Allocator, _: *UnaryExpr) anyerror!?*anyopaque,
        visit_binary_expr: *const fn (_: *anyopaque, _: Allocator, _: *BinaryExpr) anyerror!?*anyopaque,
        visit_assign_expr: *const fn (_: *anyopaque, _: Allocator, _: *AssignExpr) anyerror!?*anyopaque,
        visit_property_expr: *const fn (_: *anyopaque, _: Allocator, _: *PropertyExpr) anyerror!?*anyopaque,
        visit_call_expr: *const fn (_: *anyopaque, _: Allocator, _: *CallExpr) anyerror!?*anyopaque,
    };

    pub inline fn visit_program(ctx: *const @This(), allocator: Allocator, node: *const Program) anyerror!?*anyopaque {
        return ctx.vtable.visit_program(ctx.ptr, allocator, @constCast(node));
    }

    pub inline fn visit_decl(ctx: *const @This(), allocator: Allocator, node: *Decl) anyerror!?*anyopaque {
        return ctx.vtable.visit_decl(ctx.ptr, allocator, node);
    }

    pub inline fn visit_stmt(ctx: *const @This(), allocator: Allocator, node: *Stmt) anyerror!?*anyopaque {
        return ctx.vtable.visit_stmt(ctx.ptr, allocator, node);
    }

    pub inline fn visit_expr(ctx: *const @This(), allocator: Allocator, node: *Expr) anyerror!?*anyopaque {
        return ctx.vtable.visit_expr(ctx.ptr, allocator, node);
    }

    pub inline fn visit_obj_decl(ctx: *const @This(), allocator: Allocator, node: *ObjDecl) anyerror!?*anyopaque {
        return ctx.vtable.visit_obj_decl(ctx.ptr, allocator, node);
    }

    pub inline fn visit_fn_decl(ctx: *const @This(), allocator: Allocator, node: *FnDecl) anyerror!?*anyopaque {
        return ctx.vtable.visit_fn_decl(ctx.ptr, allocator, node);
    }

    pub inline fn visit_var_decl(ctx: *const @This(), allocator: Allocator, node: *VarDecl) anyerror!?*anyopaque {
        return ctx.vtable.visit_var_decl(ctx.ptr, allocator, node);
    }

    pub inline fn visit_if_stmt(ctx: *const @This(), allocator: Allocator, node: *IfStmt) anyerror!?*anyopaque {
        return ctx.vtable.visit_if_stmt(ctx.ptr, allocator, node);
    }

    pub inline fn visit_while_stmt(ctx: *const @This(), allocator: Allocator, node: *WhileStmt) anyerror!?*anyopaque {
        return ctx.vtable.visit_while_stmt(ctx.ptr, allocator, node);
    }

    pub inline fn visit_for_stmt(ctx: *const @This(), allocator: Allocator, node: *ForStmt) anyerror!?*anyopaque {
        return ctx.vtable.visit_for_stmt(ctx.ptr, allocator, node);
    }

    pub inline fn visit_unary_expr(ctx: *const @This(), allocator: Allocator, node: *UnaryExpr) anyerror!?*anyopaque {
        return ctx.vtable.visit_unary_expr(ctx.ptr, allocator, node);
    }

    pub inline fn visit_binary_expr(ctx: *const @This(), allocator: Allocator, node: *BinaryExpr) anyerror!?*anyopaque {
        return ctx.vtable.visit_binary_expr(ctx.ptr, allocator, node);
    }

    pub inline fn visit_assign_expr(ctx: *const @This(), allocator: Allocator, node: *AssignExpr) anyerror!?*anyopaque {
        return ctx.vtable.visit_assign_expr(ctx.ptr, allocator, node);
    }

    pub inline fn visit_property_expr(ctx: *const @This(), allocator: Allocator, node: *PropertyExpr) anyerror!?*anyopaque {
        return ctx.vtable.visit_property_expr(ctx.ptr, allocator, node);
    }

    pub inline fn visit_call_expr(ctx: *const @This(), allocator: Allocator, node: *CallExpr) anyerror!?*anyopaque {
        return ctx.vtable.visit_call_expr(ctx.ptr, allocator, node);
    }
};
