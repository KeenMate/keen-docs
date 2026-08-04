defmodule KeenDocs.POC do
  @moduledoc """
  POC entrypoint: render a sample `.md` (front matter + directives + live demos) into
  a standalone `build/poc.html`. Run with:

      mix run -e "KeenDocs.POC.build()"

  The page shell hardcodes nothing about the component being documented. It assembles
  the regions the renderer produced — head contributions, body, footer scripts — and
  the CDN tags come from front matter via `KeenDocs.Extensions.CdnPackage`.
  """

  alias KeenMarkdown.{HTML, Output}

  @doc "Render `source` to a standalone HTML page at `out`."
  @spec build(Path.t(), Path.t()) :: :ok
  def build(source \\ "priv/content/form-integration.md", out \\ "build/poc.html") do
    output = render_file(source)

    File.mkdir_p!(Path.dirname(out))
    File.write!(out, page(output))

    IO.puts("wrote #{out}  (#{byte_size(Output.body_html(output))} bytes of rendered body)")
  end

  @doc "Render a markdown file to an `Output` of page regions."
  @spec render_file(Path.t()) :: Output.t()
  def render_file(source) do
    # Front-matter split, parse and render all happen in keen_markdown; the extension
    # set (generic + keen-docs') is picked up from `config :keen_markdown, :extensions`.
    source |> File.read!() |> KeenMarkdown.render()
  end

  defp page(%Output{meta: meta} = output) do
    title = Map.get(meta, "title", "keen-docs POC")
    description = Map.get(meta, "description", "")

    """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>#{HTML.esc(title)}</title>
      <meta name="description" content="#{HTML.esc(description)}" />
    #{Output.head_html(output)}  <style>#{File.read!("priv/web/vendor/pure-css/base.css")}#{File.read!("priv/web/keendocs.css")}</style>
    </head>
    <body#{body_class(output)}>
      <main class="kd-page">
        <header class="kd-page-head">
          <h1>#{HTML.esc(title)}</h1>
          <p class="kd-page-desc">#{HTML.esc(description)}</p>
        </header>
    #{toc(output)}#{Output.body_html(output)}
      </main>
    #{Output.footer_html(output)}</body>
    </html>
    """
  end

  defp body_class(%Output{body_class: []}), do: ""
  defp body_class(%Output{body_class: classes}), do: ~s( class="#{HTML.esc(Enum.join(classes, " "))}")

  # Renders the headings the markdown pass collected — proof the generated ids are
  # real and link-able, not just decoration.
  defp toc(%Output{toc: []}), do: ""

  defp toc(%Output{toc: headings}) do
    items =
      Enum.map_join(headings, "", fn %{level: level, id: id, text: text} ->
        ~s(<li class="kd-toc-h#{level}"><a href="##{HTML.esc(id)}">#{HTML.esc(text)}</a></li>)
      end)

    ~s(<nav class="kd-toc" aria-label="On this page"><ul>#{items}</ul></nav>\n)
  end
end
