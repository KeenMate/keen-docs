# Postgrex types module so jsonb params/columns encode from and decode to Elixir maps
# (the docs.* functions take/return jsonb — frontmatter, _search_criteria, _search_settings).
# Defined at compile time via the Postgrex.Types.define/3 macro.
Postgrex.Types.define(KeenDocs.PostgrexTypes, [], json: Jason)
