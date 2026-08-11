# Vendored @keenmate/pure-admin-core

`core.css` is the **whole pure-admin framework** — the compiled `packages/core/dist/css/main.css`
from the sibling `../pure-admin` repo. It carries reboot (the 10px rem base), the layout chrome
(`pa-navbar`/`pa-layout`/`pa-sidebar`/`pa-footer`), every component (`pa-btn`/`pa-tabs`/`pa-card`/
`pa-table`/`pa-profile-panel`/…), utilities, dark mode (`.pa-mode-dark`), and a **baked-in default
theme** (`:root { --base-*; --pa-* }`). It is the keen-docs baseline used when no template/theme is
selected — the same role pure-admin-core's default theme plays.

A keen-docs **template** is a pure-admin-style theme bundle (`priv/templates/<id>/dist/<id>.css`)
that *replaces* this file — a full framework compiled with that theme's palette across its
modes (`pa-mode-*`) and variants (`pa-color-*`).

Alongside the CSS, two **self-contained vanilla-JS progressive enhancements** are vendored from the
same repo and served as-is (no build step, auto-init on `DOMContentLoaded`):

- `navbar-collapse.js` (`../pure-admin/packages/core/src/js/navbar-collapse.js`) — priority-driven
  navbar→sidebar overflow. As the header row runs out of room it folds the lowest-priority
  `.pa-header__nav` items into the sidebar (keen-docs uses `data-pa-nav-collapse="sidebar"`, target
  `#kd-nav-overflow`). Exposes `window.PaNavCollapse`.
- `sidebar-resize.js` (`../pure-admin/demo/js/sidebar-resize.js`) — drag-to-resize the sidebar
  (min 18rem / max 50rem, persisted to `localStorage`, double-click resets). Attaches to any
  `.pa-layout__sidebar--resizable` and writes `--pa-local-sidebar-width` on `:root`. Exposes
  `window.PureAdminSidebarResize`.

These are a **deliberate, small departure** from "no client-side layout JS": progressive
enhancement only — the server-rendered output is deterministic and complete; the JS merely reflows
the navbar/sidebar by viewport and enables drag-resize.

Do not hand-edit. Re-vendor all three with `make vendor-pa-core` (copies `core.css`,
`navbar-collapse.js`, and `sidebar-resize.js`). Grid columns (`.pa-col-*`) live in pure-css
`grid.css`, linked separately.
