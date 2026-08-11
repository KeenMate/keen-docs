# Theming stress-test — driving the DHL theme to 1:1

Goal: take `design/dhl.html` (a hand-drawn "fantasy" mockup) and reproduce it **on the real render
system** (theme = overlay on `core.css` skinning the actual `pa-*`/`kd-*`/`km-*` DOM), pushing to 1:1
to discover **what the theming/render system needs to expose**. Iterated with a Playwright
screenshot+inspect loop (`tmp/pw/`: `shot.js`, `region.js`, `vars.js`).

Live theme: `priv/web/vendor/themes/dhl/` (`theme.json` `base:core` + `dist/dhl.css` + `assets/`),
`config :keen_docs, :theme, "dhl"`. Compare: `design/shots/`.

## What the skin (pure CSS on the real DOM) already achieves ✅
Navbar (yellow + red rule), sidebar active pill, page head (Archivo 900 H1), **callout icons**
(type-coloured `::before` — no render change needed), showcase column cards + coloured headers,
yellow card header bars, **red table headers** + zebra, code frames, dark footer, light/dark. So the
palette + component look is fully theme-reachable via `--pa-*`/`--base-*` + selector overrides.

## Gotcha found (and fixed)
A `*/` inside a CSS comment (`pa-*/kd-*`) silently truncated the whole `:root`, so every custom prop
was undefined and the theme half-applied. **Only caught by inspecting computed styles in Playwright.**
Lesson: theme CSS authored by hand needs a lint/guard for stray comment terminators (and the future
`keendocs` CLI's render-contract validation should cover it).

## Extensibility findings — what the render system must expose

| # | Gap (DHL needs) | Today | Class | Status | Proposed mechanism |
|---|-----------------|-------|-------|--------|--------------------|
| 1 | **Brand logo** in the navbar | hardcoded `keen-docs` wordmark | render | ✅ **done** | render block `brand: {logo, label}` → `View.brand_html/2`; logo served as a theme asset (`/themes/<id>/assets/…`). DHL ships `dhl-logo.svg` + label "Developer Docs". |
| 2 | **Fewer / focused header items** (3 nav + search + one GitHub button) | harness dumped top-nav + `header_links` + Resolve + profile → center/search collapsed | render | ✅ **done** | (a) navbar rebuilt on pure-admin's **own** components — `pa-header__nav > ul > li > a` + `pa-header__dropdown` (hover, no JS) and `.pa-navbar-search`, replacing the bespoke `kd-topnav`/`kd-dd`/`kd-search`; (b) a render-block `header` config (`nav`/`links`/`resolve`/`modeToggle`/`profile` toggles + a `cta:{label,url,icon,style}` `pa-btn` CTA) chooses what occupies the bar. DHL sets `links:off, resolve:false, cta:GitHub` → search no longer crushed. |
| 3 | **Active top-nav section** (COMPONENTS pill) | top nav rendered no active state | render | ✅ **done** | `top_nav_html/1` marks the matching top node `pa-header__nav-item--active` (a **leaf** matches its own `doc_set_code`, a **section** matches when a child does — so "Components" lights up under web-multiselect). Styling is now **core-native** (rc09 ships `.pa-header__nav-item--active` = a currentColor pill); our custom underline rule was dropped in the convergence. A theme can still retint it. |
| 4 | **Version selector = package name + version badge** | `version` label + native `<select>` | render | ⬜ open | render the doc_set/package name as context + the version as a styled badge (keep the `<select>` for switching, or a button+menu). Purely-native `<select>` can't reach the pill look. |
| 5 | **Code block chrome** (lang label, traffic-lights, copy) | `.km-code > pre.lumis > code.language-x` | render (keen-markdown) | ⬜ open | expose the language on the `.km-code` wrapper (`data-lang`) so a theme can render a header via CSS; a copy button needs a tiny JS hook. Traffic-lights are pure CSS decoration. |
| 6 | **Callout icons** per type | `km-callout--<type>` (no icon el) | CSS | ✅ works | theme draws the icon with `::before` keyed on the type modifier — no render change needed. Good: callouts are icon-themeable as-is. |
| 7 | **H2 inline chips** ("FI01" badge) | plain markdown heading | authoring | n/a | author-side (inline markup / a renderer convention), not a theme concern. |
| 8 | **Component demo** (fancy facsimile) | real live `kd-demo` mount (collapsed source) | n/a | n/a | real vs fantasy — the real demo is the actual web component; not something the theme reproduces. |

### ⚠️ Systemic finding — the theming contract covers COLOURS, not SPACING

The `--pa-*` / `--base-*` contract exposes **colours, backgrounds, borders, fonts, radii** — but
**layout metrics (padding / margin / gaps / sizes) are hardcoded literals** in `core.css`. So a theme
can recolour anything with a variable, but to change *spacing* it must **override selectors** (fragile,
specificity-prone, per-theme boilerplate). Driving the DHL sidebar to 1:1 forced selector overrides for
every one of these:

| hardcoded in core/harness | had to override | should be |
|---|---|---|
| `.pa-sidebar__nav{padding:1.6rem 0}` | `padding:0` | `--pa-sidebar-nav-padding` |
| `.pa-layout__sidebar{padding:0}` (none) | `2.2rem 1.8rem 4rem` | `--pa-sidebar-padding` |
| `.pa-sidebar__link` font 16px / pad | 14px / `.7rem 1.1rem` | `--pa-sidebar-link-font-size` / `--pa-sidebar-link-padding` |
| `.kd-nav-section` margin/indent | `2.4rem 0 .8rem` / `padding-left:.8rem` | `--pa-sidebar-section-margin` / `--pa-sidebar-section-indent` |
| leaf `margin-inline-start` per level | removed | `--pa-sidebar-nesting-indent` |

**As the user put it: there's no `--pa-sidebar-top-margin` (or any spacing token) and there should be.**
This is the biggest systemic gap the stress-test found: the theming system needs a **spacing/metrics
token layer** parallel to the colour one — literals become `var(--pa-…, <default>)`, so themes tune
layout **declaratively via variables** instead of overriding selectors.

**✅ Prototyped for the sidebar** (`View.harness_css`): the `--pa-sidebar-*` set is now token-driven with
the defaults living in the `var()` fallbacks (NOT a `:root{}` block — a `:root` block is fragile: a stray
`*/` in a nearby comment silently drops it, which happened here). DHL now sets **3 tokens** in its `:root`
and carries **zero** sidebar-spacing selector overrides; Aurora/baseline get the improved defaults free.
Next: extend the same treatment to `--pa-navbar-*` / `--pa-content-*`, and ultimately push it **upstream
into pure-admin-core** so it's not a keen-docs-only patch. And add a **stray-`*/`-in-comment lint** to the
keendocs CLI's render-contract validation — this class of bug has now bitten twice (DHL skin `:root`,
harness `:root`), invisible in the source, only caught by inspecting computed styles in Playwright.

