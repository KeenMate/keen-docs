# keen-docs templates

A **template** is a complete visual system for a keen-docs site — layout shell, typography,
chrome, and content styling. It is the keen-docs analogue of a `pure-admin-themes` theme, and
this directory mirrors that repo's anatomy on purpose (theme discovery by manifest, `dist/` CSS,
a `content` markdown blurb, `pa-mode-{mode}` dark switching), so we can grow the same
`build → pack → publish` CLI later without rework.

> **Reference:** `../../../pure-admin-themes` — the pattern we follow. A pure-admin theme only
> recolors a fixed framework layout. A keen-docs template also owns the **layout + chrome + type**,
> because our "framework" (`KeenDocs.Web.View`) is deliberately thin.

## The orthogonal split: template = shape, doc_set theme = palette

| Concern | Owner | Mechanism |
|---|---|---|
| Layout shell, chrome look, typography, radii, gradients, component styling | **template** (this dir) | `dist/<id>.css` bound to the markup contract |
| Brand **colours** (accent, surfaces, semantic) | **doc_set theme** | `--base-*` overrides (`KeenDocs.Web.View.theme_css/1`) |
| Base colour **defaults** | `@keenmate/pure-css` | vendored `base.css` |

A template reads colours through the `--base-*` contract, so the **same template re-tints per
doc_set**: Calm on the KeenMate set is keen-blue; Calm on a DHL set (whose theme sets
`--base-accent-color` red) is red — no second template needed. Templates change the *shape*;
doc_set themes change the *hue*.

## Anatomy of a template

```
priv/templates/<id>/
  template.json      # manifest (see below) — presence of this file = "this is a template"
  dist/<id>.css      # the stylesheet: chrome + content, bound to the markup contract
  src/scss/<id>.scss # (optional, later) authored source that compiles to dist/<id>.css
  preview.html       # standalone: sample doc page in contract markup + link to dist/<id>.css
  README.md          # blurb, screenshots, notes
```

`template.json` largely follows `pure-admin-theme.schema.json` (`name`, `id`, `version`,
`description`, `content`, `author`, `license`, `modeCssClass`, `colorVariants[].modes[].colors`,
`features`, `exports`) plus a keen-docs `keenDocs` block (`layout`, `contract`, `fonts`).

## The markup contract (what a template styles)

Templates never invent class names — they style the **stable classes** the engine + `View` emit.
Keeping this list stable is what lets any template render any page.

### Chrome — `kd-*` (emitted by `KeenDocs.Web.View`)
- Top bar: `.kd-top` › `.kd-brand`, `.kd-brand-set`, `.kd-top-link`, `.kd-dd`/`.kd-dd-menu`,
  `.kd-search` (input + button), `.kd-mode` (dark toggle)
- Shell: `.kd-shell` › `.kd-side` (sidebar) + `.kd-main--doc` (doc) or `.kd-main` (plain)
- Sidebar: `.kd-version-l` + `.kd-version` (select); `.kd-nav-sec` (section header);
  `.kd-nav-link` (+ `.active`)
- Home hero: `.kd-hero` › `h1` + `.kd-hero-sub`
- Footer: `.kd-footer` › `.kd-footer-in`
- Misc: `.kd-badge` (+ category modifier), `.kd-toc` (on-this-page)

### Content — `km-*` (engine default profile) + pure-css grid
- Callout: `.km-callout` (info default) / `.km-callout--warning` / `--danger` ›
  `.km-callout__title`, `.km-callout__body`
- Card: `.km-card` › `.km-card__header`, `.km-card__body`
- Showcase: `.km-showcase` › `.km-showcase__title`, `.km-showcase__subtitle`, then a grid
- Columns (KeenDocs.Markup profile → `pa-grid`): `.pa-row` › `.pa-col-*` each ›
  `.km-col__header` (+ `--blue`/`--green`/`--cyan`) + `.km-col__body`
- Code: `.km-code` › `pre.lumis` (colours are **inline** from Lumis — a template only frames the
  block, never recolours tokens)
- Live demo (keen-docs ext): `.kd-demo` › `.kd-demo-live`, `.kd-demo-source`, `.kd-out`
- Tables: plain `<table>/<thead>/<th>/<td>`

> Colours come from `--base-*`; a template that hardcodes a hex where a `var(--base-*)` exists is
> a bug (it breaks per-doc_set theming). Dark mode is a `.pa-mode-dark` scope the template ships
> itself (same convention as pure-admin themes), setting `color-scheme: dark` so embedded web
> components and `light-dark()` code follow.

## Templates

| id | name | shape |
|---|---|---|
| `calm` | Calm | Branded gradient hero + colored showcase/card headers, Plus Jakarta Sans + Inter. Full-width 3-pane. (extracted from `design/brand.html`) |

## Roadmap

1. **Now:** authored `dist/<id>.css` + manifest + preview (this).
2. **Wire into `View`:** a doc_set (or hub default) picks a `template` id; `View.layout/3` links
   `/templates/<id>/dist/<id>.css` instead of the inline `harness_css` + `keendocs.css`.
3. **SCSS source** (`src/scss/<id>.scss`) importing shared partials, compiling to `dist/`.
4. **CLI** (`keendocs templates build|pack|publish`), mirroring `pure-admin-cli` /
   `pure-admin-themes`. Promote this dir to a sibling `../keen-docs-templates` when it earns it.
