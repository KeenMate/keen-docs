defmodule KeenDocs.Markdown.Renderer do
  @moduledoc """
  Renders the `KeenDocs.Markdown.DirectiveParser` node tree to an HTML string.

  Layout is a generic primitive (`columns`/`col`) decoupled from "demo-ness",
  which lives on the code fence (`demo` / `run` / `example`). `showcase` is a
  preset over `columns` that auto-assigns accent colors per column position.

  Markdown text runs and `example` fences are highlighted server-side by MDEx
  (self-contained inline styles — no client-side highlight.js, no FOUC).
  """

  alias KeenDocs.Markdown.DirectiveParser

  @accents ~w(blue green cyan amber)

  @spec render([DirectiveParser.node_t()]) :: String.t()
  def render(nodes) when is_list(nodes) do
    nodes |> Enum.map(&render_node/1) |> Enum.join("\n")
  end

  # ---- directives ----

  defp render_node({:directive, "columns", attrs, children}) do
    cols = Enum.filter(children, &col?/1)
    ~s(<div class="kd-columns" style="grid-template-columns: #{grid_template(attrs["cols"], length(cols))}">) <>
      render(children) <>
      "</div>"
  end

  defp render_node({:directive, "showcase", attrs, children}) do
    cols = Enum.filter(children, &col?/1)

    body =
      cols
      |> Enum.with_index()
      |> Enum.map(fn {c, i} -> col_html(c, Enum.at(@accents, rem(i, length(@accents)))) end)
      |> Enum.join("\n")

    header =
      case {attrs["title"], attrs["subtitle"]} do
        {nil, _} -> ""
        {title, nil} -> ~s(<h3 class="kd-showcase-title">#{esc(title)}</h3>)
        {title, sub} -> ~s(<h3 class="kd-showcase-title">#{esc(title)}</h3><p class="kd-showcase-sub">#{esc(sub)}</p>)
      end

    ~s(<section class="kd-showcase">#{header}) <>
      ~s(<div class="kd-columns" style="grid-template-columns: #{grid_template(attrs["cols"], length(cols))}">) <>
      body <>
      "</div></section>"
  end

  defp render_node({:directive, "col", attrs, _children} = col), do: col_html(col, attrs["accent"])

  defp render_node({:directive, "card", attrs, children}) do
    header = if attrs["title"], do: ~s(<div class="kd-card-header">#{esc(attrs["title"])}</div>), else: ""
    ~s(<div class="kd-card">#{header}<div class="kd-card-body">#{render(children)}</div></div>)
  end

  defp render_node({:directive, "callout", attrs, children}) do
    type = attrs["type"] || "info"
    header = if attrs["title"], do: ~s(<div class="kd-callout-title">#{esc(attrs["title"])}</div>), else: ""
    ~s(<div class="kd-callout kd-callout-#{esc(type)}">#{header}<div class="kd-callout-body">#{render(children)}</div></div>)
  end

  # unknown directive: render children in a labelled wrapper so nothing is lost
  defp render_node({:directive, name, _attrs, children}) do
    ~s(<div class="kd-directive kd-directive-#{esc(name)}">#{render(children)}</div>)
  end

  # ---- leaves ----

  defp render_node({:markdown, text}), do: MDEx.to_html!(text, mdex_opts())

  defp render_node({:fence, lang, flags, code}) do
    cond do
      "demo" in flags -> demo_html(lang, code)
      "run" in flags -> run_html(code)
      true -> ~s(<div class="kd-code">#{highlight(code, lang)}</div>)
    end
  end

  # ---- helpers ----

  defp col?({:directive, "col", _, _}), do: true
  defp col?(_), do: false

  defp col_html({:directive, "col", attrs, children}, accent) do
    accent_class = if accent, do: " kd-accent-#{esc(accent)}", else: ""
    header = if attrs["title"], do: ~s(<div class="kd-col-header#{accent_class}">#{esc(attrs["title"])}</div>), else: ""
    ~s(<div class="kd-col">#{header}<div class="kd-col-body">#{render(children)}</div></div>)
  end

  defp demo_html(lang, code) do
    id = "kd-demo-#{System.unique_integer([:positive])}"
    Process.put(:kd_last_demo, id)

    ~s(<div class="kd-demo" id="#{id}">) <>
      ~s(<div class="kd-demo-live">#{code}</div>) <>
      ~s(<details class="kd-demo-source"><summary>source</summary>#{highlight(code, lang)}</details>) <>
      "</div>"
  end

  defp run_html(code) do
    target = Process.get(:kd_last_demo, "document.body")
    root_expr = if target == "document.body", do: "document.body", else: "document.getElementById(\"#{target}\")"

    """
    <script type="module">
    (function () {
      const root = #{root_expr};
      if (!root) return;
      const el = root.querySelector(".kd-demo-live > *") || root;
      const out = (v) => {
        let o = root.querySelector(".kd-out");
        if (!o) { o = document.createElement("pre"); o.className = "kd-out"; root.appendChild(o); }
        o.textContent = typeof v === "string" ? v : JSON.stringify(v, null, 2);
      };
      #{code}
    })();
    </script>
    """
  end

  # "80/20" -> "80fr 20fr"; nil -> "repeat(N, 1fr)"
  defp grid_template(nil, n), do: "repeat(#{max(n, 1)}, 1fr)"

  defp grid_template(spec, _n) do
    spec
    |> String.split(~r/[\/\s]+/, trim: true)
    |> Enum.map(&"#{&1}fr")
    |> Enum.join(" ")
  end

  defp highlight(code, lang) do
    lang = if lang in [nil, ""], do: "text", else: lang
    MDEx.to_html!("```#{lang}\n#{code}\n```", mdex_opts())
  end

  defp mdex_opts do
    [
      extension: [table: true, strikethrough: true, autolink: true],
      render: [unsafe: false],
      syntax_highlight: [engine: :lumis, opts: [formatter: {:html_inline, theme: "github_light"}]]
    ]
  end

  defp esc(nil), do: ""
  defp esc(v) when is_binary(v), do: v |> String.replace("&", "&amp;") |> String.replace("<", "&lt;") |> String.replace(">", "&gt;") |> String.replace("\"", "&quot;")
  defp esc(v), do: v |> to_string() |> esc()
end
