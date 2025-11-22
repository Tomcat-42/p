const std = @import("std");
const ArrayList = std.ArrayList;
const fmt = std.fmt;
const Allocator = std.mem.Allocator;

const dupe = @import("util").dupe;
const move = @import("util").move;
const p = @import("p");
const Parser = p.Parser;
const Sema = p.Sema;
const Error = p.common.Error;
const steal = @import("util").steal;

sema: *Sema,

pub fn init(sema: *Sema) @This() {
    return .{ .sema = sema };
}

pub fn visitor(this: *@This()) Parser.Visitor {
    return .{
        .ptr = this,
        .vtable = .{
            .visitProgram = visitProgram,
            .visitDecl = visitDecl,
            .visitObjDecl = visitObjDecl,
            .visitObjDeclExtends = visitObjDeclExtends,
            .visitFnDecl = visitFnDecl,
            .visitFnParam = visitFnParam,
            .visitVarDecl = visitVarDecl,
            .visitVarDeclInit = visitVarDeclInit,

            .visitStmt = visitStmt,
            .visitExprStmt = visitExprStmt,
            .visitForStmt = visitForStmt,
            .visitForInit = visitForInit,
            .visitForCond = visitForCond,
            .visitForInc = visitForInc,
            .visitIfStmt = visitIfStmt,
            .visitIfElseBranch = visitIfElseBranch,
            .visitPrintStmt = visitPrintStmt,
            .visitReturnStmt = visitReturnStmt,
            .visitWhileStmt = visitWhileStmt,
            .visitBlock = visitBlock,

            .visitAssign = visitAssign,
            .visitAssignExpr = visitAssignExpr,
            .visitLogicOr = visitLogicOr,
            .visitLogicOrExpr = visitLogicOrExpr,
            .visitLogicAnd = visitLogicAnd,
            .visitLogicAndExpr = visitLogicAndExpr,
            .visitEquality = visitEquality,
            .visitEqualityExpr = visitEqualityExpr,
            .visitComparison = visitComparison,
            .visitComparisonExpr = visitComparisonExpr,
            .visitTerm = visitTerm,
            .visitTermExpr = visitTermExpr,
            .visitFactor = visitFactor,
            .visitFactorExpr = visitFactorExpr,
            .visitUnary = visitUnary,
            .visitUnaryExpr = visitUnaryExpr,
            .visitCall = visitCall,
            .visitCallExpr = visitCallExpr,
            .visitCallFn = visitCallFn,
            .visitCallProperty = visitCallProperty,
            .visitFnArg = visitFnArg,
            .visitPrimary = visitPrimary,
            .visitGroupExpr = visitGroupExpr,
        },
    };
}

fn visitProgram(this: *anyopaque, node: *const Parser.Program) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    var decls: ArrayList(Sema.Decl) = .empty;
    defer decls.deinit(builder.sema.allocator);

    try decls.ensureTotalCapacity(builder.sema.allocator, node.decls.len);
    for (node.decls) |*pdecl| decls.appendAssumeCapacity(try move(
        Sema.Decl,
        builder.sema.allocator,
        @ptrCast(@alignCast(try pdecl.visit(builder.visitor()) orelse return null)),
    ));

    return try dupe(Sema.Program, builder.sema.allocator, .{
        .decls = try decls.toOwnedSlice(builder.sema.allocator),
    });
}

fn visitDecl(this: *anyopaque, node: *const Parser.Decl) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    return switch (node.*) {
        .obj_decl => |*obj_decl| try obj_decl.visit(builder.visitor()),
        .fn_decl => |*fn_decl| try fn_decl.visit(builder.visitor()),
        .var_decl => |*var_decl| try var_decl.visit(builder.visitor()),
        .stmt => |*stmt| try dupe(
            Sema.Decl,
            builder.sema.allocator,
            .{
                .stmt = try move(
                    Sema.Stmt,
                    builder.sema.allocator,
                    @ptrCast(@alignCast(try stmt.visit(builder.visitor()) orelse return null)),
                ),
            },
        ),
    };
}

fn visitObjDecl(this: *anyopaque, node: *const Parser.ObjDecl) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    return try dupe(Sema.Decl, builder.sema.allocator, .{
        .obj = .{
            .name = node.id.value,
            .parent = if (node.extends) |extends| extends.id.value else null,
            .body = try move(
                Sema.Program,
                builder.sema.allocator,
                @ptrCast(
                    @alignCast(try node.body.program.visit(builder.visitor()) orelse return null),
                ),
            ),
        },
    });
}

