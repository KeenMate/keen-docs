defmodule KeenDocs.Extensions.Mermaid do
  @moduledoc """
  Renders ` ```mermaid ` fences as diagrams.

  Demonstrates the **asset** half of the extension contract: the block emits markup
  into the body while registering the mermaid runtime as a keyed page asset. The key
  deduplicates, so a page with ten diagrams still loads the bundle once, and a page
  with none loads nothing at all.
  """

  use KeenDocs.Markdown.Extension

  alias KeenDocs.Markdown.{Context, HTML}

  @version "11"
  @asset_key "mermaid"

  @impl true
  def fences, do: ["mermaid"]

  @impl true
  def render({:fence, _lang, _flags, code}, ctx) do
    {~s(<pre class="mermaid">#{HTML.esc(code)}</pre>), Context.put_asset(ctx, @asset_key, :footer, runtime())}
  end

  defp runtime do
    """
    <script type="module">
    import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@#{@version}/dist/mermaid.esm.min.mjs";
    mermaid.initialize({ startOnLoad: true });
    </script>
    """
  end
end
