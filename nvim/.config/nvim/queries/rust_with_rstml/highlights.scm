; extends

((doctype_node) @constant
  (#set! "priority" 130))

(doctype_node
  [
    "<!"
    ">"
  ] @tag.delimiter
  (#set! "priority" 130))

(open_tag
  [
    "<"
    ">"
  ] @tag.delimiter
  (#set! "priority" 130))

(close_tag
  [
    "</"
    ">"
  ] @tag.delimiter
  (#set! "priority" 130))

(self_closing_element_node
  [
    "<"
    "/>"
  ] @tag.delimiter
  (#set! "priority" 130))

(node_identifier
  [
    "-"
    ":"
    "::"
  ] @punctuation.delimiter
  (#set! "priority" 130))

(open_tag
  name: (node_identifier) @tag
  (#set! "priority" 130))

(close_tag
  name: (node_identifier) @tag
  (#set! "priority" 130))

(self_closing_element_node
  name: (node_identifier) @tag
  (#set! "priority" 130))

((node_identifier) @tag.attribute
  (#set! "priority" 130))

(node_attribute
  name: (node_identifier) @tag.attribute
  (#set! "priority" 130))

(generic_identifier
  [
    [
      "<"
      ">"
    ] @punctuation.delimiter
    (node_identifier) @tag
  ]
  (#set! "priority" 130))

((text_node) @variable
  (#set! "priority" 130))

(comment_node
  [
    "<!--"
    "-->"
  ] @comment
  (#set! "priority" 130))
