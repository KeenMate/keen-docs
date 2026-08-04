# Vendored @keenmate/pure-css

Built CSS vendored from the **published** [`@keenmate/pure-css`](https://www.npmjs.com/package/@keenmate/pure-css)
package — the npm release is the single source of truth. Do not edit by hand.

**Pinned version:** `@keenmate/pure-css@1.0.0-rc01` (kept in the `Makefile` as `PURE_CSS_VERSION`).

Re-vendor (fetches the pinned release from npm, copies its `dist/css` here):

    make vendor-css              # bump PURE_CSS_VERSION in the Makefile first to move versions

Then recompile — `base.css` is inlined into every page's `<style>` via a compile-time
`@external_resource` module attr, so `mix compile` picks up the new bytes.

- `base.css`      — `:root { --base-*; --pa-* }` theming contract (**inlined**, FOUC-free).
- `grid.css`      — the `pa-grid` flexbox grid: `.pa-row` / `.pa-col-{n}` (5% steps) /
                    `.pa-col-{x}-{y}` fractions, container-query responsive, auto-stack (served + linked).
- `utilities.css` — spacing / flex / display / width-height / gap / font-family / border utilities
                    (served + linked).

> Vendoring from a working-copy build once caused a stale grid (the old Yahoo `.pure-*` lingered
> after pure-css moved to `.pa-*`). Pulling from the pinned npm release prevents that.
