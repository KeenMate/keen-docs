defmodule KeenDocs.Web.View do
  @moduledoc "HTML building for the test harness — layout chrome + small helpers."

  alias KeenMarkdown.{HTML, Output}

  @doc "HTML-escape."
  defdelegate esc(s), to: HTML

  @doc "A document's URL — omits the variant segment when `show_in_path` is false (guides)."
  def doc_path(set, _variant, slug, false), do: "/#{set}/#{slug}"
  def doc_path(set, variant, slug, _true), do: "/#{set}/#{variant}/#{slug}"

  @doc "Render stored markdown to page regions via keen_markdown."
  def render_markdown(content), do: KeenMarkdown.render(content)

  @doc "Full page. `opts[:head]` / `opts[:footer]` inject renderer regions for doc pages."
  def layout(title, inner, opts \\ []) do
    """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>#{esc(title)} · keen-docs</title>
      <style>#{harness_css()}#{content_css()}</style>
    #{opts[:head] || ""}</head>
    <body>
      <nav class="hz-top">
        <a class="hz-brand" href="/">keen-docs</a>
        <form class="hz-search" action="/search" method="get">
          <input name="q" placeholder="search docs…" value="#{esc(opts[:q] || "")}" />
          <button type="submit">Search</button>
        </form>
        <a href="/resolve">Resolve package.json →</a>
      </nav>
      <main class="hz-main">
    #{inner}
      </main>
    #{opts[:footer] || ""}</body>
    </html>
    """
  end

  @doc "A little pill/badge."
  def badge(text, class \\ ""), do: ~s(<span class="hz-badge #{class}">#{esc(text)}</span>)

  defp harness_css do
    """
    *{box-sizing:border-box} body{margin:0;font:15px/1.5 system-ui,sans-serif;color:#1a2233;background:#f6f8fb}
    a{color:#2563eb;text-decoration:none} a:hover{text-decoration:underline}
    .hz-top{display:flex;align-items:center;gap:1.2rem;padding:.7rem 1.2rem;background:#0f172a;color:#fff;position:sticky;top:0}
    .hz-top a{color:#cbd5e1} .hz-brand{font-weight:700;color:#fff!important;font-size:1.05rem}
    .hz-search{margin-left:auto;display:flex;gap:.4rem}
    .hz-search input{padding:.35rem .6rem;border-radius:6px;border:1px solid #334155;background:#1e293b;color:#fff;width:16rem}
    .hz-search button,.hz-form button{padding:.35rem .8rem;border-radius:6px;border:0;background:#2563eb;color:#fff;cursor:pointer}
    .hz-main{max-width:960px;margin:1.6rem auto;padding:0 1.2rem}
    h1{font-size:1.5rem;margin:.2rem 0 1rem} h2{font-size:1.15rem;margin:1.6rem 0 .6rem}
    .hz-card{background:#fff;border:1px solid #e5e9f0;border-radius:10px;padding:1rem 1.2rem;margin:.8rem 0}
    .hz-badge{display:inline-block;font-size:.72rem;padding:.1rem .5rem;border-radius:999px;background:#e2e8f0;color:#334155;font-weight:600}
    .hz-badge.component{background:#dbeafe;color:#1d4ed8} .hz-badge.infrastructure{background:#dcfce7;color:#15803d}
    .hz-badge.guide{background:#fef9c3;color:#854d0e} .hz-badge.rc{background:#fee2e2;color:#b91c1c}
    .hz-badge.default{background:#e0e7ff;color:#4338ca} .hz-badge.hidden{background:#f1f5f9;color:#64748b}
    table{border-collapse:collapse;width:100%} td,th{padding:.45rem .6rem;text-align:left;border-bottom:1px solid #eef1f6}
    th{font-size:.78rem;text-transform:uppercase;letter-spacing:.03em;color:#64748b}
    code{background:#eef1f6;padding:.05rem .35rem;border-radius:4px;font-size:.9em}
    .hz-variant{border-left:3px solid #cbd5e1;padding-left:.9rem;margin:1rem 0}
    .hz-docs li{margin:.15rem 0} .muted{color:#64748b}
    .hz-form textarea{width:100%;min-height:12rem;font-family:ui-monospace,monospace;font-size:.85rem;padding:.7rem;border-radius:8px;border:1px solid #cbd5e1}
    .hz-crumb{font-size:.85rem;color:#64748b;margin-bottom:.6rem}
    .hz-hit{padding:.5rem 0;border-bottom:1px solid #eef1f6}
    .hz-index{margin:2rem 0 0;border:1px dashed #cbd5e1;border-radius:8px;padding:.6rem 1rem;background:#fff}
    .hz-index summary{cursor:pointer;font-weight:600;color:#334155}
    .hz-index h3{font-size:.72rem;text-transform:uppercase;letter-spacing:.03em;color:#64748b;margin:1rem 0 .3rem}
    .hz-index pre{white-space:pre-wrap;background:#f8fafc;border:1px solid #eef1f6;border-radius:6px;padding:.6rem .8rem;font-size:.8rem;margin:0}
    """
  end

  # The engine emits kd-* classes; reuse the POC stylesheet so rendered doc bodies look right.
  defp content_css do
    case File.read("priv/web/keendocs.css") do
      {:ok, css} -> css
      _ -> ""
    end
  end

  @doc "Body HTML for rendered doc content."
  def body_html(%Output{} = o), do: Output.body_html(o)
  def head_html(%Output{} = o), do: Output.head_html(o)
  def footer_html(%Output{} = o), do: Output.footer_html(o)
end
