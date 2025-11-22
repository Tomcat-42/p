; Scopes
[
  (function_declaration)
  (block)
  (for_statement)
  (while_statement)
] @local.scope

; Definitions
(function_declaration
  name: (identifier) @local.definition.function)

(variable_declaration
  name: (identifier) @local.definition.var)

(function_parameter
  parameter: (identifier) @local.definition.parameter)

; References
(identifier) @local.reference
