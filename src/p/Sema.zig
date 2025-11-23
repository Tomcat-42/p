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

allocator: Allocator,
errors: ArrayList(Error) = .empty,

pub fn init(allocator: Allocator) @This() {
    return .{ .allocator = allocator };
}

pub fn analyze(this: *@This(), cst: Parser.Program) !?Program {
    var ast_builder: AstBuilder = .init(this);
    const ast: *Program = @ptrCast(@alignCast(try cst.visit(ast_builder.visitor())));

    var ty: TypeChecker = .init(this);
    defer ty.deinit(this.allocator);

    _ = try ast.visit(ty.visitor()) orelse return null;

    return try move(Program, this.allocator, ast);
}

pub fn deinit(this: *@This()) void {
    this.errors.deinit(this.allocator);
}

pub fn errs(this: *@This()) ?[]const Error {
    if (this.errors.items.len == 0) return null;
    return this.errors.items;
}

pub const Value = union(enum) {
    any,
    nil,
    bool: bool,
    number: f64,
    string: []const u8,
    object: Object,
    function: Function,
};

pub const Object = struct {};

pub const Function = struct {};

pub const Scope = struct {
    parent: ?*@This() = null,
    bindings: StringHashMapUnmanaged(Value) = .empty,

    pub fn lookup(this: *@This(), name: []const u8) ?Value {
        var current: ?*@This() = this;
        return while (current) |scope| : (current = scope.parent) {
            if (scope.bindings.get(name)) |value|
                return value;
        } else null;
    }

    pub fn bind(this: *@This(), name: []const u8, value: Value) !?void {
        const result = try this.bindings.getOrPut(name);
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

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_program)).@"fn".return_type.? {
        return visitor.visit_program(this);
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

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_decl)).@"fn".return_type.? {
        return visitor.visit_decl(this);
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

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_obj_decl)).@"fn".return_type.? {
        return visitor.visit_obj_decl(this);
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

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_fn_decl)).@"fn".return_type.? {
        return visitor.visit_fn_decl(this);
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

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_var_decl)).@"fn".return_type.? {
        return visitor.visit_var_decl(this);
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

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_stmt)).@"fn".return_type.? {
        return visitor.visit_stmt(this);
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

    pub fn visit(this: *const @This(), visitor: *Visitor) @typeInfo(@TypeOf(Visitor.visit_if_stmt)).@"fn".return_type.? {
        return visitor.visit_if_stmt(this);
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

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_while_stmt)).@"fn".return_type.? {
        return visitor.visit_while_stmt(this);
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

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_for_stmt)).@"fn".return_type.? {
        return visitor.visit_for_stmt(this);
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

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_expr)).@"fn".return_type.? {
        return visitor.visit_expr(this);
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

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_unary_expr)).@"fn".return_type.? {
        return visitor.visit_unary_expr(this);
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

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_binary_expr)).@"fn".return_type.? {
        return visitor.visit_binary_expr(this);
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

    pub fn visit(this: *@This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_assign_expr)).@"fn".return_type.? {
        return visitor.visit_assign_expr(this);
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

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_property_expr)).@"fn".return_type.? {
        return visitor.visit_property_expr(this);
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

    pub fn visit(this: *const @This(), visitor: Visitor) @typeInfo(@TypeOf(Visitor.visit_call_expr)).@"fn".return_type.? {
        return visitor.visit_call_expr(this);
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
        visit_program: *const fn (this: *anyopaque, node: *const Program) anyerror!?*anyopaque,

        visit_decl: *const fn (this: *anyopaque, node: *const Decl) anyerror!?*anyopaque,
        visit_obj_decl: *const fn (this: *anyopaque, node: *const ObjDecl) anyerror!?*anyopaque,
        visit_fn_decl: *const fn (this: *anyopaque, node: *const FnDecl) anyerror!?*anyopaque,
        visit_var_decl: *const fn (this: *anyopaque, node: *const VarDecl) anyerror!?*anyopaque,

        visit_stmt: *const fn (this: *anyopaque, node: *const Stmt) anyerror!?*anyopaque,
        visit_if_stmt: *const fn (this: *anyopaque, node: *const IfStmt) anyerror!?*anyopaque,
        visit_while_stmt: *const fn (this: *anyopaque, node: *const WhileStmt) anyerror!?*anyopaque,
        visit_for_stmt: *const fn (this: *anyopaque, node: *const ForStmt) anyerror!?*anyopaque,

        visit_expr: *const fn (this: *anyopaque, node: *const Expr) anyerror!?*anyopaque,
        visit_unary_expr: *const fn (this: *anyopaque, node: *const UnaryExpr) anyerror!?*anyopaque,
        visit_binary_expr: *const fn (this: *anyopaque, node: *const BinaryExpr) anyerror!?*anyopaque,
        visit_assign_expr: *const fn (this: *anyopaque, node: *const AssignExpr) anyerror!?*anyopaque,
        visit_property_expr: *const fn (this: *anyopaque, node: *const PropertyExpr) anyerror!?*anyopaque,
        visit_call_expr: *const fn (this: *anyopaque, node: *const CallExpr) anyerror!?*anyopaque,
    };

    pub inline fn visit_program(this: *const @This(), node: *const Program) anyerror!?*anyopaque {
        return this.vtable.visit_program(this.ptr, node);
    }

    pub inline fn visit_decl(this: *const @This(), node: *const Decl) anyerror!?*anyopaque {
        return this.vtable.visit_decl(this.ptr, node);
    }

    pub inline fn visit_stmt(this: *const @This(), node: *const Stmt) anyerror!?*anyopaque {
        return this.vtable.visit_stmt(this.ptr, node);
    }

    pub inline fn visit_expr(this: *const @This(), node: *const Expr) anyerror!?*anyopaque {
        return this.vtable.visit_expr(this.ptr, node);
    }

    pub inline fn visit_obj_decl(this: *const @This(), node: *const ObjDecl) anyerror!?*anyopaque {
        return this.vtable.visit_obj_decl(this.ptr, node);
    }

    pub inline fn visit_fn_decl(this: *const @This(), node: *const FnDecl) anyerror!?*anyopaque {
        return this.vtable.visit_fn_decl(this.ptr, node);
    }

    pub inline fn visit_var_decl(this: *const @This(), node: *const VarDecl) anyerror!?*anyopaque {
        return this.vtable.visit_var_decl(this.ptr, node);
    }

    pub inline fn visit_if_stmt(this: *const @This(), node: *const IfStmt) anyerror!?*anyopaque {
        return this.vtable.visit_if_stmt(this.ptr, node);
    }

    pub inline fn visit_while_stmt(this: *const @This(), node: *const WhileStmt) anyerror!?*anyopaque {
        return this.vtable.visit_while_stmt(this.ptr, node);
    }

    pub inline fn visit_for_stmt(this: *const @This(), node: *const ForStmt) anyerror!?*anyopaque {
        return this.vtable.visit_for_stmt(this.ptr, node);
    }

    pub inline fn visit_unary_expr(this: *const @This(), node: *const UnaryExpr) anyerror!?*anyopaque {
        return this.vtable.visit_unary_expr(this.ptr, node);
    }

    pub inline fn visit_binary_expr(this: *const @This(), node: *const BinaryExpr) anyerror!?*anyopaque {
        return this.vtable.visit_binary_expr(this.ptr, node);
    }

    pub inline fn visit_assign_expr(this: *const @This(), node: *const AssignExpr) anyerror!?*anyopaque {
        return this.vtable.visit_assign_expr(this.ptr, node);
    }

    pub inline fn visit_property_expr(this: *const @This(), node: *const PropertyExpr) anyerror!?*anyopaque {
        return this.vtable.visit_property_expr(this.ptr, node);
    }

    pub inline fn visit_call_expr(this: *const @This(), node: *const CallExpr) anyerror!?*anyopaque {
        return this.vtable.visit_call_expr(this.ptr, node);
    }
};
