defmodule KeenDocs.Extensions.Blocks do
  @moduledoc """
  Boxed content blocks: `:::card{title=…}` and `:::callout{type=… title=…}`.

  A card is the chrome-bearing counterpart to `:::col` (DESIGN.md §5) and may sit
  inside a column. Callout types are `info` (default), `warning` and `danger`.
  """

  use KeenDocs.Markdown.Extension

  alias KeenDocs.Markdown.{HTML, Renderer}

  @impl true
  def directives, do: ~w(card callout)

  @impl true
  def render({:directive, "card", attrs, children}, ctx) do
    {body, ctx} = Renderer.render_nodes(children, ctx)

    {[~s(<div class="kd-card">), title(attrs["title"], "kd-card-header"),
      ~s(<div class="kd-card-body">), body, "</div></div>"], ctx}
  end

  def render({:directive, "callout", attrs, children}, ctx) do
    {body, ctx} = Renderer.render_nodes(children, ctx)
    type = attrs["type"] || "info"

    {[~s(<div class="kd-callout kd-callout-#{HTML.esc(type)}">),
      title(attrs["title"], "kd-callout-title"), ~s(<div class="kd-callout-body">), body,
      "</div></div>"], ctx}
  end

  defp title(nil, _class), do: ""
  defp title(text, class), do: ~s(<div class="#{class}">#{HTML.esc(text)}</div>)
end
