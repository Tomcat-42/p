; Keywords
[
  "fn"
  "let"
  "if"
  "else"
  "for"
  "while"
  "return"
  "print"
  "object"
  "extends"
] @keyword

; Functions
(function_declaration
  name: (identifier) @function)

(call_expression
  (primary_expression (identifier) @function.call))

; Variables
(variable_declaration
  name: (identifier) @variable)

(function_parameter
  parameter: (identifier) @variable.parameter)

; Literals
(number) @number
(string) @string
(true) @constant.builtin.boolean
(false) @constant.builtin.boolean
(nil) @constant.builtin

; Operators
"=" @operator
"+" @operator
"-" @operator
"*" @operator
"/" @operator
"==" @operator
"!=" @operator
"<" @operator
">" @operator
"<=" @operator
">=" @operator
"!" @operator

; Punctuation
"(" @punctuation.bracket
")" @punctuation.bracket
"{" @punctuation.bracket
"}" @punctuation.bracket
";" @punctuation.delimiter
"," @punctuation.delimiter
"." @punctuation.delimiter

; Comments
(comment) @comment
