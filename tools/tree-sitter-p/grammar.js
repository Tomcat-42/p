/**
 * @file Tree-sitter grammar for the P programming language.
 * @author Pablo Hugen <phugen@redhat.com>
 * @license MIT
 */

/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

module.exports = grammar({
  name: "p",

  extras: $ => [
    /\s/,
    $.comment,
  ],

  rules: {
    // Program = { Decl };
    source_file: $ => repeat($.declaration),

    comment: $ => token(choice(
      seq('//', /.*/),
      seq('/*', /[^*]*\*+([^/*][^*]*\*+)*/, '/')
    )),

    // Decl = ObjDecl | FnDecl | VarDecl | Stmt;
    declaration: $ => choice(
      $.object_declaration,
      $.function_declaration,
      $.variable_declaration,
      $.statement,
    ),

    // ObjDecl = "object", ID, [ ObjDeclExtends ], Block;
    object_declaration: $ => seq(
      'object',
      field('name', $.identifier),
      optional($.extends_clause),
      field('body', $.block),
    ),

    // ObjDeclExtends = "extends", ID;
    extends_clause: $ => seq(
      'extends',
      field('parent', $.identifier),
    ),

    // FnDecl = "fn", ID, "(", { FnParam }, ")", Block;
    function_declaration: $ => seq(
      'fn',
      field('name', $.identifier),
      '(',
      optional(seq(
        $.function_parameter,
        repeat(seq(',', $.function_parameter)),
        optional(','),
      )),
      ')',
      field('body', $.block),
    ),

    // FnParam = ID, [ "," ];
    function_parameter: $ => field('parameter', $.identifier),

    // VarDecl = "let", ID, [ VarDeclInit ], ";";
    variable_declaration: $ => seq(
      'let',
      field('name', $.identifier),
      optional($.variable_initializer),
      ';',
    ),

    // VarDeclInit = "=", Expr;
    variable_initializer: $ => seq(
      '=',
      field('value', $.expression),
    ),

    // Stmt = ExprStmt | ForStmt | IfStmt | PrintStmt | ReturnStmt | WhileStmt | Block;
    statement: $ => choice(
      $.expression_statement,
      $.for_statement,
      $.if_statement,
      $.print_statement,
      $.return_statement,
      $.while_statement,
      $.block,
    ),

    // ExprStmt = Expr, ";";
    expression_statement: $ => seq(
      $.expression,
      ';',
    ),

    // ForStmt = "for", "(", [ ForInit ], ";", [ ForCond ], ";", [ ForIncr ], ")", Stmt;
    for_statement: $ => seq(
      'for',
      '(',
      optional(field('initializer', $.for_initializer)),
      ';',
      optional(field('condition', $.for_condition)),
      ';',
      optional(field('increment', $.for_increment)),
      ')',
      field('body', $.statement),
    ),

    // ForInit = ("let", ID, [ VarDeclInit ]) | Expr;
    for_initializer: $ => choice(
      seq(
        'let',
        field('name', $.identifier),
        optional($.variable_initializer),
      ),
      $.expression,
    ),

    // ForCond = Expr;
    for_condition: $ => $.expression,

    // ForIncr = Expr;
    for_increment: $ => $.expression,

    // IfStmt = "if", "(", IfCond, ")", Stmt, [ IfElseBranch ];
    if_statement: $ => prec.right(seq(
      'if',
      '(',
      field('condition', $.expression),
      ')',
      field('consequence', $.statement),
      optional(field('alternative', $.else_clause)),
    )),

    // IfElseBranch = "else", Stmt;
    else_clause: $ => seq(
      'else',
      $.statement,
    ),

    // PrintStmt = "print", "(", Expr, ")", ";";
    print_statement: $ => seq(
      'print',
      '(',
      field('argument', $.expression),
      ')',
      ';',
    ),

    // ReturnStmt = "return", [ Expr ], ";";
    return_statement: $ => seq(
      'return',
      optional(field('value', $.expression)),
      ';',
    ),

    // WhileStmt = "while", "(", Expr, ")", Stmt;
    while_statement: $ => seq(
      'while',
      '(',
      field('condition', $.expression),
      ')',
      field('body', $.statement),
    ),

    // Block = "{", { Decl }, "}";
    block: $ => seq(
      '{',
      repeat($.declaration),
      '}',
    ),

    // Expr = Assign;
    expression: $ => $.assignment_expression,

    // Assign = LogicOr, [ AssignExpr ];
    assignment_expression: $ => prec.right(1, choice(
      $.logical_or_expression,
      seq(
        field('left', $.logical_or_expression),
        '=',
        field('right', $.assignment_expression),
      ),
    )),

    // LogicOr = LogicAnd, { LogicOrExpr };
    logical_or_expression: $ => prec.left(2, choice(
      $.logical_and_expression,
      seq(
        field('left', $.logical_or_expression),
        field('operator', 'or'),
        field('right', $.logical_and_expression),
      ),
    )),

    // LogicAnd = Equality, { LogicAndExpr };
    logical_and_expression: $ => prec.left(3, choice(
      $.equality_expression,
      seq(
        field('left', $.logical_and_expression),
        field('operator', 'and'),
        field('right', $.equality_expression),
      ),
    )),

    // Equality = Comparison, { EqualityExpr };
    equality_expression: $ => prec.left(4, choice(
      $.comparison_expression,
      seq(
        field('left', $.equality_expression),
        field('operator', choice('==', '!=')),
        field('right', $.comparison_expression),
      ),
    )),

    // Comparison = Term, { ComparisonExpr };
    comparison_expression: $ => prec.left(5, choice(
      $.term_expression,
      seq(
        field('left', $.comparison_expression),
        field('operator', choice('>', '>=', '<', '<=')),
        field('right', $.term_expression),
      ),
    )),

    // Term = Factor, { TermExpr };
    term_expression: $ => prec.left(6, choice(
      $.factor_expression,
      seq(
        field('left', $.term_expression),
        field('operator', choice('+', '-')),
        field('right', $.factor_expression),
      ),
    )),

    // Factor = Unary, { FactorExpr };
    factor_expression: $ => prec.left(7, choice(
      $.unary_expression,
      seq(
        field('left', $.factor_expression),
        field('operator', choice('*', '/')),
        field('right', $.unary_expression),
      ),
    )),

    // Unary = UnaryExpr | Call;
    unary_expression: $ => choice(
      $.call_expression,
      prec(8, seq(
        field('operator', choice('!', '-')),
        field('operand', $.unary_expression),
      )),
    ),

    // Call = Primary, { CallExpr };
    call_expression: $ => prec.left(9, choice(
      $.primary_expression,
      seq(
        field('function', $.call_expression),
        '(',
        optional(seq(
          $.call_argument,
          repeat(seq(',', $.call_argument)),
          optional(','),
        )),
        ')',
      ),
      seq(
        field('object', $.call_expression),
        '.',
        field('property', $.identifier),
      ),
    )),

    // FnArg = Expr, [ "," ];
    call_argument: $ => $.expression,

    // Primary = "true" | "false" | "nil" | "this" | "proto" | NUMBER | STRING | ID | GroupExpr;
    primary_expression: $ => choice(
      $.true,
      $.false,
      $.nil,
      $.this,
      $.proto,
      $.number,
      $.string,
      $.identifier,
      $.parenthesized_expression,
    ),

    // GroupExpr = "(", Expr, ")";
    parenthesized_expression: $ => seq(
      '(',
      $.expression,
      ')',
    ),

    // Keywords
    true: $ => 'true',
    false: $ => 'false',
    nil: $ => 'nil',
    this: $ => 'this',
    proto: $ => 'proto',

    // NUMBER = DIGIT, { DIGIT }, [ ".", DIGIT, { DIGIT } ];
    number: $ => token(seq(
      /[0-9]+/,
      optional(seq('.', /[0-9]+/)),
    )),

    // STRING = '"', { ALPHA | DIGIT }, '"';
    string: $ => token(seq(
      '"',
      repeat(choice(
        /[a-zA-Z0-9_]/,
        /[^\\"]/,
      )),
      '"',
    )),

    // ID = ALPHA, { ALPHA | DIGIT };
    identifier: $ => /[a-zA-Z_][a-zA-Z0-9_]*/,
  }
});
