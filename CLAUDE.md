# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this project is

keen-docs is an Elixir/Phoenix **docs + showcase engine** for KeenMate's component libraries — the
"done better" rewrite of `../svelte-docs`. Docs pages are authored in a **custom markdown superset**
and render **real, live component demos that talk to a real server**.

**Read [`DESIGN.md`](./DESIGN.md) first** — it holds the full vision, architecture decisions, the
problems being fixed, and the roadmap. This file is only the working conventions.

## Current state: POC

A plain **Mix** project (not `phx.new` yet) proving the markdown→live-docs pipeline: the core under
`lib/keen_docs/markdown/`, the authoring vocabulary as extensions under `lib/keen_docs/extensions/`,
and `lib/keen_docs/poc.ex` as the page shell. See DESIGN.md §8.

```bash
mix deps.get
mix test
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
- `markdown/renderer.ex` — node tree → `Output`. Only the dispatch loop, plain markdown and fallbacks
  live here; the authoring vocabulary lives in extensions.
- `markdown/output.ex` — the result: **page regions** (`head`/`body`/`footer` + keyed `assets`, `toc`).
  Rendering never returns a bare HTML string.
- `markdown/context.ex` — per-render state: extension registry, deterministic demo counter, accumulating
  output. **Never** reach for the process dictionary or any global here.
- `markdown/extension.ex` — behaviour: `directives/0`, `fences/0`, `render/2 → {iodata, ctx}`,
  `document/3` (before body), `finalize/1` (after body). All optional. Cross-block state goes in the
  context's private store, keyed by module.
- `extensions/` — `layout` (columns/col/showcase), `blocks` (card/callout), `demo` (demo/run/example
  fences), `app` (keen-phoenix-svelte islands: `:::app` + `:::props` + `:::placeholder`), `mermaid`,
  `open_graph`, `cdn_package`. Registered in `config :keen_docs, :extensions`.
- `poc.ex` — assembles the regions into a standalone HTML page.

**Adding a block type means writing an extension, not editing the renderer.** Extensions are installed
server-side; content repos stay pure data and never ship Elixir.

### Authoring model (keep these invariants)

- **Layout is generic and decoupled from demos.** `:::columns{cols="80/20"}` + `:::col{title=…}` is
  pure layout (CSS grid `fr` ratios, not Bootstrap 12-grid). "Demo-ness" lives on the **code fence**
  (`demo`/`run`/`example`), never on a column.
- `:::showcase` is only a **preset** over `:::columns` (positional accent colors). `:::col` = labelled
  column (no chrome); `:::card` = boxed. Don't collapse these back into a fixed 3-column component.
- Demos are usually **markup + a CDN web component pinned to the doc version**, not compiled apps.
  Islands (keen-phoenix-svelte) are the rare case.

## Conventions

- **Elixir 1.20 / OTP 29** (installed via Homebrew; `mix.exs` still declares `~> 1.15`). Idiomatic
  Elixir; small focused modules; pattern-match over conditionals.
- **Markdown engine**: MDEx (comrak Rust NIF, precompiled) + **lumis** for highlighting. Highlighting is
  opt-in and the engine isn't bundled — `{:lumis, "~> 0.1"}` + `config :mdex_native, syntax_highlighter: :lumis`.
- **Server-side rendering only** for content/highlighting — no client-side re-highlighting, no FOUC hacks
  (that was a svelte-docs anti-pattern we're explicitly removing).
- Never reintroduce a **global mutable singleton** for config/state (svelte-docs' SSR leak). Keep state
  request/domain-scoped.
- Rendering must stay **deterministic** — the same document renders to the same bytes. Ingestion relies
  on content hashing (DESIGN.md §4), so never use `System.unique_integer/1` or timestamps in output.
- When adding content features, update `priv/content/form-integration.md` (the exercise-everything sample),
  add tests under `test/`, and re-run the POC build to verify.

## Persistent design memory

The architecture of record lives in [`DESIGN.md`](./DESIGN.md) — update it when decisions change.
Cross-session context that is *not* derivable from the repo (toolchain quirks, authoring-style
preferences) lives in the memory dir indexed by
`~/.claude/projects/-Users-ondrejvalenta-Documents-GitHub-keen-docs/memory/MEMORY.md`.

## Related repos (siblings under C:\Git\KM)

`../svelte-docs` (predecessor) · `../keen-phoenix-svelte` (island mounter) · `../pure-admin-cli` (CLI to
mirror) · `../web-multiselect` (flagship web component, ships CEM) · `../keen-auth-permissions` (auth).
