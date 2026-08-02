defmodule KeenDocs.Extensions.OpenGraph do
  @moduledoc """
  Writes Open Graph and Twitter card tags into the page `<head>` from front matter.

  Demonstrates the **document hook** half of the extension contract: this extension
  renders no directive and no fence at all. It reads the document's metadata and
  contributes to a page region — which is why `render` returns an
  `KeenDocs.Markdown.Output` of regions rather than a body string.

  svelte-docs handled meta tags twice, declaratively *and* imperatively in the DOM
  (DESIGN.md §3). Here they are emitted once, server-side.
  """

  use KeenDocs.Markdown.Extension

  alias KeenDocs.Markdown.{Context, HTML}

  @impl true
  def document(meta, _tree, ctx) do
    [
      {"og:type", Map.get(meta, "og_type", "article")},
      {"og:title", meta["title"]},
      {"og:description", meta["description"]},
      {"og:image", meta["image"]},
      {"twitter:card", if(meta["image"], do: "summary_large_image", else: "summary")},
      {"twitter:title", meta["title"]},
      {"twitter:description", meta["description"]}
    ]
    |> Enum.reject(fn {_property, content} -> content in [nil, ""] end)
    |> Enum.reduce(ctx, fn {property, content}, ctx ->
      Context.put_head(ctx, tag(property, content))
    end)
  end

  defp tag(property, content),
    do: ~s(<meta property="#{property}" content="#{HTML.esc(content)}" />\n)
end