fn visitObjDeclExtends(_: *anyopaque, _: *const Parser.ObjDeclExtends) anyerror!?*anyopaque {
    unreachable;
}

fn visitFnDecl(this: *anyopaque, node: *const Parser.FnDecl) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    var params: ArrayList([]const u8) = .empty;
    defer params.deinit(builder.sema.allocator);

    try params.ensureTotalCapacity(builder.sema.allocator, node.params.len);
    for (node.params) |param| params.appendAssumeCapacity(param.id.value);

    return try dupe(Sema.Decl, builder.sema.allocator, .{
        .func = .{
            .name = node.id.value,
            .params = try params.toOwnedSlice(builder.sema.allocator),
            .body = try move(Sema.Program, builder.sema.allocator, @ptrCast(
                @alignCast(try node.body.program.visit(builder.visitor()) orelse return null),
            )),
        },
    });
}

fn visitFnParam(_: *anyopaque, _: *const Parser.FnParam) anyerror!?*anyopaque {
    unreachable;
}

fn visitVarDecl(this: *anyopaque, node: *const Parser.VarDecl) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    return try dupe(
        Sema.Decl,
        builder.sema.allocator,
        .{
            .variable = .{
                .name = node.id.value,
                .init = if (node.init) |ini| try move(
                    Sema.Expr,
                    builder.sema.allocator,
                    @ptrCast(@alignCast(try ini.expr.visit(builder.visitor()) orelse return null)),
                ) else null,
            },
        },
    );
}

fn visitVarDeclInit(_: *anyopaque, _: *const Parser.VarDeclInit) anyerror!?*anyopaque {
    unreachable;
}

fn visitStmt(this: *anyopaque, node: *const Parser.Stmt) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    return switch (node.*) {
        .expr_stmt => |*stmt| try stmt.visit(builder.visitor()),
        .for_stmt => |*stmt| try stmt.visit(builder.visitor()),
        .if_stmt => |stmt| try stmt.visit(builder.visitor()),
        .print_stmt => |*stmt| try stmt.visit(builder.visitor()),
        .return_stmt => |*stmt| try stmt.visit(builder.visitor()),
        .while_stmt => |*stmt| try stmt.visit(builder.visitor()),
        .block => |block| try block.visit(builder.visitor()),
    };
}

fn visitExprStmt(this: *anyopaque, node: *const Parser.ExprStmt) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    return try dupe(Sema.Stmt, builder.sema.allocator, .{
        .expr = try move(
            Sema.Expr,
            builder.sema.allocator,
            @ptrCast(@alignCast(try node.expr.visit(builder.visitor()) orelse return null)),
        ),
    });
}

fn visitForStmt(this: *anyopaque, node: *const Parser.ForStmt) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    return try dupe(Sema.Stmt, builder.sema.allocator, .{
        .@"for" = .{
            .init = init: {
                if (node.init) |*i| if (try i.visit(builder.visitor())) |res|
                    break :init try move(Sema.ForStmt.Init, builder.sema.allocator, @ptrCast(@alignCast(res)));
                break :init null;
            },
            .condition = cond: {
                if (node.cond) |*cond| {
                    if (try cond.visit(builder.visitor())) |res| {
                        break :cond @ptrCast(@alignCast(res));
                    }
                }
                break :cond null;
            },
            .increment = inc: {
                if (node.inc) |*inc| {
                    if (try inc.visit(builder.visitor())) |res| {
                        break :inc @ptrCast(@alignCast(res));
                    }
                }
                break :inc null;
            },
            .body = @ptrCast(@alignCast(try node.body.visit(builder.visitor()) orelse return null)),
        },
    });
}

fn visitForInit(this: *anyopaque, node: *const Parser.ForInit) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    return try dupe(Sema.ForStmt.Init, builder.sema.allocator, switch (node.*) {
        .@";" => return null,
        .var_decl => |*var_decl| .{
            .variable = (try move(
                Sema.Decl,
                builder.sema.allocator,
                @ptrCast(@alignCast(try var_decl.visit(builder.visitor()) orelse return null)),
            )).variable,
        },
        .expr => |*expr_stmt| .{
            .expr = try move(
                Sema.Expr,
                builder.sema.allocator,
                @ptrCast(@alignCast(try expr_stmt.expr.visit(builder.visitor()) orelse return null)),
            ),
        },
    });
}

