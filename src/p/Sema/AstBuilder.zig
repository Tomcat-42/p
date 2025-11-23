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

pub inline fn visitor(ctx: *const @This()) Parser.Visitor {
    return .{
        .ptr = @constCast(ctx),
        .vtable = &.{
            .visit_program = visit_program,
            .visit_decl = visit_decl,
            .visit_obj_decl = visit_obj_decl,
            .visit_obj_decl_extends = visit_obj_decl_extends,
            .visit_fn_decl = visit_fn_decl,
            .visit_fn_param = visit_fn_param,
            .visit_var_decl = visit_var_decl,
            .visit_var_decl_init = visit_var_decl_init,

            .visit_stmt = visit_stmt,
            .visit_expr_stmt = visit_expr_stmt,
            .visit_for_stmt = visit_for_stmt,
            .visit_for_init = visit_for_init,
            .visit_for_cond = visit_for_cond,
            .visit_for_inc = visit_for_inc,
            .visit_if_stmt = visit_if_stmt,
            .visit_if_else_branch = visit_if_else_branch,
            .visit_print_stmt = visit_print_stmt,
            .visit_return_stmt = visit_return_stmt,
            .visit_while_stmt = visit_while_stmt,
            .visit_block = visit_block,

            .visit_assign = visit_assign,
            .visit_assign_expr = visit_assign_expr,
            .visit_logic_or = visit_logic_or,
            .visit_logic_or_expr = visit_logic_or_expr,
            .visit_logic_and = visit_logic_and,
            .visit_logic_and_expr = visit_logic_and_expr,
            .visit_equality = visit_equality,
            .visit_equality_expr = visit_equality_expr,
            .visit_comparison = visit_comparison,
            .visit_comparison_expr = visit_comparison_expr,
            .visit_term = visit_term,
            .visit_term_expr = visit_term_expr,
            .visit_factor = visit_factor,
            .visit_factor_expr = visit_factor_expr,
            .visit_unary = visit_unary,
            .visit_unary_expr = visit_unary_expr,
            .visit_call = visit_call,
            .visit_call_expr = visit_call_expr,
            .visit_call_fn = visit_call_fn,
            .visit_call_property = visit_call_property,
            .visit_fn_arg = visit_fn_arg,
            .visit_primary = visit_primary,
            .visit_group_expr = visit_group_expr,
        },
    };
}

fn visit_program(ctx: *anyopaque, allocator: Allocator, node: *const Parser.Program) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    var decls: ArrayList(Sema.Decl) = .empty;
    defer decls.deinit(allocator);

    try decls.ensureTotalCapacity(allocator, node.decls.len);
    for (node.decls) |*pdecl| decls.appendAssumeCapacity(try move(
        Sema.Decl,
        allocator,
        @ptrCast(@alignCast(try pdecl.visit(allocator, this.visitor()) orelse return null)),
    ));

    return try dupe(Sema.Program, allocator, .{
        .decls = try decls.toOwnedSlice(allocator),
    });
}

fn visit_decl(ctx: *anyopaque, allocator: Allocator, node: *const Parser.Decl) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    return switch (node.*) {
        .obj_decl => |*obj_decl| try obj_decl.visit(allocator, this.visitor()),
        .fn_decl => |*fn_decl| try fn_decl.visit(allocator, this.visitor()),
        .var_decl => |*var_decl| try var_decl.visit(allocator, this.visitor()),
        .stmt => |*stmt| try dupe(
            Sema.Decl,
            allocator,
            .{
                .stmt = try move(
                    Sema.Stmt,
                    allocator,
                    @ptrCast(@alignCast(try stmt.visit(allocator, this.visitor()) orelse return null)),
                ),
            },
        ),
    };
}

fn visit_obj_decl(ctx: *anyopaque, allocator: Allocator, node: *const Parser.ObjDecl) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    return try dupe(Sema.Decl, allocator, .{
        .obj = .{
            .name = node.id.value,
            .parent = if (node.extends) |extends| extends.id.value else null,
            .body = try move(
                Sema.Program,
                allocator,
                @ptrCast(
                    @alignCast(try node.body.program.visit(allocator, this.visitor()) orelse return null),
                ),
            ),
        },
    });
}

