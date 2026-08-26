# Changelog

All notable changes to keen-docs are documented here. Format based on
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/). This is a pre-release POC, so
everything lives under Unreleased until the first tagged version.

## [Unreleased]

### Added — reader settings panel (pure-admin offcanvas), sidebar-resize as a setting (2026-08-11)

Ported pure-admin's floating **settings panel** — the gear-tab offcanvas drawer, styled entirely by
the already-vendored `core.css` (`.pa-settings-panel*` + `.pa-checkbox`), so this is markup + JS +
wiring with no new CSS. Scoped to the preferences keen-docs actually supports (no theme-manifest
fetch / container-width / RTL / profile options from pure-admin's demo panel — the theme stays
server-resolved per doc_set / config).

- **Controls** — Appearance (Auto/Light/Dark), Font size (rescales the `<html>` rem base via core's
  `.font-size-*`; default 10px = keen-docs' base), Font family (`--base-font-family` override, Google
  fonts pulled on demand), Sidebar (Docked/Hidden + a Resizable checkbox), and Reset to defaults. All
  persist to `kd-*` `localStorage` and apply **without a reload**.
- **Sidebar resize is now a setting** — the aside no longer hardcodes `pa-layout__sidebar--resizable`;
  the panel adds/removes it (default **on**, preserving prior behavior) and (re)inits or strips the
  vendored `sidebar-resize.js` handle. "Hidden" toggles `body.sidebar-hidden` (core collapses the
  docked sidebar to reclaim reading width; independent of the mobile `sidebar-visible` burger overlay).
- **No-flash restore** — `pref_init_js` (renamed from `mode_init_js`) now restores **both** the colour
  mode and the font-size class in the `<head>` pre-paint, since both toggle a class on `<html>` and
  restoring them from the end-of-body panel script would reflow. The panel only reflects these into its
  controls; font-family + sidebar states (which don't reflow) are restored by the panel script.
- **Serving** — the panel driver is keen-docs' own `priv/web/keendocs/settings-panel.js` (its control
  set differs from pure-admin's demo, so it's *not* vendored), served via a new `/keendocs/:file` route.
- Verified end-to-end (Playwright): open/close (toggle + outside-click), each control's effect + its
  `localStorage` key, pre-paint mode/font-size restoration on reload, panel reflecting persisted state,
  and the resizable-off setting suppressing the handle across a reload.

### Fixed — adopted pure-admin's real app-shell sidebar; killed the navbar overlap (2026-08-10)

Three navbar/sidebar defects surfaced together (thin sidebar, sidebar not reaching the footer,
navbar items overlapping the search). All three were keen-docs *diverging* from pure-admin's own
layout rather than using it — so the fix was to converge, again.

- **Full-height sidebar (app-shell)** — switched the page to pure-admin's **sticky layout mode**
  (`<body class="pa-layout--sticky">`). The aside is now a stretched flex child spanning
  header→footer with its own internal scroll (verified: aside bottom = footer top at every width);
  the footer stays pinned. Removed the harness override (`.pa-layout__sidebar{position:sticky;
  align-self:flex-start;max-height}`) whose `align-self:flex-start` was collapsing the sidebar to its
  content height. **Behavioural note:** content now scrolls inside `.pa-layout__content`, not the
  window — the faithful pure-admin admin-shell model.
- **Resizable sidebar + real width** — the aside carries `pa-layout__sidebar--resizable` and we
  vendored pure-admin's `sidebar-resize.js` (drag handle, min 18rem / max 50rem, `localStorage`,
  double-click reset; writes `--pa-local-sidebar-width`). The harness now pins the width to that var
  so it beats core's `@media(769–1024px){width:16rem}` tablet reduction — which was the "very thin"
  (160px) sidebar. Core's ≤768 auto-hide (burger overlay) still wins on specificity.
- **Navbar overlap → honest collapse** — the top-nav *was* collapsing by real measurement, but the
  search still overlapped items by 37–66px. Root cause: the search's `min-width:18rem` sat on the
  input (a grandchild), so flexbox only reserved `.pa-header__center`'s own `min-width:0`, let center
  grow to a sliver, and the search overflowed onto `start`/`end` — a deficit `navbar-collapse.js`
  couldn't see (it measures the nav's slot, which never shrank). Fix: move the reserve onto the
  **flex item** (`.pa-header__center{min-width:18rem}`, search `min-width:0`). Now flex shrinks
  `start` → the nav's slot shrinks → the collapse folds items into the sidebar until the search fits.
  Result: a clean 16px gap on both sides across 561–1400px, search keeps 186–252px, nav folds
  5→4→3→2→1 as space tightens. Also shed the ~190px stacked brand wordmark to the logo alone below
  1150px (`@media(max-width:1150px){.kd-brand-label{display:none}}`) so the fold has room before it
  starts.