fn visitForCond(this: *anyopaque, node: *const Parser.ForCond) anyerror!?*anyopaque {
    return switch (node.*) {
        .expr => |*expr_stmt| try visitAssign(this, &expr_stmt.expr),
        .@";" => null,
    };
}

fn visitForInc(this: *anyopaque, node: *const Parser.ForInc) anyerror!?*anyopaque {
    return try visitAssign(this, &node.expr);
}

fn visitIfStmt(this: *anyopaque, node: *const Parser.IfStmt) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    return try dupe(Sema.Stmt, builder.sema.allocator, .{
        .@"if" = .{
            .condition = @ptrCast(@alignCast(try node.cond.visit(builder.visitor()) orelse return null)),
            .then_branch = @ptrCast(@alignCast(try node.main_branch.visit(builder.visitor()) orelse return null)),
            .else_branch = if (node.else_branch) |*else_br|
                @ptrCast(@alignCast(try else_br.stmt.visit(builder.visitor()) orelse return null))
            else
                null,
        },
    });
}

fn visitIfElseBranch(_: *anyopaque, _: *const Parser.IfElseBranch) anyerror!?*anyopaque {
    unreachable;
}

fn visitPrintStmt(this: *anyopaque, node: *const Parser.PrintStmt) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    const expr: *Sema.Expr = @ptrCast(@alignCast(try node.expr.visit(builder.visitor()) orelse return null));
    defer builder.sema.allocator.destroy(expr);

    return try dupe(Sema.Stmt, builder.sema.allocator, .{
        .print = expr.*,
    });
}

fn visitReturnStmt(this: *anyopaque, node: *const Parser.ReturnStmt) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    return try dupe(Sema.Stmt, builder.sema.allocator, .{
        .@"return" = if (node.expr) |*expr| blk: {
            const expr_ptr: *Sema.Expr = @ptrCast(@alignCast(try expr.visit(builder.visitor()) orelse return null));
            defer builder.sema.allocator.destroy(expr_ptr);
            break :blk expr_ptr.*;
        } else null,
    });
}

fn visitWhileStmt(this: *anyopaque, node: *const Parser.WhileStmt) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    return try dupe(Sema.Stmt, builder.sema.allocator, .{
        .@"while" = .{
            .condition = @ptrCast(@alignCast(try node.cond.visit(builder.visitor()) orelse return null)),
            .body = @ptrCast(@alignCast(try node.body.visit(builder.visitor()) orelse return null)),
        },
    });
}

fn visitBlock(this: *anyopaque, node: *const Parser.Block) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    return try dupe(Sema.Stmt, builder.sema.allocator, .{
        .block = try move(
            Sema.Program,
            builder.sema.allocator,
            @ptrCast(@alignCast(try node.program.visit(builder.visitor()) orelse return null)),
        ),
    });
}

fn visitAssign(this: *anyopaque, node: *const Parser.Assign) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    const target: *Sema.Expr = @ptrCast(@alignCast(try visitLogicOr(this, node.logic_or) orelse return null));

    if (node.assign_expr) |assign_expr| {
        const value: *Sema.Expr = @ptrCast(@alignCast(try visitAssignExpr(this, assign_expr) orelse return null));
        return try dupe(Sema.Expr, builder.sema.allocator, .{
            .assign = .{
                .target = target,
                .value = value,
            },
        });
    }

    return @ptrCast(target);
}

fn visitAssignExpr(this: *anyopaque, node: *const Parser.AssignExpr) anyerror!?*anyopaque {
    return try visitAssign(this, &node.expr);
}

fn visitLogicOr(this: *anyopaque, node: *const Parser.LogicOr) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    var current: *Sema.Expr = @ptrCast(@alignCast(try node.first.visit(builder.visitor()) orelse return null));

    for (node.suffixes) |*suffix| {
        const right: *Sema.Expr = @ptrCast(@alignCast(try suffix.logic_and.visit(builder.visitor()) orelse return null));
        current = try dupe(Sema.Expr, builder.sema.allocator, .{
            .binary = .{
                .left = current,
                .op = .@"or",
                .right = right,
            },
        });
    }

    return @ptrCast(current);
}

