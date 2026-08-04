# keen-docs — feature set (as of 2026-08-04)

A snapshot of what the POC can actually do today, by layer. Legend:
**✅ working** · **🧪 proven in a throwaway spike** (`tmp/`, findings in `DESIGN.md §8`) · **⬜ not built**.

For the *vision* and architecture decisions see [`DESIGN.md`](./DESIGN.md); for what changed and when,
the `CHANGELOG.md` in each repo. This file is the "what works right now" view.

---

## 1. Markdown engine — `../keen-markdown` (`KeenMarkdown.*`)

The core rewrite lives in a standalone reusable library, consumed here via a path dep. **59 tests green.**

| Capability | Status |
|---|---|
| YAML frontmatter split → `{meta, body}` (`Frontmatter`) | ✅ |
| `:::` container directives — nested, code-fence-aware scanner (`DirectiveParser`) | ✅ |
| **Raw-body directives** — body captured verbatim as `{:raw, text}`, `:::` depth-counted so a balanced `:::demo … :::` example survives inside `:::code` (docs-about-docs) | ✅ |
| Attribute parser `{key=val key2="v2"}` | ✅ |
| Server-side syntax highlighting (MDEx/comrak NIF + lumis; inline `style=` per span → no stylesheet, no FOUC, no client JS) | ✅ |
| Output as **page regions** — `head`/`body`/`footer` + keyed `assets` + `toc`; never a bare HTML string (`Output`) | ✅ |
| Extension behaviour: `directives/0`, `raw_directives/0`, `fences/0`, `render/2`, `document/3`, `finalize/1`, `transform_markdown/2` (all optional) | ✅ |
| `transform_markdown/2` — reshape the base comrak AST (e.g. redefine `## x`) before HTML | ✅ (seam proven) |
| Deterministic output — same document → same bytes (no `unique_integer`/timestamps) | ✅ |
| Ships **zero CSS** — emits `kd-*` structural hooks; the consumer owns all styling | ✅ |
| Public API: `KeenMarkdown.render/2` and `render_body/2` | ✅ |

**Generic vocabulary** (ships in the lib, useful to any content site):

- `:::columns{cols="80/20"}` / `:::col{title=…}` / `:::showcase` — layout (CSS grid `fr` ratios, not Bootstrap 12-grid)
- `:::card` / `:::callout{type=info}` — blocks
- **`:::code{lang=…}`** — highlighted, copyable code block (raw body)
- `mermaid` — diagram
- `open_graph` — OG/social head tags
- `example` fence role — legacy; kept in the lib, but keen-docs uses `:::code` instead

## 2. keen-docs' docs-specific vocabulary (`lib/keen_docs/extensions/`)

Plug into the same behaviour; installed server-side; content repos stay pure data. **29 tests green.**

| Directive | What it does | Status |
|---|---|---|
| `:::demo` | Mounts the raw markup **live** + shows its source (raw body) | ✅ |
| `:::run` | Behavior JS bound to the **preceding** demo, emitted to the footer | ✅ |
| `:::code{lang=…}` | Copyable highlighted source (no execution) — via the lib's Code ext | ✅ |
| `cdn_package` | Loads the documented `web-*` component from jsdelivr, **pinned to the doc version** | ✅ |
| `:::app` + `:::props` + `:::placeholder` | keen-phoenix-svelte **island mounts live** on a plain (non-LiveView) page | ✅ |

> The old fence *role-flags* (`demo`/`run`/`example`) are **retired**. The fence header used to
> conflate *language* + *role*; liveness/code are now explicit directives. "Demo-ness" is never a
> column and never a fence flag.

## 3. Live demos — actually running in a browser

| Demo | Status |
|---|---|
| Real `<web-multiselect>` (rc `2.0.0-rc01`) mounts from CDN, interactive, options wired (`<option>` children / `data-options-format`) | ✅ |
| `:::run` change→output JS fires (`e.detail.selectedValues` / `selectedOptions`) | ✅ |
| **3 real published islands** from `apps.keen-phoenix-svelte.keenmate.dev`: `hello` (single-file), `metrics` (multi-file, self-resolves CSS/JSON via `import.meta.url`), `dashboard` (code-split, lazy-loads view chunks) | ✅ |
| Local island bundle served from `priv/web/apps/` | ✅ |

