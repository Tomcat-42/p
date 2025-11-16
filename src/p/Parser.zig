const std = @import("std");
const Io = std.Io;
const testing = std.testing;
const assert = std.debug.assert;
const mem = std.mem;
const fmt = std.fmt;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const p = @import("p");
const Tokenizer = p.Tokenizer;
const Token = Tokenizer.Token;
const util = @import("util");
const term = util.term;

pub const Assign = @import("Parser/Assign.zig").Assign;
pub const Expr = Assign;
pub const ForCond = Expr;
pub const ForInc = Expr;
pub const IfCond = Expr;
pub const AssignExpr = @import("Parser/AssignExpr.zig");
pub const AssignTarget = @import("Parser/AssignTarget.zig").AssignTarget;
pub const AssignTargetProperty = @import("Parser/AssignTargetProperty.zig");
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
pub const ProtoAccess = @import("Parser/ProtoAccess.zig");
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

pub const Visitor = struct {
    ptr: *anyopaque,
    vtable: VTable,

    pub const VTable = struct {
        visitProgram: *const fn (this: *anyopaque, node: *const Program) ?*anyopaque,
        visitDecl: *const fn (this: *anyopaque, node: *const Decl) ?*anyopaque,
        visitObjDecl: *const fn (this: *anyopaque, node: *const ObjDecl) ?*anyopaque,
        visitObjDeclExtends: *const fn (this: *anyopaque, node: *const ObjDeclExtends) ?*anyopaque,
        visitFnDecl: *const fn (this: *anyopaque, node: *const FnDecl) ?*anyopaque,
        visitFnParam: *const fn (this: *anyopaque, node: *const FnParam) ?*anyopaque,
        visitVarDecl: *const fn (this: *anyopaque, node: *const VarDecl) ?*anyopaque,
        visitVarDeclInit: *const fn (this: *anyopaque, node: *const VarDeclInit) ?*anyopaque,

        visitStmt: *const fn (this: *anyopaque, node: *const Stmt) ?*anyopaque,
        visitExprStmt: *const fn (this: *anyopaque, node: *const ExprStmt) ?*anyopaque,
        visitForStmt: *const fn (this: *anyopaque, node: *const ForStmt) ?*anyopaque,
        visitForInit: *const fn (this: *anyopaque, node: *const ForInit) ?*anyopaque,
        visitIfStmt: *const fn (this: *anyopaque, node: *const IfStmt) ?*anyopaque,
        visitIfElseBranch: *const fn (this: *anyopaque, node: *const IfElseBranch) ?*anyopaque,
        visitPrintStmt: *const fn (this: *anyopaque, node: *const PrintStmt) ?*anyopaque,
        visitReturnStmt: *const fn (this: *anyopaque, node: *const ReturnStmt) ?*anyopaque,
        visitWhileStmt: *const fn (this: *anyopaque, node: *const WhileStmt) ?*anyopaque,
        visitBlock: *const fn (this: *anyopaque, node: *const Block) ?*anyopaque,

        visitAssign: *const fn (this: *anyopaque, node: *const Assign) ?*anyopaque,
        visitAssignExpr: *const fn (this: *anyopaque, node: *const AssignExpr) ?*anyopaque,
        visitAssignTarget: *const fn (this: *anyopaque, node: *const AssignTarget) ?*anyopaque,
        visitAssignTargetProperty: *const fn (this: *anyopaque, node: *const AssignTargetProperty) ?*anyopaque,
        visitLogicOr: *const fn (this: *anyopaque, node: *const LogicOr) ?*anyopaque,
        visitLogicOrExpr: *const fn (this: *anyopaque, node: *const LogicOrExpr) ?*anyopaque,
        visitLogicAnd: *const fn (this: *anyopaque, node: *const LogicAnd) ?*anyopaque,
        visitLogicAndExpr: *const fn (this: *anyopaque, node: *const LogicAndExpr) ?*anyopaque,
        visitEquality: *const fn (this: *anyopaque, node: *const Equality) ?*anyopaque,
        visitEqualityExpr: *const fn (this: *anyopaque, node: *const EqualityExpr) ?*anyopaque,
        visitComparison: *const fn (this: *anyopaque, node: *const Comparison) ?*anyopaque,
        visitComparisonExpr: *const fn (this: *anyopaque, node: *const ComparisonExpr) ?*anyopaque,
        visitTerm: *const fn (this: *anyopaque, node: *const Term) ?*anyopaque,
        visitTermExpr: *const fn (this: *anyopaque, node: *const TermExpr) ?*anyopaque,
        visitFactor: *const fn (this: *anyopaque, node: *const Factor) ?*anyopaque,
        visitFactorExpr: *const fn (this: *anyopaque, node: *const FactorExpr) ?*anyopaque,
        visitUnary: *const fn (this: *anyopaque, node: *const Unary) ?*anyopaque,
        visitUnaryExpr: *const fn (this: *anyopaque, node: *const UnaryExpr) ?*anyopaque,
        visitCall: *const fn (this: *anyopaque, node: *const Call) ?*anyopaque,
        visitCallExpr: *const fn (this: *anyopaque, node: *const CallExpr) ?*anyopaque,
        visitCallFn: *const fn (this: *anyopaque, node: *const CallFn) ?*anyopaque,
        visitCallProperty: *const fn (this: *anyopaque, node: *const CallProperty) ?*anyopaque,
        visitFnArg: *const fn (this: *anyopaque, node: *const FnArg) ?*anyopaque,
        visitPrimary: *const fn (this: *anyopaque, node: *const Primary) ?*anyopaque,
        visitGroupExpr: *const fn (this: *anyopaque, node: *const GroupExpr) ?*anyopaque,
        visitProtoAccess: *const fn (this: *anyopaque, node: *const ProtoAccess) ?*anyopaque,
    };

    pub fn visitProgram(this: *const @This(), node: *const Program) ?*anyopaque {
        this.vtable.visitProgram(this.ptr, node);
    }
    pub fn visitDecl(this: *const @This(), node: *const Decl) ?*anyopaque {
        this.vtable.visitDecl(this.ptr, node);
    }
    pub fn visitObjDecl(this: *const @This(), node: *const ObjDecl) ?*anyopaque {
        this.vtable.visitObjDecl(this.ptr, node);
    }
    pub fn visitObjDeclExtends(this: *const @This(), node: *const ObjDeclExtends) ?*anyopaque {
        this.vtable.visitObjDeclExtends(this.ptr, node);
    }
    pub fn visitFnDecl(this: *const @This(), node: *const FnDecl) ?*anyopaque {
        this.vtable.visitFnDecl(this.ptr, node);
    }
    pub fn visitFnParam(this: *const @This(), node: *const FnParam) ?*anyopaque {
        this.vtable.visitFnParam(this.ptr, node);
    }
    pub fn visitVarDecl(this: *const @This(), node: *const VarDecl) ?*anyopaque {
        this.vtable.visitVarDecl(this.ptr, node);
    }
    pub fn visitVarDeclInit(this: *const @This(), node: *const VarDeclInit) ?*anyopaque {
        this.vtable.visitVarDeclInit(this.ptr, node);
    }

    pub fn visitStmt(this: *const @This(), node: *const Stmt) ?*anyopaque {
        this.vtable.visitStmt(this.ptr, node);
    }
    pub fn visitExprStmt(this: *const @This(), node: *const ExprStmt) ?*anyopaque {
        this.vtable.visitExprStmt(this.ptr, node);
    }
    pub fn visitForStmt(this: *const @This(), node: *const ForStmt) ?*anyopaque {
        this.vtable.visitForStmt(this.ptr, node);
    }
    pub fn visitForInit(this: *const @This(), node: *const ForInit) ?*anyopaque {
        this.vtable.visitForInit(this.ptr, node);
    }
    pub fn visitIfStmt(this: *const @This(), node: *const IfStmt) ?*anyopaque {
        this.vtable.visitIfStmt(this.ptr, node);
    }
    pub fn visitIfElseBranch(this: *const @This(), node: *const IfElseBranch) ?*anyopaque {
        this.vtable.visitIfElseBranch(this.ptr, node);
    }
    pub fn visitPrintStmt(this: *const @This(), node: *const PrintStmt) ?*anyopaque {
        this.vtable.visitPrintStmt(this.ptr, node);
    }
    pub fn visitReturnStmt(this: *const @This(), node: *const ReturnStmt) ?*anyopaque {
        this.vtable.visitReturnStmt(this.ptr, node);
    }
    pub fn visitWhileStmt(this: *const @This(), node: *const WhileStmt) ?*anyopaque {
        this.vtable.visitWhileStmt(this.ptr, node);
    }
    pub fn visitBlock(this: *const @This(), node: *const Block) ?*anyopaque {
        this.vtable.visitBlock(this.ptr, node);
    }

    pub fn visitAssign(this: *const @This(), node: *const Assign) ?*anyopaque {
        this.vtable.visitAssign(this.ptr, node);
    }
    pub fn visitAssignExpr(this: *const @This(), node: *const AssignExpr) ?*anyopaque {
        this.vtable.visitAssignExpr(this.ptr, node);
    }
    pub fn visitAssignTarget(this: *const @This(), node: *const AssignTarget) ?*anyopaque {
        this.vtable.visitAssignTarget(this.ptr, node);
    }
    pub fn visitAssignTargetProperty(this: *const @This(), node: *const AssignTargetProperty) ?*anyopaque {
        this.vtable.visitAssignTargetProperty(this.ptr, node);
    }
    pub fn visitLogicOr(this: *const @This(), node: *const LogicOr) ?*anyopaque {
        this.vtable.visitLogicOr(this.ptr, node);
    }
    pub fn visitLogicOrExpr(this: *const @This(), node: *const LogicOrExpr) ?*anyopaque {
        this.vtable.visitLogicOrExpr(this.ptr, node);
    }
    pub fn visitLogicAnd(this: *const @This(), node: *const LogicAnd) ?*anyopaque {
        this.vtable.visitLogicAnd(this.ptr, node);
    }
    pub fn visitLogicAndExpr(this: *const @This(), node: *const LogicAndExpr) ?*anyopaque {
        this.vtable.visitLogicAndExpr(this.ptr, node);
    }
    pub fn visitEquality(this: *const @This(), node: *const Equality) ?*anyopaque {
        this.vtable.visitEquality(this.ptr, node);
    }
    pub fn visitEqualityExpr(this: *const @This(), node: *const EqualityExpr) ?*anyopaque {
        this.vtable.visitEqualityExpr(this.ptr, node);
    }
    pub fn visitComparison(this: *const @This(), node: *const Comparison) ?*anyopaque {
        this.vtable.visitComparison(this.ptr, node);
    }
    pub fn visitComparisonExpr(this: *const @This(), node: *const ComparisonExpr) ?*anyopaque {
        this.vtable.visitComparisonExpr(this.ptr, node);
    }
    pub fn visitTerm(this: *const @This(), node: *const Term) ?*anyopaque {
        this.vtable.visitTerm(this.ptr, node);
    }
    pub fn visitTermExpr(this: *const @This(), node: *const TermExpr) ?*anyopaque {
        this.vtable.visitTermExpr(this.ptr, node);
    }
    pub fn visitFactor(this: *const @This(), node: *const Factor) ?*anyopaque {
        this.vtable.visitFactor(this.ptr, node);
    }
    pub fn visitFactorExpr(this: *const @This(), node: *const FactorExpr) ?*anyopaque {
        this.vtable.visitFactorExpr(this.ptr, node);
    }
    pub fn visitUnary(this: *const @This(), node: *const Unary) ?*anyopaque {
        this.vtable.visitUnary(this.ptr, node);
    }
    pub fn visitUnaryExpr(this: *const @This(), node: *const UnaryExpr) ?*anyopaque {
        this.vtable.visitUnaryExpr(this.ptr, node);
    }
    pub fn visitCall(this: *const @This(), node: *const Call) ?*anyopaque {
        this.vtable.visitCall(this.ptr, node);
    }
    pub fn visitCallExpr(this: *const @This(), node: *const CallExpr) ?*anyopaque {
        this.vtable.visitCallExpr(this.ptr, node);
    }
    pub fn visitCallFn(this: *const @This(), node: *const CallFn) ?*anyopaque {
        this.vtable.visitCallFn(this.ptr, node);
    }
    pub fn visitCallProperty(this: *const @This(), node: *const CallProperty) ?*anyopaque {
        this.vtable.visitCallProperty(this.ptr, node);
    }
    pub fn visitFnArg(this: *const @This(), node: *const FnArg) ?*anyopaque {
        this.vtable.visitFnArg(this.ptr, node);
    }
    pub fn visitPrimary(this: *const @This(), node: *const Primary) ?*anyopaque {
        this.vtable.visitPrimary(this.ptr, node);
    }
    pub fn visitGroupExpr(this: *const @This(), node: *const GroupExpr) ?*anyopaque {
        this.vtable.visitGroupExpr(this.ptr, node);
    }
    pub fn visitProtoAccess(this: *const @This(), node: *const ProtoAccess) ?*anyopaque {
        this.vtable.visitProtoAccess(this.ptr, node);
    }
};

