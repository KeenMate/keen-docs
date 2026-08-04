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

Demo spectrum: (a) static markup · (b) markup + generic-endpoint URL · (c) `js run` block · (d) island
app (rare) — authored as `:::app`, see §5 below.

### Rendering produces page regions, not a string

A block does not only contribute body markup: a mermaid diagram needs its runtime loaded, an OG hook
needs `<meta>` tags in the head, a `js run` block needs a module script *after* the content it drives.
So rendering returns an **`Output` of page regions** — `head`, `body`, `footer`, plus keyed `assets`,
a `toc` and `body_class` — and the page shell assembles them.

Assets are **keyed and deduplicated**: ten mermaid diagrams load the bundle once, a page with none
loads nothing. On finalize, assets lead their region so a library `<script>` always precedes the init
that uses it.

### Extensions are installed at server level

The renderer knows almost nothing about the authoring vocabulary. Every `:::directive` and every fence
role is supplied by an **extension** listed in `config :keen_docs, :extensions` — including the
built-in layout, block and demo vocabularies, so the built-ins exercise the same contract a
third-party extension would.

An extension implements any of four optional callbacks:

| Callback | Purpose |
|---|---|
| `directives/0` | the `:::name` blocks it renders |
| `fences/0` | fence keys it renders — matched against fence *flags*, then the *language* |
| `render/2` | `{iodata, context}` — emit markup *and* register assets/head/footer contributions |
| `document/3` | whole-document hook, **before** body rendering (front-matter-driven contributions) |
| `finalize/1` | hook **after** body rendering, for contributions that depend on what the page contained |
| `transform_markdown/2` | rewrite the **base-markdown AST** (comrak `MDEx.Document`) of a `{:markdown}` run before it becomes HTML — the seam for redefining built-in constructs (`##` → `<div class="header-2">`, custom lists). The `:::`/fence layers are our grammar; this reaches CommonMark underneath. Fast path is preserved when no transform is installed. |

State an extension needs across blocks lives in the context's private store, keyed by module — never
in process state.

