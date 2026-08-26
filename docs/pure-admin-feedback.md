# Feedback for pure-admin — navbar/sidebar layout defects found while building keen-docs

Context: keen-docs consumes the vendored pure-admin **core** (`core.css` + `navbar-collapse.js` +
`sidebar-resize.js`) as its baseline app-shell. While converging keen-docs' navbar/sidebar onto
pure-admin's own components (2026-08-10), three issues surfaced that are **framework defects/gaps**,
not keen-docs quirks — a consumer has to patch around them locally. Filing them here so the fixes land
upstream and every consumer benefits.

Repro baseline: a header with `.pa-header__nav[data-pa-nav-collapse]` items in `.pa-header__start`, a
search box in `.pa-header__center`, and action buttons in `.pa-header__end`; a
`.pa-layout__sidebar--resizable` in a `body.pa-layout--sticky` shell.

---

## 🔴 Bug 1 — `navbar-collapse.js` can't see overlap caused by the center (search) slot

**Symptom.** Narrow the window: the search box **overflows onto `start`/`end`** and the nav items
visibly overlap it — while `navbar-collapse.js` stops folding items, thinking everything fits.

**Root cause.** The search's `min-width` sits on the search element, which is a *child* of
`.pa-header__center`. Flexbox only honours a **flex item's own** `min-width`, and
`.pa-header__center` is `flex:1; min-width:0`. So flex lets center collapse to a sliver, the search
overflows it, and the deficit lands on the sibling slots. Meanwhile `navbar-collapse.js` measures:

```js
function overflowing() {
  return contentWidth() > nav.clientWidth + 1; // contentWidth() = sum of the NAV's own items
}
```

i.e. it only looks at the **nav's own slot** (`nav.clientWidth`). A deficit created by a *sibling*
(the center/search being crushed) never shrinks the nav's slot, so the loop terminates with items
still overlapping.

**Fix (either).**
- **Cheap/CSS:** give `.pa-header__center` (or a `.pa-navbar-search` wrapper) a real `min-width` so
  flex *reserves* it and shrinks `start` instead — which shrinks the nav's slot, so the existing
  collapse loop then fires honestly. This is exactly the one-liner keen-docs applied:
  ```css
  .pa-header__center:has(.pa-navbar-search){ min-width: 18rem; }
  /* and let the search itself be min-width:0 */
  ```
  Result: clean 16px gaps on both sides from 561–1400px, nav folds 5→4→3→2→1 as space tightens.
- **Robust/JS:** make `navbar-collapse.js` measure **available space = container − siblings**, not
  `nav.clientWidth`, so a sibling-induced deficit is detectable regardless of the layout around it.

This is the same underlying issue as the earlier "fixed 3-slot flex crushes the centred search"
observation — solving it in the framework means consumers don't each have to rediscover it.

---

## 🟠 Bug 2 — the tablet sidebar-width rule ignores the resize/theme variable

**Symptom.** A user-resized (or theme-set) sidebar width is silently discarded between 769–1024px, and
the sidebar snaps to a thin 16rem.

**Root cause.** `_layout-responsive.scss`:

```scss
@media (max-width: 1024px) and (min-width: 769px) {
  .pa-layout__sidebar { width: $sidebar-width-tablet; } // 16rem — a hard literal
}
```

This overrides the low-specificity `:where(.pa-layout__sidebar){ width: var(--pc-local-sidebar-width) }`,
so `--pc-local-sidebar-width` (written live by `sidebar-resize.js`, and settable by a theme) has no
effect in that band.

**Fix.** Drive the tablet width through the same variable, e.g.:

```scss
@media (max-width: 1024px) and (min-width: 769px) {
  .pa-layout__sidebar { --pc-local-sidebar-width: #{$sidebar-width-tablet}; }
  // or: width: min(var(--pc-local-sidebar-width), #{$sidebar-width-tablet});
}
```

so resize + theme overrides keep working (and a themed default wider than 16rem is honoured).

---

## 🟡 Gap 3 — `sidebar-resize.js` isn't shipped with core, and hardcodes values that are already vars

**Not shipped where it's used.** The script lives in `demo/js/sidebar-resize.js`, yet `_sidebar.scss`
documents `--pc-local-sidebar-width` as *"modified by JS for resize"* and ships `.pa-sidebar-resize`
styling plus `--pc-local-sidebar-min-width: 18rem` / `--pc-local-sidebar-max-width: 50rem`. It's a
first-class layout behavior — please ship it in `packages/core/src/js/` next to `navbar-collapse.js`
so consumers don't have to reach into the demo folder to vendor it.

**Hardcodes what core already exposes as vars.** `sidebar-resize.js` bakes in:

```js
const MIN_WIDTH = 180;    // 18rem at 10px base
const MAX_WIDTH = 500;    // 50rem
const DEFAULT_WIDTH = 288; // 28.8rem
// ...
const remWidth = width / 10; // assumes the 10px rem base
```

These duplicate — and can drift from — `--pc-local-sidebar-min-width` / `--pc-local-sidebar-max-width`
(and the root font size). The script should read those CSS variables instead of hardcoding them, so a
theme that changes the min/max/base stays consistent with the drag limits.

---

### Summary

| # | Severity | Where | One-line fix |
|---|----------|-------|--------------|
| 1 | 🔴 | header flex + `navbar-collapse.js` | reserve the center slot's `min-width` (or measure available space, not `nav.clientWidth`) |
| 2 | 🟠 | `_layout-responsive.scss` tablet rule | set `--pc-local-sidebar-width` in the media query instead of a hard `width` literal |
| 3 | 🟡 | `sidebar-resize.js` | ship it in core; read `--pc-local-sidebar-{min,max}-width` instead of hardcoding |