pub const Error = struct {
    message: []const u8,
    span: Token.Span,
};

tokens: *Tokenizer,
errors: ArrayList(Error) = .empty,

pub fn init(tokens: *Tokenizer) @This() {
    return .{ .tokens = tokens };
}

pub fn deinit(this: *@This(), allocator: Allocator) void {
    this.errors.deinit(allocator);
}

pub fn parse(this: *@This(), allocator: Allocator) !?Program {
    return .parse(this, allocator);
}

pub fn reset(this: *@This(), allocator: Allocator) void {
    this.tokens.reset();
    this.errors.clearAndFree(allocator);
}

pub fn getErrors(this: *@This()) !?[]const Error {
    if (this.errors.items.len == 0) return null;
    return this.errors.items;
}

pub inline fn expectOrHandleErrorAndSync(this: *@This(), allocator: Allocator, comptime expected: anytype) !?Token {
    assert(@typeInfo(@TypeOf(expected)) == .@"struct");
    assert(@typeInfo(@TypeOf(expected)).@"struct".fields.len >= 1);

    // Next token is expected, return gracefully 😄
    if (this.tokens.expect(expected)) |token| return token;

    // 💀
    const token = this.tokens.peek();
    try this.errors.append(allocator, .{
        .message = try fmt.allocPrint(allocator, "Expected {s}, got '{s}'", .{
            comptime tokens: {
                var message: []const u8 = "'" ++ @tagName(expected[0]) ++ "'";
                for (1..@typeInfo(@TypeOf(expected)).@"struct".fields.len) |i| message = message ++ ", '" ++ @tagName(expected[i]) ++ "'";
                break :tokens message;
            },
            if (token) |tok| @tagName(tok.tag) else "Unexpected EOF",
        }),
        .span = if (token) |tok| .{
            .begin = this.tokens.pos + 1,
            .end = this.tokens.pos + tok.value.len + 1,
        } else .{
            .begin = this.tokens.pos,
            .end = this.tokens.pos,
        },
    });

    return this.tokens.sync(expected);
}

fn MakeFormat(T: type) type {
    return struct {
        depth: usize = 0,
        data: *const T,

        pub fn format(this: @This(), writer: *Io.Writer) Io.Writer.Error!void {
            const depth = this.depth;

            for (0..depth) |_| try writer.print(term.SEP, .{});
            try writer.print("{s}{s}{s}\n", .{ term.FG.BLUE, @typeName(T), term.RESET });

            switch (@typeInfo(T)) {
                .@"struct" => |s| inline for (s.fields) |field| switch (@typeInfo(field.type)) {
                    .pointer => |ptr| switch (ptr.size) {
                        .one => try writer.print("{f}", @field(this.data, field.name).format(depth + 1)),
                        else => for (@field(this.data, field.name)) |f| try writer.print("{f}", f.format(depth + 1)),
                    },
                    .optional => if (@field(this.data, field.name)) |f|
                        try writer.print("{f}", f.format(depth + 1)),
                    else => try writer.print("{f}", @field(this.data, field.name).format(depth + 1)),
                },
                .@"union" => |_| switch (this.data.*) {
                    inline else => |f| try writer.print("{f}", f.format(depth + 1)),
                },
                else => @compileError("MakeFormat only supports structs and tagged unions"),
            }
        }
    };
}