fn visit_obj_decl_extends(_: *anyopaque, _: Allocator, _: *const Parser.ObjDeclExtends) anyerror!?*anyopaque {
    unreachable;
}

fn visit_fn_decl(ctx: *anyopaque, allocator: Allocator, node: *const Parser.FnDecl) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    var params: ArrayList([]const u8) = .empty;
    defer params.deinit(allocator);

    try params.ensureTotalCapacity(allocator, node.params.len);
    for (node.params) |param| params.appendAssumeCapacity(param.id.value);

    return try dupe(Sema.Decl, allocator, .{
        .func = .{
            .name = node.id.value,
            .params = try params.toOwnedSlice(allocator),
            .body = try move(Sema.Program, allocator, @ptrCast(
                @alignCast(try node.body.program.visit(allocator, this.visitor()) orelse return null),
            )),
        },
    });
}

fn visit_fn_param(_: *anyopaque, _: Allocator, _: *const Parser.FnParam) anyerror!?*anyopaque {
    unreachable;
}

fn visit_var_decl(ctx: *anyopaque, allocator: Allocator, node: *const Parser.VarDecl) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    return try dupe(
        Sema.Decl,
        allocator,
        .{
            .variable = .{
                .name = node.id.value,
                .init = if (node.init) |ini| try move(
                    Sema.Expr,
                    allocator,
                    @ptrCast(@alignCast(try ini.expr.visit(allocator, this.visitor()) orelse return null)),
                ) else null,
            },
        },
    );
}

fn visit_var_decl_init(_: *anyopaque, _: Allocator, _: *const Parser.VarDeclInit) anyerror!?*anyopaque {
    unreachable;
}

fn visit_stmt(ctx: *anyopaque, allocator: Allocator, node: *const Parser.Stmt) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    return switch (node.*) {
        .expr_stmt => |*stmt| try stmt.visit(allocator, this.visitor()),
        .for_stmt => |*stmt| try stmt.visit(allocator, this.visitor()),
        .if_stmt => |stmt| try stmt.visit(allocator, this.visitor()),
        .print_stmt => |*stmt| try stmt.visit(allocator, this.visitor()),
        .return_stmt => |*stmt| try stmt.visit(allocator, this.visitor()),
        .while_stmt => |*stmt| try stmt.visit(allocator, this.visitor()),
        .block => |block| try block.visit(allocator, this.visitor()),
    };
}

fn visit_expr_stmt(ctx: *anyopaque, allocator: Allocator, node: *const Parser.ExprStmt) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    return try dupe(Sema.Stmt, allocator, .{
        .expr = try move(
            Sema.Expr,
            allocator,
            @ptrCast(@alignCast(try node.expr.visit(allocator, this.visitor()) orelse return null)),
        ),
    });
}

fn visit_for_stmt(ctx: *anyopaque, allocator: Allocator, node: *const Parser.ForStmt) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    return try dupe(Sema.Stmt, allocator, .{
        .@"for" = .{
            .init = init: {
                if (node.init) |*i| if (try i.visit(allocator, this.visitor())) |res|
                    break :init try move(Sema.ForStmt.Init, allocator, @ptrCast(@alignCast(res)));
                break :init null;
            },
            .condition = cond: {
                if (node.cond) |*cond| {
                    if (try cond.visit(allocator, this.visitor())) |res| {
                        break :cond @ptrCast(@alignCast(res));
                    }
                }
                break :cond null;
            },
            .increment = inc: {
                if (node.inc) |*inc| {
                    if (try inc.visit(allocator, this.visitor())) |res| {
                        break :inc @ptrCast(@alignCast(res));
                    }
                }
                break :inc null;
            },
            .body = @ptrCast(@alignCast(try node.body.visit(allocator, this.visitor()) orelse return null)),
        },
    });
}

