# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this project is

keen-docs is an Elixir/Phoenix **docs + showcase engine** for KeenMate's component libraries — the
"done better" rewrite of `../svelte-docs`. Docs pages are authored in a **custom markdown superset**
and render **real, live component demos that talk to a real server**.

**Read [`DESIGN.md`](./DESIGN.md) first** — it holds the full vision, architecture decisions, the
problems being fixed, and the roadmap. This file is only the working conventions.

## Current state: POC

A plain **Mix** project (not `phx.new` yet) proving the markdown→live-docs pipeline. The pipeline is
four modules under `lib/keen_docs/markdown/` + `lib/keen_docs/poc.ex`. See DESIGN.md §8.

```bash
mix deps.get
mix run -e "KeenDocs.POC.build()"   # → build/poc.html (open in a browser)
```

## Architecture in one breath

One central multi-tenant Phoenix app, bound to many domains (hub `docs.keenmate.dev` + per-package
`web-multiselect.keenmate.dev`), fed by content-only repos published via a Node `keendocs` CLI
(pack+upload, mirroring `../pure-admin-cli`). Central DB for profiles/favorites/notes/fulltext.
Generic, data-shape-oriented endpoints back the live demos. See DESIGN.md §4–5.

## The markdown pipeline (the core)

- `markdown/frontmatter.ex` — split YAML front matter → `{meta, body}`.
- `markdown/directive_parser.ex` — **the heart**: pure Elixir, **code-fence-aware** scanner that builds a
  nested `:::` block tree. Node shapes: `{:directive, name, attrs, children}`, `{:markdown, text}`,
  `{:fence, lang, flags, code}`. Keep it dependency-free.
- `markdown/renderer.ex` — node tree → HTML. Markdown & `example` fences via `MDEx.to_html!/2`
  (server-side highlighting); `demo`/`run` fences → live region + `<script type="module">`.
- `poc.ex` — wires it into a standalone HTML page.

### Authoring model (keep these invariants)

- **Layout is generic and decoupled from demos.** `:::columns{cols="80/20"}` + `:::col{title=…}` is
  pure layout (CSS grid `fr` ratios, not Bootstrap 12-grid). "Demo-ness" lives on the **code fence**
  (`demo`/`run`/`example`), never on a column.
- `:::showcase` is only a **preset** over `:::columns` (positional accent colors). `:::col` = labelled
  column (no chrome); `:::card` = boxed. Don't collapse these back into a fixed 3-column component.
- Demos are usually **markup + a CDN web component pinned to the doc version**, not compiled apps.
  Islands (keen-phoenix-svelte) are the rare case.

## Conventions

- **Elixir 1.18 / OTP 27.** Idiomatic Elixir; small focused modules; pattern-match over conditionals.
- **Markdown engine**: MDEx (comrak Rust NIF, precompiled) + **lumis** for highlighting. Highlighting is
  opt-in and the engine isn't bundled — `{:lumis, "~> 0.1"}` + `config :mdex_native, syntax_highlighter: :lumis`.
- **Server-side rendering only** for content/highlighting — no client-side re-highlighting, no FOUC hacks
  (that was a svelte-docs anti-pattern we're explicitly removing).
- Never reintroduce a **global mutable singleton** for config/state (svelte-docs' SSR leak). Keep state
  request/domain-scoped.
- When adding content features, update `priv/content/form-integration.md` (the exercise-everything sample)
  and re-run the POC build to verify.

## Persistent design memory

Cross-session design context lives in the memory dir (indexed by
`~/.claude/projects/C--Git-KM-keen-docs/memory/MEMORY.md`): `keen-docs-purpose`,
`keen-docs-rendering-model`, `svelte-docs-architecture-issues`. Update these when decisions change.

## Related repos (siblings under C:\Git\KM)

`../svelte-docs` (predecessor) · `../keen-phoenix-svelte` (island mounter) · `../pure-admin-cli` (CLI to
mirror) · `../web-multiselect` (flagship web component, ships CEM) · `../keen-auth-permissions` (auth).