- **Vendoring** — `make vendor-pa-core` now also copies `navbar-collapse.js` and `sidebar-resize.js`
  from `../pure-admin`, so the three vendored artifacts re-sync together (README updated).

### Changed — converged navbar/sidebar onto pure-admin rc09 (navbar-collapse.js), dropping our hand-rolled overflow (2026-08-08)

pure-admin rc09 shipped a first-class version of exactly what we'd hand-rolled (*"responsive navbar
collapse + nav active state + sidebar section"*), and it even uses the class names we'd invented. Rather
than maintain two implementations, we adopted pure-admin's as-is — the navbar/sidebar are now **one
implementation**, not a parallel keen-docs copy.

- **Baseline bump** — re-vendored `core.css` from pure-admin **2.9.0-rc11** (`make vendor-pa-core`),
  which brings `.pa-header__nav-item--active` (a currentColor pill), `.pa-sidebar__section`,
  `.pa-sidebar__divider`, and the `data-pa-nav-collapse` layout contract (nav `overflow:visible` +
  shrinkable `pa-header__start`).
- **Vendored `navbar-collapse.js`** (rc09, self-contained vanilla JS, `ResizeObserver`, auto-init,
  `window.PaNavCollapse`) → `priv/web/vendor/pure-admin/`, served by `/vendor/pure-admin/:file` (now
  content-type-by-extension) and `<script>`-loaded at body end. It's progressive enhancement: the SSR
  output is unchanged/deterministic; the JS only reflows client-side by viewport.
- **Priority-driven overflow → sidebar** — the top-nav carries `data-pa-nav-collapse="sidebar"` +
  `data-pa-nav-collapse-target="#kd-nav-overflow"`; as the header narrows the JS folds the
  lowest-priority items into the sidebar under a "Browse" `.pa-sidebar__section` (leaves → links,
  dropdowns → collapsible toggle groups), and restores them as it widens. Replaces our all-or-nothing
  CSS breakpoint with real per-item measurement. rc11 dropped the old auto-pin of the active item, so we
  pin it ourselves — `top_nav_html` emits `data-pa-nav-priority="100"` on the current section, keeping it
  on the bar while the rest collapse first.
- **Sidebar everywhere** — `layout/3` always renders a sidebar host containing the overflow target, so
  even sidebar-less pages (the hub) receive the fold-in. The empty host and an otherwise-empty aside
  self-hide via `:has()`, so the hub reads full-width until items actually overflow, then *grows* a
  sidebar. (Answers the standing point that pure-admin assumes a sidebar exists.)
- **Injected-block polish** — the folded-in "Browse" items now match the doc-nav look: no bullet icons
  (`data-pa-nav-collapse-icon=""`), the dropdown caret is a CSS `::after` (not text) so rc11's `labelOf()`
  can't copy it into the rebuilt label (was showing our ▾ *and* the sidebar chevron — a double toggle),
  toggle rows share the link padding token, and the populated overflow host gets `margin-bottom` so it
  isn't crammed against the version pill. Also aligned a folded group's toggle label with the leaf links:
  the DHL theme moves the active bar to `border-inline-start` on `.pa-sidebar__link` (a 3px left inset)
  but not `.pa-sidebar__toggle`, so the toggle label sat 3px left — DHL now applies the same border to
  both. Doc-nav section headings are native `.pa-sidebar__section` (DHL restyled from the old `kd-nav-section`).
- **Removed** the hand-rolled `sidebar_hubnav_html`/`hub_target`, the `kd-sidebar-hubnav` +
  `kd-nav-section` CSS, the custom `.pa-header__nav-item--active` rule, and the `@media` that hid
  `.pa-header__nav` — all superseded by the native mechanism. Doc-nav section headings are now native
  `.pa-sidebar__section`.


### Changed — navbar rebuilt on pure-admin's own components + declarative `header` block (2026-08-06)

