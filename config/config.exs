import Config

# Use the Lumis engine for MDEx server-side syntax highlighting.
config :mdex_native, syntax_highlighter: :lumis

# Markdown extensions installed at server level. Content bundles are pure data and
# never register their own — they use whatever is listed here (DESIGN.md §4/§5).
# The layout, block and demo vocabularies are themselves extensions, so the built-ins
# exercise the same contract a third-party extension would.
config :keen_docs,
  extensions: [
    KeenDocs.Extensions.Layout,
    KeenDocs.Extensions.Blocks,
    KeenDocs.Extensions.Demo,
    KeenDocs.Extensions.App,
    KeenDocs.Extensions.Mermaid,
    KeenDocs.Extensions.OpenGraph,
    KeenDocs.Extensions.CdnPackage
  ]

# keen-phoenix-svelte islands mounted by `:::app`. `base_path` mirrors
# `KeenPhoenixSvelte.Apps.base_path/0`; `runtime` stays nil because a real Phoenix page
# calls `mountStatic()` from its own app.js — set it only for standalone pages.
config :keen_docs, KeenDocs.Extensions.App,
  base_path: "/apps",
  context: %{},
  runtime: nil
