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

## 9. Next steps

**POC scorecard.** Proven: ✅ markdown→live HTML pipeline · ✅ extension model · ✅ library extraction ·
✅ `transform_markdown` (redefine base constructs) · ✅ HEEx target (`:::card`→`<.card>` real components) ·
✅ cached HEEx route (P1) · ✅ dynamic `{{vars}}` · ✅ compile-boundary safety hardening.
Open POCs: P2 island actually mounts · P3 generic data endpoint + live demo · P4 publish/ingest + dedup ·
P5 multi-version + domain routing · P6 CEM→API reference · P7 fulltext.

1. **Phoenix-ify**: `phx.new`, mount the renderer in a controller/LiveView route (the `Output` regions
   map onto a layout's head/body/footer slots). The P1 spike (`tmp/keen_docs_p1`) is the template.
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
