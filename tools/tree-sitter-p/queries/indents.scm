; Indent
[
  (block)
  (function_declaration)
  (object_declaration)
  (if_statement)
  (else_clause)
  (while_statement)
  (for_statement)
] @indent.begin

; Dedent
[
  "}"
] @indent.branch

; Ignore
[
  (comment)
  (string)
] @indent.ignore
