# Changelog

All notable changes to keen-docs are documented here. Format based on
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/). This is a pre-release POC, so
everything lives under Unreleased until the first tagged version.

## [Unreleased]

### Added — content columns render on pure-css `pa-grid` (`KeenDocs.Markup` profile) (2026-08-04)

keen-docs now ships a `KeenMarkdown.Profile` (`KeenDocs.Markup`, wired via
`config :keen_markdown, :profile`) that overrides the layout slots (Level-2 structure): `:::columns`
→ `.pa-row`, each `:::col` → `.pa-col-<width>`, a non-column child → `.pa-col-100`. So content
columns use pure-css's native grid — gutters, container-query responsiveness and mobile auto-stack
come for free — and share one grid vocabulary with pure-admin pages. Other blocks keep the engine's
default `km-*`.

- Column width comes from the engine's new `:col` `width` assign (`{part, total}`); it maps to an
  **exact** `pa-col` fraction when the ratio reduces to one pa-grid ships (`80/20` →
  `.pa-col-4-5`/`.pa-col-1-5`, thirds → `.pa-col-1-3`), else the nearest 5% column. A standalone
  `:::col` is an auto `.pa-col`.
- Dropped the now-dead `.km-columns` / `.km-columns__span` / `.km-col` grid rules from keendocs.css
  (content no longer emits them); the column label/body chrome (`.km-col__header--*`, `.km-col__body`)
  stays.

### Fixed — stale vendored grid (dead Yahoo `.pure-*`) (2026-08-04)

pure-css replaced its legacy Yahoo PureCSS grid (`.pure-g`/`.pure-u-*`) with the native flexbox
`pa-grid` (`.pa-row` / `.pa-col-{n}` 5% increments + `.pa-col-{x}-{y}` fractions + container-query
responsive + auto-stack). keen-docs' vendored `grid.css` was never updated — it still shipped 462
dead `.pure-*` rules and zero `.pa-*`. Re-vendored all three (`base`/`grid`/`utilities`) from the
current pure-css build; fixed a stale `.pure-u-*` comment in `router.ex`. (Nothing rendered a grid
class, so no visual change — it was dead weight served to every page.)

### Changed — harness chrome renamed `hz-*` → `kd-*`; more pure-css utilities (2026-08-04)

Now that `kd-*` denotes keen-docs' own vocabulary (content is the engine's `km-*`), the harness
chrome moved off the cryptic `hz-` ("harness") prefix onto `kd-*` — `kd-top`, `kd-side`,
`kd-nav-link`, `kd-card`, `kd-hero`, `kd-dd-menu`, … (a straight rename in `view.ex` + `router.ex`;
no collisions with keen-docs' existing `kd-page`/`kd-toc`/`kd-demo`/`kd-app`).

- **Border utilities used** on the footer (`.border-top`), hero (`.border-bottom`) and nav dropdown
  (`.border .rounded`), dropping the equivalent custom rules. (These were briefly enabled via a
  keendocs.css `--border-color`/`--border-radius` shim; that shim was **removed** once pure-css was
  fixed to make the border/rounded utilities self-sufficient and runtime-themeable — see the pure-css
  changelog. Re-vendored `base.css`/`utilities.css`.)
- **`@external_resource`** added for the inlined `base.css` + `dark-theme.css` in `view.ex`, so `mix`
  recompiles the view when they change (a bare compile-time `File.read` is invisible to the recompile
  tracker, which had silently inlined a stale `base.css`).
- Themed backgrounds/text-colours stay custom `var(--base-*)` — pure-css has no `bg-*` utilities and
  its colour utilities depend on framework vars the lean bundle doesn't carry.

### Changed — harness chrome lays out with pure-css utilities (2026-08-04)

The `hz-*` chrome classes stopped hand-rolling layout: the two-column shell, top nav, search,
sidebar nav, version label and footer now use `@keenmate/pure-css` utility/grid classes
(`d-flex`, `flex-column`, `align-items-*`, `gap-*`, `wr-16`, `flex-fill`, `ml-auto`). Fully-layout
classes (`hz-topnav`, `hz-nav`, `hz-footer-links`) were deleted; the rest slimmed to the bits
utilities can't express (themed surfaces/borders, `position: sticky`, component behaviour). Needed
one addition to the foundation — `gap-*`/`gap-x-*`/`gap-y-*` (see the pure-css changelog) — re-vendored.

### Changed — content vocabulary is now the engine's `km-*` (keen-docs owns only `kd-*`) (2026-08-04)

keen_markdown stopped hardcoding class names (see its changelog: presentation **profiles**, default
BEM `km-*`). keen-docs **adopts the engine default profile** — so rendered content is `km-card`,
`km-callout`, `km-columns`, `km-col__header--blue`, `km-code`, … — and the `kd-*` prefix now means
*only* keen-docs' own things.

- `priv/web/keendocs.css` — the generic content selectors were renamed to the engine's BEM `km-*`
  (`.km-card`/`.km-card__header`/`.km-card__body`, `.km-callout--warning`, `.km-columns`/
  `.km-columns__span`, `.km-col`/`.km-col__header--blue`, `.km-showcase__title`, `.km-code`). They're
  still styled off the `--base-*` contract, so theming/dark-mode are unaffected.
- **`kd-*` is now purely keen-docs'** — its extensions (`kd-demo`, `kd-app`, `kd-out`), the POC page
  shell (`kd-page`, `kd-toc`) and its CSS vars (`--kd-*`). No cross-repo leak: the engine's default is
  its own `km-*`, and keen-docs could override to any vocabulary via a profile if it wanted.
- No `:profile` config — keen-docs rides the default. A pure-admin / cafeindustrial consumer would
  set one (Level-1 class map or Level-2 structure) to get its own markup from the same documents.

### Added — dark mode (2026-08-04)

A site-wide dark theme, proving the `--base-*` foundation: one class flip re-themes the chrome, the
`kd-*` content, and embedded components together.

- **`priv/web/dark-theme.css`** — a lean `--base-*` override scoped to `html.pa-mode-dark`, using
  pure-admin's dark palette (`#1a1a1a`/`#242424`/`#333` surfaces, `#f2f2f2`/`#b8b8b8` text, `#404040`
  borders) and its `.pa-mode-dark` + `color-scheme: dark` dual-mode convention. Inlined into the page
  `<style>` (compile-time module attr) so the toggle flips with no flash.
