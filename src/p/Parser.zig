const std = @import("std");
const Io = std.Io;
const assert = std.debug.assert;
const mem = std.mem;
const fmt = std.fmt;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const p = @import("p");
const common = p.common;
pub const Error = common.Error;
const Tokenizer = p.Tokenizer;
const Token = Tokenizer.Token;

pub const Assign = @import("Parser/Assign.zig");
pub const Expr = Assign;
pub const IfCond = Expr;
pub const AssignExpr = @import("Parser/AssignExpr.zig");
pub const Block = @import("Parser/Block.zig");
pub const Call = @import("Parser/Call.zig");
pub const CallExpr = @import("Parser/CallExpr.zig").CallExpr;
pub const CallFn = @import("Parser/CallFn.zig");
pub const CallProperty = @import("Parser/CallProperty.zig");
pub const Comparison = @import("Parser/Comparison.zig");
pub const ComparisonExpr = @import("Parser/ComparisonExpr.zig");
pub const Decl = @import("Parser/Decl.zig").Decl;
pub const Equality = @import("Parser/Equality.zig");
pub const EqualityExpr = @import("Parser/EqualityExpr.zig");
pub const ExprStmt = @import("Parser/ExprStmt.zig");
pub const Factor = @import("Parser/Factor.zig");
pub const FactorExpr = @import("Parser/FactorExpr.zig");
pub const FnArg = @import("Parser/FnArg.zig");
pub const FnDecl = @import("Parser/FnDecl.zig");
pub const FnParam = @import("Parser/FnParam.zig");
pub const ForCond = @import("Parser/ForCond.zig").ForCond;
pub const ForInc = @import("Parser/ForInc.zig").ForInc;
pub const ForInit = @import("Parser/ForInit.zig").ForInit;
pub const ForStmt = @import("Parser/ForStmt.zig");
pub const GroupExpr = @import("Parser/GroupExpr.zig");
pub const IfElseBranch = @import("Parser/IfElseBranch.zig");
pub const IfStmt = @import("Parser/IfStmt.zig");
pub const LogicAnd = @import("Parser/LogicAnd.zig");
pub const LogicAndExpr = @import("Parser/LogicAndExpr.zig");
pub const LogicOr = @import("Parser/LogicOr.zig");
pub const LogicOrExpr = @import("Parser/LogicOrExpr.zig");
pub const ObjDecl = @import("Parser/ObjDecl.zig");
pub const ObjDeclExtends = @import("Parser/ObjDeclExtends.zig");
pub const Primary = @import("Parser/Primary.zig").Primary;
pub const PrintStmt = @import("Parser/PrintStmt.zig");
pub const Program = @import("Parser/Program.zig");
pub const ReturnStmt = @import("Parser/ReturnStmt.zig");
pub const Stmt = @import("Parser/Stmt.zig").Stmt;
pub const IfMainBranch = Stmt;
pub const Term = @import("Parser/Term.zig");
pub const TermExpr = @import("Parser/TermExpr.zig");
pub const Unary = @import("Parser/Unary.zig").Unary;
pub const UnaryExpr = @import("Parser/UnaryExpr.zig");
pub const VarDecl = @import("Parser/VarDecl.zig");
pub const VarDeclInit = @import("Parser/VarDeclInit.zig");
pub const WhileStmt = @import("Parser/WhileStmt.zig");

tokens: Tokenizer = .{},
errors: ArrayList(Error) = .empty,

pub fn init(tokens: Tokenizer) @This() {
    return .{ .tokens = tokens };
}

pub fn parse(
    this: *@This(),
    allocator: Allocator,
) !?Program {
    return .parse(this, allocator);
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    for (this.errors.items) |*err| err.deinit(allocator);
    this.errors.deinit(allocator);
}

pub fn reset(this: *@This(), allocator: Allocator) void {
    this.tokens.reset();
    this.errors.clearAndFree(allocator);
}

pub fn errs(this: *const @This()) ?[]const Error {
    if (this.errors.items.len == 0) return null;
    return this.errors.items;
}

