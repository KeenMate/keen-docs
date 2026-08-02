defmodule KeenDocs.Markdown.Output do
  @moduledoc """
  The result of rendering a document: **page regions**, not a single HTML string.

  A directive or fence does not only produce body markup — a mermaid diagram needs
  its runtime loaded, an OG hook needs `<meta>` tags in the head, a `js run` block
  needs a module script *after* the content it drives. Each contribution has to land
  in the region where it belongs, so `render` returns this struct and the page shell
  assembles it.

  Regions accumulate reversed (O(1) prepend) and are flipped by `finalize/1`.

  `assets` are keyed and deduplicated: two mermaid diagrams on a page must load the
  mermaid bundle once. On finalize, assets are emitted *before* the direct
  contributions of their region, so library tags precede the inits that use them.
  """

  alias KeenDocs.Markdown.Output

  @type region :: :head | :footer
  @type asset :: %{key: String.t(), region: region(), html: iodata()}
  @type heading :: %{level: pos_integer(), id: String.t(), text: String.t()}

  @type t :: %__MODULE__{
          meta: map(),
          head: iodata(),
          body: iodata(),
          footer: iodata(),
          assets: [asset()],
          toc: [heading()],
          body_class: [String.t()]
        }

  defstruct meta: %{}, head: [], body: [], footer: [], assets: [], toc: [], body_class: []

  @doc "A fresh output carrying the document's front matter."
  @spec new(map()) :: t()
  def new(meta \\ %{}), do: %Output{meta: meta}

  @doc "Append body markup."
  @spec put_body(t(), iodata()) :: t()
  def put_body(%Output{} = out, html), do: %{out | body: [html | out.body]}

  @doc "Append a `<head>` contribution (meta/link/style)."
  @spec put_head(t(), iodata()) :: t()
  def put_head(%Output{} = out, html), do: %{out | head: [html | out.head]}

  @doc "Append an end-of-`<body>` contribution (module scripts, inits)."
  @spec put_footer(t(), iodata()) :: t()
  def put_footer(%Output{} = out, html), do: %{out | footer: [html | out.footer]}

  @doc """
  Register a keyed asset in `region`, ignoring repeats of the same `key`.

  This is what makes an extension safe to use many times on one page.
  """
  @spec put_asset(t(), String.t(), region(), iodata()) :: t()
  def put_asset(%Output{} = out, key, region, html) when region in [:head, :footer] do
    if Enum.any?(out.assets, &(&1.key == key)) do
      out
    else
      %{out | assets: [%{key: key, region: region, html: html} | out.assets]}
    end
  end

  @doc "Record a heading for the table of contents."
  @spec put_heading(t(), pos_integer(), String.t(), String.t()) :: t()
  def put_heading(%Output{} = out, level, id, text),
    do: %{out | toc: [%{level: level, id: id, text: text} | out.toc]}

  @doc "Add a class to the page body."
  @spec put_body_class(t(), String.t()) :: t()
  def put_body_class(%Output{} = out, class) do
    if class in out.body_class, do: out, else: %{out | body_class: [class | out.body_class]}
  end

  @doc """
  Flip every accumulator into source order and fold assets into their region.

  Assets lead their region so a library `<script>` is always emitted before the
  init script that depends on it.
  """
  @spec finalize(t()) :: t()
  def finalize(%Output{} = out) do
    assets = Enum.reverse(out.assets)

    %{
      out
      | head: assets_for(assets, :head) ++ Enum.reverse(out.head),
        body: Enum.reverse(out.body),
        footer: assets_for(assets, :footer) ++ Enum.reverse(out.footer),
        assets: assets,
        toc: Enum.reverse(out.toc),
        body_class: Enum.reverse(out.body_class)
    }
  end

  @doc "Body markup as a binary. Call after `finalize/1`."
  @spec body_html(t()) :: String.t()
  def body_html(%Output{body: body}), do: IO.iodata_to_binary(body)

  @doc "Head contributions as a binary. Call after `finalize/1`."
  @spec head_html(t()) :: String.t()
  def head_html(%Output{head: head}), do: IO.iodata_to_binary(head)

  @doc "Footer contributions as a binary. Call after `finalize/1`."
  @spec footer_html(t()) :: String.t()
  def footer_html(%Output{footer: footer}), do: IO.iodata_to_binary(footer)

  defp assets_for(assets, region),
    do: assets |> Enum.filter(&(&1.region == region)) |> Enum.map(& &1.html)
end