fn visitLogicOrExpr(this: *anyopaque, node: *const Parser.LogicOrExpr) anyerror!?*anyopaque {
    _ = this;
    _ = node;
    // This visitor is not actually called directly; visitLogicOr handles LogicOrExpr inline
    unreachable;
}

fn visitLogicAnd(this: *anyopaque, node: *const Parser.LogicAnd) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    var current: *Sema.Expr = @ptrCast(@alignCast(try node.first.visit(builder.visitor()) orelse return null));

    for (node.suffixes) |*suffix| {
        const right: *Sema.Expr = @ptrCast(@alignCast(try suffix.equality.visit(builder.visitor()) orelse return null));
        current = try dupe(Sema.Expr, builder.sema.allocator, .{
            .binary = .{
                .left = current,
                .op = .@"and",
                .right = right,
            },
        });
    }

    return @ptrCast(current);
}

fn visitLogicAndExpr(_: *anyopaque, _: *const Parser.LogicAndExpr) anyerror!?*anyopaque {
    unreachable;
}

fn visitEquality(this: *anyopaque, node: *const Parser.Equality) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    var current: *Sema.Expr = @ptrCast(@alignCast(try node.first.visit(builder.visitor()) orelse return null));

    for (node.suffixes) |*suffix| {
        const right: *Sema.Expr = @ptrCast(@alignCast(try suffix.comparison.visit(builder.visitor()) orelse return null));
        current = try dupe(Sema.Expr, builder.sema.allocator, .{
            .binary = .{
                .left = current,
                .op = switch (suffix.op.tag) {
                    .@"==" => .@"==",
                    .@"!=" => .@"!=",
                    else => unreachable,
                },
                .right = right,
            },
        });
    }

    return @ptrCast(current);
}

fn visitEqualityExpr(_: *anyopaque, _: *const Parser.EqualityExpr) anyerror!?*anyopaque {
    unreachable;
}

fn visitComparison(this: *anyopaque, node: *const Parser.Comparison) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    var current: *Sema.Expr = @ptrCast(@alignCast(try node.first.visit(builder.visitor()) orelse return null));

    for (node.suffixes) |*suffix| {
        const right: *Sema.Expr = @ptrCast(@alignCast(try suffix.term.visit(builder.visitor()) orelse return null));
        current = try dupe(Sema.Expr, builder.sema.allocator, .{
            .binary = .{
                .left = current,
                .op = switch (suffix.op.tag) {
                    .@">" => .@">",
                    .@">=" => .@">=",
                    .@"<" => .@"<",
                    .@"<=" => .@"<=",
                    else => unreachable,
                },
                .right = right,
            },
        });
    }

    return @ptrCast(current);
}

fn visitComparisonExpr(_: *anyopaque, _: *const Parser.ComparisonExpr) anyerror!?*anyopaque {
    unreachable;
}

fn visitTerm(this: *anyopaque, node: *const Parser.Term) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    var current: *Sema.Expr = @ptrCast(@alignCast(try node.first.visit(builder.visitor()) orelse return null));

    for (node.suffixes) |*suffix| {
        const right: *Sema.Expr = @ptrCast(@alignCast(try suffix.factor.visit(builder.visitor()) orelse return null));
        current = try dupe(Sema.Expr, builder.sema.allocator, .{
            .binary = .{
                .left = current,
                .op = switch (suffix.op.tag) {
                    .@"+" => .@"+",
                    .@"-" => .@"-",
                    else => unreachable,
                },
                .right = right,
            },
        });
    }

    return @ptrCast(current);
}

fn visitTermExpr(_: *anyopaque, _: *const Parser.TermExpr) anyerror!?*anyopaque {
    unreachable;
}

fn visitFactor(this: *anyopaque, node: *const Parser.Factor) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    var current: *Sema.Expr = @ptrCast(@alignCast(try node.first.visit(builder.visitor()) orelse return null));

    for (node.suffixes) |*suffix| {
        const right: *Sema.Expr = @ptrCast(@alignCast(try suffix.unary.visit(builder.visitor()) orelse return null));
        current = try dupe(Sema.Expr, builder.sema.allocator, .{
            .binary = .{
                .left = current,
                .op = switch (suffix.op.tag) {
                    .@"*" => .@"*",
                    .@"/" => .@"/",
                    else => unreachable,
                },
                .right = right,
            },
        });
    }

    return @ptrCast(current);
}

