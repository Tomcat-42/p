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

allocator: Allocator,
tokens: Tokenizer,
errors: ArrayList(Error) = .empty,

pub fn init(allocator: Allocator, tokens: Tokenizer) @This() {
    return .{
        .allocator = allocator,
        .tokens = tokens,
    };
}

pub fn parse(
    this: *@This(),
) !?Program {
    return .parse(this);
}

pub fn deinit(this: *@This()) void {
    for (this.errors.items) |*err| err.deinit(this.allocator);
    this.errors.deinit(this.allocator);
}

pub fn reset(this: *@This(), allocator: Allocator) void {
    this.tokens.reset();
    this.errors.clearAndFree(allocator);
}

pub fn errs(this: *@This()) ?[]const Error {
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
        visit_program: *const fn (this: *anyopaque, node: *const Program) anyerror!?*anyopaque,
        visit_decl: *const fn (this: *anyopaque, node: *const Decl) anyerror!?*anyopaque,
        visit_obj_decl: *const fn (this: *anyopaque, node: *const ObjDecl) anyerror!?*anyopaque,
        visit_obj_decl_extends: *const fn (this: *anyopaque, node: *const ObjDeclExtends) anyerror!?*anyopaque,
        visit_fn_decl: *const fn (this: *anyopaque, node: *const FnDecl) anyerror!?*anyopaque,
        visit_fn_param: *const fn (this: *anyopaque, node: *const FnParam) anyerror!?*anyopaque,
        visit_var_decl: *const fn (this: *anyopaque, node: *const VarDecl) anyerror!?*anyopaque,
        visit_var_decl_init: *const fn (this: *anyopaque, node: *const VarDeclInit) anyerror!?*anyopaque,

        visit_stmt: *const fn (this: *anyopaque, node: *const Stmt) anyerror!?*anyopaque,
        visit_expr_stmt: *const fn (this: *anyopaque, node: *const ExprStmt) anyerror!?*anyopaque,
        visit_for_stmt: *const fn (this: *anyopaque, node: *const ForStmt) anyerror!?*anyopaque,
        visit_for_init: *const fn (this: *anyopaque, node: *const ForInit) anyerror!?*anyopaque,
        visit_for_cond: *const fn (this: *anyopaque, node: *const ForCond) anyerror!?*anyopaque,
        visit_for_inc: *const fn (this: *anyopaque, node: *const ForInc) anyerror!?*anyopaque,
        visit_if_stmt: *const fn (this: *anyopaque, node: *const IfStmt) anyerror!?*anyopaque,
        visit_if_else_branch: *const fn (this: *anyopaque, node: *const IfElseBranch) anyerror!?*anyopaque,
        visit_print_stmt: *const fn (this: *anyopaque, node: *const PrintStmt) anyerror!?*anyopaque,
        visit_return_stmt: *const fn (this: *anyopaque, node: *const ReturnStmt) anyerror!?*anyopaque,
        visit_while_stmt: *const fn (this: *anyopaque, node: *const WhileStmt) anyerror!?*anyopaque,
        visit_block: *const fn (this: *anyopaque, node: *const Block) anyerror!?*anyopaque,

        visit_assign: *const fn (this: *anyopaque, node: *const Assign) anyerror!?*anyopaque,
        visit_assign_expr: *const fn (this: *anyopaque, node: *const AssignExpr) anyerror!?*anyopaque,
        visit_logic_or: *const fn (this: *anyopaque, node: *const LogicOr) anyerror!?*anyopaque,
        visit_logic_or_expr: *const fn (this: *anyopaque, node: *const LogicOrExpr) anyerror!?*anyopaque,
        visit_logic_and: *const fn (this: *anyopaque, node: *const LogicAnd) anyerror!?*anyopaque,
        visit_logic_and_expr: *const fn (this: *anyopaque, node: *const LogicAndExpr) anyerror!?*anyopaque,
        visit_equality: *const fn (this: *anyopaque, node: *const Equality) anyerror!?*anyopaque,
        visit_equality_expr: *const fn (this: *anyopaque, node: *const EqualityExpr) anyerror!?*anyopaque,
        visit_comparison: *const fn (this: *anyopaque, node: *const Comparison) anyerror!?*anyopaque,
        visit_comparison_expr: *const fn (this: *anyopaque, node: *const ComparisonExpr) anyerror!?*anyopaque,
        visit_term: *const fn (this: *anyopaque, node: *const Term) anyerror!?*anyopaque,
        visit_term_expr: *const fn (this: *anyopaque, node: *const TermExpr) anyerror!?*anyopaque,
        visit_factor: *const fn (this: *anyopaque, node: *const Factor) anyerror!?*anyopaque,
        visit_factor_expr: *const fn (this: *anyopaque, node: *const FactorExpr) anyerror!?*anyopaque,
        visit_unary: *const fn (this: *anyopaque, node: *const Unary) anyerror!?*anyopaque,
        visit_unary_expr: *const fn (this: *anyopaque, node: *const UnaryExpr) anyerror!?*anyopaque,
        visit_call: *const fn (this: *anyopaque, node: *const Call) anyerror!?*anyopaque,
        visit_call_expr: *const fn (this: *anyopaque, node: *const CallExpr) anyerror!?*anyopaque,
        visit_call_fn: *const fn (this: *anyopaque, node: *const CallFn) anyerror!?*anyopaque,
        visit_call_property: *const fn (this: *anyopaque, node: *const CallProperty) anyerror!?*anyopaque,
        visit_fn_arg: *const fn (this: *anyopaque, node: *const FnArg) anyerror!?*anyopaque,
        visit_primary: *const fn (this: *anyopaque, node: *const Primary) anyerror!?*anyopaque,
        visit_group_expr: *const fn (this: *anyopaque, node: *const GroupExpr) anyerror!?*anyopaque,
    };

    pub inline fn visit_program(this: *const @This(), node: *const Program) anyerror!?*anyopaque {
        return this.vtable.visit_program(this.ptr, node);
    }
    pub inline fn visit_decl(this: *const @This(), node: *const Decl) anyerror!?*anyopaque {
        return this.vtable.visit_decl(this.ptr, node);
    }
    pub inline fn visit_obj_decl(this: *const @This(), node: *const ObjDecl) anyerror!?*anyopaque {
        return this.vtable.visit_obj_decl(this.ptr, node);
    }
    pub inline fn visit_obj_decl_extends(this: *const @This(), node: *const ObjDeclExtends) anyerror!?*anyopaque {
        return this.vtable.visit_obj_decl_extends(this.ptr, node);
    }
    pub inline fn visit_fn_decl(this: *const @This(), node: *const FnDecl) anyerror!?*anyopaque {
        return this.vtable.visit_fn_decl(this.ptr, node);
    }
    pub inline fn visit_fn_param(this: *const @This(), node: *const FnParam) anyerror!?*anyopaque {
        return this.vtable.visit_fn_param(this.ptr, node);
    }
    pub inline fn visit_var_decl(this: *const @This(), node: *const VarDecl) anyerror!?*anyopaque {
        return this.vtable.visit_var_decl(this.ptr, node);
    }
    pub inline fn visit_var_decl_init(this: *const @This(), node: *const VarDeclInit) anyerror!?*anyopaque {
        return this.vtable.visit_var_decl_init(this.ptr, node);
    }

    pub inline fn visit_stmt(this: *const @This(), node: *const Stmt) anyerror!?*anyopaque {
        return this.vtable.visit_stmt(this.ptr, node);
    }
    pub inline fn visit_expr_stmt(this: *const @This(), node: *const ExprStmt) anyerror!?*anyopaque {
        return this.vtable.visit_expr_stmt(this.ptr, node);
    }
    pub inline fn visit_for_stmt(this: *const @This(), node: *const ForStmt) anyerror!?*anyopaque {
        return this.vtable.visit_for_stmt(this.ptr, node);
    }
    pub inline fn visit_for_init(this: *const @This(), node: *const ForInit) anyerror!?*anyopaque {
        return this.vtable.visit_for_init(this.ptr, node);
    }
    pub inline fn visit_for_cond(this: *const @This(), node: *const ForCond) anyerror!?*anyopaque {
        return this.vtable.visit_for_cond(this.ptr, node);
    }
    pub inline fn visit_for_inc(this: *const @This(), node: *const ForInc) anyerror!?*anyopaque {
        return this.vtable.visit_for_inc(this.ptr, node);
    }
    pub inline fn visit_if_stmt(this: *const @This(), node: *const IfStmt) anyerror!?*anyopaque {
        return this.vtable.visit_if_stmt(this.ptr, node);
    }
    pub inline fn visit_if_else_branch(this: *const @This(), node: *const IfElseBranch) anyerror!?*anyopaque {
        return this.vtable.visit_if_else_branch(this.ptr, node);
    }
    pub inline fn visit_print_stmt(this: *const @This(), node: *const PrintStmt) anyerror!?*anyopaque {
        return this.vtable.visit_print_stmt(this.ptr, node);
    }
    pub inline fn visit_return_stmt(this: *const @This(), node: *const ReturnStmt) anyerror!?*anyopaque {
        return this.vtable.visit_return_stmt(this.ptr, node);
    }
    pub inline fn visit_while_stmt(this: *const @This(), node: *const WhileStmt) anyerror!?*anyopaque {
        return this.vtable.visit_while_stmt(this.ptr, node);
    }
    pub inline fn visit_block(this: *const @This(), node: *const Block) anyerror!?*anyopaque {
        return this.vtable.visit_block(this.ptr, node);
    }

    pub inline fn visit_assign(this: *const @This(), node: *const Assign) anyerror!?*anyopaque {
        return this.vtable.visit_assign(this.ptr, node);
    }
    pub inline fn visit_assign_expr(this: *const @This(), node: *const AssignExpr) anyerror!?*anyopaque {
        return this.vtable.visit_assign_expr(this.ptr, node);
    }
    pub inline fn visit_logic_or(this: *const @This(), node: *const LogicOr) anyerror!?*anyopaque {
        return this.vtable.visit_logic_or(this.ptr, node);
    }
    pub inline fn visit_logic_or_expr(this: *const @This(), node: *const LogicOrExpr) anyerror!?*anyopaque {
        return this.vtable.visit_logic_or_expr(this.ptr, node);
    }
    pub inline fn visit_logic_and(this: *const @This(), node: *const LogicAnd) anyerror!?*anyopaque {
        return this.vtable.visit_logic_and(this.ptr, node);
    }
    pub inline fn visit_logic_and_expr(this: *const @This(), node: *const LogicAndExpr) anyerror!?*anyopaque {
        return this.vtable.visit_logic_and_expr(this.ptr, node);
    }
    pub inline fn visit_equality(this: *const @This(), node: *const Equality) anyerror!?*anyopaque {
        return this.vtable.visit_equality(this.ptr, node);
    }
    pub inline fn visit_equality_expr(this: *const @This(), node: *const EqualityExpr) anyerror!?*anyopaque {
        return this.vtable.visit_equality_expr(this.ptr, node);
    }
    pub inline fn visit_comparison(this: *const @This(), node: *const Comparison) anyerror!?*anyopaque {
        return this.vtable.visit_comparison(this.ptr, node);
    }
    pub inline fn visit_comparison_expr(this: *const @This(), node: *const ComparisonExpr) anyerror!?*anyopaque {
        return this.vtable.visit_comparison_expr(this.ptr, node);
    }
    pub inline fn visit_term(this: *const @This(), node: *const Term) anyerror!?*anyopaque {
        return this.vtable.visit_term(this.ptr, node);
    }
    pub inline fn visit_term_expr(this: *const @This(), node: *const TermExpr) anyerror!?*anyopaque {
        return this.vtable.visit_term_expr(this.ptr, node);
    }
    pub inline fn visit_factor(this: *const @This(), node: *const Factor) anyerror!?*anyopaque {
        return this.vtable.visit_factor(this.ptr, node);
    }
    pub inline fn visit_factor_expr(this: *const @This(), node: *const FactorExpr) anyerror!?*anyopaque {
        return this.vtable.visit_factor_expr(this.ptr, node);
    }
    pub inline fn visit_unary(this: *const @This(), node: *const Unary) anyerror!?*anyopaque {
        return this.vtable.visit_unary(this.ptr, node);
    }
    pub inline fn visit_unary_expr(this: *const @This(), node: *const UnaryExpr) anyerror!?*anyopaque {
        return this.vtable.visit_unary_expr(this.ptr, node);
    }
    pub inline fn visit_call(this: *const @This(), node: *const Call) anyerror!?*anyopaque {
        return this.vtable.visit_call(this.ptr, node);
    }
    pub inline fn visit_call_expr(this: *const @This(), node: *const CallExpr) anyerror!?*anyopaque {
        return this.vtable.visit_call_expr(this.ptr, node);
    }
    pub inline fn visit_call_fn(this: *const @This(), node: *const CallFn) anyerror!?*anyopaque {
        return this.vtable.visit_call_fn(this.ptr, node);
    }
    pub inline fn visit_call_property(this: *const @This(), node: *const CallProperty) anyerror!?*anyopaque {
        return this.vtable.visit_call_property(this.ptr, node);
    }
    pub inline fn visit_fn_arg(this: *const @This(), node: *const FnArg) anyerror!?*anyopaque {
        return this.vtable.visit_fn_arg(this.ptr, node);
    }
    pub inline fn visit_primary(this: *const @This(), node: *const Primary) anyerror!?*anyopaque {
        return this.vtable.visit_primary(this.ptr, node);
    }
    pub inline fn visit_group_expr(this: *const @This(), node: *const GroupExpr) anyerror!?*anyopaque {
        return this.vtable.visit_group_expr(this.ptr, node);
    }
};
