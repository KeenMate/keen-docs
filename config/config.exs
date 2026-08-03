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
    KeenMarkdown.Extensions.Code,
    KeenMarkdown.Extensions.Mermaid,
    KeenMarkdown.Extensions.OpenGraph,
    KeenDocs.Extensions.Demo,
    KeenDocs.Extensions.CdnPackage,
    KeenDocs.Extensions.App
  ]

# keen-phoenix-svelte islands mounted by `:::app`. `base_path` mirrors
# `KeenPhoenixSvelte.Apps.base_path/0`. This harness is a plain (non-LiveView) page, so it
# sets `runtime` to the esbuild-bundled keen-phoenix-svelte client (served at
# /apps_runtime.js by KeenDocs.Web.Router); the App extension emits a footer bootstrap that
# imports it and calls mountStatic(), which mounts every island under /apps/<name>/main.mjs.
config :keen_docs, KeenDocs.Extensions.App,
  base_path: "/apps",
  context: %{site: "keen-docs harness"},
  runtime: "/apps_runtime.js"

# DB connection for KeenDocs.Repo (raw Postgrex — no Ecto). Targets the `keen_docs`
# database built by debee in ../keen-docs-database; mirrors the db-gen connection in
# .local.db-gen.json (role name == password == "keen_docs"). Dev-targeting for now —
# move to env-specific config (dev/runtime) when the app is Phoenix-ified.
config :keen_docs, KeenDocs.Repo,
  hostname: "db-01.km8.local",
  port: 5432,
  username: "keen_docs",
  password: "keen_docs",
  database: "keen_docs"
