defmodule KeenDocs.Markdown.ExtensionTest do
  use ExUnit.Case, async: true

  alias KeenDocs.Markdown.{Context, DirectiveParser, Output, Renderer}

  defmodule Stub do
    @moduledoc "A third-party extension, standing in for anything installed server-side."

    use KeenDocs.Markdown.Extension

    alias KeenDocs.Markdown.Context

    @impl true
    def directives, do: ["stub"]

    @impl true
    def fences, do: ["stub"]

    @impl true
    def render({:directive, "stub", _attrs, children}, ctx) do
      {inner, ctx} = Renderer.render_nodes(children, ctx)
      {["<div class=\"stub\">", inner, "</div>"], with_asset(ctx)}
    end

    def render({:fence, _lang, _flags, code}, ctx) do
      {"<pre class=\"stub\">#{code}</pre>", with_asset(ctx)}
    end

    @impl true
    def document(meta, _tree, ctx),
      do: Context.put_head(ctx, ~s(<meta name="stub-title" content="#{meta["title"]}" />))

    defp with_asset(ctx),
      do: Context.put_asset(ctx, "stub-runtime", :footer, "<script>stub()</script>")
  end

  defp render(source, opts), do: source |> DirectiveParser.parse() |> Renderer.render(opts)

  describe "registration" do
    test "an extension can claim a directive" do
      out = render(":::stub\nHELLO\n:::\n", extensions: [Stub])

      assert Output.body_html(out) =~ ~s(<div class="stub">)
      assert Output.body_html(out) =~ "HELLO"
    end

    test "an extension can claim a fence language" do
      out = render("```stub\nCODE\n```\n", extensions: [Stub])

      assert Output.body_html(out) =~ ~s(<pre class="stub">CODE</pre>)
    end

    test "a fence flag wins over the language" do
      ctx = Context.new(extensions: [Stub, KeenDocs.Extensions.Demo])

      assert Context.fence_handler(ctx, ["stub"], "js") == Stub
      assert Context.fence_handler(ctx, ["run"], "js") == KeenDocs.Extensions.Demo
      assert Context.fence_handler(ctx, [], "js") == nil
    end

    test "passing :extensions replaces the built-ins, so unclaimed directives fall back" do
      out = render(":::card\nKEEP\n:::\n", extensions: [Stub])

      assert Output.body_html(out) =~ "KEEP"
      assert Output.body_html(out) =~ "kd-directive-card"
      refute Output.body_html(out) =~ "kd-card-body"
    end
  end

  describe "page regions" do
    test "a document hook contributes to the head without rendering a block" do
      out = render("text\n", extensions: [Stub], meta: %{"title" => "T"})

      assert Output.head_html(out) =~ ~s(<meta name="stub-title" content="T" />)
    end

    test "assets deduplicate by key across repeated use" do
      out = render("```stub\na\n```\n```stub\nb\n```\n```stub\nc\n```\n", extensions: [Stub])

      assert length(out.assets) == 1
      assert out.footer |> IO.iodata_to_binary() |> String.split("stub()") |> length() == 2
    end

    test "assets lead their region so runtimes precede the scripts that use them" do
      out = render("```stub\na\n```\n", extensions: [Stub])
      footer = Output.footer_html(out)

      assert footer =~ "stub()"
      assert out.assets == [%{key: "stub-runtime", region: :footer, html: "<script>stub()</script>"}]
    end
  end

  describe "mermaid" do
    test "renders a diagram and registers its runtime once per page" do
      out =
        render("```mermaid\ngraph TD\n```\n```mermaid\ngraph LR\n```\n",
          extensions: [KeenDocs.Extensions.Mermaid]
        )

      assert Output.body_html(out) =~ ~s(<pre class="mermaid">graph TD</pre>)
      assert Output.body_html(out) =~ ~s(<pre class="mermaid">graph LR</pre>)

      runtime_loads = Output.footer_html(out) |> String.split("mermaid.esm.min.mjs") |> length()
      assert runtime_loads == 2, "expected the mermaid runtime exactly once"
    end

    test "loads nothing when the page has no diagram" do
      out = render("just text\n", extensions: [KeenDocs.Extensions.Mermaid])

      assert Output.footer_html(out) == ""
      assert out.assets == []
    end
  end

  describe "open graph" do
    test "builds tags from front matter and skips absent values" do
      out =
        render("text\n",
          extensions: [KeenDocs.Extensions.OpenGraph],
          meta: %{"title" => "Form Integration", "description" => "Live demos"}
        )

      head = Output.head_html(out)

      assert head =~ ~s(<meta property="og:title" content="Form Integration" />)
      assert head =~ ~s(<meta property="og:description" content="Live demos" />)
      assert head =~ ~s(<meta property="twitter:card" content="summary" />)
      refute head =~ "og:image"
    end

    test "escapes metadata" do
      out =
        render("text\n",
          extensions: [KeenDocs.Extensions.OpenGraph],
          meta: %{"title" => ~s("quoted" & <tagged>)}
        )

      assert Output.head_html(out) =~ "&quot;quoted&quot; &amp; &lt;tagged&gt;"
    end
  end

  describe "cdn package" do
    @meta %{
      "uses" => "@keenmate/web-multiselect",
      "version" => "2.0.0",
      "cdn" => %{"script" => "dist/multiselect.js", "style" => "dist/style.css"}
    }

    test "pins the package to the declared version" do
      out = render("text\n", extensions: [KeenDocs.Extensions.CdnPackage], meta: @meta)
      head = Output.head_html(out)

      assert head =~ "https://cdn.jsdelivr.net/npm/@keenmate/web-multiselect@2.0.0/dist/multiselect.js"
      assert head =~ "https://cdn.jsdelivr.net/npm/@keenmate/web-multiselect@2.0.0/dist/style.css"
    end

    test "emits only what front matter declares" do
      meta = %{"uses" => "@keenmate/web-multiselect", "cdn" => %{"script" => "dist/m.js"}}
      out = render("text\n", extensions: [KeenDocs.Extensions.CdnPackage], meta: meta)

      assert Output.head_html(out) =~ ~s(<script type="module")
      refute Output.head_html(out) =~ "stylesheet"
    end

    test "does nothing when the page documents no package" do
      out = render("text\n", extensions: [KeenDocs.Extensions.CdnPackage], meta: %{})

      assert Output.head_html(out) == ""
    end
  end

  describe "demo and run pairing" do
    @extensions [KeenDocs.Extensions.Demo]

    test "a run block contributes to the footer, not the body" do
      out = render("```html demo\n<b>x</b>\n```\n```js run\nout(1)\n```\n", extensions: @extensions)

      assert Output.footer_html(out) =~ "out(1)"
      assert Output.footer_html(out) =~ ~s|getElementById("kd-demo-1")|
      refute Output.body_html(out) =~ "out(1)"
    end

    # Regression for the process-dictionary leak: pairing used to live in Process.put/2,
    # so a run block with no demo of its own silently bound to a demo id from whatever
    # document had been rendered earlier in the same process.
    test "a run block with no preceding demo does not bind to an earlier document" do
      _first = render("```html demo\n<b>x</b>\n```\n", extensions: @extensions)
      second = render("```js run\nout(1)\n```\n", extensions: @extensions)

      assert Output.footer_html(second) == ""
      assert Output.body_html(second) =~ "kd-demo-orphan"
      refute Output.body_html(second) =~ "kd-demo-1"
    end

    test "each demo binds its own run block" do
      out =
        render(
          "```html demo\n<b>x</b>\n```\n```js run\nfirst()\n```\n" <>
            "```html demo\n<b>y</b>\n```\n```js run\nsecond()\n```\n",
          extensions: @extensions
        )

      footer = Output.footer_html(out)

      assert footer =~ ~s|getElementById("kd-demo-1")|
      assert footer =~ ~s|getElementById("kd-demo-2")|
      assert [_, after_first] = String.split(footer, "first()")
      assert after_first =~ ~s|getElementById("kd-demo-2")|
    end

    test "an example fence is highlighted but not executed" do
      out = render("```js example\nlet a = 1\n```\n", extensions: @extensions)

      assert Output.body_html(out) =~ ~s(<div class="kd-code">)
      assert Output.footer_html(out) == ""
    end
  end
end
