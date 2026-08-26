# Vendored @keenmate/pure-css

Built CSS vendored from [`@keenmate/pure-css`](https://www.npmjs.com/package/@keenmate/pure-css).
Do not edit by hand.

**Source (default): the local sibling working copy `../pure-css/dist/css`.** While pure-css and
keen-docs are co-developed, the local build is the source of truth so new layers land immediately
without a publish/version bump. Re-vendor with:

    make vendor-css          # copies ../pure-css/dist/css/*.css here — run ../pure-css's build FIRST

> ⚠️ `vendor-css` copies whatever is in `../pure-css/dist` — make sure it's freshly built, or you'll
> vendor a stale layer (this once left an old grid behind after pure-css moved `.pure-*` → `.pa-*`).

For a **pinned, registry-as-truth** build instead (reproducible, no local sibling needed):

    make vendor-css-npm      # uses PURE_CSS_VERSION in the Makefile (currently 1.0.0-rc01)

Either way, recompile afterwards — `base.css`, `reboot.css`, `scrollbars.css` are inlined into every
page's `<style>` via compile-time `@external_resource` module attrs, so `mix compile` picks up new bytes.

## Layers

- `base.css`      — `:root { --base-*; --pa-* }` theming contract (**inlined**, FOUC-free). Variables
                    only — no element selectors.
- `reboot.css`    — **the 10px rem base** (`html{font-size:10px}`) + box-sizing + typography reset +
                    `body` defaults. **Inlined** (the 10px root must be set before anything sized in
                    rem — pure-css authors its whole scale against it). Added in pure-css 1.0.0-rc02.
- `scrollbars.css`— themed thin scrollbars (`--pa-*`). **Inlined**. Added in rc02.
- `grid.css`      — the `pa-grid` flexbox grid: `.pc-row` / `.pc-col-{n}` (5% steps) /
                    `.pc-col-{x}-{y}` fractions, container-query responsive, auto-stack (served + linked).
- `utilities.css` — spacing / flex / display / width-height / gap / font-family / border utilities
                    (served + linked).

> The chrome layout (`pa-navbar`/`pa-layout`/`pa-sidebar`/`pa-footer`) and the profile panel now come
> from the full **pure-admin `core.css`** bundle (`../pure-admin/core.css`, `make vendor-pa-core`),
> which `View.styles/1` links as the baseline shell. The old hand-extracted `layout.css` /
> `profile-panel.css` fragments here are **superseded and unreferenced** (pending removal in themes
> Phase 5); core.css also carries the 10px base, grid and utilities, so those layers are linked from
> it too rather than separately.
