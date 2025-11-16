const std = @import("std");
const Io = std.Io;
const testing = std.testing;
const assert = std.debug.assert;
const mem = std.mem;
const fmt = std.fmt;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const util = @import("util");
const t = util.term;
const p = @import("p");
const Tokenizer = p.Tokenizer;
const Token = Tokenizer.Token;

const Parser = @This();

pub const Error = struct {
    message: []const u8,
    span: Token.Span,
};

tokens: *Tokenizer,
errors: ArrayList(Error) = .empty,

pub fn init(tokens: *Tokenizer) Parser {
    return .{ .tokens = tokens };
}

pub fn deinit(this: *Parser, allocator: Allocator) void {
    this.errors.deinit(allocator);
}

pub fn parse(this: *Parser, allocator: Allocator) !?Program {
    return .parse(this, allocator);
}

pub fn reset(this: *Parser, allocator: Allocator) void {
    this.tokens.reset();
    this.errors.clearAndFree(allocator);
}

pub fn getErrors(this: *@This()) !?[]const Error {
    if (this.errors.items.len == 0) return null;
    return this.errors.items;
}

inline fn expectOrHandleErrorAndSync(this: *Parser, allocator: Allocator, comptime expected: anytype) !?Token {
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

pub const Program = struct {
    decls: []const Decl,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        var decls: ArrayList(Decl) = .empty;
        defer decls.deinit(allocator);

        while (parser.tokens.peek() != null) if (try Decl.parse(parser, allocator)) |decl| {
            try decls.append(allocator, decl);
        };

        return .{ .decls = try decls.toOwnedSlice(allocator) };
    }

    pub fn deinit(this: *@This(), allocator: Allocator) void {
        allocator.free(this.decls);
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitProgram(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const Decl = union(enum) {
    ObjDecl: ObjDecl,
    FnDecl: FnDecl,
    VarDecl: VarDecl,
    Stmt: Stmt,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        return switch (try parser.tokens.peek() orelse return null) {
            .object => .{ .ObjDecl = try ObjDecl.parse(parser, allocator) orelse return null },
            .@"fn" => .{ .FnDecl = try FnDecl.parse(parser, allocator) orelse return null },
            .let => .{ .VarDecl = try VarDecl.parse(parser, allocator) orelse return null },
            else => .{ .Stmt = try Stmt.parse(parser, allocator) orelse return null },
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitDecl(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
pub const ObjDecl = struct {
    object: Token,
    id: Token,
    extends: ?ObjDeclExtends,
    body: Block,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const object = try parser.expectOrHandleErrorAndSync(allocator, .{.object}) orelse return null;
        const id = try parser.expectOrHandleErrorAndSync(allocator, .{.identifier}) orelse return null;
        const extends: ?ObjDeclExtends = switch (try parser.tokens.peek() orelse return null) {
            .extends => try ObjDeclExtends.parse(parser, allocator) orelse return null,
            else => null,
        };
        const body = try Block.parse(parser, allocator) orelse return null;

        return .{
            .object = object,
            .id = id,
            .extends = extends,
            .body = body,
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitObjDecl(this);
    }
};
pub const ObjDeclExtends = struct {
    extends: Token,
    id: Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const extends = try parser.expectOrHandleErrorAndSync(allocator, .{.extends}) orelse return null;
        const id = try parser.expectOrHandleErrorAndSync(allocator, .{.identifier}) orelse return null;

        return .{ .extends = extends, .id = id };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitObjDeclExtends(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
pub const FnDecl = struct {
    @"fn": Token,
    id: Token,
    @"(": Token,
    params: []const FnParam,
    @")": Token,
    body: Block,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const @"fn" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"fn"}) orelse return null;
        const id = try parser.expectOrHandleErrorAndSync(allocator, .{.identifier}) orelse return null;
        const @"(" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"("}) orelse return null;

        var params: ArrayList(FnParam) = .empty;
        defer params.deinit(allocator);
        while (try FnParam.parse(parser, allocator)) |param|
            try params.append(allocator, param);

        const @")" = try parser.expectOrHandleErrorAndSync(allocator, .{.@")"}) orelse return null;
        const body = try Block.parse(parser, allocator) orelse return null;

        return .{
            .@"fn" = @"fn",
            .id = id,
            .@"(" = @"(",
            .params = params,
            .@")" = @")",
            .body = body,
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitFnDecl(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
pub const FnParam = struct {
    id: Token,
    @",": Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const id = try parser.expectOrHandleErrorAndSync(
            allocator,
            .{.identifier},
        ) orelse return null;
        const @"," = parser.tokens.expect(.{.@","});

        return .{ .id = id, .@"," = @"," };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitFnParam(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
pub const VarDecl = struct {
    let: Token,
    id: Token,
    init: ?VarDeclInit,
    @";": Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const let = try parser.expectOrHandleErrorAndSync(allocator, .{.let}) orelse return null;
        const id = try parser.expectOrHandleErrorAndSync(allocator, .{.identifier}) orelse return null;
        const initv: ?VarDeclInit = switch (try parser.tokens.peek() orelse return null) {
            .@"=" => try VarDeclInit.parse(parser, allocator) orelse return null,
            else => null,
        };
        const @";" = try parser.expectOrHandleErrorAndSync(allocator, .{.@";"}) orelse return null;

        return .{
            .let = let,
            .id = id,
            .init = initv,
            .@";" = @";",
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitVarDecl(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
pub const VarDeclInit = struct {
    @"=": Token,
    expr: Expr,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const @"=" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"="}) orelse return null;
        const expr = try Expr.parse(parser, allocator) orelse return null;

        return .{ .@"=" = @"=", .expr = &expr };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitVarDeclInit(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
pub const Stmt = union(enum) {
    expr_stmt: ExprStmt,
    for_stmt: ForStmt,
    if_stmt: IfStmt,
    print_stmt: PrintStmt,
    return_stmt: ReturnStmt,
    while_stmt: WhileStmt,
    block: Block,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        return switch (try parser.tokens.peek() orelse return null) {
            .@"for" => .{ .for_stmt = try ForStmt.parse(parser, allocator) orelse return null },
            .@"if" => .{ .if_stmt = try IfStmt.parse(parser, allocator) orelse return null },
            .print => .{ .print_stmt = try PrintStmt.parse(parser, allocator) orelse return null },
            .@"return" => .{ .return_stmt = try ReturnStmt.parse(parser, allocator) orelse return null },
            .@"while" => .{ .while_stmt = try WhileStmt.parse(parser, allocator) orelse return null },
            .@"{" => .{ .block = try Block.parse(parser, allocator) orelse return null },
            else => .{ .expr_stmt = try ExprStmt.parse(parser, allocator) orelse return null },
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitStmt(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const ExprStmt = struct {
    expr: *const Expr,
    @";": Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const expr = try Expr.parse(parser, allocator) orelse return null;
        const @";" = try parser.expectOrHandleErrorAndSync(allocator, .{.@";"}) orelse return null;

        return .{ .expr = &expr, .@";" = @";" };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitExprStmt(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
pub const ForStmt = struct {
    @"for": Token,
    @"(": Token,
    init: ?ForInit,
    @";": Token,
    cond: ?ForCond,
    @";'": Token,
    inc: ?ForInc,
    @")": Token,
    body: Block,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const @"for" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"for"}) orelse return null;
        const @"(" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"("}) orelse return null;

        const initv = try ForInit.parse(parser, allocator);
        const @";" = try parser.expectOrHandleErrorAndSync(allocator, .{.@";"}) orelse return null;

        const cond = try ForCond.parse(parser, allocator);
        const @";'" = try parser.expectOrHandleErrorAndSync(allocator, .{.@";"}) orelse return null;

        const inc = try ForInc.parse(parser, allocator);
        const @")" = try parser.expectOrHandleErrorAndSync(allocator, .{.@")"}) orelse return null;
        const body = try Block.parse(parser, allocator) orelse return null;

        return .{
            .@"for" = @"for",
            .@"(" = @"(",
            .init = initv,
            .@";" = @";",
            .cond = cond,
            .@";'" = @";'",
            .inc = inc,
            .@")" = @")",
            .body = body,
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitForStmt(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
pub const ForInit = union(enum) {
    var_decl: VarDecl,
    expr: Expr,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        return switch (try parser.tokens.peek() orelse return null) {
            .let => .{ .var_decl = try VarDecl.parse(parser, allocator) orelse return null },
            else => .{ .expr = try Expr.parse(parser, allocator) orelse return null },
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitForInit(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
pub const ForCond = Expr;
pub const ForInc = Expr;

pub const IfStmt = struct {
    @"if": Token,
    @"(": Token,
    cond: IfCond,
    @")": Token,
    main_branch: IfMainBranch,
    else_branch: ?IfElseBranch,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const @"if" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"if"}) orelse return null;
        const @"(" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"("}) orelse return null;
        const cond = try IfCond.parse(parser, allocator) orelse return null;
        const @")" = try parser.expectOrHandleErrorAndSync(allocator, .{.@")"}) orelse return null;
        const main_branch = try IfMainBranch.parse(parser, allocator) orelse return null;
        const else_branch = try IfElseBranch.parse(parser, allocator);

        return .{
            .@"if" = @"if",
            .@"(" = @"(",
            .cond = cond,
            .@")" = @")",
            .main_branch = main_branch,
            .else_branch = else_branch,
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitIfStmt(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
pub const IfCond = Expr;
pub const IfMainBranch = Stmt;
pub const IfElseBranch = struct {
    @"else": Token,
    stmt: Stmt,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const @"else" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"else"}) orelse return null;
        const stmt = try Stmt.parse(parser, allocator) orelse return null;

        return .{ .@"else" = @"else", .stmt = stmt };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitIfElseBranch(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const PrintStmt = struct {
    print: Token,
    @"(": Token,
    expr: Expr,
    @")": Token,
    @";": Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const print = try parser.expectOrHandleErrorAndSync(allocator, .{.print}) orelse return null;
        const @"(" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"("}) orelse return null;
        const expr = try Expr.parse(parser, allocator) orelse return null;
        const @")" = try parser.expectOrHandleErrorAndSync(allocator, .{.@")"}) orelse return null;
        const @";" = try parser.expectOrHandleErrorAndSync(allocator, .{.@";"}) orelse return null;

        return .{
            .print = print,
            .@"(" = @"(",
            .expr = &expr,
            .@")" = @")",
            .@";" = @";",
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitPrintStmt(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
pub const ReturnStmt = struct {
    @"return": Token,
    expr: ?Expr,
    @";": Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const @"return" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"return"}) orelse return null;
        const expr = try Expr.parse(parser, allocator);
        const @";" = try parser.expectOrHandleErrorAndSync(allocator, .{.@";"}) orelse return null;

        return .{
            .@"return" = @"return",
            .expr = expr,
            .@";" = @";",
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitReturnStmt(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const WhileStmt = struct {
    @"while": Token,
    @"(": Token,
    cond: Expr,
    @")": Token,
    body: Block,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const @"while" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"while"}) orelse return null;
        const @"(" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"("}) orelse return null;
        const cond = try Expr.parse(parser, allocator) orelse return null;
        const @")" = try parser.expectOrHandleErrorAndSync(allocator, .{.@")"}) orelse return null;
        const body = try Block.parse(parser, allocator) orelse return null;

        return .{
            .@"while" = @"while",
            .@"(" = @"(",
            .cond = &cond,
            .@")" = @")",
            .body = body,
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitWhileStmt(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const Block = struct {
    @"{": Token,
    stmts: []const Stmt,
    @"}": Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const @"{" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"{"}) orelse return null;

        var stmts: ArrayList(Stmt) = .empty;
        defer stmts.deinit(allocator);
        while (try Stmt.parse(parser, allocator)) |stmt|
            try stmts.append(allocator, stmt);

        const @"}" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"}"}) orelse return null;

        return .{
            .@"{" = @"{",
            .stmts = try stmts.toOwnedSlice(allocator),
            .@"}" = @"}",
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitBlock(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const Expr = Assign;

pub const Assign = union(enum) {
    assign_expr: *const AssignExpr,
    logic_or: *const LogicOr,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        if (try AssignExpr.parse(parser, allocator)) |expr|
            return .{ .assign_expr = try allocator.dupe(@This(), expr) };

        const logic_or = try LogicOr.parse(parser, allocator) orelse return null;
        return .{ .logic_or = try allocator.dupe(LogicOr, &logic_or) };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitAssign(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const AssignExpr = struct {
    target: AssignTarget,
    @"=": Token,
    value: Assign,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const target = try AssignTarget.parse(parser, allocator) orelse return null;
        const @"=" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"="}) orelse return null;
        const value = try Assign.parse(parser, allocator) orelse return null;

        return .{ .target = target, .op = @"=", .value = value };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitAssignExpr(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const AssignTarget = union(enum) {
    prop: AssignTargetProperty,
    id: Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        return switch (parser.tokens.peek() orelse return null) {
            .identifier => .{ .id = try parser.tokens.next().? },
            else => .{ .prop = try AssignTargetProperty.parse(parser, allocator) orelse return null },
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitAssignTarget(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const AssignTargetProperty = struct {
    call: Call,
    @".": Token,
    id: Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const call = try Call.parse(parser, allocator) orelse return null;
        const dot = try parser.expectOrHandleErrorAndSync(allocator, .{.@"."}) orelse return null;
        const id = try parser.expectOrHandleErrorAndSync(allocator, .{.identifier}) orelse return null;

        return .{ .call = call, .@"." = dot, .id = id };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitAssignTargetProperty(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const LogicOr = struct {
    first: LogicAnd,
    suffixes: []const LogicOrSuffix,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const first = try LogicAnd.parse(parser, allocator) orelse return null;

        var suffixes: ArrayList(LogicOrSuffix) = .empty;
        defer suffixes.deinit(allocator);
        while (try LogicOrSuffix.parse(parser, allocator)) |suffix|
            try suffixes.append(allocator, suffix);

        return .{
            .first = first,
            .suffixes = try suffixes.toOwnedSlice(allocator),
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitLogicOr(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const LogicOrSuffix = struct {
    op: LogicOrOp,
    logic_and: LogicAnd,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const op = try LogicOrOp.parse(parser, allocator) orelse return null;
        const logic_and = try LogicAnd.parse(parser, allocator) orelse return null;

        return .{ .op = op, .logic_and = logic_and };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitLogicOrSuffix(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const LogicOrOp = union(enum) {
    @"or": Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        return switch (try parser.tokens.peek() orelse return null) {
            .@"or" => .{ .@"or" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"or"}) orelse return null },
            else => return null,
        };
    }
    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitLogicOrOp(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const LogicAnd = struct {
    first: Equality,
    suffixes: []const LogicAndSuffix,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const first = try Equality.parse(parser, allocator) orelse return null;

        var suffixes: ArrayList(LogicAndSuffix) = .empty;
        defer suffixes.deinit(allocator);
        while (try LogicAndSuffix.parse(parser, allocator)) |suffix|
            try suffixes.append(allocator, suffix);

        return .{
            .first = first,
            .suffixes = try suffixes.toOwnedSlice(allocator),
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitLogicAnd(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const LogicAndSuffix = struct {
    op: LogicAndOp,
    equality: Equality,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const op = try LogicAndOp.parse(parser, allocator) orelse return null;
        const equality = try Equality.parse(parser, allocator) orelse return null;

        return .{ .op = op, .equality = equality };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitLogicAndSuffix(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const LogicAndOp = union(enum) {
    @"and": Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        return switch (try parser.tokens.peek() orelse return null) {
            .@"and" => .{ .@"and" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"and"}) orelse return null },
            else => return null,
        };
    }
    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitLogicAndOp(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const Equality = struct {
    first: Comparison,
    suffixes: []const EqualitySuffix,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const first = try Comparison.parse(parser, allocator) orelse return null;

        var suffixes: ArrayList(EqualitySuffix) = .empty;
        defer suffixes.deinit(allocator);
        while (try EqualitySuffix.parse(parser, allocator)) |suffix|
            try suffixes.append(allocator, suffix);

        return .{
            .first = first,
            .suffixes = try suffixes.toOwnedSlice(allocator),
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitEquality(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
pub const EqualitySuffix = struct {
    op: EqualityOp,
    comparison: Comparison,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const op = try EqualityOp.parse(parser, allocator) orelse return null;
        const comparison = try Comparison.parse(parser, allocator) orelse return null;

        return .{ .op = op, .comparison = comparison };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitEqualitySuffix(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};
pub const EqualityOp = union(enum) {
    @"!=": Token,
    @"==": Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        return switch (try parser.tokens.peek() orelse return null) {
            .@"!=" => .{ .@"!=" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"!="}) orelse return null },
            .@"==" => .{ .@"==" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"=="}) orelse return null },
            else => return null,
        };
    }
    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitEqualityOp(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const Comparison = struct {
    first: Term,
    suffixes: []const ComparisonSuffix,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const first = try Term.parse(parser, allocator) orelse return null;

        var suffixes: ArrayList(ComparisonSuffix) = .empty;
        defer suffixes.deinit(allocator);
        while (try ComparisonSuffix.parse(parser, allocator)) |suffix|
            try suffixes.append(allocator, suffix);

        return .{
            .first = first,
            .suffixes = try suffixes.toOwnedSlice(allocator),
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitComparison(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const ComparisonSuffix = struct {
    op: ComparisonOp,
    term: Term,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const op = try ComparisonOp.parse(parser, allocator) orelse return null;
        const term = try Term.parse(parser, allocator) orelse return null;

        return .{ .op = op, .term = term };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitComparisonSuffix(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const ComparisonOp = union(enum) {
    @">": Token,
    @">=": Token,
    @"<": Token,
    @"<=": Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        return switch (try parser.tokens.peek() orelse return null) {
            .@">" => .{ .@">" = try parser.expectOrHandleErrorAndSync(allocator, .{.@">"}) orelse return null },
            .@">=" => .{ .@">=" = try parser.expectOrHandleErrorAndSync(allocator, .{.@">="}) orelse return null },
            .@"<" => .{ .@"<" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"<"}) orelse return null },
            .@"<=" => .{ .@"<=" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"<="}) orelse return null },
            else => return null,
        };
    }
    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitComparisonOp(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const Term = struct {
    first: Factor,
    suffixes: []const TermSuffix,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const first = try Factor.parse(parser, allocator) orelse return null;

        var suffixes: ArrayList(TermSuffix) = .empty;
        defer suffixes.deinit(allocator);
        while (try TermSuffix.parse(parser, allocator)) |suffix|
            try suffixes.append(allocator, suffix);

        return .{
            .first = first,
            .suffixes = try suffixes.toOwnedSlice(allocator),
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitTerm(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const TermSuffix = struct {
    op: TermOp,
    factor: Factor,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const op = try TermOp.parse(parser, allocator) orelse return null;
        const factor = try Factor.parse(parser, allocator) orelse return null;

        return .{ .op = op, .factor = factor };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitTermSuffix(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const TermOp = union(enum) {
    plus: Token,
    minus: Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        return switch (try parser.tokens.peek() orelse return null) {
            .@"+" => .{ .plus = try parser.expectOrHandleErrorAndSync(allocator, .{.@"+"}) orelse return null },
            .@"-" => .{ .minus = try parser.expectOrHandleErrorAndSync(allocator, .{.@"-"}) orelse return null },
            else => return null,
        };
    }
    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitTermOp(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const Factor = struct {
    first: Unary,
    suffixes: []const FactorSuffix,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const first = try Unary.parse(parser, allocator) orelse return null;

        var suffixes: ArrayList(FactorSuffix) = .empty;
        defer suffixes.deinit(allocator);
        while (try FactorSuffix.parse(parser, allocator)) |suffix|
            try suffixes.append(allocator, suffix);

        return .{
            .first = first,
            .suffixes = try suffixes.toOwnedSlice(allocator),
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitFactor(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const FactorSuffix = struct {
    op: FactorOp,
    unary: Unary,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const op = try FactorOp.parse(parser, allocator) orelse return null;
        const unary = try Unary.parse(parser, allocator) orelse return null;

        return .{ .op = op, .unary = unary };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitFactorSuffix(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const FactorOp = union(enum) {
    mul: Token,
    div: Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        return switch (try parser.tokens.peek() orelse return null) {
            .@"*" => .{ .mul = try parser.expectOrHandleErrorAndSync(allocator, .{.@"*"}) orelse return null },
            .@"/" => .{ .div = try parser.expectOrHandleErrorAndSync(allocator, .{.@"/"}) orelse return null },
            else => return null,
        };
    }
    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitFactorOp(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const Unary = union(enum) {
    unary_expr: *const UnaryExpr,
    call: Call,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        return switch (try parser.tokens.peek() orelse return null) {
            .@"-", .@"!" => .{ .unary_expr = try allocator.dupe(UnaryExpr, try UnaryExpr.parse(parser, allocator) orelse return null) },
            else => .{ .call = try Call.parse(parser, allocator) orelse return null },
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitUnary(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const UnaryExpr = struct {
    op: UnaryOp,
    call: Unary,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const op = try UnaryOp.parse(parser, allocator);
        const call = try Call.parse(parser, allocator) orelse return null;

        return .{ .op = op, .call = call };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitUnaryExpr(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const UnaryOp = union(enum) {
    neg: Token,
    not: Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        return switch (try parser.tokens.peek() orelse return null) {
            .@"-" => .{ .neg = try parser.expectOrHandleErrorAndSync(allocator, .{.@"-"}) orelse return null },
            .@"!" => .{ .not = try parser.expectOrHandleErrorAndSync(allocator, .{.@"!"}) orelse return null },
            else => return null,
        };
    }
    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitUnaryOp(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const Call = struct {
    primary: Primary,
    calls: []const CallSuffix,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const primary = try Primary.parse(parser, allocator) orelse return null;

        var calls: ArrayList(CallSuffix) = .empty;
        defer calls.deinit(allocator);
        while (try CallSuffix.parse(parser, allocator)) |suffix|
            try calls.append(allocator, suffix);

        return .{
            .primary = primary,
            .calls = try calls.toOwnedSlice(allocator),
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitCall(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const CallSuffix = union(enum) {
    call_fn: CallFn,
    call_property: CallProperty,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        return switch (try parser.tokens.peek() orelse return null) {
            .@"(" => .{ .call_fn = try CallFn.parse(parser, allocator) orelse return null },
            .@"." => .{ .call_property = try CallProperty.parse(parser, allocator) orelse return null },
            else => return null,
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitCallSuffix(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const CallFn = struct {
    @"(": Token,
    args: []const FnArg,
    @")": Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const @"(" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"("}) orelse return null;

        var args: ArrayList(FnArg) = .empty;
        defer args.deinit(allocator);
        while (try FnArg.parse(parser, allocator)) |arg|
            try args.append(allocator, arg);

        const @")" = try parser.expectOrHandleErrorAndSync(allocator, .{.@")"}) orelse return null;

        return .{ .@"(" = @"(", .args = try args.toOwnedSlice(allocator), .@")" = @")" };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitCallFn(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const CallProperty = struct {
    @".": Token,
    id: Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const @"." = try parser.expectOrHandleErrorAndSync(allocator, .{.@"."}) orelse return null;
        const id = try parser.expectOrHandleErrorAndSync(allocator, .{.identifier}) orelse return null;

        return .{ .@"." = @".", .id = id };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitCallProperty(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const FnArg = struct {
    expr: Expr,
    @",": ?Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const expr = try Expr.parse(parser, allocator) orelse return null;
        const @"," = parser.tokens.expect(.{.@","});

        return .{ .expr = expr, .@"," = @"," };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitFnArg(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const Primary = union(enum) {
    true: Token,
    false: Token,
    nil: Token,
    this: Token,
    number: Token,
    string: Token,
    id: Token,
    group_expr: PrimaryGroupExpr,
    proto_access: PrimaryProtoAccess,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        return switch (try parser.tokens.peek() orelse return null) {
            .true => .{ .true = parser.tokens.next().? },
            .false => .{ .false = parser.tokens.next().? },
            .nil => .{ .nil = parser.tokens.next().? },
            .this => .{ .this = parser.tokens.next().? },
            .number => .{ .number = parser.tokens.next().? },
            .string => .{ .string = parser.tokens.next().? },
            .identifier => .{ .id = parser.tokens.next().? },
            .@"(" => .{ .group_expr = try PrimaryGroupExpr.parse(parser, allocator) orelse return null },
            .proto => .{ .proto_access = try PrimaryProtoAccess.parse(parser, allocator) orelse return null },
            else => return null,
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitPrimary(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const PrimaryGroupExpr = struct {
    @"(": Token,
    expr: Expr,
    @")": Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const @"(" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"("}) orelse return null;
        const expr = try Expr.parse(parser, allocator) orelse return null;
        const @")" = try parser.expectOrHandleErrorAndSync(allocator, .{.@")"}) orelse return null;

        return .{ .@"(" = @"(", .expr = &expr, .@")" = @")" };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitGroupExpr(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const PrimaryProtoAccess = struct {
    proto: Token,
    @".": Token,
    id: Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const proto = try parser.expectOrHandleErrorAndSync(allocator, .{.identifier}) orelse return null;
        const @"." = try parser.expectOrHandleErrorAndSync(allocator, .{.@"."}) orelse return null;
        const id = try parser.expectOrHandleErrorAndSync(allocator, .{.identifier}) orelse return null;

        return .{ .proto = proto, .@"." = @".", .id = id };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitProtoAccess(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

fn MakeFormat(T: type) type {
    return struct {
        depth: usize = 0,
        data: *const T,

        pub fn format(this: @This(), writer: *Io.Writer) Io.Writer.Error!void {
            const depth = this.depth;

            for (0..depth) |_| try writer.print(t.SEP, .{});
            try writer.print("{s}{s}{s}\n", .{ t.FG.BLUE, @typeName(T), t.RESET });

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

pub const Visitor = struct {
    ptr: *anyopaque,
    vtable: VTable,

    pub const VTable = struct {
        visitProgram: *const fn (this: *anyopaque, expr: *const Expr) *anyopaque,
    };

    pub fn visitProgram(this: *Visitor, expr: *const Expr) void {
        this.vtable.visitProgram(this.ptr, expr);
    }
};
