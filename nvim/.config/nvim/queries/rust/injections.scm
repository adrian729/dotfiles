; extends

((macro_invocation
  macro: (identifier) @_macro
  (token_tree) @injection.content)
  (#eq? @_macro "html")
  (#set! injection.language "rstml")
  (#set! injection.include-children))
