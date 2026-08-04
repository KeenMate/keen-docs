defmodule KeenDocs.Web.View do
  @moduledoc "HTML building for the test harness — layout chrome + small helpers."

  alias KeenMarkdown.{HTML, Output}
  alias KeenDocs.Content

  @doc "HTML-escape."
  defdelegate esc(s), to: HTML

  @doc "A document's URL — omits the variant segment when `show_in_path` is false (guides)."
  def doc_path(set, _variant, slug, false), do: "/#{set}/#{slug}"
  def doc_path(set, variant, slug, _true), do: "/#{set}/#{variant}/#{slug}"

  @doc "Render stored markdown to page regions via keen_markdown."
  def render_markdown(content), do: KeenMarkdown.render(content)

  @doc """
  Full page. `opts[:head]` / `opts[:footer]` inject renderer regions for doc pages.
  `opts[:docset]` (a `get_doc_set` row) supplies per-set chrome — accent, header links,
  footer. `opts[:sidebar]` (pre-rendered nav HTML) turns the body into a two-column shell.
  """
  def layout(title, inner, opts \\ []) do
    docset = opts[:docset]
    sidebar = opts[:sidebar]

    body_region =
      if sidebar && sidebar != "" do
        """
        <div class="kd-shell d-flex align-items-start">
          <aside class="kd-side wr-16 flex-shrink-0">#{sidebar}</aside>
          <main class="kd-main--doc flex-fill">
        #{inner}
          </main>
        </div>
        """
      else
        ~s(<main class="kd-main">\n#{inner}\n  </main>)
      end

    """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>#{esc(title)} · keen-docs</title>
      <link rel="stylesheet" href="/vendor/pure-css/grid.css" />
      <link rel="stylesheet" href="/vendor/pure-css/utilities.css" />
      <style>#{base_vars_css()}#{dark_theme_css()}#{theme_css(docset)}#{harness_css()}#{content_css()}</style>
      <script>#{mode_init_js()}</script>
    #{docset_head(docset, opts[:canonical])}#{opts[:head] || ""}</head>
    <body>
      <nav class="kd-top d-flex align-items-center gap-5">
        <a class="kd-brand" href="/">keen-docs</a>#{brand_suffix(docset)}
        #{top_nav_html()}
        <form class="kd-search d-flex gap-2 ml-auto" action="/search" method="get">
          <input name="q" placeholder="search docs…" value="#{esc(opts[:q] || "")}" />
          <button type="submit">Search</button>
        </form>
        #{header_links(docset)}<a href="/resolve">Resolve package.json →</a>
        #{mode_toggle_html()}
      </nav>
    #{body_region}
    #{docset_footer(docset)}#{opts[:footer] || ""}</body>
    </html>
    """
  end

  @doc """
  Pre-rendered navigation sidebar: an optional version selector (carries the current slug
  across versions) above the nav tree from `get_doc_nav` (already in render order). Sections
  are group headers; leaves link to their page. A leaf may pin its own `variant_code` (e.g. a
  doc-set-wide 'shared' page) and its URL then honours THAT variant's `show_in_path`, so a
  shared page lands at `/set/slug` while a versioned page keeps its version segment.
  `active_slug` marks the current page. `variants` is the full `list_doc_variants` result.
  """
  def sidebar_html(set, nav_rows, active_variant, active_slug, variants) do
    vmap = Map.new(variants, &{&1.code, &1.show_in_path})
    # Un-pinned (versioned) leaves render under the active version — but when you're on a
    # doc-set-wide page (a hidden variant), they fall back to the DEFAULT version, not this
    # page's hidden variant, so they keep their version segment.
    base_variant =
      if Map.get(vmap, active_variant) == true, do: active_variant, else: default_version(variants)

    selector = version_selector(set, variants, active_variant, active_slug)

    items =
      Enum.map_join(nav_rows, "", fn n ->
        pad = "padding-left:#{(n.level - 1) * 0.85 + 0.1}rem"

        if n.is_section do
          ~s(<div class="kd-nav-sec" style="#{pad}">#{esc(n.label)}</div>)
        else
          v = n.variant_code || base_variant
          show = Map.get(vmap, v, true)
          active = if n.slug == active_slug, do: " active", else: ""
          ~s(<a class="kd-nav-link#{active}" style="#{pad}" href="#{doc_path(set, v, n.slug, show)}">#{esc(n.label)}</a>)
        end
      end)

    nav = if items == "", do: "", else: ~s(<nav class="d-flex flex-column">#{items}</nav>)
    if selector == "" and nav == "", do: "", else: selector <> nav
  end

  # The default version variant code (a shown-in-path variant): is_default first, else the first.
  defp default_version(variants) do
    versions = Enum.filter(variants, & &1.show_in_path)
    v = Enum.find(versions, & &1.is_default) || List.first(versions)
    v && v.code
  end

  # A version <select> that jumps to the same page under another version, carrying the current
  # slug across. "Versions" are the variants shown in the path (components); a hidden 'shared'
  # variant holding doc-set-wide pages is not a version and is skipped. Plain-page harness → a
  # one-line onchange navigation, no framework.
  defp version_selector(set, variants, active_variant, active_slug) do
    versions = Enum.filter(variants, & &1.show_in_path)
    on_version = Enum.any?(versions, &(&1.code == active_variant))
    # carry the current slug across versions — but only when it IS a versioned page; a
    # doc-set-wide slug has no per-version copy, so switch to that version's Overview instead.
    slug = if on_version, do: active_slug || "index", else: "index"

    if versions == [] do
      ""
    else
      selected = if on_version, do: active_variant, else: default_version(variants)

      opts =
        Enum.map_join(versions, "", fn v ->
          sel = if v.code == selected, do: " selected", else: ""
          ~s(<option value="/#{esc(set)}/#{esc(v.code)}/#{esc(slug)}"#{sel}>#{esc(v.title || v.code)}</option>)
        end)

      ~s(<label class="kd-version-l d-flex align-items-center gap-2">version<select class="kd-version" onchange="location.href=this.value">#{opts}</select></label>)
    end
  end

  @doc """
  The global (hub) top navigation, shown site-wide. Level-1 nodes render as top-bar items;
  a level-1 section with children becomes a hover dropdown of its level-2 links. Each leaf
  targets a doc_set (→ its homepage), an internal site_page, or an external URL.
  """
  def top_nav_html do
    case hub_nav() do
      [] ->
        ""

      rows ->
        tops = Enum.filter(rows, &(&1.level == 1))

        items =
          Enum.map_join(tops, "", fn n ->
            kids = Enum.filter(rows, &(&1.level == 2 and String.starts_with?(&1.node_path, n.node_path <> ".")))

            if n.is_section and kids != [] do
              menu = Enum.map_join(kids, "", &nav_link(&1, "kd-dd-item"))
              ~s(<div class="kd-dd"><button type="button" class="kd-dd-btn">#{esc(n.label)} ▾</button><div class="kd-dd-menu border rounded">#{menu}</div></div>)
            else
              nav_link(n, "kd-top-link")
            end
          end)

        ~s(<div class="d-flex align-items-center gap-1">#{items}</div>)
    end
  end

  defp hub_nav do
    Content.rows(Content.get_site_nav("hub"))
  rescue
    _ -> []
  end

  defp nav_link(n, class) do
    {href, external?} =
      cond do
        n.doc_set_code -> {"/#{n.doc_set_code}", false}
        n.slug -> {"/#{n.slug}", false}
        n.url -> {n.url, true}
        true -> {"#", false}
      end

    tgt = if external?, do: ~s( target="_blank" rel="noopener"), else: ""
    ~s(<a class="#{class}" href="#{esc(href)}"#{tgt}>#{esc(n.label)}</a>)
  end

  # ── per-doc_set chrome (from get_doc_set.settings) ──────────────────────────
  defp settings(%{settings: s}) when is_map(s), do: s
  defp settings(_), do: %{}

  # The @keenmate/pure-css `--base-*` defaults, inlined once per page so the chrome (which
  # reads var(--base-*)) has no FOUC and needs no extra request. Read at compile time from the
  # vendored artifact so it's deterministic and the file is the single source of truth.
  @base_vars_css (case File.read("priv/web/vendor/pure-css/base.css") do
                    {:ok, css} -> css
                    _ -> ""
                  end)
  defp base_vars_css, do: @base_vars_css

  # Dark mode: a --base-* override scoped to `html.pa-mode-dark`, inlined so the toggle
  # flips instantly with no flash. Read once at compile time (single source: dark-theme.css).
  @dark_theme_css (case File.read("priv/web/dark-theme.css") do
                     {:ok, css} -> css
                     _ -> ""
                   end)
  defp dark_theme_css, do: @dark_theme_css

  # Applied in <head> before the body paints, so the initial mode is set with no FOUC: an
  # explicit choice in localStorage wins, otherwise follow the OS `prefers-color-scheme`.
  defp mode_init_js do
    "(function(){try{var m=localStorage.getItem('kd-mode');" <>
      "if(m==='dark'||(!m&&matchMedia('(prefers-color-scheme:dark)').matches))" <>
      "document.documentElement.classList.add('pa-mode-dark');}catch(e){}})();"
  end

  # Top-bar button that toggles the dark class and persists the choice.
  defp mode_toggle_html do
    onclick =
      "var d=document.documentElement.classList.toggle('pa-mode-dark');" <>
        "try{localStorage.setItem('kd-mode',d?'dark':'light');}catch(e){}"

    ~s(<button type="button" class="kd-mode" onclick="#{onclick}" title="Toggle dark mode" aria-label="Toggle dark mode">◑</button>)
  end

  # Per-doc_set theme: overrides `--base-*` from `settings.theme`, layered after the defaults so
  # it wins. `accent` sets --base-accent-color and re-derives hover/active/light at runtime via
  # color-mix (the SCSS build derives them, but a live override can't run Sass). `theme.vars` is
  # an escape hatch: any `{"page-bg" => "#…"}` becomes `--base-page-bg: #…`. Because every
  # consumer — the chrome, the kd-* content, and embedded web/svelte components — reads the same
  # variables, this one block re-themes all of them, including a mounted <web-multiselect>.
  defp theme_css(nil), do: ""

  defp theme_css(docset) do
    case theme_decls(settings(docset)["theme"]) do
      "" -> ""
      decls -> ":root{#{decls}}"
    end
  end

  defp theme_decls(theme) when is_map(theme) do
    accent_decls(theme["accent"]) <> var_decls(theme["vars"])
  end

  defp theme_decls(_), do: ""

  defp accent_decls(nil), do: ""

  defp accent_decls(accent) do
    a = esc(to_string(accent))

    # Also publish the raw accent so dark mode (.pa-mode-dark) can brighten it for
    # contrast on dark surfaces while keeping the doc's brand hue (see dark-theme.css).
    "--kd-doc-accent:#{a};" <>
      "--base-accent-color:#{a};" <>
      "--base-accent-color-hover:color-mix(in srgb, #{a} 88%, #fff);" <>
      "--base-accent-color-active:color-mix(in srgb, #{a} 76%, #fff);" <>
      "--base-accent-color-light:color-mix(in srgb, #{a} 8%, transparent);" <>
      "--base-focus-ring-color:#{a};"
  end

  defp var_decls(vars) when is_map(vars) do
    Enum.map_join(vars, "", fn {k, v} ->
      "--base-#{esc(to_string(k))}:#{esc(to_string(v))};"
    end)
  end

  defp var_decls(_), do: ""

  defp brand_suffix(nil), do: ""

  defp brand_suffix(docset) do
    case docset.title do
      nil -> ""
      t -> ~s( <span class="kd-brand-set">/ #{esc(t)}</span>)
    end
  end

  defp header_links(nil), do: ""

  defp header_links(docset) do
    case settings(docset)["header_links"] do
      links when is_list(links) ->
        Enum.map_join(links, "", fn l ->
          ~s(<a href="#{esc(l["url"])}" target="_blank" rel="noopener">#{esc(l["label"])}</a>)
        end)

      _ ->
        ""
    end
  end

  defp docset_footer(nil), do: ""

  defp docset_footer(docset) do
    s = settings(docset)
    f = s["footer"] || %{}
    copy = f["copyright"]
    author = s["author"]
    site_url = s["site_url"]

    # left: copyright · author (linked to site_url when present)
    author_html =
      cond do
        author && site_url -> ~s( · <a href="#{esc(site_url)}" target="_blank" rel="noopener">#{esc(author)}</a>)
        author -> ~s( · #{esc(author)})
        true -> ""
      end

    left = "#{esc(copy || "")}#{author_html}"

    # right: footer links · social handles
    links =
      (f["links"] || [])
      |> Enum.map_join(" · ", fn l -> ~s(<a href="#{esc(l["url"])}">#{esc(l["label"])}</a>) end)

    social =
      (s["social"] || [])
      |> Enum.map_join(" ", fn x ->
        ~s(<a class="kd-social" href="#{esc(x["url"])}" target="_blank" rel="noopener" title="#{esc(x["name"] || "")}">#{esc(x["name"] || x["icon"] || "link")}</a>)
      end)

    right = [links, social] |> Enum.reject(&(&1 == "")) |> Enum.join(" · ")

    if left != "" or right != "" do
      ~s(<footer class="kd-footer border-top"><div class="kd-footer-in d-flex gap-4 flex-wrap"><span>#{left}</span> <span class="ml-auto">#{right}</span></div></footer>)
    else
      ""
    end
  end

  # <head> contributions from the doc_set: author meta, per-page canonical, and the
  # head_assets list (extra_javascript / stylesheets declared once for the whole set).
  defp docset_head(docset, canonical) do
    s = settings(docset)
    author = if a = s["author"], do: ~s(  <meta name="author" content="#{esc(a)}" />\n), else: ""
    canon = if canonical, do: ~s(  <link rel="canonical" href="#{esc(canonical)}" />\n), else: ""
    author <> canon <> head_assets(s["head_assets"])
  end

  defp head_assets(list) when is_list(list), do: Enum.map_join(list, "", &head_asset/1)
  defp head_assets(_), do: ""

  # A string asset is classified by extension; an object carries its own rel/type.
  defp head_asset(a) when is_binary(a) do
    cond do
      String.ends_with?(a, ".css") -> ~s(  <link rel="stylesheet" href="#{esc(a)}" />\n)
      String.ends_with?(a, ".js") or String.ends_with?(a, ".mjs") -> ~s(  <script type="module" src="#{esc(a)}"></script>\n)
      true -> ~s(  <link href="#{esc(a)}" />\n)
    end
  end

  defp head_asset(%{"src" => src} = a),
    do: ~s(  <script src="#{esc(src)}"#{if a["type"], do: ~s( type="#{esc(a["type"])}"), else: ""}></script>\n)

  defp head_asset(%{"href" => href} = a),
    do: ~s(  <link rel="#{esc(a["rel"] || "stylesheet")}" href="#{esc(href)}" />\n)

  defp head_asset(_), do: ""

  @doc "A homepage hero band: the doc_set title + its description as a tagline subtitle."
  def hero_html(_title, nil), do: ""
  def hero_html(_title, ""), do: ""

  def hero_html(title, description) do
    ~s(<header class="kd-hero border-bottom"><h1>#{esc(title || "")}</h1><p class="kd-hero-sub">#{esc(description)}</p></header>)
  end

  @doc "A little pill/badge."
  def badge(text, class \\ ""), do: ~s(<span class="kd-badge #{class}">#{esc(text)}</span>)

  # Site chrome. Colours come from the @keenmate/pure-css `--base-*` contract so a doc_set's
  # theme (theme_css/1) restyles the harness too. Fallbacks keep it sane if base.css is absent.
  # The top bar is deliberately the inverse surface; the shades layered ON the dark bar
  # (search field, on-bar hovers) stay literal so they read regardless of theme. Category
  # badges are semantic chips, not theme colours, so they stay literal too.
  defp harness_css do
    """
    *{box-sizing:border-box} body{margin:0;font:15px/1.5 var(--base-font-family,system-ui,sans-serif);color:var(--base-text-color-1,#1a2233);background:var(--base-page-bg,#f6f8fb)}
    a{color:var(--base-accent-color,#2563eb);text-decoration:none} a:hover{text-decoration:underline}
    /* Layout scaffolding (flex/grid/gap/spacing/width) is done with pure-css utility classes in
       the markup; the rules below are only the irreducible bits utilities can't express —
       themed surfaces/borders, sticky positioning, and component behaviour. */
    .kd-top{padding:.7rem 1.2rem;background:var(--base-inverse-bg,#0f172a);color:#fff;position:sticky;top:0;z-index:20}
    .kd-top a{color:#cbd5e1} .kd-brand{font-weight:700;color:#fff!important;font-size:1.05rem}
    .kd-top-link,.kd-dd-btn{color:#cbd5e1;background:none;border:0;font:inherit;cursor:pointer;padding:.35rem .6rem;border-radius:6px}
    .kd-top-link:hover,.kd-dd-btn:hover{background:rgba(255,255,255,.12);color:#fff;text-decoration:none}
    .kd-dd{position:relative}
    .kd-dd-menu{display:none;position:absolute;top:100%;left:0;background:var(--base-main-bg,#fff);box-shadow:0 8px 24px var(--base-shadow-color,rgba(0,0,0,.14));min-width:12rem;padding:.3rem;z-index:30}
    .kd-dd:hover .kd-dd-menu{display:block}
    .kd-dd-item{display:block;padding:.4rem .6rem;border-radius:6px;color:var(--base-text-color-1,#334155);font-size:.9rem}
    .kd-dd-item:hover{background:var(--base-hover-bg,#eef2f7);text-decoration:none}
    .kd-search input{padding:.35rem .6rem;border-radius:6px;border:1px solid #334155;background:#1e293b;color:#fff;width:16rem}
    .kd-search button,.kd-form button{padding:.35rem .8rem;border-radius:6px;border:0;background:var(--base-accent-color,#2563eb);color:var(--base-text-color-on-accent,#fff);cursor:pointer}
    .kd-mode{background:rgba(255,255,255,.1);color:#fff;border:0;border-radius:6px;padding:.3rem .55rem;font-size:1rem;line-height:1;cursor:pointer}
    .kd-mode:hover{background:rgba(255,255,255,.2)}
    .kd-main{max-width:960px;margin:1.6rem auto;padding:0 1.2rem}
    h1{font-size:1.5rem;margin:.2rem 0 1rem} h2{font-size:1.15rem;margin:1.6rem 0 .6rem}
    .kd-card{background:var(--base-main-bg,#fff);border:1px solid var(--base-border-color,#e5e9f0);border-radius:10px;padding:1rem 1.2rem;margin:.8rem 0}
    .kd-badge{display:inline-block;font-size:.72rem;padding:.1rem .5rem;border-radius:999px;background:#e2e8f0;color:#334155;font-weight:600}
    .kd-badge.component{background:#dbeafe;color:#1d4ed8} .kd-badge.infrastructure{background:#dcfce7;color:#15803d}
    .kd-badge.guide{background:#fef9c3;color:#854d0e} .kd-badge.rc{background:#fee2e2;color:#b91c1c}
    .kd-badge.default{background:#e0e7ff;color:#4338ca} .kd-badge.hidden{background:#f1f5f9;color:#64748b}
    table{border-collapse:collapse;width:100%} td,th{padding:.45rem .6rem;text-align:left;border-bottom:1px solid var(--base-border-color,#eef1f6)}
    th{font-size:.78rem;text-transform:uppercase;letter-spacing:.03em;color:var(--base-text-color-2,#64748b)}
    code{background:var(--base-subtle-bg,#eef1f6);padding:.05rem .35rem;border-radius:4px;font-size:.9em}
    .kd-variant{border-left:3px solid var(--base-border-color,#cbd5e1);padding-left:.9rem;margin:1rem 0}
    .kd-docs li{margin:.15rem 0} .muted{color:var(--base-text-color-2,#64748b)}
    .kd-form textarea{width:100%;min-height:12rem;font-family:var(--base-font-family-mono,ui-monospace,monospace);font-size:.85rem;padding:.7rem;border-radius:8px;border:1px solid var(--base-border-color,#cbd5e1)}
    .kd-crumb{font-size:.85rem;color:var(--base-text-color-2,#64748b);margin-bottom:.6rem}
    .kd-hit{padding:.5rem 0;border-bottom:1px solid var(--base-border-color,#eef1f6)}
    .kd-index{margin:2rem 0 0;border:1px dashed var(--base-border-color,#cbd5e1);border-radius:8px;padding:.6rem 1rem;background:var(--base-main-bg,#fff)}
    .kd-index summary{cursor:pointer;font-weight:600;color:var(--base-text-color-1,#334155)}
    .kd-index h3{font-size:.72rem;text-transform:uppercase;letter-spacing:.03em;color:var(--base-text-color-2,#64748b);margin:1rem 0 .3rem}
    .kd-index pre{white-space:pre-wrap;background:var(--base-page-bg,#f8fafc);border:1px solid var(--base-border-color,#eef1f6);border-radius:6px;padding:.6rem .8rem;font-size:.8rem;margin:0}
    .kd-brand-set{color:#94a3b8!important;font-weight:600}
    .kd-top>a[target]{color:#cbd5e1}
    .kd-shell{max-width:1180px;margin:0 auto}
    .kd-side{position:sticky;top:3.1rem;max-height:calc(100vh - 3.1rem);overflow:auto;padding:1.4rem .8rem 2rem;border-right:1px solid var(--base-border-color,#e5e9f0)}
    .kd-main--doc{margin:1.6rem 0;padding:0 1.6rem;max-width:820px;min-width:0}
    .kd-version-l{font-size:.68rem;text-transform:uppercase;letter-spacing:.05em;color:var(--base-text-color-3,#94a3b8);font-weight:700;margin:0 .1rem 1.1rem}
    .kd-version{flex:1;padding:.35rem .5rem;border:1px solid var(--base-border-color,#cbd5e1);border-radius:6px;background:var(--base-main-bg,#fff);font-size:.85rem;color:var(--base-text-color-1,#1a2233);cursor:pointer}
    .kd-nav-sec{font-size:.72rem;text-transform:uppercase;letter-spacing:.04em;color:var(--base-text-color-3,#94a3b8);font-weight:700;margin:.9rem 0 .25rem}
    .kd-nav-link{display:block;padding:.28rem .55rem;border-radius:6px;color:var(--base-text-color-1,#334155);font-size:.9rem}
    .kd-nav-link:hover{background:var(--base-hover-bg,#eef2f7);text-decoration:none}
    .kd-nav-link.active{background:var(--base-accent-color,#4f46e5);color:var(--base-text-color-on-accent,#fff);font-weight:600}
    .kd-footer{background:var(--base-main-bg,#fff);margin-top:2.5rem}
    .kd-footer-in{max-width:1180px;margin:0 auto;padding:1rem 1.4rem;font-size:.85rem;color:var(--base-text-color-2,#64748b)}
    .kd-social{color:var(--base-text-color-2,#64748b)}
    .kd-hero{margin:0 0 1.6rem;padding:0 0 1.2rem}
    .kd-hero h1{margin:0 0 .35rem;font-size:1.9rem}
    .kd-hero-sub{margin:0;font-size:1.05rem;color:var(--base-text-color-2,#64748b);max-width:46rem}
    .kd-desc{font-size:.82rem;margin-top:.15rem}
    @media(max-width:820px){.kd-shell{flex-direction:column}.kd-side{position:static;max-height:none;border-right:0;border-bottom:1px solid var(--base-border-color,#e5e9f0);width:auto!important}}
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
