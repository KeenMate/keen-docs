# Vendored @keenmate/pure-css

Built CSS copied from `../pure-css/dist/css` (`@keenmate/pure-css`). Do not edit by hand.
Re-vendor after rebuilding pure-css:

    cp ../pure-css/dist/css/{base,grid,utilities}.css priv/web/vendor/pure-css/

- `base.css`      — `:root{--base-*}` theming contract (inlined into every page's <style>).
- `grid.css`      — `.pure-g` / `.pure-u-*` (served + linked).
- `utilities.css` — spacing / flex / display / width-height / font-family (served + linked).