### ⚠️ Finding — an embedded component can clobber the theme's `--base-*` at `:root`

Porting the version control to a live `<web-multiselect>` (render block `versionControl:{type,module,style,label}`
→ `View.version_selector`) revealed the component **writes `--base-accent-color:#4f46e5` onto `:root` on
upgrade** (its fallback), overriding the *theme's* accent on any page it's embedded. Themes that drive
links/buttons off `--base-accent-color` would get tinted on demo pages. Mitigation used: the version dot
reads `--pa-accent` (chrome token, untouched). Real fixes: (a) the component should scope its `--base-*`
fallbacks to its host, not `:root` (upstream web-multiselect); (b) keen-docs chrome should prefer `--pa-*`
for its own accents. Note-to-self: this is the flip side of "components read `--base-*`" — they must not
*write* them globally.

### ⚠️ Finding — pure-admin's header is a fixed 3-slot flex; start/end are `flex-shrink:0`

Adopting pure-admin's own navbar (gap #2) exposed the shape of its header: `.pa-navbar__inner` is a
flex row of `.pa-header__start` · `.pa-header__center` · `.pa-header__end`, where **start and end are
`flex-shrink:0`** and only the centre (`flex:1; min-width:0`) can shrink. So the model assumes a
*modest* item budget — pile the whole hub nav into `start` and `header_links` + Resolve into `end` and
the centred search collapses to zero and the shrink-0 sides overlap (seen: search crushed behind
"GitHub"). The bend that fits docs is **compositional, not CSS**: choose what occupies the bar (the
`header` render-block) rather than fight the flex. Left open upstream: pure-admin could add a
`--pa-navbar-*` spacing layer and/or let the nav region shrink/scroll, so a heavier nav degrades
gracefully instead of crushing the search. Also unresolved: the hub nav still carries a "GitHub" text
item *and* we add a GitHub CTA — dedupe belongs in the hub-nav seed, not the theme.

