defmodule KeenDocs.Extensions.AppTest do
  use ExUnit.Case, async: true

  alias KeenDocs.Markdown.{DirectiveParser, Output, Renderer}

  @extensions [KeenDocs.Extensions.App]

  defp render(source, opts \\ []) do
    source
    |> DirectiveParser.parse()
    |> Renderer.render(Keyword.put_new(opts, :extensions, @extensions))
  end

  defp body(source, opts \\ []), do: source |> render(opts) |> Output.body_html()

  # The runtime JSON is written with `escape: :html_safe` (as <.runtime> does), so `/`
  # arrives as `\/` — it lives inside a <script> tag and must not be able to close it.
  # Decode rather than string-matching the escaped form.
  defp json_script(out, id) do
    [_, json] = Regex.run(~r|id="#{id}">(.*?)</script>|s, Output.head_html(out))
    Jason.decode!(json)
  end

  defp manifest(out), do: json_script(out, "keen-apps")

  describe "the island wrapper" do
    test "matches the <.app> contract" do
      html = body(~s(:::app{name="org-browser"}\n:::\n))

      assert html =~ ~s(phx-hook="KeenApp")
      assert html =~ ~s(phx-update="ignore")
      assert html =~ ~s(data-app="org-browser")
      assert html =~ ~s(data-eager="false")
      assert html =~ ~s(id="kd-app-1")
    end

    test "honours an explicit id, class, tag and eager flag" do
      html = body(~s(:::app{name="like" id="like-42" class="w-full" tag=section eager}\n:::\n))

      assert html =~ ~s(<section id="like-42" class="w-full")
      assert html =~ ~s(data-eager="true")
      assert html =~ "</section>"
    end

    test "falls back to a div when the tag is not a plain element name" do
      assert body(~s(:::app{name="x" tag="<script>"}\n:::\n)) =~ "<div id="
    end

    test "ids are deterministic and increment per document" do
      html = body(~s(:::app{name="a"}\n:::\n:::app{name="b"}\n:::\n))

      assert html =~ ~s(id="kd-app-1")
      assert html =~ ~s(id="kd-app-2")
      assert body(~s(:::app{name="a"}\n:::\n)) =~ ~s(id="kd-app-1")
    end
  end

  describe "props" do
    test "come from a JSON fence in a :::props block" do
      html =
        body("""
        :::app{name="org-browser"}
        :::props
        ```json
        { "org_id": 42, "depth": 3 }
        ```
        :::
        :::
        """)

      assert html =~ ~s(data-props="{&quot;depth&quot;:3,&quot;org_id&quot;:42}")
    end

    test "default to an empty object" do
      assert body(~s(:::app{name="x"}\n:::\n)) =~ ~s(data-props="{}")
    end

    test "component= is folded in as a prop" do
      assert body(~s(:::app{name="x" component="tree"}\n:::\n)) =~ ~s(&quot;component&quot;:&quot;tree&quot;)
    end

    # Validated at build time so a broken island fails here, not in the browser.
    test "malformed JSON is reported instead of shipped" do
      html =
        body("""
        :::app{name="x"}
        :::props
        ```json
        { not json
        ```
        :::
        :::
        """)

      assert html =~ "kd-app-error"
      assert html =~ "valid JSON"
      refute html =~ "data-app"
    end

    test "a non-object JSON body is rejected" do
      html = body(~s(:::app{name="x"}\n:::props\n```json\n[1,2]\n```\n:::\n:::\n))

      assert html =~ "must contain a JSON object"
    end
  end

  describe "placeholder" do
    test "renders the :::placeholder block inside the wrapper" do
      html =
        body("""
        :::app{name="x"}
        :::placeholder
        Loading the org browser…
        :::
        :::
        """)

      assert html =~ "Loading the org browser"
      assert html =~ ~s(data-app="x")
    end

    test "is empty when no placeholder block is given" do
      assert body(~s(:::app{name="x"}\n:::\n)) =~ ~s(data-eager="false"></div>)
    end
  end

  describe "page runtime" do
    test "emits the context script, manifest and a preload per island" do
      out = render(~s(:::app{name="a"}\n:::\n:::app{name="b"}\n:::\n))

      assert Output.head_html(out) =~ ~s(<script type="application/json" id="keen-context">)
      assert manifest(out) == %{"a" => "/apps/a/main.mjs", "b" => "/apps/b/main.mjs"}
      assert Output.head_html(out) =~ ~s(<link rel="modulepreload" href="/apps/a/main.mjs" />)
    end

    test "emits nothing at all when the page mounts no island" do
      out = render("just prose\n")

      assert Output.head_html(out) == ""
      assert Output.footer_html(out) == ""
    end

    test "a repeated island appears once in the manifest" do
      out = render(~s(:::app{name="a"}\n:::\n:::app{name="a"}\n:::\n))

      assert Output.body_html(out) =~ ~s(id="kd-app-2")
      assert length(out.assets) == 3, "context + manifest + one preload"
    end

    test "src= overrides the resolved bundle url" do
      out = render(~s(:::app{name="a" src="https://cdn.example.com/a.mjs"}\n:::\n))

      assert manifest(out) == %{"a" => "https://cdn.example.com/a.mjs"}
      assert Output.head_html(out) =~ ~s(crossorigin="anonymous")
    end

    test "front matter can map an app to a bundle url" do
      out = render(~s(:::app{name="a"}\n:::\n), meta: %{"apps" => %{"a" => "/bundles/a.mjs"}})

      assert manifest(out) == %{"a" => "/bundles/a.mjs"}
      refute Output.head_html(out) =~ "crossorigin"
    end

    test "front matter app_context is merged into the page context" do
      out = render(~s(:::app{name="a"}\n:::\n), meta: %{"app_context" => %{"api_base" => "/api"}})

      assert json_script(out, "keen-context") == %{"api_base" => "/api"}
    end

    # <.app> tracks used apps in Process.put/2; the render context carries them here.
    test "islands do not leak into a later document's manifest" do
      _first = render(~s(:::app{name="first"}\n:::\n))
      second = render(~s(:::app{name="second"}\n:::\n))

      assert manifest(second) == %{"second" => "/apps/second/main.mjs"}
    end
  end

  describe "validation" do
    test "an app without a name is reported" do
      html = body(":::app\n:::\n")

      assert html =~ "kd-app-error"
      assert html =~ "needs a"
      refute html =~ "data-app"
    end
  end

  describe "sub-blocks outside an island" do
    test ":::props renders nothing on its own" do
      assert body(":::props\n```json\n{}\n```\n:::\n") == ""
    end

    test ":::placeholder renders its content on its own" do
      assert body(":::placeholder\nvisible\n:::\n") =~ "visible"
    end
  end
end
