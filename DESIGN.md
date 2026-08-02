# keen-docs — Design & Roadmap

> Status: **early / POC**. This document captures the vision, architecture decisions,
> and next steps for keen-docs. It is the source of truth for *why* — code comments cover *how*.

## 1. What this is

keen-docs is an Elixir/Phoenix **docs + showcase engine** for KeenMate's component
libraries (`web-*` web components, `svelte-*` packages). It is the "done better" rewrite of
[`../svelte-docs`](../svelte-docs).

The defining capability: documentation pages contain **real, live component demos that talk to a
real server** (store/load data, fulltext search, form round-trips) — not screenshots, not
client-only toys. This is now possible because of [`../keen-phoenix-svelte`](../keen-phoenix-svelte),
which mounts compiled front-end apps as islands into Phoenix pages (LiveView *or* plain controller)
with an `api`/`live`/`channel` bridge to the backend.

## 2. History & motivation

- `../svelte-docs` is a SvelteKit npm lib (`@keenmate/svelte-docs`) of docs+showcase components
  (`DocLayout`, `ShowcaseSection`, `CodeShowcase`, `ConfigProvider`, …), consumed by per-package
  **static** showcase repos like `../web-multiselect-showcase` → deployed to e.g.
  `web-multiselect.keenmate.dev`.
- It began because mkdocs and friends couldn't render live Svelte apps / real use cases.
- Its limits (see §3) — no live server-backed demos, no multi-version docs, and an SSG-shaped
  architecture — are what keen-docs exists to fix.

## 3. Problems in svelte-docs that keen-docs fixes

| Problem | Why it exists | keen-docs fix |
|---|---|---|
| **Global singleton config store** (`stores/config.svelte.ts` mutated during render, read directly by `DocLayout`) — SSR state-leak anti-pattern | An npm lib can't prop-drill config through consumer-authored routes | Per-request rendering; config is request/domain-scoped |
| **Client-side syntax highlighting** (hljs in `$effect`, `CodeRenderer` builds DOM in `onMount`) → code flashes plain then highlights | Lib renders in the browser, can't run a build-time pass over arbitrary content | **Server-side highlighting** (MDEx/lumis) — no FOUC, no client hljs |
| **Meta tags handled twice** (declarative `svelte:head` + imperative DOM) + inline FOUC-prevention style blob | Working around SSG/hydration | Rendered once, server-side |
| **No multi-version docs** | — | Version = a published content bundle; demo runtime pinned via CDN version |
| **Demos aren't real** | Static SvelteKit can't hit a server | Live islands + generic server endpoints |

## 4. Target architecture

**One central multi-tenant Phoenix app** — *not* a Hex library consumed by per-package apps, and
*not* per-package deploys. Modeled on `../pure-admin-cli`'s publish flow.

1. **Content repos = pure data.** e.g. `web-multiselect-docs` (does not exist yet): a
   **folder-per-version** tree of custom markdown + a manifest + assets. No server code.
2. **`keendocs` CLI (Node, npm `@keenmate/keendocs`).** `keendocs publish` packs a version into a
   zip + manifest and uploads to the central app via an API key. Mirrors
   `../pure-admin-cli/lib/commands/theme-publish.js`: pack → multipart POST `/api/.../upload` →
   server content-hash dedup (`updated`/`unchanged`), `426` version-gates the CLI.
3. **Central app, bound to many domains.** `docs.keenmate.dev` = aggregate dashboard + cross-library
   search; `web-multiselect.keenmate.dev` = the *same app* scoped to one package (header links back to
   the hub). Domain = tenant scope, one shared DB.
4. **One central DB** → users get **one place** for profiles, favorites, notes, and fulltext search
   across all libraries (not spread over per-package sites). Auth likely via
   `../keen-auth-permissions`.

This dissolves the old docs-vs-showcase duality: a package's standalone site and the aggregated hub
are the same app at two domain scopes, not two builds.

### The hard problem: "real" endpoints without content-defined endpoints

Demos need real data, but content repos are pure data and must **not** define server endpoints. So
keen-docs provides **generic, component-agnostic endpoints organized by data shape**, and demo apps
are coded against this documented contract:

- **List/search datasets** — `GET /api/data/:set?q=&page=&size=` (languages, countries, users, …) → multiselect, async-search, grid
- **Hierarchical** — `GET /api/tree/:set?parent=` → treeview
- **Per-session sandbox key-value/doc store** — `POST/PUT/GET /api/sandbox/:ns/:key`, auto-reset → inline-edit, form round-trips
- **Temporal/events** — → daterangepicker, calendar

The demo's data source is declared in its manifest (`data: { source: "data.languages" }` or
`"sandbox"`), not written as code by the author.

## 5. Content authoring model

**Content = a custom markdown superset**, rendered server-side (Elixir). This is the core deliverable.

- **Frontmatter (YAML):** page metadata (title, description, nav section/order, `uses` package).
- **Container directives `:::name{attrs}` … `:::`** (nestable):
  - `:::columns{cols="80/20"}` + `:::col{title=…}` — **generic layout**, free-form width ratios via
    CSS grid `fr` (true 80/20, not Bootstrap 12-grid), responsive-stacking.
  - `:::showcase` — a **preset** = `:::columns` with positional accent colors (blue/green/cyan) for the
    classic Demo/Controls/Description look.
  - `:::card{title=…}` — boxed card (chrome). `:::col` is a plain labelled column (no chrome).
  - `:::callout{type=info|warning|danger title=…}` — alert/callout.
