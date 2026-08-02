defmodule KeenDocs.Extensions.CdnPackage do
  @moduledoc """
  Loads the component package a page documents from jsdelivr, pinned to a version.

  This is DESIGN.md §5's "demos are markup + a CDN web component pinned to the doc
  version" made data-driven: the page shell no longer hardcodes a package, the
  document declares one in front matter.

      uses: "@keenmate/web-multiselect"
      version: "2.0.0"
      cdn:
        script: "dist/multiselect.js"
        style: "dist/style.css"

  `script` and `style` are paths within the package; each is emitted only if present,
  so a package with no stylesheet simply declares none. Both are registered as keyed
  assets, which keeps them ahead of any demo `run` script in the footer ordering.
  """

  use KeenMarkdown.Extension

  alias KeenMarkdown.{Context, HTML}

  @cdn "https://cdn.jsdelivr.net/npm"

  @impl true
  def document(meta, _tree, ctx) do
    case package(meta) do
      nil -> ctx
      package -> load(package, cdn_paths(meta), ctx)
    end
  end

  defp load(package, paths, ctx) do
    base = "#{@cdn}/#{package}#{version_suffix(paths[:version])}"

    ctx
    |> asset(paths[:style], "cdn-style:#{package}", :head, &stylesheet(base, &1))
    |> asset(paths[:script], "cdn-script:#{package}", :head, &module_script(base, &1))
  end

  defp asset(ctx, nil, _key, _region, _build), do: ctx
  defp asset(ctx, "", _key, _region, _build), do: ctx

  defp asset(ctx, path, key, region, build),
    do: Context.put_asset(ctx, key, region, build.(path))

  defp stylesheet(base, path),
    do: ~s(<link rel="stylesheet" href="#{HTML.esc("#{base}/#{path}")}" />\n)

  defp module_script(base, path),
    do: ~s(<script type="module" src="#{HTML.esc("#{base}/#{path}")}"></script>\n)

  # `uses:` may name the package directly or carry it under a `package:` key.
  defp package(meta) do
    case meta["uses"] do
      name when is_binary(name) -> name
      %{"package" => name} when is_binary(name) -> name
      _ -> nil
    end
  end

  defp cdn_paths(meta) do
    cdn = if is_map(meta["cdn"]), do: meta["cdn"], else: %{}
    uses = if is_map(meta["uses"]), do: meta["uses"], else: %{}

    [
      version: meta["version"] || uses["version"] || cdn["version"],
      script: cdn["script"] || uses["script"],
      style: cdn["style"] || uses["style"]
    ]
  end

  defp version_suffix(nil), do: ""
  defp version_suffix(""), do: ""
  defp version_suffix(version), do: "@#{version}"
end
