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

pub const Type = union(enum) { any, nil, bool, number, string, object, function };

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
        for (this.body.decls) |*decl| decl.deinit(allocator);
        allocator.free(this.body.decls);
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
        for (this.body.decls) |*decl| decl.deinit(allocator);
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

    pub fn visit(this: *@This(), allocator: Allocator, visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_if_stmt)).@"fn".return_type.? {
        return visitor.visit_if_stmt(allocator, this);
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
        visit_program: *const fn (this: *anyopaque, allocator: Allocator, node: *Program) anyerror!?*anyopaque,

        visit_decl: *const fn (this: *anyopaque, allocator: Allocator, node: *Decl) anyerror!?*anyopaque,
        visit_obj_decl: *const fn (this: *anyopaque, allocator: Allocator, node: *ObjDecl) anyerror!?*anyopaque,
        visit_fn_decl: *const fn (this: *anyopaque, allocator: Allocator, node: *FnDecl) anyerror!?*anyopaque,
        visit_var_decl: *const fn (this: *anyopaque, allocator: Allocator, node: *VarDecl) anyerror!?*anyopaque,

        visit_stmt: *const fn (this: *anyopaque, allocator: Allocator, node: *Stmt) anyerror!?*anyopaque,
        visit_if_stmt: *const fn (this: *anyopaque, allocator: Allocator, node: *IfStmt) anyerror!?*anyopaque,
        visit_while_stmt: *const fn (this: *anyopaque, allocator: Allocator, node: *WhileStmt) anyerror!?*anyopaque,
        visit_for_stmt: *const fn (this: *anyopaque, allocator: Allocator, node: *ForStmt) anyerror!?*anyopaque,

        visit_expr: *const fn (this: *anyopaque, allocator: Allocator, node: *Expr) anyerror!?*anyopaque,
        visit_unary_expr: *const fn (this: *anyopaque, allocator: Allocator, node: *UnaryExpr) anyerror!?*anyopaque,
        visit_binary_expr: *const fn (this: *anyopaque, allocator: Allocator, node: *BinaryExpr) anyerror!?*anyopaque,
        visit_assign_expr: *const fn (this: *anyopaque, allocator: Allocator, node: *AssignExpr) anyerror!?*anyopaque,
        visit_property_expr: *const fn (this: *anyopaque, allocator: Allocator, node: *PropertyExpr) anyerror!?*anyopaque,
        visit_call_expr: *const fn (this: *anyopaque, allocator: Allocator, node: *CallExpr) anyerror!?*anyopaque,
    };

    pub inline fn visit_program(this: *const @This(), allocator: Allocator, node: *const Program) anyerror!?*anyopaque {
        return this.vtable.visit_program(this.ptr, allocator, @constCast(node));
    }

    pub inline fn visit_decl(this: *const @This(), allocator: Allocator, node: *Decl) anyerror!?*anyopaque {
        return this.vtable.visit_decl(this.ptr, allocator, node);
    }

    pub inline fn visit_stmt(this: *const @This(), allocator: Allocator, node: *Stmt) anyerror!?*anyopaque {
        return this.vtable.visit_stmt(this.ptr, allocator, node);
    }

    pub inline fn visit_expr(this: *const @This(), allocator: Allocator, node: *Expr) anyerror!?*anyopaque {
        return this.vtable.visit_expr(this.ptr, allocator, node);
    }

    pub inline fn visit_obj_decl(this: *const @This(), allocator: Allocator, node: *ObjDecl) anyerror!?*anyopaque {
        return this.vtable.visit_obj_decl(this.ptr, allocator, node);
    }

    pub inline fn visit_fn_decl(this: *const @This(), allocator: Allocator, node: *FnDecl) anyerror!?*anyopaque {
        return this.vtable.visit_fn_decl(this.ptr, allocator, node);
    }

    pub inline fn visit_var_decl(this: *const @This(), allocator: Allocator, node: *VarDecl) anyerror!?*anyopaque {
        return this.vtable.visit_var_decl(this.ptr, allocator, node);
    }

    pub inline fn visit_if_stmt(this: *const @This(), allocator: Allocator, node: *IfStmt) anyerror!?*anyopaque {
        return this.vtable.visit_if_stmt(this.ptr, allocator, node);
    }

    pub inline fn visit_while_stmt(this: *const @This(), allocator: Allocator, node: *WhileStmt) anyerror!?*anyopaque {
        return this.vtable.visit_while_stmt(this.ptr, allocator, node);
    }

    pub inline fn visit_for_stmt(this: *const @This(), allocator: Allocator, node: *ForStmt) anyerror!?*anyopaque {
        return this.vtable.visit_for_stmt(this.ptr, allocator, node);
    }

    pub inline fn visit_unary_expr(this: *const @This(), allocator: Allocator, node: *UnaryExpr) anyerror!?*anyopaque {
        return this.vtable.visit_unary_expr(this.ptr, allocator, node);
    }

    pub inline fn visit_binary_expr(this: *const @This(), allocator: Allocator, node: *BinaryExpr) anyerror!?*anyopaque {
        return this.vtable.visit_binary_expr(this.ptr, allocator, node);
    }

    pub inline fn visit_assign_expr(this: *const @This(), allocator: Allocator, node: *AssignExpr) anyerror!?*anyopaque {
        return this.vtable.visit_assign_expr(this.ptr, allocator, node);
    }

    pub inline fn visit_property_expr(this: *const @This(), allocator: Allocator, node: *PropertyExpr) anyerror!?*anyopaque {
        return this.vtable.visit_property_expr(this.ptr, allocator, node);
    }

    pub inline fn visit_call_expr(this: *const @This(), allocator: Allocator, node: *CallExpr) anyerror!?*anyopaque {
        return this.vtable.visit_call_expr(this.ptr, allocator, node);
    }
};