fn visit_for_init(ctx: *anyopaque, allocator: Allocator, node: *const Parser.ForInit) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    return try dupe(Sema.ForStmt.Init, allocator, switch (node.*) {
        .@";" => return null,
        .var_decl => |*var_decl| .{
            .variable = (try move(
                Sema.Decl,
                allocator,
                @ptrCast(@alignCast(try var_decl.visit(allocator, this.visitor()) orelse return null)),
            )).variable,
        },
        .expr => |*expr_stmt| .{
            .expr = try move(
                Sema.Expr,
                allocator,
                @ptrCast(@alignCast(try expr_stmt.expr.visit(allocator, this.visitor()) orelse return null)),
            ),
        },
    });
}

fn visit_for_cond(ctx: *anyopaque, allocator: Allocator, node: *const Parser.ForCond) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));
    return switch (node.*) {
        .expr => |*expr_stmt| try expr_stmt.visit(allocator, this.visitor()),
        .@";" => null,
    };
}

fn visit_for_inc(ctx: *anyopaque, allocator: Allocator, node: *const Parser.ForInc) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));
    return try node.expr.visit(allocator, this.visitor());
}

fn visit_if_stmt(ctx: *anyopaque, allocator: Allocator, node: *const Parser.IfStmt) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    return try dupe(Sema.Stmt, allocator, .{
        .@"if" = .{
            .condition = @ptrCast(@alignCast(try node.cond.visit(allocator, this.visitor()) orelse return null)),
            .then_branch = @ptrCast(@alignCast(try node.main_branch.visit(allocator, this.visitor()) orelse return null)),
            .else_branch = if (node.else_branch) |*else_br|
                @ptrCast(@alignCast(try else_br.stmt.visit(allocator, this.visitor()) orelse return null))
            else
                null,
        },
    });
}

fn visit_if_else_branch(_: *anyopaque, _: Allocator, _: *const Parser.IfElseBranch) anyerror!?*anyopaque {
    unreachable;
}

fn visit_print_stmt(ctx: *anyopaque, allocator: Allocator, node: *const Parser.PrintStmt) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    const expr = try move(Sema.Expr, allocator, @ptrCast(@alignCast(
        try node.expr.visit(allocator, this.visitor()) orelse return null,
    )));

    return try dupe(Sema.Stmt, allocator, .{ .print = expr });
}

fn visit_return_stmt(ctx: *anyopaque, allocator: Allocator, node: *const Parser.ReturnStmt) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    return try dupe(Sema.Stmt, allocator, .{
        .@"return" = if (node.expr) |*expr| blk: {
            const expr_ptr: *Sema.Expr = @ptrCast(@alignCast(try expr.visit(allocator, this.visitor()) orelse return null));
            defer allocator.destroy(expr_ptr);
            break :blk expr_ptr.*;
        } else null,
    });
}

fn visit_while_stmt(ctx: *anyopaque, allocator: Allocator, node: *const Parser.WhileStmt) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    return try dupe(Sema.Stmt, allocator, .{
        .@"while" = .{
            .condition = @ptrCast(@alignCast(try node.cond.visit(allocator, this.visitor()) orelse return null)),
            .body = @ptrCast(@alignCast(try node.body.visit(allocator, this.visitor()) orelse return null)),
        },
    });
}

fn visit_block(ctx: *anyopaque, allocator: Allocator, node: *const Parser.Block) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    return try dupe(Sema.Stmt, allocator, .{
        .block = try move(
            Sema.Program,
            allocator,
            @ptrCast(@alignCast(try node.program.visit(allocator, this.visitor()) orelse return null)),
        ),
    });
}

fn visit_assign(ctx: *anyopaque, allocator: Allocator, node: *const Parser.Assign) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));
    const target: *Sema.Expr = @ptrCast(@alignCast(
        try node.logic_or.visit(allocator, this.visitor()) orelse
            return null,
    ));

    if (node.assign_expr) |assign_expr| {
        const value: *Sema.Expr = @ptrCast(@alignCast(
            try assign_expr.visit(allocator, this.visitor()) orelse
                return null,
        ));
        return try dupe(Sema.Expr, allocator, .{
            .assign = .{
                .target = target,
                .value = value,
            },
        });
    }

    return @ptrCast(target);
}

fn visit_assign_expr(ctx: *anyopaque, allocator: Allocator, node: *const Parser.AssignExpr) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));
    return try node.expr.visit(allocator, this.visitor());
}