fn visitFactorExpr(_: *anyopaque, _: *const Parser.FactorExpr) anyerror!?*anyopaque {
    unreachable;
}

fn visitUnary(this: *anyopaque, node: *const Parser.Unary) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    return switch (node.*) {
        .unary_expr => |unary_expr| try visitUnaryExpr(this, unary_expr),
        .call => |*call| try call.visit(builder.visitor()),
    };
}

fn visitUnaryExpr(this: *anyopaque, node: *const Parser.UnaryExpr) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    return try dupe(Sema.Expr, builder.sema.allocator, .{
        .unary = .{
            .op = switch (node.op.tag) {
                .@"-" => .@"-",
                .@"!" => .@"!",
                else => unreachable,
            },
            .operand = @ptrCast(@alignCast(try node.call.visit(builder.visitor()) orelse return null)),
        },
    });
}

fn visitCall(this: *anyopaque, node: *const Parser.Call) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    var current_expr: *Sema.Expr = @ptrCast(@alignCast(try node.primary.visit(builder.visitor()) orelse return null));

    for (node.calls) |*call_expr| {
        current_expr = switch (call_expr.*) {
            .call_fn => |*call_fn| blk: {
                const args = try builder.sema.allocator.alloc(*Sema.Expr, call_fn.args.len);
                for (call_fn.args, 0..) |*arg, i| {
                    args[i] = @ptrCast(@alignCast(try arg.visit(builder.visitor()) orelse return null));
                }

                break :blk try dupe(Sema.Expr, builder.sema.allocator, .{
                    .call = .{
                        .callee = current_expr,
                        .args = args,
                    },
                });
            },
            .call_property => |*prop| try dupe(Sema.Expr, builder.sema.allocator, .{
                .property = .{
                    .object = current_expr,
                    .name = prop.id.value,
                },
            }),
        };
    }

    return @ptrCast(current_expr);
}

fn visitCallExpr(_: *anyopaque, _: *const Parser.CallExpr) anyerror!?*anyopaque {
    unreachable;
}

fn visitCallFn(_: *anyopaque, _: *const Parser.CallFn) anyerror!?*anyopaque {
    unreachable;
}

fn visitCallProperty(this: *anyopaque, node: *const Parser.CallProperty) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    return try dupe(Sema.Expr, builder.sema.allocator, .{ .identifier = node.id.value });
}

fn visitFnArg(this: *anyopaque, node: *const Parser.FnArg) anyerror!?*anyopaque {
    return try visitAssign(this, &node.expr);
}

fn visitPrimary(this: *anyopaque, node: *const Parser.Primary) anyerror!?*anyopaque {
    const builder: *@This() = @ptrCast(@alignCast(this));

    return switch (node.*) {
        .nil => try dupe(Sema.Expr, builder.sema.allocator, .nil),
        .this => try dupe(Sema.Expr, builder.sema.allocator, .this),
        .proto => try dupe(Sema.Expr, builder.sema.allocator, .proto),
        .true => try dupe(Sema.Expr, builder.sema.allocator, .{ .bool = true }),
        .false => try dupe(Sema.Expr, builder.sema.allocator, .{ .bool = false }),
        .number => |token| try dupe(Sema.Expr, builder.sema.allocator, .{
            .number = std.fmt.parseFloat(f64, token.value) catch {
                try builder.sema.errors.append(
                    builder.sema.allocator,
                    Error.init(try fmt.allocPrint(
                        builder.sema.allocator,
                        "Invalid number literal: '{}'",
                        .{token.value},
                    ), token.span),
                );
                return null;
            },
        }),
        .string => |token| try dupe(Sema.Expr, builder.sema.allocator, .{ .string = token.value }),
        .id => |token| try dupe(Sema.Expr, builder.sema.allocator, .{ .identifier = token.value }),
        .group_expr => |*group| try group.expr.visit(builder.visitor()) orelse return null,
    };
}

fn visitGroupExpr(this: *anyopaque, node: *const Parser.GroupExpr) anyerror!?*anyopaque {
    return try visitAssign(this, &node.expr);
}
