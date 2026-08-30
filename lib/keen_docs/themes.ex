defmodule KeenDocs.Themes do
  @moduledoc """
  The per-doc_set **render contract** — keen-docs' declarative layout vocabulary.

  keen-docs is a `@keenmate/pure-css`-only consumer: it styles the app shell (pc-*) and its own
  chrome components (kd-*) itself, with **no pure-admin dependency and no CSS theme bundles**. What
  survives here is the keen-docs-NATIVE render layer: a bounded, data-only vocabulary (hero band,
  breadcrumbs, TOC placement, region toggles, navbar composition, fonts, brand, version control) that
  `KeenDocs.Web.View` interprets when assembling a page. Themes never ship executable layout code
  (deterministic / no-RCE invariant).

  A doc_set selects a named contract via `settings["theme"]["id"]` (global default:
  `config :keen_docs, :theme`); `render_block/1` merges the matching block from the `keendocs.json`
  manifest over the baseline defaults. "theme id" is now just a NAME for a render contract — the old
  pure-admin theme *stylesheets* (aurora/nato/…) are gone. Reads happen at request time from disk (no
  global mutable state) — cheap and deterministic. See `docs/themes.md`.
  """

  @manifest "keendocs.json"

  # The declarative render contract (v1.0). These defaults reproduce keen-docs' baseline assembly
  # exactly, so a doc_set WITHOUT a `keendocs` block renders as it does today. A contract opts into
  # changes by overriding individual keys — the View interprets this bounded vocabulary.
  @render_defaults %{
    "contract" => "1.0",
    # named layout variant → a `kd-layout--<name>` hook class on `.pc-layout` ("default" = none)
    "layout" => "default",
    # the in-content page head: the hero band, breadcrumbs and badges toggles
    "pageHead" => %{"hero" => true, "crumbs" => true, "badges" => true, "subtitleFrom" => "description"},
    # table of contents from the document headings: off | inline | right-rail
    "toc" => %{"show" => false, "placement" => "off"},
    # region toggles: the sidebar, the footer, and the header search box position (center | off)
    "regions" => %{"sidebar" => true, "footer" => true, "search" => "center"},
    # optional web fonts: {href, body, heading, mono} — a <link> + --base-font-family* overrides
    "fonts" => nil,
    # optional navbar brand slot: {logo, label} — a logo image (theme asset URL) + a label,
    # replacing the plain "keen-docs" wordmark. The doc_set title still renders as the suffix.
    "brand" => nil,
    # optional version control widget: nil → the native <select>. A map
    # {type:"web-multiselect", module, style, label} renders the version switcher as a live
    # <web-multiselect> (dogfooding), loading the component module/style and showing `label` as the
    # package pill. `module`/`style` should match the doc set's component version to dedupe with demos.
    "versionControl" => nil,
    # navbar composition — chooses what appears in the fixed 3-slot navbar (start/end are
    # flex-shrink:0, so too many items crush the centred search):
    #   nav        the hub top-nav          "hub" | "off"
    #   links      per-doc_set header_links "show" | "off"
    #   resolve    the "Resolve package.json →" utility link   true | false
    #   modeToggle the dark-mode button     true | false
    #   profile    the profile button       true | false
    #   cta        an optional primary button pinned at the end: {label, url, icon, style}
    #              (style → a kd-btn--<style> variant; default "primary")
    "header" => %{
      "nav" => "hub",
      "links" => "show",
      "resolve" => true,
      "modeToggle" => true,
      "profile" => true,
      "cta" => nil
    }
  }

  @doc "The baseline render contract defaults (a doc_set with no `keendocs` block)."
  def render_defaults, do: @render_defaults

  @doc "Decoded `keendocs.json` (manifest), or an empty map when absent/unreadable."
  def manifest do
    case File.read(Path.join(File.cwd!(), @manifest)) do
      {:ok, json} -> Jason.decode!(json)
      _ -> %{}
    end
  end

  @doc """
  The merged render contract for a named theme: the baseline defaults overlaid with the manifest's
  per-theme `keendocs` block (`keendocs.json` → `themes.<id>.keendocs`). `nil` → the defaults verbatim.
  Nested keys deep-merge, so a block that sets only `{"toc": {"placement": "right-rail"}}` keeps every
  other default. Always a fully-populated map.
  """
  def render_block(nil), do: @render_defaults

  def render_block(id) when is_binary(id) do
    manifest_block = get_in(manifest(), ["themes", id, "keendocs"]) || %{}
    deep_merge(@render_defaults, manifest_block)
  end

  # Recursive map merge: nested maps merge key-by-key (so partial overrides keep sibling defaults);
  # any non-map value (or a map replacing a nil like `fonts`) is taken from the override.
  defp deep_merge(a, b) when is_map(a) and is_map(b),
    do: Map.merge(a, b, fn _k, av, bv -> deep_merge(av, bv) end)

  defp deep_merge(_a, b), do: b
end
