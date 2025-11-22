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
    vtable: VTable,

    pub const VTable = struct {
        visitProgram: *const fn (this: *anyopaque, node: *const Program) anyerror!?*anyopaque,
        visitDecl: *const fn (this: *anyopaque, node: *const Decl) anyerror!?*anyopaque,
        visitObjDecl: *const fn (this: *anyopaque, node: *const ObjDecl) anyerror!?*anyopaque,
        visitObjDeclExtends: *const fn (this: *anyopaque, node: *const ObjDeclExtends) anyerror!?*anyopaque,
        visitFnDecl: *const fn (this: *anyopaque, node: *const FnDecl) anyerror!?*anyopaque,
        visitFnParam: *const fn (this: *anyopaque, node: *const FnParam) anyerror!?*anyopaque,
        visitVarDecl: *const fn (this: *anyopaque, node: *const VarDecl) anyerror!?*anyopaque,
        visitVarDeclInit: *const fn (this: *anyopaque, node: *const VarDeclInit) anyerror!?*anyopaque,

        visitStmt: *const fn (this: *anyopaque, node: *const Stmt) anyerror!?*anyopaque,
        visitExprStmt: *const fn (this: *anyopaque, node: *const ExprStmt) anyerror!?*anyopaque,
        visitForStmt: *const fn (this: *anyopaque, node: *const ForStmt) anyerror!?*anyopaque,
        visitForInit: *const fn (this: *anyopaque, node: *const ForInit) anyerror!?*anyopaque,
        visitForCond: *const fn (this: *anyopaque, node: *const ForCond) anyerror!?*anyopaque,
        visitForInc: *const fn (this: *anyopaque, node: *const ForInc) anyerror!?*anyopaque,
        visitIfStmt: *const fn (this: *anyopaque, node: *const IfStmt) anyerror!?*anyopaque,
        visitIfElseBranch: *const fn (this: *anyopaque, node: *const IfElseBranch) anyerror!?*anyopaque,
        visitPrintStmt: *const fn (this: *anyopaque, node: *const PrintStmt) anyerror!?*anyopaque,
        visitReturnStmt: *const fn (this: *anyopaque, node: *const ReturnStmt) anyerror!?*anyopaque,
        visitWhileStmt: *const fn (this: *anyopaque, node: *const WhileStmt) anyerror!?*anyopaque,
        visitBlock: *const fn (this: *anyopaque, node: *const Block) anyerror!?*anyopaque,

        visitAssign: *const fn (this: *anyopaque, node: *const Assign) anyerror!?*anyopaque,
        visitAssignExpr: *const fn (this: *anyopaque, node: *const AssignExpr) anyerror!?*anyopaque,
        visitLogicOr: *const fn (this: *anyopaque, node: *const LogicOr) anyerror!?*anyopaque,
        visitLogicOrExpr: *const fn (this: *anyopaque, node: *const LogicOrExpr) anyerror!?*anyopaque,
        visitLogicAnd: *const fn (this: *anyopaque, node: *const LogicAnd) anyerror!?*anyopaque,
        visitLogicAndExpr: *const fn (this: *anyopaque, node: *const LogicAndExpr) anyerror!?*anyopaque,
        visitEquality: *const fn (this: *anyopaque, node: *const Equality) anyerror!?*anyopaque,
        visitEqualityExpr: *const fn (this: *anyopaque, node: *const EqualityExpr) anyerror!?*anyopaque,
        visitComparison: *const fn (this: *anyopaque, node: *const Comparison) anyerror!?*anyopaque,
        visitComparisonExpr: *const fn (this: *anyopaque, node: *const ComparisonExpr) anyerror!?*anyopaque,
        visitTerm: *const fn (this: *anyopaque, node: *const Term) anyerror!?*anyopaque,
        visitTermExpr: *const fn (this: *anyopaque, node: *const TermExpr) anyerror!?*anyopaque,
        visitFactor: *const fn (this: *anyopaque, node: *const Factor) anyerror!?*anyopaque,
        visitFactorExpr: *const fn (this: *anyopaque, node: *const FactorExpr) anyerror!?*anyopaque,
        visitUnary: *const fn (this: *anyopaque, node: *const Unary) anyerror!?*anyopaque,
        visitUnaryExpr: *const fn (this: *anyopaque, node: *const UnaryExpr) anyerror!?*anyopaque,
        visitCall: *const fn (this: *anyopaque, node: *const Call) anyerror!?*anyopaque,
        visitCallExpr: *const fn (this: *anyopaque, node: *const CallExpr) anyerror!?*anyopaque,
        visitCallFn: *const fn (this: *anyopaque, node: *const CallFn) anyerror!?*anyopaque,
        visitCallProperty: *const fn (this: *anyopaque, node: *const CallProperty) anyerror!?*anyopaque,
        visitFnArg: *const fn (this: *anyopaque, node: *const FnArg) anyerror!?*anyopaque,
        visitPrimary: *const fn (this: *anyopaque, node: *const Primary) anyerror!?*anyopaque,
        visitGroupExpr: *const fn (this: *anyopaque, node: *const GroupExpr) anyerror!?*anyopaque,
    };

    pub fn visitProgram(this: *const @This(), node: *const Program) anyerror!?*anyopaque {
        return this.vtable.visitProgram(this.ptr, node);
    }
    pub fn visitDecl(this: *const @This(), node: *const Decl) anyerror!?*anyopaque {
        return this.vtable.visitDecl(this.ptr, node);
    }
    pub fn visitObjDecl(this: *const @This(), node: *const ObjDecl) anyerror!?*anyopaque {
        return this.vtable.visitObjDecl(this.ptr, node);
    }
    pub fn visitObjDeclExtends(this: *const @This(), node: *const ObjDeclExtends) anyerror!?*anyopaque {
        return this.vtable.visitObjDeclExtends(this.ptr, node);
    }
    pub fn visitFnDecl(this: *const @This(), node: *const FnDecl) anyerror!?*anyopaque {
        return this.vtable.visitFnDecl(this.ptr, node);
    }
    pub fn visitFnParam(this: *const @This(), node: *const FnParam) anyerror!?*anyopaque {
        return this.vtable.visitFnParam(this.ptr, node);
    }
    pub fn visitVarDecl(this: *const @This(), node: *const VarDecl) anyerror!?*anyopaque {
        return this.vtable.visitVarDecl(this.ptr, node);
    }
    pub fn visitVarDeclInit(this: *const @This(), node: *const VarDeclInit) anyerror!?*anyopaque {
        return this.vtable.visitVarDeclInit(this.ptr, node);
    }

    pub fn visitStmt(this: *const @This(), node: *const Stmt) anyerror!?*anyopaque {
        return this.vtable.visitStmt(this.ptr, node);
    }
    pub fn visitExprStmt(this: *const @This(), node: *const ExprStmt) anyerror!?*anyopaque {
        return this.vtable.visitExprStmt(this.ptr, node);
    }
    pub fn visitForStmt(this: *const @This(), node: *const ForStmt) anyerror!?*anyopaque {
        return this.vtable.visitForStmt(this.ptr, node);
    }
    pub fn visitForInit(this: *const @This(), node: *const ForInit) anyerror!?*anyopaque {
        return this.vtable.visitForInit(this.ptr, node);
    }
    pub fn visitForCond(this: *const @This(), node: *const ForCond) anyerror!?*anyopaque {
        return this.vtable.visitForCond(this.ptr, node);
    }
    pub fn visitForInc(this: *const @This(), node: *const ForInc) anyerror!?*anyopaque {
        return this.vtable.visitForInc(this.ptr, node);
    }
    pub fn visitIfStmt(this: *const @This(), node: *const IfStmt) anyerror!?*anyopaque {
        return this.vtable.visitIfStmt(this.ptr, node);
    }
    pub fn visitIfElseBranch(this: *const @This(), node: *const IfElseBranch) anyerror!?*anyopaque {
        return this.vtable.visitIfElseBranch(this.ptr, node);
    }
    pub fn visitPrintStmt(this: *const @This(), node: *const PrintStmt) anyerror!?*anyopaque {
        return this.vtable.visitPrintStmt(this.ptr, node);
    }
    pub fn visitReturnStmt(this: *const @This(), node: *const ReturnStmt) anyerror!?*anyopaque {
        return this.vtable.visitReturnStmt(this.ptr, node);
    }
    pub fn visitWhileStmt(this: *const @This(), node: *const WhileStmt) anyerror!?*anyopaque {
        return this.vtable.visitWhileStmt(this.ptr, node);
    }
    pub fn visitBlock(this: *const @This(), node: *const Block) anyerror!?*anyopaque {
        return this.vtable.visitBlock(this.ptr, node);
    }

    pub fn visitAssign(this: *const @This(), node: *const Assign) anyerror!?*anyopaque {
        return this.vtable.visitAssign(this.ptr, node);
    }
    pub fn visitAssignExpr(this: *const @This(), node: *const AssignExpr) anyerror!?*anyopaque {
        return this.vtable.visitAssignExpr(this.ptr, node);
    }
    pub fn visitLogicOr(this: *const @This(), node: *const LogicOr) anyerror!?*anyopaque {
        return this.vtable.visitLogicOr(this.ptr, node);
    }
    pub fn visitLogicOrExpr(this: *const @This(), node: *const LogicOrExpr) anyerror!?*anyopaque {
        return this.vtable.visitLogicOrExpr(this.ptr, node);
    }
    pub fn visitLogicAnd(this: *const @This(), node: *const LogicAnd) anyerror!?*anyopaque {
        return this.vtable.visitLogicAnd(this.ptr, node);
    }
    pub fn visitLogicAndExpr(this: *const @This(), node: *const LogicAndExpr) anyerror!?*anyopaque {
        return this.vtable.visitLogicAndExpr(this.ptr, node);
    }
    pub fn visitEquality(this: *const @This(), node: *const Equality) anyerror!?*anyopaque {
        return this.vtable.visitEquality(this.ptr, node);
    }
    pub fn visitEqualityExpr(this: *const @This(), node: *const EqualityExpr) anyerror!?*anyopaque {
        return this.vtable.visitEqualityExpr(this.ptr, node);
    }
    pub fn visitComparison(this: *const @This(), node: *const Comparison) anyerror!?*anyopaque {
        return this.vtable.visitComparison(this.ptr, node);
    }
    pub fn visitComparisonExpr(this: *const @This(), node: *const ComparisonExpr) anyerror!?*anyopaque {
        return this.vtable.visitComparisonExpr(this.ptr, node);
    }
    pub fn visitTerm(this: *const @This(), node: *const Term) anyerror!?*anyopaque {
        return this.vtable.visitTerm(this.ptr, node);
    }
    pub fn visitTermExpr(this: *const @This(), node: *const TermExpr) anyerror!?*anyopaque {
        return this.vtable.visitTermExpr(this.ptr, node);
    }
    pub fn visitFactor(this: *const @This(), node: *const Factor) anyerror!?*anyopaque {
        return this.vtable.visitFactor(this.ptr, node);
    }
    pub fn visitFactorExpr(this: *const @This(), node: *const FactorExpr) anyerror!?*anyopaque {
        return this.vtable.visitFactorExpr(this.ptr, node);
    }
    pub fn visitUnary(this: *const @This(), node: *const Unary) anyerror!?*anyopaque {
        return this.vtable.visitUnary(this.ptr, node);
    }
    pub fn visitUnaryExpr(this: *const @This(), node: *const UnaryExpr) anyerror!?*anyopaque {
        return this.vtable.visitUnaryExpr(this.ptr, node);
    }
    pub fn visitCall(this: *const @This(), node: *const Call) anyerror!?*anyopaque {
        return this.vtable.visitCall(this.ptr, node);
    }
    pub fn visitCallExpr(this: *const @This(), node: *const CallExpr) anyerror!?*anyopaque {
        return this.vtable.visitCallExpr(this.ptr, node);
    }
    pub fn visitCallFn(this: *const @This(), node: *const CallFn) anyerror!?*anyopaque {
        return this.vtable.visitCallFn(this.ptr, node);
    }
    pub fn visitCallProperty(this: *const @This(), node: *const CallProperty) anyerror!?*anyopaque {
        return this.vtable.visitCallProperty(this.ptr, node);
    }
    pub fn visitFnArg(this: *const @This(), node: *const FnArg) anyerror!?*anyopaque {
        return this.vtable.visitFnArg(this.ptr, node);
    }
    pub fn visitPrimary(this: *const @This(), node: *const Primary) anyerror!?*anyopaque {
        return this.vtable.visitPrimary(this.ptr, node);
    }
    pub fn visitGroupExpr(this: *const @This(), node: *const GroupExpr) anyerror!?*anyopaque {
        return this.vtable.visitGroupExpr(this.ptr, node);
    }
};
