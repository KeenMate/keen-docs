defmodule KeenDocs.Markdown.Context do
  @moduledoc """
  Per-render state threaded through the renderer.

  Holds the resolved extension registry, the accumulating `KeenDocs.Markdown.Output`
  and the demo/run pairing counters. It is built fresh per `render` call from an
  explicit argument that falls back to app config — never a mutable global, which is
  the svelte-docs anti-pattern DESIGN.md §3 exists to remove.

  Demo ids come from a plain per-document counter (`kd-demo-1`, `kd-demo-2`, …) and
  **not** `System.unique_integer/1`, so rendering the same document twice produces
  byte-identical HTML. DESIGN.md §4 specifies content-hash dedup on upload; ids that
  changed per render would defeat hashing.
  """

  alias KeenDocs.Markdown.{Context, Output}

  @default_extensions [
    KeenDocs.Extensions.Layout,
    KeenDocs.Extensions.Blocks,
    KeenDocs.Extensions.Demo,
    KeenDocs.Extensions.App,
    KeenDocs.Extensions.Mermaid,
    KeenDocs.Extensions.OpenGraph,
    KeenDocs.Extensions.CdnPackage
  ]

  @default_theme "github_light"

  @type t :: %__MODULE__{
          directives: %{String.t() => module()},
          fences: %{String.t() => module()},
          document_hooks: [module()],
          finalize_hooks: [module()],
          out: Output.t(),
          counters: %{String.t() => non_neg_integer()},
          last_demo: String.t() | nil,
          private: map(),
          theme: String.t()
        }

  defstruct directives: %{},
            fences: %{},
            document_hooks: [],
            finalize_hooks: [],
            out: %Output{},
            counters: %{},
            last_demo: nil,
            private: %{},
            theme: @default_theme

  @doc """
  Build a context.

  Options:

    * `:extensions` — modules to install. Defaults to `config :keen_docs, :extensions`,
      then to the built-in set. Passing the option replaces the list wholesale, so a
      built-in can be switched off.
    * `:meta` — front matter, carried on the output.
    * `:theme` — Lumis highlight theme.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    extensions = Keyword.get_lazy(opts, :extensions, &configured_extensions/0)
    meta = Keyword.get(opts, :meta, %{})

    %Context{
      directives: index_by(extensions, :directives),
      fences: index_by(extensions, :fences),
      document_hooks: Enum.filter(extensions, &exports?(&1, :document, 3)),
      finalize_hooks: Enum.filter(extensions, &exports?(&1, :finalize, 1)),
      out: Output.new(meta),
      theme: Keyword.get(opts, :theme, @default_theme)
    }
  end

  @doc "Extensions installed at server level, or the built-in set."
  @spec configured_extensions() :: [module()]
  def configured_extensions,
    do: Application.get_env(:keen_docs, :extensions, @default_extensions)

  @doc "The built-in extension set, for tests and for config to build on."
  @spec default_extensions() :: [module()]
  def default_extensions, do: @default_extensions

  @doc "Extension registered for a `:::name` directive, or `nil`."
  @spec directive_handler(t(), String.t()) :: module() | nil
  def directive_handler(%Context{directives: directives}, name), do: Map.get(directives, name)

  @doc """
  Extension registered for a fence.

  Flags win over the language, so ` ```js run ` reaches the demo extension while a
  plain ` ```js ` falls through to ordinary highlighting.
  """
  @spec fence_handler(t(), [String.t()], String.t()) :: module() | nil
  def fence_handler(%Context{fences: fences}, flags, lang) do
    Enum.find_value(flags, fn flag -> Map.get(fences, flag) end) || Map.get(fences, lang)
  end

  @doc "Options for `Lumis.highlight!/2` at this context's theme."
  @spec lumis_opts(t(), String.t() | nil) :: keyword()
  def lumis_opts(%Context{theme: theme}, language),
    do: [formatter: {:html_inline, theme: theme, language: language}]

  # ---- output delegation (keeps extensions from reaching into ctx.out) ----

  @doc "Append body markup."
  @spec put_body(t(), iodata()) :: t()
  def put_body(%Context{} = ctx, html), do: %{ctx | out: Output.put_body(ctx.out, html)}

  @doc "Append a `<head>` contribution."
  @spec put_head(t(), iodata()) :: t()
  def put_head(%Context{} = ctx, html), do: %{ctx | out: Output.put_head(ctx.out, html)}

  @doc "Append an end-of-`<body>` contribution."
  @spec put_footer(t(), iodata()) :: t()
  def put_footer(%Context{} = ctx, html), do: %{ctx | out: Output.put_footer(ctx.out, html)}

  @doc "Register a keyed, deduplicated page asset."
  @spec put_asset(t(), String.t(), Output.region(), iodata()) :: t()
  def put_asset(%Context{} = ctx, key, region, html),
    do: %{ctx | out: Output.put_asset(ctx.out, key, region, html)}

  @doc "Record a heading for the table of contents."
  @spec put_heading(t(), pos_integer(), String.t(), String.t()) :: t()
  def put_heading(%Context{} = ctx, level, id, text),
    do: %{ctx | out: Output.put_heading(ctx.out, level, id, text)}

  @doc "Front matter for the document being rendered."
  @spec meta(t()) :: map()
  def meta(%Context{out: %Output{meta: meta}}), do: meta

  @doc """
  Store extension-private state, keyed by the extension's own module.

  This is how an extension remembers something across blocks — which islands the page
  mounted, say — without reaching for process state.
  """
  @spec put_private(t(), module(), term()) :: t()
  def put_private(%Context{private: private} = ctx, module, value),
    do: %{ctx | private: Map.put(private, module, value)}

  @doc "Read extension-private state, or `default` if the extension stored nothing."
  @spec get_private(t(), module(), term()) :: term()
  def get_private(%Context{private: private}, module, default \\ nil),
    do: Map.get(private, module, default)

  # ---- demo / run pairing ----

  @doc """
  Allocate the next deterministic id under `prefix` — `kd-demo-1`, `kd-app-1`, ….

  Counters are per document, so the same source always yields the same ids.
  """
  @spec next_id(t(), String.t()) :: {String.t(), t()}
  def next_id(%Context{counters: counters} = ctx, prefix) do
    count = Map.get(counters, prefix, 0) + 1
    {"#{prefix}-#{count}", %{ctx | counters: Map.put(counters, prefix, count)}}
  end

  @doc """
  Allocate the next demo id and remember it as the current demo.

  A following `js run` fence binds to it via `last_demo/1`. Depth-first render order
  is document order, so "the last demo seen" is the demo the author wrote it under.
  """
  @spec next_demo_id(t()) :: {String.t(), t()}
  def next_demo_id(ctx) do
    {id, ctx} = next_id(ctx, "kd-demo")
    {id, %{ctx | last_demo: id}}
  end

  @doc "Id of the most recently rendered demo, or `nil` if none precedes this point."
  @spec last_demo(t()) :: String.t() | nil
  def last_demo(%Context{last_demo: last}), do: last

  @doc "Flip the accumulated output into source order."
  @spec finalize(t()) :: Output.t()
  def finalize(%Context{out: out}), do: Output.finalize(out)

  # ---- registry building ----

  defp index_by(extensions, callback) do
    for module <- extensions,
        exports?(module, callback, 0),
        key <- apply(module, callback, []),
        into: %{} do
      {key, module}
    end
  end

  defp exports?(module, function, arity) do
    Code.ensure_loaded?(module) and function_exported?(module, function, arity)
  end
end
