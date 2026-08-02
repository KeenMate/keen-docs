defmodule KeenDocs.Markdown.Extension do
  @moduledoc """
  Behaviour for a keen-docs markdown extension.

  Extensions are **installed and configured at server level** — they widen what
  authored markdown is allowed to use. Content repos stay pure data (DESIGN.md §4):
  a docs bundle never ships Elixir, it just uses whatever the server has installed.

      config :keen_docs, extensions: [KeenDocs.Extensions.Layout, MyApp.Diagrams]

  An extension may hook in at three points, all optional:

    * `c:directives/0` — the `:::name` blocks it renders.
    * `c:fences/0` — the fence keys it renders. A key matches a fence *flag*
      (` ```js run `) or, failing that, the fence *language* (` ```mermaid `).
    * `c:document/3` — a whole-document hook that contributes without rendering
      anything inline (OG/meta tags built from front matter, for example).
    * `c:finalize/1` — runs *after* the body is rendered, for contributions that
      depend on what the page turned out to contain. `document/3` cannot know that
      yet; an island manifest listing every `:::app` on the page needs it.

  `c:render/2` returns `{iodata, context}` rather than a string. That is what lets
  one block emit markup *and* register a page asset, a footer script or a head tag —
  see `KeenDocs.Markdown.Output`.

  An extension that has to remember something across blocks keeps it in the context's
  private store (`KeenDocs.Markdown.Context.put_private/3`), keyed by its own module,
  rather than in process state.
  """

  alias KeenDocs.Markdown.{Context, DirectiveParser}

  @doc "Directive names (`:::name`) this extension renders."
  @callback directives() :: [String.t()]

  @doc "Fence keys this extension renders — matched against fence flags, then the language."
  @callback fences() :: [String.t()]

  @doc "Render one node, returning its markup and the updated context."
  @callback render(DirectiveParser.node_t(), Context.t()) :: {iodata(), Context.t()}

  @doc "Contribute to the document as a whole, before body rendering."
  @callback document(meta :: map(), tree :: [DirectiveParser.node_t()], Context.t()) :: Context.t()

  @doc "Contribute after body rendering, once what the page contains is known."
  @callback finalize(Context.t()) :: Context.t()

  @optional_callbacks directives: 0, fences: 0, render: 2, document: 3, finalize: 1

  @doc """
  Convenience `use` that declares the behaviour and defaults the list callbacks to
  empty, so an extension only implements the hooks it actually has.
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour KeenDocs.Markdown.Extension

      @impl true
      def directives, do: []

      @impl true
      def fences, do: []

      defoverridable directives: 0, fences: 0
    end
  end
end
