# Vendored @keenmate/pure-css

CSS **and** JS vendored from [`@keenmate/pure-css`](https://www.npmjs.com/package/@keenmate/pure-css).
Do not edit by hand. **keen-docs is a pure-css-only consumer — it has no pure-admin dependency;** the
app shell + its runtime live here.

**Source (default): the local sibling working copy `../pure-css`.** While pure-css and keen-docs are
co-developed, the local build is the source of truth so new layers land immediately without a
publish/version bump. Re-vendor with:

    make vendor-css          # copies ../pure-css/dist/css/*.css + ../pure-css/src/js/*.js here — build ../pure-css FIRST

> ⚠️ `vendor-css` copies whatever is in `../pure-css` — make sure it's freshly built, or you'll vendor
> a stale layer.

For a **pinned, registry-as-truth** build instead (reproducible, no local sibling needed):

    make vendor-css-npm      # uses PURE_CSS_VERSION in the Makefile (currently 1.0.0-rc06)

Either way, recompile afterwards — `base.css`, `reboot.css`, `scrollbars.css` are inlined into every
page's `<style>` via compile-time `@external_resource`, so `mix compile` picks up new bytes.

## CSS

- `base.css`       — `:root { --base-*; --pc-* }` theming contract (**inlined**, FOUC-free). Variables
                     only, no selectors.
- `reboot.css`     — **the 10px rem base** (`html{font-size:10px}`) + box-sizing + typography reset.
                     **Inlined** (the 10px root must be set before anything sized in rem).
- `scrollbars.css` — themed thin scrollbars (`--pc-*`). **Inlined**.
- `pure-css.css`   — **the full bundle** `View.styles/1` LINKS: `--base-*`/`--pc-*` vars + reboot +
                     scrollbars + grid (`.pc-row`/`.pc-col-*`) + utilities + the **pc-\* app shell**
                     (`pc-navbar`/`pc-navmenu`/`pc-layout`/`pc-sidebar`/`pc-footer`). Since rc05 the
                     shell ships here — there is no separate pure-admin `core.css` anymore. Since
                     **rc06** every shell color reference falls back to `--base-*`
                     (`var(--pc-navbar-bg, var(--base-main-bg))`, …), so the shell renders correctly
                     from the base contract alone — keen-docs supplies NO `--pc-*` shell tokens.

## JS runtime (dependency-free, served as `text/javascript`)

Loaded at body end in order, then `pureCss.components.initAll(document)`:

- `pure-css.js`        — installs `window.pureCss` (event bus, viewport/colorScheme/device, overlay,
                         `components.initAll`).
- `fit.js`             — the Fit engine (`data-pc-fit*`); **absorbed the old `navbar-collapse.js`**, so
                         nav folding is `data-pc-fit-nav` (keen-docs uses `="sidebar"` → folds the
                         top-nav into `#kd-nav-overflow`).
- `navbar-dropdown.js` — touch/hover nav dropdowns.
- `sidebar-resize.js`  — drag-to-resize the sidebar (`window.pureCss.components.sidebarResize`;
                         keen-docs' settings panel toggles `.pc-layout__sidebar--resizable`).

keen-docs' own chrome components (`kd-btn`/`kd-checkbox`/`kd-profile-panel`/`kd-settings-panel`/
`kd-tabs`) are NOT vendored — they live in `priv/web/keendocs-components.css`.