- **Fence roles** (demo-ness lives on the fence, decoupled from layout):
  - ` ```html demo ` / ` ```svelte demo ` — **live** region (element mounts) + source view.
  - ` ```js run ` — executes client-side, scoped to the preceding demo (`el`, `out()` helpers).
  - ` ```lang example ` / plain fence — highlighted, copyable source (not executed).

### Demos are mostly markup + CDN, not compiled apps

KeenMate `web-*` components are **web components** (custom elements). A demo is usually just HTML using
the element (`<web-multiselect data-options="…">`) + the element's module from **npm CDN (jsdelivr),
pinned to the doc version** → demo-runtime versioning is free. Server-backed demos often just point the
element at a generic endpoint (`data-url="/api/data/languages"`). True keen-phoenix-svelte island apps
are the **rare** case (LiveView / custom interactive, e.g. inline-edit, chat).

Demo spectrum: (a) static markup · (b) markup + generic-endpoint URL · (c) `js run` block · (d) island app (rare).

### API Reference is generated

Packages already ship `custom-elements.json` (CEM) + `web-types.json` (e.g. `../web-multiselect`).
The API Reference page is **generated from the CEM manifest** per version — no hand-written API pages.

## 6. Decisions locked

- CLI runtime: **Node** (npm `@keenmate/keendocs`).
- Markdown engine: **MDEx** (comrak Rust NIF, precompiled) + **lumis** for server-side highlighting.
- Layout is generic (`columns`/`col`); `showcase` is a preset; `col` = labelled (no chrome), `card` = boxed.
- Width shorthand: `cols="80/20"`; demos load from CDN pinned to version; `js run` executes (content is trusted — published via API-keyed CLI).

## 7. Open questions (decide before/while building the real app)

- **Directive syntax** final sign-off (`:::name{attrs}` + fence flags) — currently assumed good.
- **Multi-tab code**: auto-tab consecutive `example` fences vs explicit `:::code{tabs}` wrapper (lean: explicit).
- **CDN vs self-hosted** component bundles (lean: self-host from ingested bundle + CDN fallback; works offline/intranet).
- **Content storage**: Postgres rows + tsvector/pgvector for fulltext; assets/bundles on disk or object storage.
- **Auth**: confirm `../keen-auth-permissions` for profiles/favorites/notes.
- **Trust model**: confirm content is trusted so inline `js run` may execute.

## 8. Where we are — POC

A **plain Mix project** (not `phx.new` yet) proving the markdown→live-docs pipeline is manageable.

Files:
- `lib/keen_docs/markdown/frontmatter.ex` — YAML front-matter split (`yaml_elixir`).
- `lib/keen_docs/markdown/directive_parser.ex` — **core**: pure Elixir, code-fence-aware nested `:::` block tree.
- `lib/keen_docs/markdown/renderer.ex` — node tree → HTML; markdown/`example` via MDEx (server-side highlight), `demo`/`run` → live region + script.
- `lib/keen_docs/poc.ex` — renders `priv/content/form-integration.md` → standalone `build/poc.html`.
- `priv/content/form-integration.md` — sample exercising every feature (showcase, 80/20 columns, callout, card, table, live `<web-multiselect>` + `js run`).
- `priv/web/keendocs.css` — POC styles.

**Run:** `mix run -e "KeenDocs.POC.build()"` then open `build/poc.html`.

**Verified:** showcase 3 positional-accent columns; true 80/20 CSS-grid; callout; card; GFM table; two live
`<web-multiselect>@2.0.0` from jsdelivr; `js run` change→output; **server-side syntax highlighting**
(inline styles, no client hljs / no FOUC).

**Gotcha recorded:** MDEx `default_syntax_highlight_options` is `nil` (opt-in) and neither `:lumis` nor
`:syntect` ships in the precompiled `mdex_native` — need `{:lumis, "~> 0.1"}` + `config :mdex_native,
syntax_highlighter: :lumis`.

## 9. Next steps

1. **Phoenix-ify**: `phx.new`, mount the renderer in a controller/LiveView route (renderer already returns an HTML string).
2. **Tabbed code** (`:::code{tabs}`) to replace the POC's `<details>` source view (the CodeShowcase equivalent).
3. **Content bundle + manifest format** (folder-per-version) — the unit `keendocs publish` ships and the app ingests.
4. **`keendocs` CLI** (Node) — `publish` (pack + upload) mirroring `pure-admin-cli`; `init`/`dev` later.
5. **Ingestion + storage** — upload endpoint, content-hash dedup, Postgres + fulltext.
6. **Domain-scoped routing** — hub vs single-package views from one app.
7. **Generic demo endpoints** — the data-shape API (list/search, tree, sandbox, temporal).
8. **Auth + profiles/favorites/notes** (keen-auth-permissions).
9. **API Reference generator** from `custom-elements.json`.
10. **Port `web-multiselect-showcase`** as the first real content repo (dogfood).

## Related repos

- `../svelte-docs` — the predecessor (SvelteKit lib).
- `../keen-phoenix-svelte` — island mounter (Hex `keen_phoenix_svelte` / npm `@keenmate/phoenix_svelte`).
- `../pure-admin-cli` — the CLI publish flow to mirror.
- `../web-multiselect` — flagship web component (ships CEM manifest); first content target.
- `../keen-auth-permissions` — likely auth layer.
