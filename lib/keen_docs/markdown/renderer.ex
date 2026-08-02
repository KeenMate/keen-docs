defmodule KeenDocs.Markdown.Renderer do
  @moduledoc """
  Renders a `KeenDocs.Markdown.DirectiveParser` node tree into a
  `KeenDocs.Markdown.Output` — page regions, not a single HTML string.

  The renderer itself knows almost nothing about the authoring vocabulary. Every
  `:::directive` and every fence role is provided by an extension registered in the
  `KeenDocs.Markdown.Context`; the built-in layout, block, demo and diagram support
  are just the extensions that ship in the box. What is left here is the dispatch
  loop, plain markdown text, and the fallback for unclaimed nodes.

  Markdown and code are highlighted server-side (MDEx + Lumis, inline styles), so
  there is no client-side highlighter and no FOUC.
  """

  alias KeenDocs.Markdown.{Context, DirectiveParser, HTML, Output}

  @heading_re ~r|<h([1-6]) id="([^"]*)"[^>]*>(.*?)</h\1>|s
  @tag_re ~r/<[^>]*>/

  @doc """
  Render a node tree to an `Output`.

  Options are passed to `KeenDocs.Markdown.Context.new/1` — `:extensions`, `:meta`
  and `:theme`.
  """
  @spec render([DirectiveParser.node_t()], keyword()) :: Output.t()
  def render(nodes, opts \\ []) when is_list(nodes) do
    ctx = opts |> Context.new() |> run_document_hooks(nodes)
    {html, ctx} = render_nodes(nodes, ctx)

    ctx
    |> Context.put_body(html)
    |> run_finalize_hooks()
    |> Context.finalize()
  end

  @doc """
  Render a list of nodes, threading the context.

  Extensions call this to render their own children.
  """
  @spec render_nodes([DirectiveParser.node_t()], Context.t()) :: {iodata(), Context.t()}
  def render_nodes(nodes, ctx) when is_list(nodes) do
    {html, ctx} =
      Enum.reduce(nodes, {[], ctx}, fn node, {acc, ctx} ->
        {html, ctx} = render_node(node, ctx)
        {[html | acc], ctx}
      end)

    {Enum.reverse(html), ctx}
  end

  @doc "Highlight a code string server-side, at the context's theme."
  @spec highlight(String.t(), String.t() | nil, Context.t()) :: iodata()
  def highlight(code, lang, ctx) do
    Lumis.highlight!(code, Context.lumis_opts(ctx, language(lang)))
  end

  @doc "MDEx options for this context — GFM on, raw HTML allowed, heading ids generated."
  @spec mdex_opts(Context.t()) :: keyword()
  def mdex_opts(%Context{theme: theme}) do
    [
      extension: [
        table: true,
        strikethrough: true,
        autolink: true,
        tasklist: true,
        footnotes: true,
        header_id_prefix: ""
      ],
      # Content is trusted: it ships through the API-keyed publish CLI (DESIGN.md §6),
      # so authors may use inline HTML (<kbd>, <sup>, …) in prose.
      render: [unsafe: true],
      syntax_highlight: [engine: :lumis, opts: [formatter: {:html_inline, theme: theme}]]
    ]
  end

  # ---- dispatch ----

  defp render_node({:directive, name, _attrs, children} = node, ctx) do
    case Context.directive_handler(ctx, name) do
      nil ->
        # Unknown directive: keep the children rather than dropping the block.
        {html, ctx} = render_nodes(children, ctx)
        {[~s(<div class="kd-directive kd-directive-#{HTML.esc(name)}">), html, "</div>"], ctx}

      module ->
        module.render(node, ctx)
    end
  end

  defp render_node({:fence, lang, flags, code} = node, ctx) do
    case Context.fence_handler(ctx, flags, lang) do
      nil -> {[~s(<div class="kd-code">), highlight(code, lang, ctx), "</div>"], ctx}
      module -> module.render(node, ctx)
    end
  end

  defp render_node({:markdown, text}, ctx) do
    html = MDEx.to_html!(text, mdex_opts(ctx))
    {html, collect_headings(html, ctx)}
  end

  # ---- document hooks ----

  defp run_document_hooks(ctx, nodes) do
    meta = Context.meta(ctx)
    Enum.reduce(ctx.document_hooks, ctx, fn module, ctx -> module.document(meta, nodes, ctx) end)
  end

  # Runs once the body is rendered, for contributions that depend on what the page
  # turned out to contain — an island manifest cannot be built before that.
  defp run_finalize_hooks(ctx),
    do: Enum.reduce(ctx.finalize_hooks, ctx, fn module, ctx -> module.finalize(ctx) end)

  # ---- table of contents ----

  # Read the ids comrak actually generated rather than re-implementing its slugifier.
  defp collect_headings(html, ctx) do
    @heading_re
    |> Regex.scan(html)
    |> Enum.reduce(ctx, fn [_, level, id, inner], ctx ->
      Context.put_heading(ctx, String.to_integer(level), id, text_of(inner))
    end)
  end

  defp text_of(inner), do: @tag_re |> Regex.replace(inner, "") |> String.trim()

  defp language(lang) when lang in [nil, ""], do: "text"
  defp language(lang), do: lang
end