fn visit_logic_or(ctx: *anyopaque, allocator: Allocator, node: *const Parser.LogicOr) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    var current: *Sema.Expr = @ptrCast(@alignCast(try node.first.visit(allocator, this.visitor()) orelse return null));

    for (node.suffixes) |*suffix| {
        const right: *Sema.Expr = @ptrCast(@alignCast(try suffix.logic_and.visit(allocator, this.visitor()) orelse return null));
        current = try dupe(Sema.Expr, allocator, .{
            .binary = .{
                .left = current,
                .op = .@"or",
                .right = right,
            },
        });
    }

    return @ptrCast(current);
}

fn visit_logic_or_expr(_: *anyopaque, _: Allocator, _: *const Parser.LogicOrExpr) anyerror!?*anyopaque {
    unreachable;
}

fn visit_logic_and(ctx: *anyopaque, allocator: Allocator, node: *const Parser.LogicAnd) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    var current: *Sema.Expr = @ptrCast(@alignCast(try node.first.visit(allocator, this.visitor()) orelse return null));

    for (node.suffixes) |*suffix| {
        const right: *Sema.Expr = @ptrCast(@alignCast(try suffix.equality.visit(allocator, this.visitor()) orelse return null));
        current = try dupe(Sema.Expr, allocator, .{
            .binary = .{
                .left = current,
                .op = .@"and",
                .right = right,
            },
        });
    }

    return @ptrCast(current);
}

fn visit_logic_and_expr(_: *anyopaque, _: Allocator, _: *const Parser.LogicAndExpr) anyerror!?*anyopaque {
    unreachable;
}

