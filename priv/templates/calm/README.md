# Calm

A branded, confident keen-docs template: a gradient hero band, colored showcase / card /
table headers, and a spacious **full-width three-pane** shell (nav · content · toc). Plus Jakarta
Sans headings, Inter body, JetBrains Mono code.

Extracted from `design/brand.html` and re-bound to the keen-docs **markup contract** (see
`../README.md`), so it styles real rendered pages rather than bespoke markup.

## Files

- `template.json` — manifest (id, modes, colours, fonts, exports)
- `dist/calm.css` — the stylesheet (chrome + content, contract-bound)
- `preview.html` — open in a browser to see the sample doc page rendered by `dist/calm.css`

## Colour = doc_set theme, not the template

Calm reads hues from the `--base-*` contract. Its gradient is built from
`var(--base-accent-color)`, so a doc_set whose `theme_css` sets a different accent gets Calm in
that colour — no template fork. Calm only fixes the **shape** (gradient, radii, shadows, fonts,
layout).

## Dark mode

Ships its own `html.pa-mode-dark` scope (sets `color-scheme: dark` so embedded web components and
`light-dark()` code follow). Toggle by adding/removing `pa-mode-dark` on `<html>`; the preview
persists the choice to `localStorage` and follows `prefers-color-scheme` on first load.

## Preview note

The `<web-multiselect>` in the preview is a **static facsimile** (the real component styles itself
from `--base-*`), and the preview's `<style>` block holds only preview-only cosmetics (facsimile +
`light-dark()` code tokens that mimic Lumis' real dual-theme output). Nothing there belongs to the
template — `dist/calm.css` is the whole template.
