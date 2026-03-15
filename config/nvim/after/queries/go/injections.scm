; extends

; SQL in raw string literals (backticks)
((raw_string_literal
  (raw_string_literal_content) @injection.content)
  (#lua-match? @injection.content "^%s*SELECT")
  (#set! injection.language "sql"))
((raw_string_literal
  (raw_string_literal_content) @injection.content)
  (#lua-match? @injection.content "^%s*INSERT")
  (#set! injection.language "sql"))
((raw_string_literal
  (raw_string_literal_content) @injection.content)
  (#lua-match? @injection.content "^%s*UPDATE")
  (#set! injection.language "sql"))
((raw_string_literal
  (raw_string_literal_content) @injection.content)
  (#lua-match? @injection.content "^%s*DELETE")
  (#set! injection.language "sql"))
((raw_string_literal
  (raw_string_literal_content) @injection.content)
  (#lua-match? @injection.content "^%s*CREATE")
  (#set! injection.language "sql"))
((raw_string_literal
  (raw_string_literal_content) @injection.content)
  (#lua-match? @injection.content "^%s*ALTER")
  (#set! injection.language "sql"))
((raw_string_literal
  (raw_string_literal_content) @injection.content)
  (#lua-match? @injection.content "^%s*DROP")
  (#set! injection.language "sql"))
((raw_string_literal
  (raw_string_literal_content) @injection.content)
  (#lua-match? @injection.content "^%s*WITH")
  (#set! injection.language "sql"))
((raw_string_literal
  (raw_string_literal_content) @injection.content)
  (#lua-match? @injection.content "^%s*MERGE")
  (#set! injection.language "sql"))

; SQL in interpreted string literals (double quotes)
((interpreted_string_literal
  (interpreted_string_literal_content) @injection.content)
  (#lua-match? @injection.content "^%s*SELECT")
  (#set! injection.language "sql"))
((interpreted_string_literal
  (interpreted_string_literal_content) @injection.content)
  (#lua-match? @injection.content "^%s*INSERT")
  (#set! injection.language "sql"))
((interpreted_string_literal
  (interpreted_string_literal_content) @injection.content)
  (#lua-match? @injection.content "^%s*UPDATE")
  (#set! injection.language "sql"))
((interpreted_string_literal
  (interpreted_string_literal_content) @injection.content)
  (#lua-match? @injection.content "^%s*DELETE")
  (#set! injection.language "sql"))