Extensions are **server-installed, never content-authored**: content repos stay pure data (§4) and
simply use whatever the server has. Reference implementations: `Mermaid` (asset contribution),
`OpenGraph` (document hook → head), `CdnPackage` (front matter `uses:`/`version:` → pinned jsdelivr
tags, which is how §5's "pinned to the doc version" is actually delivered), and `App` (below).

### `:::app` — keen-phoenix-svelte islands

`:::app` is the markdown equivalent of `<.app>`, rendering the same wrapper contract
(`phx-hook="KeenApp"`, `phx-update="ignore"`, `data-app`, JSON `data-props`, `data-eager`). Every part
is a **named block** rather than an inferred one:

```
:::app{name="org-browser" component="tree"}
:::props        ← a JSON fence, validated at build time
:::placeholder  ← markup shown until the island mounts
:::
```

Bundle URL resolution, most specific first: a `src=` attribute → front matter `apps: {name: url}` →
the configured `base_path` (`/apps/<name>/main.mjs`, mirroring `KeenPhoenixSvelte.Apps.base_path/0`).

Page-level runtime (`keen-context`, the `keen-apps` manifest, one `modulepreload` per island) is
emitted from `finalize/1`, because the manifest must list every island the page turned out to mount —
which `document/3` runs too early to know. `mountStatic()` bootstrapping is emitted only if a
`runtime:` URL is configured; a real Phoenix page calls it from its own `app.js`.

Note that `<.app>` tracks used apps in `Process.put/2`. Here they ride the render context instead, so
two documents rendered in one process cannot bleed into each other's manifest — the same class of bug
§3 exists to remove, avoided by construction.

### API Reference is generated

Packages already ship `custom-elements.json` (CEM) + `web-types.json` (e.g. `../web-multiselect`).
The API Reference page is **generated from the CEM manifest** per version — no hand-written API pages.

### Rendering targets: HTML and HEEx (proven — see §8)

The parser/renderer are **output-format-agnostic** — the renderer just concatenates whatever iodata the
extensions return. The target is decided entirely by *which extension set is installed*:

- **HTML target (default).** `:::card` → `<div class="kd-card">…</div>`. What the POC and any static host uses.
- **HEEx target.** `:::card` → a component tag `<.card>…</.card>` that a **consuming Phoenix app** compiles
  against its own design system (e.g. `keen_pure_admin` / pure-admin function components). Base markdown
  still renders to HTML (a subset of HEEx, so it slots straight into `<.card>`). Children are rendered to
  HTML **first**, then wrapped — keen_markdown owns markdown→HTML, the compile step owns component-tag→component.

keen_markdown stays **Phoenix-free**: a HEEx extension only emits `<.card>` *strings*; the consumer runs
`Phoenix.LiveView.TagEngine.compile/2` in a module that imports the components. Same engine, different
extension list — this is why extracting `keen_markdown` mattered.

**Compile & cache model** (for content stored in a DB, compiled on the fly):

- A published version is content-hash-immutable (§4), so it's a stable cache key.
- **Static page** → render once, cache the **HTML** (~1 µs/request warm).
- **Dynamic page** (per-user) → cache the **compiled template**, render per request with assigns (~255 µs).
- The compile itself (~9–12 ms) is paid once per version, never per request.
- Each page picks its strategy via **frontmatter metadata** (`cache: static | per_user`), read off `Output.meta`.

**Content variables** — `{{user.displayName}}` (mustache, deliberately *not* HEEx `{}` / EEx `<%%>`). A
whitelisted dotted path `[\w.]+` is translated to a safe lookup `Vars.get(assigns, "user.displayName")`
(read-only into the per-request assigns map — never arbitrary code) and populated per request.

**Safety at the compile boundary** — compiling author content = running code, so the invariant is *only
trusted tokens ever reach the compiler*. The proven approach: emit trusted constructs (component tags,
`{{var}}` lookups) as forge-proof **sentinels** (base64, null-delimited — comrak strips nulls so content
can't forge one), **neutralize** the whole body (escape every author `{}` / `<% %>` / `<.component>`),
then **swap** sentinels back into real HEEx. This blocks RCE via `{6*7}`, `<%= %>`, `<.evil>` injection
while keeping legit components and vars working. **XSS is a separate axis** — raw author HTML (`<script>`)
still passes with `unsafe: true`; sanitize (ammonia / `unsafe: false`) if content is ever untrusted.

## 6. Decisions locked

- CLI runtime: **Node** (npm `@keenmate/keendocs`).
- Markdown engine: **MDEx** (comrak Rust NIF, precompiled) + **lumis** for server-side highlighting.
  **Confirmed over `md`** after checking the ecosystem: MDEx is extensible at the *options* and *AST*
  levels but **not the grammar** — comrak can't learn new source syntax like `:::`. That's fine, because
  *our directive layer supplies the grammar* and delegates prose to comrak. `md` (am-kantox) is the only
  grammar-extensible Elixir lib, but explicitly drops CommonMark compliance and comrak's speed — a trade
  we don't need. Earmark is retired/deprecated; cmark archived. Base markdown is ~60% of a real doc, so
  correctness of the payload matters more than base-grammar extensibility we already have one layer up.
- **Rendering target is pluggable via the extension set** — HTML (default) or HEEx component tags compiled
  by the consumer. The parser/renderer are format-agnostic; output format is purely an extension concern.
- **DB content → HEEx compiled on the fly, cached per content hash.** Static pages cache rendered HTML;
  per-user pages cache the compiled template and render per request with assigns. Strategy is declared per
  page in frontmatter (`cache:`).
- **Content variables** use mustache `{{a.b}}` → whitelisted `Vars.get(assigns, "a.b")` (read-only, not code).
- **Compile-boundary safety = trust separation** (sentinel → neutralize → swap): only trusted tokens are
  compiled, so author `{…}`/`<%…%>`/`<.component>` can't execute (RCE-safe). XSS remains a separate policy.
- **Styling is theme-driven off the `@keenmate/pure-css` `--base-*` foundation.** The engine still ships
  no CSS (emits classed HTML + inline-styled code); the *consumer's* styling reads the KeenMate `--base-*`
  custom properties — the same contract pure-admin, its themes, and every web/svelte component derive from.
  `../pure-css` (`@keenmate/pure-css`) is that foundation (variables + PureCSS grid + utilities), extracted
  from `pure-admin-core` so a docs site consumes it without the component library. keen-docs vendors the
  **built** CSS (`priv/web/vendor/pure-css/`), inlines `base.css` for FOUC-free vars, and links grid/utils.
  A **theme is a `--base-*` override** (per `doc_set` from `settings.theme`, emitted after the defaults);
  because everything reads `--base-*`, one override re-themes the chrome, the `kd-*` content, *and* an
  embedded `<web-multiselect>` at once. Same model as `../pure-admin-themes`, so the same publish CLI/infra
  applies. (De-duping `pure-admin-core` to import `pure-css` is a planned follow-up, not yet done.)
- Layout is generic (`columns`/`col`); `showcase` is a preset; `col` = labelled (no chrome), `card` = boxed.
- Width shorthand: `cols="80/20"`; demos load from CDN pinned to version.
- **Trust model: content is trusted**, because it ships through the API-keyed publish CLI. Therefore
  inline `js run` executes *and* prose may contain inline HTML (`<kbd>`, `<sup>`, …) — MDEx runs with
  `unsafe: true`. Revisit only if untrusted/community-contributed content is ever accepted.
- **Rendering returns page regions** (`head`/`body`/`footer` + keyed assets), never a bare HTML string.
- **The rendering engine is a standalone library**, `keen_markdown` (`../keen-markdown`, module root
  `KeenMarkdown`). keen-docs consumes it via a path dep. Boundary: **generic vocabulary lives in the
  library** (layout, cards/callouts, `example` fences, mermaid, OG); **docs-specific vocabulary stays in
  keen-docs** (live `demo`/`run` fences, `cdn_package`, `app` islands). This lets a content portal like
  `../cafeindustrial-cz` reuse the engine without any docs machinery.
- **Extensions are server-installed** and configured in `config :keen_markdown, :extensions`; content
  repos never register their own. The built-in vocabulary is itself a set of extensions.
- Demo ids are a **deterministic per-document counter** (`kd-demo-1`, …), so the same document always
  renders to the same bytes — random ids would defeat the content-hash dedup in §4.
- **DB access layer = stored functions + raw Postgrex, NOT Ecto** (matches `../keen-auth-permissions`).
  The schema lives in the database as SQL functions; `db-gen` (KeenMate's Go generator, vendored as
  `db-gen-win.exe`/`db-gen-linux` + `db-gen.json` + `db-gen/*.gotmpl`) reads those functions and generates
  the typed Elixir wrappers — `KeenDocs.Database` context + `KeenDocs.Database.{Models,Parsers}.*` — into
  `lib/keen_docs/database/` (committed). A thin `KeenDocs.Repo` (Postgrex `start_link` + `query/2`) is all
  the generated `use KeenDocs.Database, repo: …` needs; no Ecto schemas/migrations. **Migrations are run by
  debee** (see the toolchain note in §8).

## 7. Open questions (decide before/while building the real app)

- **Directive syntax** final sign-off (`:::name{attrs}` + fence flags) — currently assumed good.
- **Multi-tab code**: the wrapper alone is *not explicit enough* — consecutive bare fences inside
  `:::code{tabs}` leave the tab boundary ambiguous and give nowhere to hang a human-readable title.
  Direction: a per-tab marker carrying its own title, with the fence inside still carrying `lang` for
  highlighting — `:::code{tabs}` › `:::tab{title="HTML"}` › fence › `:::`. Settle the exact syntax
  before implementing.
- **CDN vs self-hosted** component bundles (lean: self-host from ingested bundle + CDN fallback; works offline/intranet).
- **Content storage**: Postgres rows + tsvector/pgvector for fulltext; assets/bundles on disk or object storage.
- **Auth**: confirm `../keen-auth-permissions` for profiles/favorites/notes.
- **Multi-package CDN**: `CdnPackage` currently loads one package per page from front matter. Decide
  whether a page may document several at once.
- **HEEx target productionization**: the safety approach (sentinel/neutralize/swap) is proven in a spike;
  decide whether the HEEx extension set + safe compile pipeline live in a `keen_markdown_heex` companion,
  in keen-docs, or in each consumer (e.g. keen_pure_admin). Also: whether the engine should natively emit
  a *skeleton + fragments* (author content as assigns data) as an even stronger trust boundary.
- **XSS policy**: with `unsafe: true`, trusted content may embed `<script>`. Confirm trusted-only, else
  add HTML sanitization (ammonia / `unsafe: false`). Orthogonal to the RCE hardening.
- **Vars in attributes**: `{{var}}` populates in body text; supporting it in directive/component attributes
  (`:::card{title="{{user.name}}"}`) needs separate handling (currently escaped).
- **Neutralization audit**: the compile-boundary escape list is a construct blacklist — audit + fuzz before
  production; the sentinel *trust separation* is the backbone, neutralization is defense on top.
- **Does keen-docs itself need the HEEx target?** Its demos are client-side (CDN web components, islands),
  so HTML output suffices. HEEx/components earn their keep for a portal (keen_pure_admin) wanting docs
  chrome to *be* real design-system components. keen-docs may stay HTML-target; HEEx is a portal concern.

## 8. Where we are — POC

A **plain Mix project** (not `phx.new` yet) proving the markdown→live-docs pipeline is manageable.
Built on **Elixir 1.20.2 / OTP 29**; `mix.exs` still declares `~> 1.15` and nothing is pinned.

**The engine now lives in `../keen-markdown`** (Hex `keen_markdown`, module root `KeenMarkdown`);
keen-docs consumes it via `{:keen_markdown, path: "../keen-markdown"}` and adds only its docs-specific
extensions. Work on the parser/renderer/behaviour happens in that repo.

In `../keen-markdown` (`KeenMarkdown.*`, 56 tests):
- `frontmatter.ex` — YAML front-matter split (`yaml_elixir`).
- `directive_parser.ex` — **core**: pure Elixir, code-fence-aware nested `:::` block tree.
- `renderer.ex` — node tree → `Output`; dispatch loop, plain markdown, fallbacks, `transform_markdown` hook.
- `output.ex` / `context.ex` / `extension.ex` / `html.ex` — regions, per-render state, behaviour, escaping.
- `keen_markdown.ex` — public API (`KeenMarkdown.render/2` → `Output`).
- generic extensions: `layout` (columns/col/showcase), `blocks` (card/callout), `example`
  (highlighted copyable source), `mermaid`, `open_graph`. **Ships no CSS** — emits classed HTML + inline-styled code; the consumer owns styling.

In keen-docs (the first consumer, 29 tests):
- `lib/keen_docs/extensions/` — `demo` (live `demo`/`run` fences), `cdn_package` (jsdelivr, pinned),
  `app` (keen-phoenix-svelte islands).
- `lib/keen_docs/poc.ex` — renders `priv/content/form-integration.md` → standalone `build/poc.html`.
- `priv/content/form-integration.md` — sample exercising every feature.
- `priv/web/keendocs.css` — all POC styling (page shell + `kd-*` component classes the engine emits + demo/island); the engine ships none.
- The full vocabulary is assembled in `config :keen_markdown, :extensions` = generic set ++ keen-docs' three.

**Run:** `mix test` (here **and** in `../keen-markdown`), then `mix run -e "KeenDocs.POC.build()"` and open `build/poc.html`.

**Verified:** showcase 3 positional-accent columns; true 80/20 CSS-grid; callout; card; GFM table; two live
`<web-multiselect>@2.0.0` from jsdelivr (loaded from front matter, not hardcoded); `js run` change→output
from the footer; mermaid diagram with its runtime loaded once; OG tags; heading ids + TOC;
**server-side syntax highlighting** (inline styles, no client hljs / no FOUC); byte-identical output
across repeated renders; `:::app` island wrapper + `keen-apps` manifest + module preload.

**Not yet proven / known gaps:**
- **Islands do not actually mount in the POC.** `:::app` renders the wrapper, manifest, context script
  and preload correctly, but this standalone page serves no bundle and calls no `mountStatic()`.
  Real mounting is only testable after step 1 below.
- **Fences are detected at any indentation** (`@fence_re` is anchored `^\s*`), so a fence indented
  inside a list item is hoisted out as a top-level fence node and breaks the list. Pre-existing;
  fixing it means reworking fence detection, so it was left alone rather than risking the
  fence-length fix.
- No `:::code{tabs}` yet — the `<details>` source view still stands in.

**Defects found and fixed once the pipeline was probed directly** (the original sample passed only
because every directive in it happened to carry attributes):

| Defect | Cause |
|---|---|
| Attribute-less directive crashed the parser | `Regex.run/2` drops trailing non-participating groups, so `:::columns` matched as 2 elements |
| A shorter nested fence closed a longer one | closing test accepted any run of ≥3 of the same char |
| `showcase` silently dropped non-`col` children | rendered only its filtered columns |
| `columns` leaked stray prose into the grid | rendered all children as grid items |
| `js run` bound to a demo from a *previously rendered document* | pairing lived in `Process.put/2` — the §3 anti-pattern in miniature |
| Inline HTML in prose was stripped | `unsafe: false` |
| No heading ids | `header_id_prefix` not set |

**Gotchas recorded:**
- MDEx `default_syntax_highlight_options` is `nil` (opt-in) and neither `:lumis` nor `:syntect` ships in
  the precompiled `mdex_native` — need `{:lumis, "~> 0.1"}` + `config :mdex_native, syntax_highlighter: :lumis`.
- `extension: [header_ids: …]` is **deprecated** in MDEx 0.13.5 → `header_id_prefix`. Use the empty
  prefix: a non-empty one prefixes the `id` but *not* the generated anchor's `href`, breaking self-links.
- Call `Lumis.highlight!/2` directly rather than round-tripping code through a markdown fence string —
  the round-trip cannot represent a sample that itself contains fences.
- Precompiled NIFs resolve to `nif-2.15` artifacts and work on OTP 29; no Rust toolchain needed.

### Proven in throwaway spikes (`keen-docs/tmp/`, gitignored)

The HEEx/DB-content story was de-risked end to end in scratch projects (`tmp/heex_proof`,
`tmp/keen_docs_p1`). Code is throwaway; the findings are the keepers:

- **`transform_markdown` hook** (landed in keen_markdown, 4 tests): `## x` → `<div class="header-2">x</div>`
  via comrak AST rewrite, base markdown around it untouched. Proves redefining built-in constructs.
- **`MDEx.to_heex` works on runtime strings** (it's a macro that snapshots the *caller's* imports at
  compile time, but the content is a runtime arg). Confirmed `<.card>` from a DB string compiles against
  a real component. Underlying primitive: `Phoenix.LiveView.TagEngine.compile/2` + `Code.eval_quoted`.
  Gotcha: MDEx does **not** markdown-process a component's children — fine, since keen_markdown renders
  children to HTML first.
- **HEEx extension set** (`:::card` → `<.card>`, ~20 lines): same engine, only the extension list differs;
  compiled against real `card/1`/`callout/1` components → real design-system HTML.
- **P1 — cached HTTP route** (Bandit + Plug, ETS cache keyed by content hash): cold render **~9.2 ms**
  (parse + MDEx + TagEngine.compile + eval), warm **~1 µs** (~9000× speedup). `GET /docs/:id` served with
  `x-cache: hit`. Confirms MDEx's "eval each time is slow" warning *and* that per-version caching erases it.
- **Dynamic `{{vars}}`**: same compiled template rendered for two users (Ondrej/Alice) with different
  output; compile once **~12 ms**, per-request render **~255 µs**. `cache: per_user` frontmatter drives it.
- **Safety hardening**: naive compile of author `{6*7}` **executed → "42" (RCE)**; the sentinel→neutralize
  →swap pipeline made `{6*7}`, `<%= %>`, `<.evil>` all inert while legit `{{vars}}` and `:::card` still work.
- **P3 — server-backed live demo** (`tmp/keen_docs_p3`, Bandit + real `KeenDocs.Extensions.Demo`): a
  ` ```html demo ` + ` ```js run ` fence pair authored in markdown mounts a CDN `<web-multiselect>` and wires
  its `searchCallback` to a **generic `/api/data/:set?q=` endpoint on the same app**. Verified headlessly:
  `GET /api/data/countries?q=ge` → `[Algeria, Argentina, Georgia, Germany]` (server-side filter), unknown set
  → 404 with known-set list, and the rendered page carries the component + the footer run-script that fetches
  it. Proves the load-bearing promise — demos that talk to a *real* generic server, authored inline. The
  data endpoint is the "data-shape-oriented endpoint" of §4 in miniature: adding a data set = the whole backend.
- **P2 — island actually mounts** (`tmp/keen_docs_p2`, Bandit + real `KeenDocs.Extensions.App`): `:::app{name}`
  emits the real `<div data-app phx-hook="KeenApp" data-props>` wrapper + `#keen-apps` manifest + `#keen-context`
  + modulepreload + a `mountStatic()` footer bootstrap. The **real keen-phoenix-svelte client runtime**
  (esbuild-bundled to `/apps_runtime.js`; `phoenix` inlined but inert) drives the **real prebuilt `hello-js`
  bundle**. Verified headlessly (`mount-proof.mjs`): the runtime's `AppsManager.create` cleared the server
  placeholder and mounted the island; markup rendered ("Plain JS island — 0 ticks") and advanced to "1 tick" —
  i.e. mounted *and* live. `.mjs` must be served as `text/javascript` or the browser rejects the ES module.
- **P4 — publish/ingest + content-hash dedup** (`tmp/keen_docs_p4`: a Node `keendocs` CLI mirroring
  pure-admin-cli's idioms — hand-rolled argv parser, ANSI phase logs, per-file sha256 + a rolled-up
  `content_sha` — and an Elixir/Bandit ingest server with a **content-addressed blob store**). Proven end to
  end: publish `v2.0.0` → 3 blobs stored; republish unchanged → `unchanged`, **0 writes** (whole-version
  `content_sha` hit); publish `v2.0.1` with a byte-identical `index.md` → `stored 2, deduped 1`, blob store
  **5 not 6** — the shared file is stored once across versions (**per-file dedup, the payoff**). Bonus: the
  ingested bytes render through the real `keen_markdown` (`GET /docs/:pkg/:ver/:slug`). Gates work: Bearer
  auth → `401`, `x-keendocs-cli-version` below the server minimum → `426` (version-gates the CLI, per §4.2).
  POC transport is JSON+base64 (dedup is the point); the real CLI packs a zip + multipart like pure-admin-cli.
- **P5 — multi-version + domain-scoped routing** (`tmp/keen_docs_p5`, one Bandit app): a single `Endpoint`
  plug resolves the **request Host into a tenant scope** and forwards — the whole multi-tenant trick
  (DESIGN.md §4.3). The hub host (`docs.localhost`) aggregates *every* package with its semver-`latest`;
  a package subdomain (`web-multiselect.localhost`) is the *same app* scoped to one library. Multi-version
  works: `/` → latest (2.1.0 over 2.0.0 via `Version` sort, not lexical), `/2.0.0` explicit, a version
  switcher that carries the current slug across versions (`/2.0.0/getting-started`), and page nav from the
  catalog. Content is a folder-per-version tree read into `:persistent_term` at boot (stands in for the DB
  after P4 ingest); pages render through the real `keen_markdown`. Verified with `curl -H "Host: …"`: hub
  aggregation, per-package scoping, cross-domain links both ways, `404` for unknown tenant and unknown version.
- **P6 — CEM → API reference generator** (`tmp/keen_docs_p6`): a docs-specific `:::api{tag="web-multiselect"}`
  extension that reads the component's `custom-elements.json` (CEM, schema 1.0.0) and generates the reference
  — the realisation of §5 "API Reference is generated". Run against web-multiselect's **real 203 KB CEM**:
  it emitted **75 attributes · 38 properties · 4 methods · 3 events**, with attribute→property mapping
  (`search-hint`→`searchHint`), full typed method signatures
  (`setSelected(values: (string | number)[], opts: { notify?: boolean })`), and — crucially — *only the
  public API*: private/protected/static members and the custom-element/form lifecycle callbacks
  (`connectedCallback`, `formResetCallback`, static `formAssociated`, …) are all filtered out (0 leakage).
  Author writes one directive; the table stays in lock-step with the shipped manifest. CEM parsed once and
  cached in `:persistent_term` (manifests are large + immutable per version).

### Database & codegen toolchain (wired 2026-08-03)

The persistence layer is real and proven end to end, using two KeenMate tools:

- **`../keen-docs-database`** — the SQL, applied by **debee** (a PostgreSQL migration orchestrator; env in
  `debee.env` + `.debee.env`, run `make setup` = `debee -o fullService`). It's a copy of the
  postgresql-permissions-model test DB: files **000–009 are the common framework** (roles, version
  management, helpers), **010/012/013 are illustrative** auth examples. Fixed for keen-docs: recreate script
  default → `keen_docs`, `DBDESTDB=keen_docs`, retargeted `99_fix_permissions.sql` to the `keen_docs` role
  (deleted the duplicate `099_` — 3-digit prefixes get swept into the migration run, 2-digit don't).
  `make setup` builds the `keen_docs` DB (role name == password == `keen_docs`) on `db-01.km8.local`.
- **`db-gen`** (vendored in keen-docs) — connects to `keen_docs`, reads stored functions, generates the
  Elixir wrappers via Go templates. `db-gen.json` + `db-gen/*.gotmpl` were **copied from
  keen-auth-permissions**; retargeted to namespace `KeenDocs.Database` and output `lib/keen_docs/database/`.
  Run `./db-gen-win.exe generate`. Has `--llm` (and `validate`/`routines`/`database-changes`).
- **`KeenDocs.Repo`** (`lib/keen_docs/repo.ex`) — thin Postgrex wrapper; `mix compile` green; a smoke test
  drove a generated wrapper (`check_version/2`) against the live DB and got a typed model back.
- **Update loop:** `make setup` (in keen-docs-database) → `db-gen generate` (in keen-docs). Both need the DB
  reachable (VPN to `db-01.km8.local`). Not yet supervised at boot — start `KeenDocs.Repo` where a live DB
  is actually needed (the eventual Phoenix supervisor / test helper).

- **keen_docs content schema (`public.*`, migration `100_docs_content.sql`)** — the first application domain,
  authored to the **Bliss PostgreSQL guidelines** (`BlissFramework/web/docs/coding-guidelines-postgres`).
  Main-project tables live in **`public`** (KeenMate convention), not a dedicated schema; the migration sits
  in the 100+ range (000–099 is the borrowed permission-model framework). Singular tables with
  `<table>_id generated always as identity` + universal audit columns (audit columns first); `nrm_` search
  column + a generated `tsvector`; `ensure_*` idempotent upserts (`ensure` is the registry verb — not
  "ingest"); the `search_*` two-jsonb signature (`_search_criteria` + `_search_settings`, lenient parse,
  whitelisted `order_by`, no dynamic SQL); and the **public-API-types rule** (functions expose only stock
  types + `jsonb`; `tsvector`/`tsquery` stay internal).

  **The shape — three-level tree, kind-interpreted middle:** `doc_set → doc_variant → document`, plus a
  content-addressed `content_blob` (the P4 dedup, in SQL — `ensure_content_blob` reports `__deduped`).
  - **`doc_set`** = a documented *subject* (generic on purpose — a component library, a guidelines
    collection, or an infra area — *not* a component-only "package"). `code` is the URL slug.
    Discriminated by `kind_code` → `const.doc_set_kind` (`component`/`guide`/`infrastructure`; FK, not
    enum). `doc_set_package` (0..n) carries registry identity (`ecosystem_code` → `const.package_ecosystem`
    = npm/nuget/hex/go_module/cargo/executable, each with `manifest_file` + install/registry templates, and
    a `package_name`), so an uploaded `package.json`/`*.csproj`/`mix.exs` resolves to the right docs.
  - **`doc_variant`** = the **neutral middle partition**, its meaning set by the parent's kind:
    *component* → a **version** (`code`='2.0.0', `applies_to` jsonb coverage ranges, `maturity_code` →
    `const.version_maturity` so a pre-release is reachable but never "latest"); *infrastructure* → a
    **division** (`code`='azure'/'aws', parallel, `is_default`); *guide* → a single `'main'` variant with
    `show_in_path=false` so its URL segment is omitted (**generic guides carry no version**). Same tree,
    one `ensure_document` path, one set of queries for all three.
  - **`document`** = a page; bytes live once in `content_blob`, `nrm_search_data` + a generated `tsvector`.

  Rendering/routing branches on `kind` (a `component` set gets CDN demos + a CEM API ref; the rest are
  prose). Version-less guides and provider divisions were the requirements that proved the middle layer
  must **not** be hardcoded as "version". `ensure_doc_set`'s `_kind_code` is null-means-leave-alone (and
  the auto-create path passes null) so re-publishing a page never clobbers a deliberate kind. Functions:
  `ensure_doc_set/ensure_doc_set_package/ensure_doc_variant/ensure_content_blob/ensure_document`,
  `list_doc_sets/list_doc_variants/get_default_variant`, `resolve_doc_variant` (installed version →
  covering variant via half-open semver bounds in `applies_to`, else default fallback), and
  `search_documents` (returns `variant_code`, filters by `kind`).

  **Version resolution decouples doc cadence from release cadence:** the content repo holds a *handful* of
  folders (one per doc line, e.g. `v2.0.0/` + a `manifest.json` with `appliesTo`), never one per patch —
  `web-multiselect@2.1.4 → v2.0.0` resolves through `applies_to: [{from:"2.0.0", to:"3.0.0"}]`, no per-patch
  row anywhere. (`resolve_doc_variant` currently matches on semver *core* bounds — pre-release suffix
  ignored for containment; a `semver` PG extension or Elixir `Version` swap is a localized change if tighter
  matching is wanted. npm `^`/`~` → `{from,to}` expansion happens at publish/ingest.)
  **This is P7 (full-text) for real:** `search_documents` ranks via `ts_rank(search_vector, websearch_to_tsquery)`
  with a `pg_trgm` substring fallback. Proven end-to-end as the `keen_docs` role (grants via
  `99_fix_permissions.sql`), then through the regenerated `KeenDocs.Database.*` wrappers — public-schema
  functions generate with no prefix, e.g. `KeenDocs.DB.ensure_document/10` (jsonb maps encode via
  `KeenDocs.PostgrexTypes` + Jason): ensure → dedup → ranked search → get. Deferred to when auth is wired:
  publish behind an `auth.*` permission check + `public.journal` audit.

  **Example content** lives in `999_examples.sql` (a swept migration, so `make setup` recreates it every
  time via idempotent `ensure_*` calls) — sample `component`/`infrastructure`/`guide` sets. The seed/schema
  split is deliberate: migrations ship schema + `const` lookups only; *content* (doc_sets, variants,
  documents) is published via the eventual `keendocs` CLI, never as DDL — `999_examples.sql` just stands in
  for the CLI until it exists. `tmp/docs_variant_demo.exs` is a read-only visualizer over the seed (nav
  tree, URL construction, `package.json` → doc-version resolution).

## 9. Next steps

**POC scorecard.** Proven: ✅ markdown→live HTML pipeline · ✅ extension model · ✅ library extraction ·
✅ `transform_markdown` (redefine base constructs) · ✅ HEEx target (`:::card`→`<.card>` real components) ·
✅ cached HEEx route (P1) · ✅ dynamic `{{vars}}` · ✅ compile-boundary safety hardening ·
✅ P2 island actually mounts · ✅ P3 generic data endpoint + live server-backed demo ·
✅ P4 publish/ingest + content-hash dedup (Node `keendocs` CLI + blob-store ingest) ·
✅ P5 multi-version + domain-scoped routing (host = tenant scope; hub aggregates, subdomain scopes) ·
✅ P6 CEM→API reference (`:::api{tag}` generates attrs/props/methods/events from custom-elements.json) ·
✅ P7 Postgres fulltext — delivered for real (not a spike) as the `docs.*` schema; see the toolchain note.
All planned POCs are proven.

1. **Phoenix-ify** — *first cut done as a minimal web layer.* `KeenDocs.Application` supervises
   `KeenDocs.Repo` + a Bandit/Plug router (`KeenDocs.Web.Router`, port 4000; run `mix run --no-halt` or
   `iex -S mix`). `KeenDocs.Content` (`use KeenDocs.Database`) is the data API; routes exercise every aspect
   over the live `public.*` functions: `/` hub (all doc_sets + kind/package), `/:set` variant nav, `/:set/:variant/:slug`
   rendered document (markdown → `KeenMarkdown.render` → head/body/footer regions), `/:set/:seg` (guide
   pretty-URL vs variant landing, decided from `show_in_path`), `/search?q=&kind=`, and `/resolve`
   (paste a `package.json` → matched `doc_set` + version resolution via `applies_to`, with fallback). This
   is Plug (the substrate Phoenix runs on), so promoting to `phx.new` + LiveView is additive — the `Output`
   regions already map onto a layout's head/body/footer slots. The P1 spike (`tmp/keen_docs_p1`) remains the
   HEEx/LiveView template.
2. **Tabbed code** (`:::code{tabs}` + per-tab markers, see §7) to replace the POC's `<details>` source view.
3. **Content bundle + manifest format** (folder-per-version) — the unit `keendocs publish` ships and the app ingests.
4. **`keendocs` CLI** (Node) — `publish` (pack + upload) mirroring `pure-admin-cli`; `init`/`dev` later.
5. **Ingestion + storage** — upload endpoint, content-hash dedup, Postgres + fulltext.
6. **Domain-scoped routing** — hub vs single-package views from one app.
7. **Generic demo endpoints** — the data-shape API (list/search, tree, sandbox, temporal).
8. **Auth + profiles/favorites/notes** (keen-auth-permissions).
9. **API Reference generator** from `custom-elements.json`.
10. **Port `web-multiselect-showcase`** as the first real content repo (dogfood).

## Related repos

- `../keen-markdown` — **the extracted rendering engine** (Hex `keen_markdown`, module root `KeenMarkdown`);
  keen-docs consumes it via a path dep. The parser/renderer/extensions live here now.
- `../svelte-docs` — the predecessor (SvelteKit lib).
- `../keen-phoenix-svelte` — island mounter (Hex `keen_phoenix_svelte` / npm `@keenmate/phoenix_svelte`).
- `../pure-admin-cli` — the CLI publish flow to mirror.
- `../web-multiselect` — flagship web component (ships CEM manifest); first content target.
- `../keen-auth-permissions` — likely auth layer.
- `../cafeindustrial-cz` — a Phoenix portal (LiveView, hardcoded `.heex` content today); candidate second
  consumer of `keen_markdown` and the HEEx-target case.
