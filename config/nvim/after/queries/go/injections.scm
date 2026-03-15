; extends

; SQL in raw string literals (backticks)
((raw_string_literal
  (raw_string_literal_content) @injection.content)
  (#sql-keyword? @injection.content)
  (#set! injection.language "sql"))

; SQL in interpreted string literals (double quotes)
((interpreted_string_literal
  (interpreted_string_literal_content) @injection.content)
  (#sql-keyword? @injection.content)
  (#set! injection.language "sql"))
