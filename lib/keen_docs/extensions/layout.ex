defmodule KeenDocs.Extensions.Layout do
  @moduledoc """
  Generic layout primitives: `:::columns`, `:::col` and the `:::showcase` preset.

  Layout is decoupled from "demo-ness" (DESIGN.md §5) — a column is just a column,
  and whether something is a live demo is decided on the code fence. Widths are free
  ratios via CSS grid `fr` units, so `cols="80/20"` is a true 80/20 split rather than
  the nearest 12-grid approximation.

  `showcase` is only a preset over `columns`: the same grid plus section chrome and
  positional accent colours.

  Children that are not `:::col` are **not** dropped and do not become stray grid
  cells — they span the full row, so prose written between or above columns keeps its
  place in the source order.
  """

  use KeenDocs.Markdown.Extension

  alias KeenDocs.Markdown.{HTML, Renderer}

  @accents ~w(blue green cyan)

  @impl true
  def directives, do: ~w(columns col showcase)

  @impl true
  def render({:directive, "columns", attrs, children}, ctx), do: grid(attrs, children, ctx, false)

  def render({:directive, "showcase", attrs, children}, ctx) do
    {grid, ctx} = grid(attrs, children, ctx, true)

    {[~s(<section class="kd-showcase">), header(attrs), grid, "</section>"], ctx}
  end

  def render({:directive, "col", attrs, children}, ctx),
    do: column(attrs, children, attrs["accent"], ctx)

  # ---- grid ----

  defp grid(attrs, children, ctx, accents?) do
    columns = Enum.count(children, &col?/1)

    {parts, ctx, _index} =
      Enum.reduce(children, {[], ctx, 0}, fn child, {acc, ctx, index} ->
        place(child, acc, ctx, index, accents?)
      end)

    open =
      ~s(<div class="kd-columns" style="grid-template-columns: #{template(attrs["cols"], columns)}">)

    {[open, Enum.reverse(parts), "</div>"], ctx}
  end

  defp place({:directive, "col", attrs, children}, acc, ctx, index, accents?) do
    {html, ctx} = column(attrs, children, accent(attrs["accent"], index, accents?), ctx)
    {[html | acc], ctx, index + 1}
  end

  # Anything that is not a column spans the whole row instead of being silently
  # dropped (showcase used to) or shifting the grid (columns used to).
  defp place(node, acc, ctx, index, _accents?) do
    {html, ctx} = Renderer.render_nodes([node], ctx)
    {[[~s(<div class="kd-span">), html, "</div>"] | acc], ctx, index}
  end

  defp column(attrs, children, accent, ctx) do
    {body, ctx} = Renderer.render_nodes(children, ctx)

    {[~s(<div class="kd-col">), column_header(attrs["title"], accent), ~s(<div class="kd-col-body">),
      body, "</div></div>"], ctx}
  end

  defp column_header(nil, _accent), do: ""

  defp column_header(title, accent) do
    class = if accent, do: " kd-accent-#{HTML.esc(accent)}", else: ""
    ~s(<div class="kd-col-header#{class}">#{HTML.esc(title)}</div>)
  end

  # An explicit accent= always wins; showcase then falls back to position.
  defp accent(explicit, _index, _accents?) when is_binary(explicit), do: explicit
  defp accent(_explicit, index, true), do: Enum.at(@accents, rem(index, length(@accents)))
  defp accent(_explicit, _index, false), do: nil

  defp col?({:directive, "col", _attrs, _children}), do: true
  defp col?(_node), do: false

  # "80/20" -> "80fr 20fr"; absent -> equal columns.
  defp template(nil, count), do: "repeat(#{max(count, 1)}, 1fr)"

  defp template(spec, _count) do
    spec
    |> String.split(~r{[/\s]+}, trim: true)
    |> Enum.map_join(" ", &"#{&1}fr")
  end

  defp header(attrs) do
    title = attrs["title"]
    subtitle = attrs["subtitle"]

    [
      if(title, do: ~s(<h3 class="kd-showcase-title">#{HTML.esc(title)}</h3>), else: ""),
      if(subtitle, do: ~s(<p class="kd-showcase-sub">#{HTML.esc(subtitle)}</p>), else: "")
    ]
  end

  @doc "Accent colours assigned by position inside a `:::showcase`."
  def accents, do: @accents
end