pub inline fn match(
    this: *@This(),
    allocator: Allocator,
    comptime behaviour: @typeInfo(@TypeOf(Tokenizer.match)).@"fn".params[1].type.?,
    comptime expected: anytype,
) !?Token {
    assert(@typeInfo(@TypeOf(expected)) == .@"struct");
    assert(@typeInfo(@TypeOf(expected)).@"struct".fields.len >= 1);

    if (this.tokens.match(behaviour, expected)) |token| return token;

    const token = this.tokens.peek();
    try this.errors.append(allocator, .{
        .message = try fmt.allocPrint(allocator, "Expected {s}, got '{s}'", .{
            comptime tokens: {
                var message: []const u8 = "'" ++ @tagName(expected[0]) ++ "'";
                for (1..@typeInfo(@TypeOf(expected)).@"struct".fields.len) |i| message = message ++ ", '" ++ @tagName(expected[i]) ++ "'";
                break :tokens message;
            },
            if (token) |tok| @tagName(tok.tag) else "EOF",
        }),
        .span = if (token) |tok| .{
            .begin = this.tokens.pos + 1,
            .end = this.tokens.pos + tok.value.len + 1,
        } else .{
            .begin = this.tokens.pos,
            .end = this.tokens.pos,
        },
    });

    return this.tokens.sync(behaviour, expected);
}