The navbar was the least pure-admin-native part of the chrome (bespoke `kd-topnav`/`kd-dd`/`kd-search`
in pure-admin's slots). Rebuilt it on pure-admin's **own** components and made its composition
theme-declarative (DHL stress-test gap #2). See `docs/theme-stress-test-dhl.md`.

- **Native nav** — `top_nav_html` now emits `pa-header__nav > ul > li > a` with a nested
  `ul.pa-header__dropdown` for sections; the dropdown reveals on hover via pure-admin's CSS, **no JS**.
  Removed the `kd-topnav`/`kd-top-link`/`kd-dd*` widgets and their harness CSS.
- **Native search** — the header search is now pure-admin's `.pa-navbar-search` box (icon · input · `/`
  kbd). Bend: a real submittable `<input>` sits where its placeholder span would (`.pa-navbar-search__input`).
- **`header` render-block** (contract v1.0) — chooses what occupies the bar: `nav` (`hub`|`off`),
  `links` (`show`|`off`), `resolve`/`modeToggle`/`profile` bools, and `cta: {label, url, icon, style}`
  (a `pa-btn--<style>` call-to-action). `View.header_end_html/2` composes `pa-header__end` from it.
- **Active top-nav** (DHL gap #3) — `top_nav_html/1` marks the current doc_set's top node
  `pa-header__nav-item--active` (a leaf matches its own `doc_set_code`; a section matches when a child
  does, so "Components" lights up under web-multiselect). Styled accent-underline + bold, themeable via
  `--pa-accent`/`--pa-header-text` (DHL → red underline).
- **Finding** — pure-admin's header is a fixed 3-slot flex with `flex-shrink:0` start/end, so too many
  items crush the centred search; the fix is compositional (the `header` block), not CSS. DHL sets
  `links:off, resolve:false, cta:GitHub` → the search is no longer squished.

### Changed — responsive navbar: stacked brand + navbar→sidebar overflow (2026-08-06)

Follow-up to the navbar rebuild, making the bar hold up as it narrows (it was cramming ~940px).

- **Stacked brand** — the wordmark is now the theme label over a small doc_set line (`kd-brand-label` >
  `kd-brand-set`), divided from the logo by a left rule (matches the DHL mockup). Sizes tunable via
  `--pa-brand-label-size` / `--pa-brand-set-size` / `--pa-brand-divider` (defaults 12px / 10px).
- **Navbar→sidebar overflow** — instead of the hub nav just vanishing at narrow widths, it renders a
  second time as the sidebar's first block (`kd-sidebar-hubnav`, a "Browse" group), hidden at wide
  widths and CSS-revealed at ≤1024px — the same breakpoint where `pa-header__nav` hides. So the items
  **move into the sidebar** rather than becoming unreachable. Deterministic (both copies are SSR'd; CSS
  chooses which shows) — no JS overflow measurement. `View.sidebar_hubnav_html/1`.
- **Progressive shedding** — as the bar narrows it drops least-important-first: `≤1200px` utility links
  (Resolve/`header_links`), `≤1024px` the top nav (→ sidebar) + CTA label (→ icon only), `≤560px` the
  centred search + brand suffix. Widths are tunable; the *order* is the design.
- **Note** — this is the answer to "pure-admin was never designed to work *without* a sidebar": keen-docs
  pairs navbar + sidebar and treats the sidebar as the navbar's overflow surface.

### Added — DHL theme driven to 1:1: render extensions + spacing tokens (2026-08-06)

A stress-test — reproduce the hand-drawn `design/dhl.html` mockup **on the real render system** (theme
= overlay skinning the actual `pa-*`/`kd-*`/`km-*` DOM) — to find what the theming/render system must
expose. Iterated with a Playwright screenshot+computed-style loop (`tmp/pw/`, gitignored). Catalogued in
**`docs/theme-stress-test-dhl.md`**. New capabilities, all render-block-declarative:

- **Brand slot** — `keendocs.brand: {logo, label}` → `View.brand_html/2` renders a theme logo (a theme
  asset served at `/themes/<id>/assets/…`) + label in place of the hardcoded `keen-docs` wordmark. DHL
  ships `dhl-logo.svg` + "Developer Docs".
- **`versionControl` render block** — a theme can render the version switcher as a live
  `<web-multiselect multiple="false">` instead of a native `<select>` (dogfooding): `{type, module,
  style, label}`. `View.version_selector/5` emits the package pill + component; the module/style load in
  the head (before the theme CSS so the theme's palette wins); navigate-on-change in `layout_js`.
- **Sidebar spacing-token layer** — the systemic finding: the `--pa-*`/`--base-*` contract covered
  colours but **hardcoded spacing** as literals, forcing selector overrides. `harness_css` now drives
  sidebar layout off `--pa-sidebar-*` tokens (padding, nav-padding, item-gap, link-padding/font-size,
  section-margin/indent/font-size) with defaults in the `var()` fallbacks. A theme tunes layout by
  setting a few tokens (DHL sets 3) instead of overriding selectors; every theme gets the fixed defaults
  (proper padding, aligned section headers, no core `.pa-sidebar__nav` top gap).
- **Sidebar nav alignment** — `View.sidebar_html` no longer indents section-grouped leaves per level
  (level-2 leaves aligned with ungrouped level-1 like "Overview"); only genuine level-3+ nesting indents.
- **web-multiselect nav reorder** — the example doc_set's nav now leads with a `Project` section holding
  Overview + the doc-set-wide changelog/migration (edited `999_examples.sql` `ensure_doc_nav` calls +
  applied surgically to the live DB). Confirms section names/order are **per-doc_set seed data**, never
  hardcoded.
- Findings logged for follow-up: an embedded `<web-multiselect>` **writes `--base-*` onto `:root`** on
  upgrade (clobbers the theme accent — dodged via `--pa-accent`); and a **stray `*/` inside a CSS comment**
  silently truncates a rule (bit us twice — a lint belongs in the future keendocs CLI's contract check).

### Added — keen-docs themes (Aurora, DHL) as override-on-core skins (2026-08-05)

keen-docs' own themes are the **design directions** in `design/*.html` (aurora, brand, editorial,
terminal, glass, dhl…), authored as **overlays on the vendored `core.css`** — a `theme.json` with
`"base": "core"` + a `dist/<id>.css` that reskins the *real* DOM via `--pa-*`/`--base-*` overrides +
`html.pc-mode-dark`, no SCSS build. (The copied pure-admin bundles — nato/dracula/corporate — were only
to prove the mechanism; they're **standalone** bundles that replace `core.css`. `KeenDocs.Themes.overlay?/1`
picks the delivery per theme.) Aurora (airy modern-SaaS) and DHL (yellow/red, Archivo) both ship live;
`design/aurora.css` + the static `aurora-real.html`/`dhl-pure.html` were the authoring previews (built by
capturing the real rendered DOM and skinning it, so they never diverge from real markup).

### Added — Declarative theme render layer (the `keendocs` render block) (2026-08-05)

Beyond CSS, a theme carries a small **declarative** page-assembly block (contract v1.0) that `View.layout/3`
interprets — no theme-supplied code (keeps the deterministic/no-RCE invariants). `KeenDocs.Themes.render_block/1`
deep-merges baseline defaults ← `keendocs.json` per-theme block ← the theme's own `theme.json` `keendocs`.
Vocabulary: `pageHead` (hero/crumbs/badges), `toc` (off/inline/right-rail, from the doc's headings),
`regions` (sidebar/footer/search toggles), `layout` variant class, `fonts` (`<link>` + `--base-font-family*`),
`brand`, `versionControl`. Defaults reproduce the baseline exactly (a themeless page is byte-identical).
Router migrated its `hero:` callers to `page:` + `toc:` data — the doc supplies *what*, the theme decides
*how*. Full vocabulary table in `docs/themes.md`.

### Added — Theme bundles: pure-admin's theme mechanism, keendocs-flavoured (2026-08-05)

keen-docs replicates pure-admin's whole theming mechanism. Baseline is the single vendored **`core.css`**
framework bundle (`make vendor-pa-core`, served at `/vendor/pure-admin/:file`) — it carries the 10px rem
base, reset, grid, utilities, all `pa-*` chrome and a baked light palette, so `View.styles/1` links one
sheet instead of the old hand-extracted `layout.css`/`profile-panel.css` fragments (now unreferenced,
pending removal). Themes are declared in **`keendocs.json`** (`themesDir` + `source` + `themes`), installed
under `priv/web/vendor/themes/<id>/` (`theme.json` + `dist/<id>.css` + `assets/`), served at
`/themes/:id/dist/:file` + `/themes/:id/assets/*`. **`KeenDocs.Themes`** answers which themes exist/where
(`declared`/`installed?`/`overlay?`/`local?`/`read`/`render_block`) and `seed_from/1` (+ `make seed-themes`)
copies the pure-admin sample bundles from `../pure-admin-themes` (writing `keendocs.lock.json`). Selection:
`config :keen_docs, :theme` globally, overridable per doc_set via `settings["theme"]["id"]` (which also
carries the existing `accent`/`vars` micro-override); `nil`/uninstalled → the core baseline. Modes work
theme-agnostically (bundles scope dark as a bare `.pc-mode-dark`, toggled on `<html>`). The plan of record
lives in **`docs/themes.md`** (Phases 1–3 done; 4 = the keendocs CLI, 5 = cleanup).

### Fixed — dark-mode readability: card headers & error blocks (2026-08-04)

Card headers were white-on-light (unreadable) in dark mode: `.km-card__header` used
`background: var(--kd-secondary)` — but that's `--base-text-color-1`, a *text* colour, which flips
light in dark mode (a filled bar sourced from a text colour). Switched to `--base-inverse-bg` (dark
in both themes → white text always reads). Same class of bug fixed on `.kd-demo-orphan` /
`.kd-app-error` (hardcoded light `#fdecee` → `--base-danger-bg-light` / `--base-danger-color`). The
`.kd-badge` category chips keep their literal colours on purpose (self-contained pills).

### Added — content columns render on pure-css `pa-grid` (`KeenDocs.Markup` profile) (2026-08-04)

keen-docs now ships a `KeenMarkdown.Profile` (`KeenDocs.Markup`, wired via
`config :keen_markdown, :profile`) that overrides the layout slots (Level-2 structure): `:::columns`
→ `.pc-row`, each `:::col` → `.pc-col-<width>`, a non-column child → `.pc-col-100`. So content
columns use pure-css's native grid — gutters, container-query responsiveness and mobile auto-stack
come for free — and share one grid vocabulary with pure-admin pages. Other blocks keep the engine's
default `km-*`.

- Column width comes from the engine's new `:col` `width` assign (`{part, total}`); it maps to an
  **exact** `pc-col` fraction when the ratio reduces to one pa-grid ships (`80/20` →
  `.pc-col-4-5`/`.pc-col-1-5`, thirds → `.pc-col-1-3`), else the nearest 5% column. A standalone
  `:::col` is an auto `.pc-col`.
- Dropped the now-dead `.km-columns` / `.km-columns__span` / `.km-col` grid rules from keendocs.css
  (content no longer emits them); the column label/body chrome (`.km-col__header--*`, `.km-col__body`)
  stays.

### Changed — vendored pure-css now tracks the published npm release (2026-08-04)

`@keenmate/pure-css` is published (`1.0.0-rc01`), so the vendored CSS tracks a pinned **release**
instead of a local working-copy build — the registry is the single source of truth, which is what
prevents drift like the stale-grid bug below. New `make vendor-css` `npm pack`s the pinned version
(`PURE_CSS_VERSION` in the Makefile) and copies its `dist/css` into `priv/web/vendor/pure-css`;
provenance README rewritten (it was itself stale, still describing `.pure-*`). Current bytes are
byte-identical to `1.0.0-rc01`.

### Fixed — stale vendored grid (dead Yahoo `.pure-*`) (2026-08-04)

pure-css replaced its legacy Yahoo PureCSS grid (`.pure-g`/`.pure-u-*`) with the native flexbox
`pa-grid` (`.pc-row` / `.pc-col-{n}` 5% increments + `.pc-col-{x}-{y}` fractions + container-query
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

- **`priv/web/dark-theme.css`** — a lean `--base-*` override scoped to `html.pc-mode-dark`, using
  pure-admin's dark palette (`#1a1a1a`/`#242424`/`#333` surfaces, `#f2f2f2`/`#b8b8b8` text, `#404040`
  borders) and its `.pc-mode-dark` + `color-scheme: dark` dual-mode convention. Inlined into the page
  `<style>` (compile-time module attr) so the toggle flips with no flash.
- **Brand accent preserved across modes** — `theme_css/1` now also publishes the doc's raw accent as
  `--kd-doc-accent`; dark mode *brightens* it (`color-mix`) for contrast on dark surfaces instead of
  replacing it, falling back to pure-admin's dark blue on pages without a doc theme.
- **Toggle + FOUC-free init** — a top-bar `◑` button (`View.mode_toggle_html/0`) toggles the class and
  persists to `localStorage`; a tiny `<head>` script (`mode_init_js/0`) sets the initial mode before
  paint (explicit choice wins, else OS `prefers-color-scheme`). No framework, no re-render.
- **Code blocks follow the mode too** — keen_markdown now highlights code once for both themes via
  `light-dark()` (its `:dark_theme` / multi-themes formatter), so `.pc-mode-dark`'s `color-scheme: dark`
  flips fenced code (tokens + background) to `github_dark` with no extra work here. (Closes the earlier
  "code stays light in dark mode" gap — see the keen-markdown changelog.) `github_light`/`github_dark`
  are the defaults; overridable via `config :keen_markdown, :theme` / `:dark_theme`.

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