Seed page `web-multiselect/2.0.0/islands` mounts all three via the page's front-matter `apps:` map.

## 4. Content database — `../keen-docs-database` (debee-managed)

Stored SQL functions + raw Postgrex + db-gen codegen — **no Ecto** (mirrors `../keen-auth-permissions`).
Authored to the Bliss PostgreSQL guidelines.

| Capability | Status |
|---|---|
| `doc_set → doc_variant → document` hierarchy + content-addressed `content_blob` | ✅ |
| `const` lookups (`doc_set_kind` / `package_ecosystem` / `version_maturity`) as FKs, not enums | ✅ |
| **Weighted full-text search** — `setweight` A=title, B=keywords, C=extracted prose; `ts_rank` reads the weights | ✅ |
| `internal.markdown_to_search_text` — strips frontmatter, `:::code/demo/run` blocks, fences, directive lines, links & md markers → indexes **prose, not syntax** | ✅ |
| Keyword folding from frontmatter (`description`/`summary`/`keywords`, array or string) → weight B | ✅ |
| pg_trgm substring fallback (title + keywords) | ✅ |
| `get_document_index/3` — inspect exactly what got indexed | ✅ |
| Package resolution: `package.json` dep → `doc_set` + version via `applies_to` (with fallback) | ✅ |
| `ensure_document` upsert with content hashing (dedup) | ✅ |
| db-gen typed wrappers → `KeenDocs.Database.*` (committed); `public` fns get no prefix | ✅ |

## 5. Web harness — Plug on Bandit (`KeenDocs.Web.Router`)

Deliberately minimal (Phoenix's substrate) so it promotes to `phx.new` + LiveView without rework.
Handlers are thin — data shape comes from the DB (`kind_code`/`show_in_path`/`applies_to`), never hardcoded.

| Route | Status |
|---|---|
| `GET /` — hub, every `doc_set` | ✅ |
| `GET /:set` — set landing (variants + their pages) | ✅ |
| `GET /:set/:seg` — guide pretty-URL (hidden variant) **or** variant landing, decided from `show_in_path` | ✅ |
| `GET /:set/:variant/:slug` — rendered document (markdown → regions → head/body/footer) | ✅ |
| `GET /search?q=&kind=` — full-text + trigram, ranked | ✅ |
| `GET`/`POST /resolve` — paste a `package.json` → matched doc links + version resolution | ✅ |
| `GET /apps_runtime.js` + `GET /apps/:name/main.mjs` — island runtime + bundles (`text/javascript`) | ✅ |
| **🔍 search-index inspector** panel on each doc — shows keywords (B) + extracted prose (C) | ✅ |

`make dev` → `http://localhost:4000` (frees the port first). Also: `make poc` (standalone `build/poc.html`),
`make demo` (read-only content visualizer), `make db-gen` (regenerate wrappers).

---

## What's not built yet (honest gaps)

| Gap | Status | Notes |
|---|---|---|
| Full Phoenix app | ⬜ | Still plain Mix + Plug; no LiveView. Harness designed to promote without rework. |
| `keendocs` CLI (pack + upload / ingest) | 🧪 | Publish/ingest + content-hash dedup proven in a spike; not productized. Mirrors `../pure-admin-cli`. |
| Multi-domain routing (hub + per-package domains) | ⬜ | Designed (`docs.keenmate.dev` + `web-multiselect.keenmate.dev`); not wired in the harness. |
| CEM → API reference generation | 🧪 | Spike only. |
| HEEx rendering target (real components in a Phoenix portal) | 🧪 | Proven in `tmp/heex_proof` (sentinel→neutralize→swap compile-safety); no live consumer yet. |
| Auth / profiles / favorites / notes | ⬜ | Central-DB features designed; not built. |
| `{{vars}}` templating in content | 🧪 | Spike only. |

## Repo status

All three sibling repos are committed on branch `prod` (a deliberate working-branch convention),
**not pushed**:

| Repo | Role |
|---|---|
| `../keen-markdown` | The extracted rendering engine (the core lives there) |
| `keen-docs` (this) | First consumer — docs-specific extensions, DB layer, web harness |
| `../keen-docs-database` | The SQL (content domain + framework), debee-managed |
