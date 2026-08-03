# Changelog

All notable changes to keen-docs are documented here. Format based on
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/). This is a pre-release POC, so
everything lives under Unreleased until the first tagged version.

## [Unreleased]

### Changed — Authoring model: liveness is a directive, not a fence flag (2026-08-03)

The fence header used to carry two orthogonal things — *language* (`html`) and *role*
(`demo`/`run`/`example`) — so a one-word flag silently flipped a code block into a live
app. Retired the role flags; the vocabulary is now fully directive-driven:

- **`:::demo`** — mounts the markup live and shows its source (was ` ```html demo `).
- **`:::run`** — behavior JS bound to the preceding demo, emitted to the footer (was
  ` ```js run `).
- **`:::code{lang=…}`** — a highlighted code block (was ` ```lang example ` / plain fence).

`KeenDocs.Extensions.Demo` is now directive-based; the config vocabulary swaps
`KeenMarkdown.Extensions.Example` → `.Code`. Backed by keen-markdown's new **raw-body
directive** support (see that repo's changelog) — a raw directive captures its body
verbatim, so `:::code` can show `:::demo`/fence syntax without it being parsed. Seed
(`999_examples.sql`) and the POC sample migrated to the new syntax.

### Added — `:::app` islands mount live in the harness (2026-08-03)

The harness now mounts a real keen-phoenix-svelte island on a plain (non-LiveView) page:

- Serves the esbuild-bundled client runtime at **`/apps_runtime.js`** and island bundles at
  **`/apps/:name/main.mjs`** (both `text/javascript`), via `KeenDocs.Web.Router`.
- `config :keen_docs, KeenDocs.Extensions.App, runtime: "/apps_runtime.js"` → the App
  extension emits a footer `mountStatic()` bootstrap + `#keen-apps` manifest + modulepreload.
- New seed page `web-multiselect/2.0.0/islands` mounts the **real published apps** from the
  external CDN `apps.keen-phoenix-svelte.keenmate.dev` — `hello` (single-file), `metrics`
  (multi-file, self-resolves its CSS/JSON via `import.meta.url`) and `dashboard` (code-split,
  lazy-loads view chunks) — imported `:direct` via the page's front-matter `apps:` map, with
  `crossorigin` modulepreloads. A local `hello` bundle in `priv/web/apps/` remains as the
  served-locally example.
- Corrects the earlier assumption that islands require LiveView — `mountStatic()` is a
  first-class path for plain pages (LiveView only adds the live channel bridge).

### Added — Full-text index inspector (2026-08-03)

The document page now renders a collapsible **🔍 search index** panel showing exactly what
the full-text layer indexed for that page — the front-matter keywords (weight B) and the
prose extracted from the markdown (weight C), with directive syntax, fenced code and HTML
chrome stripped. Backed by the new `public.get_document_index/3` (via `KeenDocs.Content`).
The raw markdown is stored but never what gets searched — see the DB changelog for the
`markdown_to_search_text` / weighted-`tsvector` / keyword-folding work behind it.

### Added — Web test harness (2026-08-03)

A minimal, browsable web layer over the content database — Plug on Bandit (the substrate
Phoenix runs on), so it promotes to full Phoenix + LiveView later without rework.

- **`KeenDocs.Application`** — supervises `KeenDocs.Repo` + the Bandit/Plug server
  (`config :keen_docs, KeenDocs.Web, port: 4000`).
- **`KeenDocs.Content`** — the data API (`use KeenDocs.Database, repo: KeenDocs.Repo`) plus
  `rows/1`/`one/1` helpers.
- **`KeenDocs.Web.Router` / `.View`** — routes exercising every aspect over the live
  `public.*` functions: `/` hub, `/:set` variant nav, `/:set/:variant/:slug` rendered document
  (markdown → `KeenMarkdown.render` → head/body/footer regions), `/:set/:seg` (guide pretty-URL
  vs variant landing, decided from `show_in_path`), `/search?q=&kind=`, and `/resolve`
  (paste a `package.json` → matched `doc_set` + version resolution via `applies_to`, with fallback).
- **`Makefile`** — `dev` (harness, frees the port first via `kill-port`), `iex`, `db-gen`,
  `demo`, `poc`, `deps`, `test`, `clean`; `kill-port` mirrors `../web-multiselect`.
- **`tmp/docs_variant_demo.exs`** — read-only visualizer over the seeded content (nav tree,
  URL construction, `package.json` → doc-version resolution).
- Deps: `{:plug, "~> 1.16"}`, `{:bandit, "~> 1.0"}`.

### Added — Database layer (P7, for real) (2026-08-03)

Persistence via stored SQL functions + raw Postgrex + code generation — **no Ecto** (mirrors
`../keen-auth-permissions`). The SQL lives in `../keen-docs-database` (managed by debee); this
repo consumes it. See that repo's changelog for the schema (`doc_set → doc_variant → document`,
content-addressed `content_blob`, package resolution, fulltext search).

- **`KeenDocs.Repo`** — thin Postgrex wrapper (`start_link/1`, `query/2`, `query!/2`,
  `child_spec/1`, `after_connect` sets `search_path`). Config in `config :keen_docs, KeenDocs.Repo`.
- **`KeenDocs.PostgrexTypes`** — `Postgrex.Types.define(..., json: Jason)` so jsonb params/returns
  encode as maps.
- **`KeenDocs.Database.*`** — db-gen-generated typed wrappers (`db-gen.json` + `db-gen/*.gotmpl`
  retargeted from keen-auth-permissions to the `KeenDocs.Database` namespace / `lib/keen_docs/database/`).
  `public`-schema functions generate with no prefix (`KeenDocs.Content.ensure_document/10`, …).
- Dep: `{:postgrex, "~> 0.19"}`. Update loop: `make setup` (in keen-docs-database) → `make db-gen`.

### Added — Markdown → live-docs POC pipeline

The core proof: a custom markdown superset (YAML front matter + `:::` container directives +
role-flagged code fences) rendering to real, live component demos. The rendering **engine was
extracted** to `../keen-markdown` (`KeenMarkdown`); this repo is its first consumer and adds only
the docs-specific extensions (`lib/keen_docs/extensions/`: `demo`, `cdn_package`, `app`) plus
`KeenDocs.POC` (the standalone-page shell, `mix run -e "KeenDocs.POC.build()"`).

Proven POC spikes (details in `DESIGN.md` §8): live CDN web-component demos, keen-phoenix-svelte
islands, generic data endpoint, publish/ingest + content-hash dedup, multi-version + domain-scoped
routing, CEM → API reference, and the Postgres fulltext layer (now delivered for real, above).

### Changed

- `DESIGN.md` — kept as the architecture of record; §8 documents the `doc_variant` content model
  and toolchain, §9 marks the web harness as the first cut of "Phoenix-ify".