- **Brand accent preserved across modes** — `theme_css/1` now also publishes the doc's raw accent as
  `--kd-doc-accent`; dark mode *brightens* it (`color-mix`) for contrast on dark surfaces instead of
  replacing it, falling back to pure-admin's dark blue on pages without a doc theme.
- **Toggle + FOUC-free init** — a top-bar `◑` button (`View.mode_toggle_html/0`) toggles the class and
  persists to `localStorage`; a tiny `<head>` script (`mode_init_js/0`) sets the initial mode before
  paint (explicit choice wins, else OS `prefers-color-scheme`). No framework, no re-render.
- Known gap: fenced-code highlighting is lumis **inline** styles (light bg), so code blocks stay
  light-themed in dark mode — a dark highlight-theme swap is a separate task.

### Changed — theming on the `@keenmate/pure-css` `--base-*` foundation (2026-08-04)

The harness and rendered content now derive every colour/font from the KeenMate `--base-*` custom
properties (the theming contract shared with pure-admin and every web/svelte component), instead of
the old bespoke `--kd-*` palette and hardcoded hex. One consequence is the headline win: an embedded
`<web-multiselect>` demo now inherits the doc's theme, because it reads the same `--base-*` variables.

- **New sibling package `@keenmate/pure-css`** (`../pure-css`) — the CSS foundation (`--base-*`
  variables + PureCSS grid + utilities + `.font-family-*`) extracted from `pure-admin-core` so
  docs/portals can consume it without the component library. keen-docs vendors its **built** CSS
  (`priv/web/vendor/pure-css/{base,grid,utilities}.css`) — no Sass toolchain here.
- **Delivery** — `base.css` (the `:root{--base-*}` defaults, 94 vars) is **inlined** into every page's
  `<style>` (FOUC-free, read at compile time from the vendored file); `grid.css` + `utilities.css` are
  **linked** (`GET /vendor/pure-css/:file`, served `text/css`) so authored content can use
  `.pure-u-*`/`.m-*`. The standalone POC (`KeenDocs.POC`) inlines `base.css` too.
- **Per-doc_set theme** — `accent_css/1` (which only set `--kd-accent`) is replaced by `theme_css/1`:
  it reads `settings.theme` and emits a `:root` override *after* the defaults. `theme.accent` sets
  `--base-accent-color` and re-derives hover/active/light at runtime via `color-mix()`; `theme.vars`
  is an escape hatch (`{"page-bg" => "#…"}` → `--base-page-bg`). The seeded web-multiselect accent
  (`#4f46e5`) and hub accent (`#0ea5e9`) now actually drive the whole page — no re-seed needed.
- `harness_css` and `keendocs.css` rewritten onto `var(--base-*, <fallback>)`; the `--kd-*` names
  survive as a thin semantic alias layer sourced from `--base-*`. The dark top-bar's on-bar shades
  and the categorical badge colours stay literal on purpose.

