defmodule KeenDocs.Themes do
  @moduledoc """
  The installed **theme** bundles — keen-docs' copy of pure-admin's themes mechanism.

  A keen-docs theme is a self-contained pure-admin theme bundle (`theme.json` + `dist/<id>.css`
  + bundled `assets/`, carrying its own 10px base, chrome, grid, palette and light/dark modes)
  copied from the `../pure-admin-themes` source into `themesDir`. The set of installed themes is
  declared in `keendocs.json` (mirrors `pureadmin.json`); `seed_from/1` is the manual stand-in for
  the future `keendocs themes install` (Phase 4), writing a `keendocs.lock.json` of resolved versions.

  `KeenDocs.Web.View` links the active theme's `dist/<id>.css` instead of the core baseline; this
  module answers "which themes exist, where, and what does the manifest say" so resolution stays
  data-driven. Reads happen at request time from disk (no global mutable state) — cheap and
  deterministic. See `docs/themes.md`.
  """

  @manifest "keendocs.json"
  @lock "keendocs.lock.json"

  # The declarative render contract (v1.0). These defaults reproduce keen-docs' baseline assembly
  # exactly, so a theme WITHOUT a `keendocs` block (every upstream pure-admin theme) renders as it
  # does today. A theme opts into changes by overriding individual keys — the View interprets this
  # bounded vocabulary; themes never ship executable layout code (deterministic / no-RCE invariant).
  @render_defaults %{
    "contract" => "1.0",
    # named layout variant → a `kd-layout--<name>` hook class on `.pa-layout` ("default" = none)
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
    # navbar composition — bends pure-admin's fixed 3-slot header (start/end are flex-shrink:0, so
    # too many items crush the centred search) to the docs' item budget by choosing what appears:
    #   nav        the hub top-nav          "hub" | "off"
    #   links      per-doc_set header_links "show" | "off"
    #   resolve    the "Resolve package.json →" utility link   true | false
    #   modeToggle the dark-mode button     true | false
    #   profile    the profile button       true | false
    #   cta        an optional primary button pinned at the end: {label, url, icon, style}
    #              (style → a pa-btn--<style> variant; default "primary")
    "header" => %{
      "nav" => "hub",
      "links" => "show",
      "resolve" => true,
      "modeToggle" => true,
      "profile" => true,
      "cta" => nil
    }
  }

  @doc "The baseline render contract defaults (a theme with no `keendocs` block)."
  def render_defaults, do: @render_defaults

  @doc "Decoded `keendocs.json` (manifest), or an empty map when absent/unreadable."
  def manifest do
    case File.read(Path.join(File.cwd!(), @manifest)) do
      {:ok, json} -> Jason.decode!(json)
      _ -> %{}
    end
  end

  @doc "Absolute path to the theme install dir (`themesDir` in the manifest)."
  def dir do
    rel = manifest()["themesDir"] || "priv/web/vendor/themes"
    Path.join(File.cwd!(), rel)
  end

  @doc "The theme-source root used for seeding (`source` in the manifest)."
  def source, do: manifest()["source"] || "../pure-admin-themes"

  @doc "The declared theme ids (keys of the manifest `themes` object), sorted."
  def declared do
    case manifest()["themes"] do
      m when is_map(m) -> m |> Map.keys() |> Enum.sort()
      _ -> []
    end
  end

  @doc "The path an installed theme's stylesheet would live at (`themesDir/<id>/dist/<id>.css`)."
  def css_path(id), do: Path.join([dir(), id, "dist", "#{id}.css"])

  @doc "True when a valid id has its bundle stylesheet on disk (safe to link)."
  def installed?(id) when is_binary(id), do: valid_id?(id) and File.exists?(css_path(id))
  def installed?(_), do: false

  @doc """
  True when a theme is an **overlay** on the vendored core.css (its `theme.json` declares
  `"base": "core"`) — a keen-docs-authored theme (e.g. Aurora) that layers on the framework rather
  than replacing it. False for self-contained bundles copied from pure-admin (nato/dracula/…), which
  carry their own framework and REPLACE core.css. Drives how `View.styles/1` links the stylesheets.
  """
  def overlay?(id), do: match?(%{"base" => "core"}, read(id))

  @doc "True when a theme is hand-authored here (manifest `local`), so `seed_from/1` won't copy it."
  def local?(id), do: get_in(manifest(), ["themes", id, "local"]) == true

  @doc "Decoded `theme.json` for an installed theme, or nil."
  def read(id) do
    with true <- valid_id?(id),
         {:ok, json} <- File.read(Path.join([dir(), id, "theme.json"])),
         {:ok, map} <- Jason.decode(json) do
      map
    else
      _ -> nil
    end
  end

  @doc """
  The `pa-color-*` class for a theme's default colour variant, or "" when the theme is
  single-variant (its default variant `id` is "" — nato/dracula/corporate). Driven by the
  manifest's `variantCssClass` template (`pa-color-{variant}`) so it stays theme-defined.
  """
  def default_variant_class(id) do
    case read(id) do
      %{"colorVariants" => variants, "variantCssClass" => tmpl} when is_list(variants) ->
        variant_class(variants, tmpl)

      _ ->
        ""
    end
  end

  defp variant_class(variants, tmpl) do
    default = Enum.find(variants, & &1["default"]) || List.first(variants) || %{}

    case default["id"] do
      v when is_binary(v) and v != "" -> String.replace(tmpl || "pa-color-{variant}", "{variant}", v)
      _ -> ""
    end
  end

  # Install shape / traversal guard: a theme id is a lowercase slug (matches the on-disk dir and
  # the CSS filename), so it can never escape themesDir.
  defp valid_id?(id), do: is_binary(id) and id =~ ~r/^[a-z][a-z0-9-]*$/

  @doc """
  Seed the declared themes from a source root (default: the manifest `source`, `../pure-admin-themes`).
  Copies each theme's `theme.json` + `dist/<id>.css` + optional `assets/` into `themesDir/<id>/`, then
  writes `keendocs.lock.json` with the resolved version of each. The manual stand-in for
  `keendocs themes install`; run via `make seed-themes`.
  """
  def seed_from(src_root \\ source()) do
    # Hand-authored (local) themes live in the repo already — never copy over them.
    {local, ids} = Enum.split_with(declared(), &local?/1)
    if local != [], do: IO.puts("Skipping local (hand-authored) theme(s): #{Enum.join(local, ", ")}")

    dst_root = dir()
    File.mkdir_p!(dst_root)

    locked =
      Map.new(ids, fn id ->
        src = Path.join(src_root, id)
        dst = Path.join(dst_root, id)
        version = install_one(id, src, dst)
        {id, %{"version" => version, "source" => Path.join(src_root, id)}}
      end)

    lock = %{"themesDir" => manifest()["themesDir"], "themes" => locked}
    File.write!(Path.join(File.cwd!(), @lock), Jason.encode!(lock, pretty: true) <> "\n")

    IO.puts("Seeded #{length(ids)} theme(s) into #{dst_root}: #{Enum.join(ids, ", ")}")
    locked
  end

  @doc """
  The merged render contract for a theme: the baseline defaults overlaid with the manifest's
  per-theme block (`keendocs.json` → `themes.<id>.keendocs`, the consumer override for upstream
  themes that lack one) then the theme's own `theme.json` `keendocs` block (theme-authored, wins).
  `nil` (the core baseline) → the defaults verbatim. Nested keys deep-merge, so a block that sets
  only `{"pageHead": {"hero": false}}` keeps every other default. Always a fully-populated map.
  """
  def render_block(nil), do: @render_defaults

  def render_block(id) when is_binary(id) do
    manifest_block = get_in(manifest(), ["themes", id, "keendocs"]) || %{}
    theme_block = (read(id) || %{})["keendocs"] || %{}

    @render_defaults
    |> deep_merge(manifest_block)
    |> deep_merge(theme_block)
  end

  # Recursive map merge: nested maps merge key-by-key (so partial overrides keep sibling defaults);
  # any non-map value (or a map replacing a nil like `fonts`) is taken from the override.
  defp deep_merge(a, b) when is_map(a) and is_map(b),
    do: Map.merge(a, b, fn _k, av, bv -> deep_merge(av, bv) end)

  defp deep_merge(_a, b), do: b

  # Copy one theme bundle; return its declared version (from theme.json) for the lock.
  defp install_one(id, src, dst) do
    unless File.dir?(src), do: raise("theme source not found: #{src}")

    File.mkdir_p!(Path.join(dst, "dist"))
    File.cp!(Path.join(src, "theme.json"), Path.join(dst, "theme.json"))
    File.cp!(Path.join([src, "dist", "#{id}.css"]), Path.join([dst, "dist", "#{id}.css"]))

    assets = Path.join(src, "assets")
    if File.dir?(assets), do: File.cp_r!(assets, Path.join(dst, "assets"))

    case Jason.decode(File.read!(Path.join(dst, "theme.json"))) do
      {:ok, %{"version" => v}} -> v
      _ -> nil
    end
  end
end
