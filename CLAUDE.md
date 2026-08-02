# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this project is

keen-docs is an Elixir/Phoenix **docs + showcase engine** for KeenMate's component libraries — the
"done better" rewrite of `../svelte-docs`. Docs pages are authored in a **custom markdown superset**
and render **real, live component demos that talk to a real server**.

**Read [`DESIGN.md`](./DESIGN.md) first** — it holds the full vision, architecture decisions, the
problems being fixed, and the roadmap. This file is only the working conventions.

## Current state: POC

A plain **Mix** project (not `phx.new` yet) proving the markdown→live-docs pipeline. The rendering
**engine has been extracted** to a sibling library, [`../keen-markdown`](../keen-markdown) (Hex
`keen_markdown`, module root `KeenMarkdown`), consumed here via a path dep. keen-docs is now the engine's
first consumer; it adds only its **docs-specific extensions** (`lib/keen_docs/extensions/`) plus
`lib/keen_docs/poc.ex` as the page shell. See DESIGN.md §8.

```bash
mix deps.get
mix test                            # keen-docs' own tests; run `mix test` in ../keen-markdown too
mix run -e "KeenDocs.POC.build()"   # → build/poc.html (open in a browser)
```

## Architecture in one breath

One central multi-tenant Phoenix app, bound to many domains (hub `docs.keenmate.dev` + per-package
`web-multiselect.keenmate.dev`), fed by content-only repos published via a Node `keendocs` CLI
(pack+upload, mirroring `../pure-admin-cli`). Central DB for profiles/favorites/notes/fulltext.
Generic, data-shape-oriented endpoints back the live demos. See DESIGN.md §4–5.

## The markdown pipeline (the core — now in `../keen-markdown`)

The engine lives in the `keen_markdown` library. Work on the parser/renderer/behaviour happens **there**,
not here. Its modules (`KeenMarkdown.*`):

- `frontmatter.ex` — split YAML front matter → `{meta, body}`.
- `directive_parser.ex` — **the heart**: pure Elixir, **code-fence-aware** scanner that builds a nested
  `:::` block tree. Node shapes: `{:directive, name, attrs, children}`, `{:markdown, text}`,
  `{:fence, lang, flags, code}`. Keep it dependency-free.
- `renderer.ex` — node tree → `Output`. Only the dispatch loop, plain markdown and fallbacks live here;
  the authoring vocabulary lives in extensions.
- `output.ex` — the result: **page regions** (`head`/`body`/`footer` + keyed `assets`, `toc`). Rendering
  never returns a bare HTML string.
- `context.ex` — per-render state: extension registry, deterministic demo counter, accumulating output.
  **Never** reach for the process dictionary or any global here.
- `extension.ex` — behaviour: `directives/0`, `fences/0`, `render/2 → {iodata, ctx}`, `document/3`
  (before body), `finalize/1` (after body). All optional. Cross-block state goes in the context's private
  store, keyed by module.
- `keen_markdown.ex` — the public API: `KeenMarkdown.render/2` → `Output`.
- **generic extensions** (ship in the lib, useful to any content site): `layout` (columns/col/showcase),
  `blocks` (card/callout), `example` (highlighted copyable source), `mermaid`, `open_graph`.

**keen-docs' own extensions** (`lib/keen_docs/extensions/`, docs-specific, plug into the same behaviour):
- `demo` — the live fence roles `demo`/`run` (mount + run a component; `run` scripts go to the footer).
- `cdn_package` — load the documented `web-*` component from jsdelivr, pinned to the doc version.
- `app` — keen-phoenix-svelte islands (`:::app` + `:::props` + `:::placeholder`).
- `poc.ex` — assembles the regions into a standalone HTML page (inlines `keendocs.css`; the engine ships no CSS — it emits `kd-*` classes + inline-styled code, and the consumer owns styling).

The full vocabulary is assembled in `config :keen_markdown, :extensions` = generic set ++ keen-docs' three.

**Adding a block type means writing an extension, not editing the renderer.** A *generic* block (any site
would want it) belongs in `../keen-markdown`; a *docs-specific* one (live components, CDN, islands) belongs
here. Extensions are installed server-side; content repos stay pure data and never ship Elixir.

### Rendering target is pluggable (HTML today, HEEx proven)

The parser/renderer are output-format-agnostic — the extension set decides the target. HTML mode:
`:::card` → `<div class="kd-card">`. HEEx mode (for a Phoenix portal like keen_pure_admin): `:::card` →
`<.card>` component tags the consumer compiles (`Phoenix.LiveView.TagEngine.compile/2`) against its design
system. keen_markdown stays **Phoenix-free** — it only emits strings. See DESIGN.md §5 "Rendering targets"
and §8 for the proven spikes (`transform_markdown` for redefining `##`; DB-content→`<.card>`; cached route;
`{{vars}}`; compile-boundary safety = sentinel→neutralize→swap).

### POC spikes live in `tmp/` (gitignored, throwaway)

Runtime/HEEx experiments live under `tmp/heex_proof` and `tmp/keen_docs_p1` — scratch projects, not part
of the build. The **findings** are recorded in DESIGN.md §8; the code is disposable. Don't rely on them.

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

`../keen-markdown` (**the extracted rendering engine — the core lives there now**) · `../svelte-docs`
(predecessor) · `../keen-phoenix-svelte` (island mounter) · `../pure-admin-cli` (CLI to mirror) ·
`../web-multiselect` (flagship web component, ships CEM) · `../keen-auth-permissions` (auth) ·
`../cafeindustrial-cz` (Phoenix portal — a candidate second consumer of `keen_markdown`).
