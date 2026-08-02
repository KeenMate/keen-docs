defmodule KeenDocs.POC do
  @moduledoc """
  POC entrypoint: render a sample `.md` (front matter + directives + live demo)
  into a standalone `build/poc.html` that mounts a real `<web-multiselect>` from
  the jsdelivr CDN. Run with:

      mix run -e "KeenDocs.POC.build()"
  """

  alias KeenDocs.Markdown.{Frontmatter, DirectiveParser, Renderer}

  @cdn_ver "2.0.0"

  def build(source \\ "priv/content/form-integration.md", out \\ "build/poc.html") do
    raw = File.read!(source)
    {meta, body} = Frontmatter.split(raw)
    html = body |> DirectiveParser.parse() |> Renderer.render()

    File.mkdir_p!(Path.dirname(out))
    File.write!(out, page(meta, html))
    IO.puts("wrote #{out}  (#{byte_size(html)} bytes of rendered content)")
  end

  defp page(meta, content) do
    title = Map.get(meta, "title", "keen-docs POC")
    desc = Map.get(meta, "description", "")
    css = File.read!("priv/web/keendocs.css")

    """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>#{title}</title>
      <meta name="description" content="#{desc}" />
      <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@keenmate/web-multiselect@#{@cdn_ver}/dist/style.css" />
      <script type="module" src="https://cdn.jsdelivr.net/npm/@keenmate/web-multiselect@#{@cdn_ver}/dist/multiselect.js"></script>
      <style>#{css}</style>
    </head>
    <body>
      <main class="kd-page">
        <header class="kd-page-head">
          <h1>#{title}</h1>
          <p class="kd-page-desc">#{desc}</p>
        </header>
        #{content}
      </main>
    </body>
    </html>
    """
  end
end