pub const Visitor = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        visit_program: *const fn (_: *anyopaque, _: Allocator, _: *const Program) anyerror!?*anyopaque,
        visit_decl: *const fn (_: *anyopaque, _: Allocator, _: *const Decl) anyerror!?*anyopaque,
        visit_obj_decl: *const fn (_: *anyopaque, _: Allocator, _: *const ObjDecl) anyerror!?*anyopaque,
        visit_obj_decl_extends: *const fn (_: *anyopaque, _: Allocator, _: *const ObjDeclExtends) anyerror!?*anyopaque,
        visit_fn_decl: *const fn (_: *anyopaque, _: Allocator, _: *const FnDecl) anyerror!?*anyopaque,
        visit_fn_param: *const fn (_: *anyopaque, _: Allocator, _: *const FnParam) anyerror!?*anyopaque,
        visit_var_decl: *const fn (_: *anyopaque, _: Allocator, _: *const VarDecl) anyerror!?*anyopaque,
        visit_var_decl_init: *const fn (_: *anyopaque, _: Allocator, _: *const VarDeclInit) anyerror!?*anyopaque,

        visit_stmt: *const fn (_: *anyopaque, _: Allocator, _: *const Stmt) anyerror!?*anyopaque,
        visit_expr_stmt: *const fn (_: *anyopaque, _: Allocator, _: *const ExprStmt) anyerror!?*anyopaque,
        visit_for_stmt: *const fn (_: *anyopaque, _: Allocator, _: *const ForStmt) anyerror!?*anyopaque,
        visit_for_init: *const fn (_: *anyopaque, _: Allocator, _: *const ForInit) anyerror!?*anyopaque,
        visit_for_cond: *const fn (_: *anyopaque, _: Allocator, _: *const ForCond) anyerror!?*anyopaque,
        visit_for_inc: *const fn (_: *anyopaque, _: Allocator, _: *const ForInc) anyerror!?*anyopaque,
        visit_if_stmt: *const fn (_: *anyopaque, _: Allocator, _: *const IfStmt) anyerror!?*anyopaque,
        visit_if_else_branch: *const fn (_: *anyopaque, _: Allocator, _: *const IfElseBranch) anyerror!?*anyopaque,
        visit_print_stmt: *const fn (_: *anyopaque, _: Allocator, _: *const PrintStmt) anyerror!?*anyopaque,
        visit_return_stmt: *const fn (_: *anyopaque, _: Allocator, _: *const ReturnStmt) anyerror!?*anyopaque,
        visit_while_stmt: *const fn (_: *anyopaque, _: Allocator, _: *const WhileStmt) anyerror!?*anyopaque,
        visit_block: *const fn (_: *anyopaque, _: Allocator, _: *const Block) anyerror!?*anyopaque,

        visit_assign: *const fn (_: *anyopaque, _: Allocator, _: *const Assign) anyerror!?*anyopaque,
        visit_assign_expr: *const fn (_: *anyopaque, _: Allocator, _: *const AssignExpr) anyerror!?*anyopaque,
        visit_logic_or: *const fn (_: *anyopaque, _: Allocator, _: *const LogicOr) anyerror!?*anyopaque,
        visit_logic_or_expr: *const fn (_: *anyopaque, _: Allocator, _: *const LogicOrExpr) anyerror!?*anyopaque,
        visit_logic_and: *const fn (_: *anyopaque, _: Allocator, _: *const LogicAnd) anyerror!?*anyopaque,
        visit_logic_and_expr: *const fn (_: *anyopaque, _: Allocator, _: *const LogicAndExpr) anyerror!?*anyopaque,
        visit_equality: *const fn (_: *anyopaque, _: Allocator, _: *const Equality) anyerror!?*anyopaque,
        visit_equality_expr: *const fn (_: *anyopaque, _: Allocator, _: *const EqualityExpr) anyerror!?*anyopaque,
        visit_comparison: *const fn (_: *anyopaque, _: Allocator, _: *const Comparison) anyerror!?*anyopaque,
        visit_comparison_expr: *const fn (_: *anyopaque, _: Allocator, _: *const ComparisonExpr) anyerror!?*anyopaque,
        visit_term: *const fn (_: *anyopaque, _: Allocator, _: *const Term) anyerror!?*anyopaque,
        visit_term_expr: *const fn (_: *anyopaque, _: Allocator, _: *const TermExpr) anyerror!?*anyopaque,
        visit_factor: *const fn (_: *anyopaque, _: Allocator, _: *const Factor) anyerror!?*anyopaque,
        visit_factor_expr: *const fn (_: *anyopaque, _: Allocator, _: *const FactorExpr) anyerror!?*anyopaque,
        visit_unary: *const fn (_: *anyopaque, _: Allocator, _: *const Unary) anyerror!?*anyopaque,
        visit_unary_expr: *const fn (_: *anyopaque, _: Allocator, _: *const UnaryExpr) anyerror!?*anyopaque,
        visit_call: *const fn (_: *anyopaque, _: Allocator, _: *const Call) anyerror!?*anyopaque,
        visit_call_expr: *const fn (_: *anyopaque, _: Allocator, _: *const CallExpr) anyerror!?*anyopaque,
        visit_call_fn: *const fn (_: *anyopaque, _: Allocator, _: *const CallFn) anyerror!?*anyopaque,
        visit_call_property: *const fn (_: *anyopaque, _: Allocator, _: *const CallProperty) anyerror!?*anyopaque,
        visit_fn_arg: *const fn (_: *anyopaque, _: Allocator, _: *const FnArg) anyerror!?*anyopaque,
        visit_primary: *const fn (_: *anyopaque, _: Allocator, _: *const Primary) anyerror!?*anyopaque,
        visit_group_expr: *const fn (_: *anyopaque, _: Allocator, _: *const GroupExpr) anyerror!?*anyopaque,
    };

    pub inline fn visit_program(ctx: *const @This(), allocator: Allocator, node: *const Program) anyerror!?*anyopaque {
        return ctx.vtable.visit_program(ctx.ptr, allocator, node);
    }
    pub inline fn visit_decl(ctx: *const @This(), allocator: Allocator, node: *const Decl) anyerror!?*anyopaque {
        return ctx.vtable.visit_decl(ctx.ptr, allocator, node);
    }
    pub inline fn visit_obj_decl(ctx: *const @This(), allocator: Allocator, node: *const ObjDecl) anyerror!?*anyopaque {
        return ctx.vtable.visit_obj_decl(ctx.ptr, allocator, node);
    }
    pub inline fn visit_obj_decl_extends(ctx: *const @This(), allocator: Allocator, node: *const ObjDeclExtends) anyerror!?*anyopaque {
        return ctx.vtable.visit_obj_decl_extends(ctx.ptr, allocator, node);
    }
    pub inline fn visit_fn_decl(ctx: *const @This(), allocator: Allocator, node: *const FnDecl) anyerror!?*anyopaque {
        return ctx.vtable.visit_fn_decl(ctx.ptr, allocator, node);
    }
    pub inline fn visit_fn_param(ctx: *const @This(), allocator: Allocator, node: *const FnParam) anyerror!?*anyopaque {
        return ctx.vtable.visit_fn_param(ctx.ptr, allocator, node);
    }
    pub inline fn visit_var_decl(ctx: *const @This(), allocator: Allocator, node: *const VarDecl) anyerror!?*anyopaque {
        return ctx.vtable.visit_var_decl(ctx.ptr, allocator, node);
    }
    pub inline fn visit_var_decl_init(ctx: *const @This(), allocator: Allocator, node: *const VarDeclInit) anyerror!?*anyopaque {
        return ctx.vtable.visit_var_decl_init(ctx.ptr, allocator, node);
    }

    pub inline fn visit_stmt(ctx: *const @This(), allocator: Allocator, node: *const Stmt) anyerror!?*anyopaque {
        return ctx.vtable.visit_stmt(ctx.ptr, allocator, node);
    }
    pub inline fn visit_expr_stmt(ctx: *const @This(), allocator: Allocator, node: *const ExprStmt) anyerror!?*anyopaque {
        return ctx.vtable.visit_expr_stmt(ctx.ptr, allocator, node);
    }
    pub inline fn visit_for_stmt(ctx: *const @This(), allocator: Allocator, node: *const ForStmt) anyerror!?*anyopaque {
        return ctx.vtable.visit_for_stmt(ctx.ptr, allocator, node);
    }
    pub inline fn visit_for_init(ctx: *const @This(), allocator: Allocator, node: *const ForInit) anyerror!?*anyopaque {
        return ctx.vtable.visit_for_init(ctx.ptr, allocator, node);
    }
    pub inline fn visit_for_cond(ctx: *const @This(), allocator: Allocator, node: *const ForCond) anyerror!?*anyopaque {
        return ctx.vtable.visit_for_cond(ctx.ptr, allocator, node);
    }
    pub inline fn visit_for_inc(ctx: *const @This(), allocator: Allocator, node: *const ForInc) anyerror!?*anyopaque {
        return ctx.vtable.visit_for_inc(ctx.ptr, allocator, node);
    }
    pub inline fn visit_if_stmt(ctx: *const @This(), allocator: Allocator, node: *const IfStmt) anyerror!?*anyopaque {
        return ctx.vtable.visit_if_stmt(ctx.ptr, allocator, node);
    }
    pub inline fn visit_if_else_branch(ctx: *const @This(), allocator: Allocator, node: *const IfElseBranch) anyerror!?*anyopaque {
        return ctx.vtable.visit_if_else_branch(ctx.ptr, allocator, node);
    }
    pub inline fn visit_print_stmt(ctx: *const @This(), allocator: Allocator, node: *const PrintStmt) anyerror!?*anyopaque {
        return ctx.vtable.visit_print_stmt(ctx.ptr, allocator, node);
    }
    pub inline fn visit_return_stmt(ctx: *const @This(), allocator: Allocator, node: *const ReturnStmt) anyerror!?*anyopaque {
        return ctx.vtable.visit_return_stmt(ctx.ptr, allocator, node);
    }
    pub inline fn visit_while_stmt(ctx: *const @This(), allocator: Allocator, node: *const WhileStmt) anyerror!?*anyopaque {
        return ctx.vtable.visit_while_stmt(ctx.ptr, allocator, node);
    }
    pub inline fn visit_block(ctx: *const @This(), allocator: Allocator, node: *const Block) anyerror!?*anyopaque {
        return ctx.vtable.visit_block(ctx.ptr, allocator, node);
    }

    pub inline fn visit_assign(ctx: *const @This(), allocator: Allocator, node: *const Assign) anyerror!?*anyopaque {
        return ctx.vtable.visit_assign(ctx.ptr, allocator, node);
    }
    pub inline fn visit_assign_expr(ctx: *const @This(), allocator: Allocator, node: *const AssignExpr) anyerror!?*anyopaque {
        return ctx.vtable.visit_assign_expr(ctx.ptr, allocator, node);
    }
    pub inline fn visit_logic_or(ctx: *const @This(), allocator: Allocator, node: *const LogicOr) anyerror!?*anyopaque {
        return ctx.vtable.visit_logic_or(ctx.ptr, allocator, node);
    }
    pub inline fn visit_logic_or_expr(ctx: *const @This(), allocator: Allocator, node: *const LogicOrExpr) anyerror!?*anyopaque {
        return ctx.vtable.visit_logic_or_expr(ctx.ptr, allocator, node);
    }
    pub inline fn visit_logic_and(ctx: *const @This(), allocator: Allocator, node: *const LogicAnd) anyerror!?*anyopaque {
        return ctx.vtable.visit_logic_and(ctx.ptr, allocator, node);
    }
    pub inline fn visit_logic_and_expr(ctx: *const @This(), allocator: Allocator, node: *const LogicAndExpr) anyerror!?*anyopaque {
        return ctx.vtable.visit_logic_and_expr(ctx.ptr, allocator, node);
    }
    pub inline fn visit_equality(ctx: *const @This(), allocator: Allocator, node: *const Equality) anyerror!?*anyopaque {
        return ctx.vtable.visit_equality(ctx.ptr, allocator, node);
    }
    pub inline fn visit_equality_expr(ctx: *const @This(), allocator: Allocator, node: *const EqualityExpr) anyerror!?*anyopaque {
        return ctx.vtable.visit_equality_expr(ctx.ptr, allocator, node);
    }
    pub inline fn visit_comparison(ctx: *const @This(), allocator: Allocator, node: *const Comparison) anyerror!?*anyopaque {
        return ctx.vtable.visit_comparison(ctx.ptr, allocator, node);
    }
    pub inline fn visit_comparison_expr(ctx: *const @This(), allocator: Allocator, node: *const ComparisonExpr) anyerror!?*anyopaque {
        return ctx.vtable.visit_comparison_expr(ctx.ptr, allocator, node);
    }
    pub inline fn visit_term(ctx: *const @This(), allocator: Allocator, node: *const Term) anyerror!?*anyopaque {
        return ctx.vtable.visit_term(ctx.ptr, allocator, node);
    }
    pub inline fn visit_term_expr(ctx: *const @This(), allocator: Allocator, node: *const TermExpr) anyerror!?*anyopaque {
        return ctx.vtable.visit_term_expr(ctx.ptr, allocator, node);
    }
    pub inline fn visit_factor(ctx: *const @This(), allocator: Allocator, node: *const Factor) anyerror!?*anyopaque {
        return ctx.vtable.visit_factor(ctx.ptr, allocator, node);
    }
    pub inline fn visit_factor_expr(ctx: *const @This(), allocator: Allocator, node: *const FactorExpr) anyerror!?*anyopaque {
        return ctx.vtable.visit_factor_expr(ctx.ptr, allocator, node);
    }
    pub inline fn visit_unary(ctx: *const @This(), allocator: Allocator, node: *const Unary) anyerror!?*anyopaque {
        return ctx.vtable.visit_unary(ctx.ptr, allocator, node);
    }
    pub inline fn visit_unary_expr(ctx: *const @This(), allocator: Allocator, node: *const UnaryExpr) anyerror!?*anyopaque {
        return ctx.vtable.visit_unary_expr(ctx.ptr, allocator, node);
    }
    pub inline fn visit_call(ctx: *const @This(), allocator: Allocator, node: *const Call) anyerror!?*anyopaque {
        return ctx.vtable.visit_call(ctx.ptr, allocator, node);
    }
    pub inline fn visit_call_expr(ctx: *const @This(), allocator: Allocator, node: *const CallExpr) anyerror!?*anyopaque {
        return ctx.vtable.visit_call_expr(ctx.ptr, allocator, node);
    }
    pub inline fn visit_call_fn(ctx: *const @This(), allocator: Allocator, node: *const CallFn) anyerror!?*anyopaque {
        return ctx.vtable.visit_call_fn(ctx.ptr, allocator, node);
    }
    pub inline fn visit_call_property(ctx: *const @This(), allocator: Allocator, node: *const CallProperty) anyerror!?*anyopaque {
        return ctx.vtable.visit_call_property(ctx.ptr, allocator, node);
    }
    pub inline fn visit_fn_arg(ctx: *const @This(), allocator: Allocator, node: *const FnArg) anyerror!?*anyopaque {
        return ctx.vtable.visit_fn_arg(ctx.ptr, allocator, node);
    }
    pub inline fn visit_primary(ctx: *const @This(), allocator: Allocator, node: *const Primary) anyerror!?*anyopaque {
        return ctx.vtable.visit_primary(ctx.ptr, allocator, node);
    }
    pub inline fn visit_group_expr(ctx: *const @This(), allocator: Allocator, node: *const GroupExpr) anyerror!?*anyopaque {
        return ctx.vtable.visit_group_expr(ctx.ptr, allocator, node);
    }
};
