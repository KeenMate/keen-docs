defmodule KeenDocs.Extensions.CdnPackageTest do
  use ExUnit.Case, async: true

  alias KeenMarkdown.{DirectiveParser, Output, Renderer}

  @extensions [KeenDocs.Extensions.CdnPackage]

  defp render(source, opts),
    do: source |> DirectiveParser.parse() |> Renderer.render(Keyword.put_new(opts, :extensions, @extensions))

  @meta %{
    "uses" => "@keenmate/web-multiselect",
    "version" => "2.0.0",
    "cdn" => %{"script" => "dist/multiselect.js", "style" => "dist/style.css"}
  }

  test "pins the package to the declared version" do
    out = render("text\n", meta: @meta)
    head = Output.head_html(out)

    assert head =~ "https://cdn.jsdelivr.net/npm/@keenmate/web-multiselect@2.0.0/dist/multiselect.js"
    assert head =~ "https://cdn.jsdelivr.net/npm/@keenmate/web-multiselect@2.0.0/dist/style.css"
  end

  test "emits only what front matter declares" do
    meta = %{"uses" => "@keenmate/web-multiselect", "cdn" => %{"script" => "dist/m.js"}}
    out = render("text\n", meta: meta)

    assert Output.head_html(out) =~ ~s(<script type="module")
    refute Output.head_html(out) =~ "stylesheet"
  end

  test "does nothing when the page documents no package" do
    out = render("text\n", meta: %{})

    assert Output.head_html(out) == ""
  end
end