### Added — doc_set homepage, navigation sidebar & chrome in the harness (2026-08-04)

A `doc_set` is no longer just a list of pages — it renders as one product's docs site, driven
entirely by data (the DB changelog covers the `doc_set` presentation surface + `doc_nav` tree):

- **Navigation sidebar** — `KeenDocs.Web.View.sidebar_html/5` renders `get_doc_nav/1` rows
  (already in render order from the materialized-path tree; sections as group headers, leaves
  linking to their page in the active variant, current page marked). `render_document` and the
  set landing wrap the body in a two-column shell via the new `set_chrome/3`.
- **Custom homepage** — `GET /:set` now renders the set's authored `home_slug` document when it
  has one (`get_doc_set/1`), instead of the auto-generated variant list; the list stays the
  fallback for sets without a homepage.
- **Per-set chrome** — `layout/3` takes an `opts[:docset]` and paints the accent color
  (`--kd-accent`), the set title next to the brand, header links, and a footer (copyright +
  links) from the `settings` jsonb. Pages with no doc_set (hub / search / resolve) are unchanged.
- Page `nav:` frontmatter is no longer the source of truth for ordering — the authored
  `doc_nav` tree is. Requires `make db-gen` (new `get_doc_set` / `get_doc_nav` wrappers, changed
  `ensure_doc_set` arity).

### Added — Global (hub) homepage, pages & cross-set navigation (2026-08-04)

The hub is now its own site, not just an auto-generated index (backed by the new `site` /
`site_page` / `site_nav` domain — see the DB changelog):

- **Global top-nav** — `View.top_nav_html/0` renders `get_site_nav("hub")` site-wide in the
  header: level-1 items, a level-1 section becomes a hover dropdown of its children. Each leaf
  targets a doc_set (→ its homepage), an internal `site_page`, or an external URL — that union
  is the cross-set navigation.
- **Hub homepage** — `GET /` renders the hub site's authored `home_slug` page (with a hero from
  the site title + description) instead of the doc_set table; the table remains the fallback
  (`hub_index_table/1`) when no homepage is set.
- **Global standalone pages** — a bare `/:slug` that is not a doc_set resolves to a hub
  `site_page` (`/about`); `render_site_page/3` renders it full-width (the top-nav is its
  navigation, no doc_set sidebar), reusing the same footer/accent/head chrome as a doc_set.
- Authoring convention: a homepage rendered with a hero must not repeat the title as an `# H1`
  (the hero supplies it) — the seeded hub homepage was corrected to start straight with content.

### Added — Surface the rest of the doc_set settings (2026-08-04)

The presentation fields already stored on `doc_set` are now rendered — closing the mkdocs
parity bucket with no schema change:

- **`description`** — on the hub card (sub-line under the title) and as the homepage **hero**
  subtitle (`View.hero_html/2`; the homepage branch passes `hero: true`).
- **`settings.author`** — `<meta name="author">` and a footer credit linked to `site_url`.
- **`settings.site_url`** — a per-page `<link rel="canonical">` (`site_url` + request path).
- **`settings.social[]`** — rendered in the footer alongside the footer links.
- **`settings.head_assets[]`** — emitted into `<head>` (`View.head_asset/1`): a string is
  classified by extension (`.css` → stylesheet, `.js`/`.mjs` → module script), an object
  carries its own `rel`/`type`/`src`/`href`. Seed adds a `jsdelivr` preconnect as the example.

### Added — Version selector & doc-set-wide pages (2026-08-04)

- **Version selector** — a combobox at the top of the sidebar (`View.version_selector/4`)
  listing the set's versions (the `show_in_path` variants; a hidden `shared` variant is not a
  version). It **carries the current slug across versions** (`/web-multiselect/2.0.0/forms` →
  `…/3.0.0-rc1/forms`); on a doc-set-wide page it targets each version's Overview instead.
  Plain-page harness → a one-line `onchange` navigation, no framework.
- **Doc-set-wide pages** — pages that belong to the whole set, not a version (changelog,
  migration). They live in a hidden `shared` variant (`show_in_path=false`) so their URL omits
  the version segment (`/web-multiselect/changelog`), and a nav leaf reaches them by pinning
  `variant_code`. `router.ex` resolves a bare `/:set/:slug` in the default variant first, then
  any hidden variant (`resolve_page_variant/3`). The sidebar builds each leaf's URL from *its
  own* variant's `show_in_path`, so versioned and doc-set-wide links coexist correctly.

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