fn visit_equality(ctx: *anyopaque, allocator: Allocator, node: *const Parser.Equality) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    var current: *Sema.Expr = @ptrCast(@alignCast(
        try node.first.visit(allocator, this.visitor()) orelse return null,
    ));

    for (node.suffixes) |*suffix| {
        const right: *Sema.Expr = @ptrCast(@alignCast(
            try suffix.comparison.visit(allocator, this.visitor()) orelse
                return null,
        ));
        current = try dupe(Sema.Expr, allocator, .{
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

fn visit_equality_expr(_: *anyopaque, _: Allocator, _: *const Parser.EqualityExpr) anyerror!?*anyopaque {
    unreachable;
}

fn visit_comparison(ctx: *anyopaque, allocator: Allocator, node: *const Parser.Comparison) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    var current: *Sema.Expr = @ptrCast(@alignCast(
        try node.first.visit(allocator, this.visitor()) orelse return null,
    ));

    for (node.suffixes) |*suffix| {
        const right: *Sema.Expr = @ptrCast(@alignCast(
            try suffix.term.visit(allocator, this.visitor()) orelse return null,
        ));
        current = try dupe(Sema.Expr, allocator, .{
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

fn visit_comparison_expr(_: *anyopaque, _: Allocator, _: *const Parser.ComparisonExpr) anyerror!?*anyopaque {
    unreachable;
}

fn visit_term(ctx: *anyopaque, allocator: Allocator, node: *const Parser.Term) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    var current: *Sema.Expr = @ptrCast(@alignCast(try node.first.visit(allocator, this.visitor()) orelse return null));

    for (node.suffixes) |*suffix| {
        const right: *Sema.Expr = @ptrCast(@alignCast(try suffix.factor.visit(allocator, this.visitor()) orelse return null));
        current = try dupe(Sema.Expr, allocator, .{
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

fn visit_term_expr(_: *anyopaque, _: Allocator, _: *const Parser.TermExpr) anyerror!?*anyopaque {
    unreachable;
}

fn visit_factor(ctx: *anyopaque, allocator: Allocator, node: *const Parser.Factor) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    var current: *Sema.Expr = @ptrCast(@alignCast(try node.first.visit(allocator, this.visitor()) orelse return null));

    for (node.suffixes) |*suffix| {
        const right: *Sema.Expr = @ptrCast(@alignCast(try suffix.unary.visit(allocator, this.visitor()) orelse return null));
        current = try dupe(Sema.Expr, allocator, .{
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

fn visit_factor_expr(_: *anyopaque, _: Allocator, _: *const Parser.FactorExpr) anyerror!?*anyopaque {
    unreachable;
}

fn visit_unary(ctx: *anyopaque, allocator: Allocator, node: *const Parser.Unary) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    return switch (node.*) {
        inline else => |unary_expr| try unary_expr.visit(allocator, this.visitor()),
    };
}

fn visit_unary_expr(ctx: *anyopaque, allocator: Allocator, node: *const Parser.UnaryExpr) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    return try dupe(Sema.Expr, allocator, .{
        .unary = .{
            .op = switch (node.op.tag) {
                .@"-" => .@"-",
                .@"!" => .@"!",
                else => unreachable,
            },
            .operand = @ptrCast(@alignCast(try node.call.visit(allocator, this.visitor()) orelse return null)),
        },
    });
}

fn visit_call(ctx: *anyopaque, allocator: Allocator, node: *const Parser.Call) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    var current_expr: *Sema.Expr = @ptrCast(@alignCast(try node.primary.visit(allocator, this.visitor()) orelse return null));

    for (node.calls) |*call_expr| {
        current_expr = switch (call_expr.*) {
            .call_fn => |*call_fn| blk: {
                const args = try allocator.alloc(*Sema.Expr, call_fn.args.len);
                for (call_fn.args, 0..) |*arg, i| args[i] = @ptrCast(@alignCast(
                    try arg.visit(
                        allocator,
                        this.visitor(),
                    ) orelse return null,
                ));

                break :blk try dupe(Sema.Expr, allocator, .{
                    .call = .{
                        .callee = current_expr,
                        .args = args,
                    },
                });
            },
            .call_property => |*prop| try dupe(Sema.Expr, allocator, .{
                .property = .{
                    .object = current_expr,
                    .name = prop.id.value,
                },
            }),
        };
    }

    return @ptrCast(current_expr);
}

fn visit_call_expr(_: *anyopaque, _: Allocator, _: *const Parser.CallExpr) anyerror!?*anyopaque {
    unreachable;
}

fn visit_call_fn(_: *anyopaque, _: Allocator, _: *const Parser.CallFn) anyerror!?*anyopaque {
    unreachable;
}

fn visit_call_property(_: *anyopaque, allocator: Allocator, node: *const Parser.CallProperty) anyerror!?*anyopaque {
    return try dupe(Sema.Expr, allocator, .{ .identifier = node.id.value });
}

fn visit_fn_arg(ctx: *anyopaque, allocator: Allocator, node: *const Parser.FnArg) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));
    return node.expr.visit(allocator, this.visitor());
}

fn visit_primary(ctx: *anyopaque, allocator: Allocator, node: *const Parser.Primary) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));

    return switch (node.*) {
        .nil => try dupe(Sema.Expr, allocator, .nil),
        .this => try dupe(Sema.Expr, allocator, .this),
        .proto => try dupe(Sema.Expr, allocator, .proto),
        .true => try dupe(Sema.Expr, allocator, .{ .bool = true }),
        .false => try dupe(Sema.Expr, allocator, .{ .bool = false }),
        .number => |token| try dupe(Sema.Expr, allocator, .{
            .number = std.fmt.parseFloat(f64, token.value) catch {
                try this.sema.errors.append(
                    allocator,
                    Error.init(try fmt.allocPrint(
                        allocator,
                        "Invalid number literal: '{s}'",
                        .{token.value},
                    ), token.span),
                );
                return null;
            },
        }),
        .string => |token| try dupe(Sema.Expr, allocator, .{ .string = token.value }),
        .id => |token| try dupe(Sema.Expr, allocator, .{ .identifier = token.value }),
        .group_expr => |*group| try group.expr.visit(allocator, this.visitor()) orelse return null,
    };
}

fn visit_group_expr(ctx: *anyopaque, allocator: Allocator, node: *const Parser.GroupExpr) anyerror!?*anyopaque {
    const this: *@This() = @ptrCast(@alignCast(ctx));
    return node.expr.visit(allocator, this.visitor());
}
