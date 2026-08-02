import Config

# Use the Lumis engine for MDEx server-side syntax highlighting. This configures the
# :mdex_native application (highlighting is opt-in; the precompiled NIF bundles no
# engine), so the running app must set it even though keen_markdown carries the code.
config :mdex_native, syntax_highlighter: :lumis

# The markdown vocabulary available to content, assembled from the keen_markdown generic
# set plus keen-docs' own docs-specific extensions (live demos, CDN packages, islands).
# Content bundles are pure data and never register their own — they use what is listed
# here. Both the built-ins and keen-docs' extensions exercise the same behaviour.
config :keen_markdown,
  extensions: [
    KeenMarkdown.Extensions.Layout,
    KeenMarkdown.Extensions.Blocks,
    KeenMarkdown.Extensions.Example,
    KeenMarkdown.Extensions.Mermaid,
    KeenMarkdown.Extensions.OpenGraph,
    KeenDocs.Extensions.Demo,
    KeenDocs.Extensions.CdnPackage,
    KeenDocs.Extensions.App
  ]

# keen-phoenix-svelte islands mounted by `:::app`. `base_path` mirrors
# `KeenPhoenixSvelte.Apps.base_path/0`; `runtime` stays nil because a real Phoenix page
# calls `mountStatic()` from its own app.js — set it only for standalone pages.
config :keen_docs, KeenDocs.Extensions.App,
  base_path: "/apps",
  context: %{},
  runtime: nil