**Resolution — the sidebar is the navbar's overflow surface (now via pure-admin's own rc09 mechanism).**
pure-admin was never designed to work *without* a sidebar; keen-docs always pairs navbar + sidebar, so
at narrow widths the hub nav doesn't vanish — it **moves into the sidebar**. We first hand-rolled this
(CSS-only, all-or-nothing at ≤1024), then **converged onto pure-admin rc09's `navbar-collapse.js`**
(`data-pa-nav-collapse="sidebar"`), which does true priority-driven per-item overflow into a "Browse"
`.pa-sidebar__section` (leaves → links, dropdowns → collapsible groups), auto-pins `--active`, and
restores on widening. `layout/3` always renders a sidebar host (`#kd-nav-overflow`); the empty host +
otherwise-empty aside self-hide via `:has()`, so even the hub *grows* a sidebar only when items fold in.
This is a small, deliberate departure from the CSS-only/no-JS stance — the collapse is progressive
enhancement (SSR stays deterministic; JS only reflows by viewport). Non-nav controls still shed via CSS
(`≤1200` utility links → `≤768` CTA label → `≤560` search + brand suffix). Also fixed here: the brand is
a **stacked** wordmark (`kd-brand-label` > `kd-brand-set`, tunable via
`--pa-brand-label-size`/`-set-size`/`-divider`) — the inline suffix had been oversized.

### Positive findings (system already flexible enough)
- **Overlay-on-core** works cleanly: a hand-authored theme reskins the whole page via variables +
  selector overrides, no SCSS build, no framework fork.
- `--pa-*` (chrome) + `--base-*` (content) + `html.pa-mode-dark` reach every surface incl. embedded
  components. Callout icons, table headers, card bars, code frames all reachable in pure CSS.
- The render block (`toc`, `fonts`, now `brand`) is the right home for declarative per-theme
  page-assembly — extending it (now `brand`, `versionControl`, `header`) is the natural path for #2–#4.
- **Pure-admin's own navbar components fit docs** with only two small bends: a real submittable
  `<input>` inside the `.pa-navbar-search` trigger box, and a dropdown caret. The `pa-header__dropdown`
  reveals on hover with **no JS** — one less bespoke widget to own.

## Next
- **Spacing/metrics token layer** (the systemic finding above) — expose `--pa-*` spacing variables in
  pure-admin-core + harness defaults, so layout is tunable via variables not selector overrides. Top
  priority: it's what makes every *other* theme cheaper to build.
- Render extensions: #2 (header config) ✅, #3 (nav active) ✅, #4 (version control → live
  `<web-multiselect>`) ✅ done. Next: #5 (code-block chrome) is a keen-markdown change. Dedupe the
  hub-nav "GitHub" seed item now that a CTA covers it.
