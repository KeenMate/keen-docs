defmodule KeenDocs.Markdown.RendererTest do
  use ExUnit.Case, async: true

  alias KeenDocs.Markdown.{DirectiveParser, Output, Renderer}

  defp render(source, opts \\ []), do: source |> DirectiveParser.parse() |> Renderer.render(opts)
  defp body(source, opts \\ []), do: source |> render(opts) |> Output.body_html()

  describe "columns" do
    test "turns a cols ratio into free-form grid tracks" do
      assert body(":::columns{cols=\"80/20\"}\n:::col\na\n:::\n:::col\nb\n:::\n:::\n") =~
               "grid-template-columns: 80fr 20fr"
    end

    test "defaults to equal tracks sized by the number of columns" do
      assert body(":::columns\n:::col\na\n:::\n:::col\nb\n:::\n:::\n") =~
               "grid-template-columns: repeat(2, 1fr)"
    end

    # Regression: stray prose used to render as an unlabelled grid cell, silently
    # shifting every column one track to the right.
    test "keeps non-column children and spans them across the row" do
      html = body(":::columns\nSTRAY\n:::col\na\n:::\n:::\n")

      assert html =~ "STRAY"
      assert html =~ "kd-span"
      # One real column, so the grid stays a single track.
      assert html =~ "grid-template-columns: repeat(1, 1fr)"
    end

    test "assigns no accent by default" do
      refute body(":::columns\n:::col{title=A}\na\n:::\n:::\n") =~ "kd-accent-"
    end
  end

  describe "showcase" do
    # Regression: showcase rendered only its :::col children, so anything else the
    # author wrote inside the block vanished from the page with no warning.
    test "keeps prose written directly inside the block" do
      html = body(":::showcase\nINSIDE_SHOWCASE\n:::col\na\n:::\n:::\n")

      assert html =~ "INSIDE_SHOWCASE"
    end

    test "assigns accents by column position" do
      html = body(":::showcase\n:::col{title=A}\na\n:::\n:::col{title=B}\nb\n:::\n:::col{title=C}\nc\n:::\n:::\n")

      assert html =~ "kd-accent-blue"
      assert html =~ "kd-accent-green"
      assert html =~ "kd-accent-cyan"
    end

    test "an explicit accent overrides the positional one" do
      html = body(":::showcase\n:::col{title=A accent=cyan}\na\n:::\n:::\n")

      assert html =~ "kd-accent-cyan"
      refute html =~ "kd-accent-blue"
    end

    test "renders title and subtitle chrome" do
      html = body(~s(:::showcase{title="T" subtitle="S"}\n:::col\na\n:::\n:::\n))

      assert html =~ ~s(<h3 class="kd-showcase-title">T</h3>)
      assert html =~ ~s(<p class="kd-showcase-sub">S</p>)
    end

    test "escapes chrome text" do
      assert body(~s(:::showcase{title="<script>"}\n:::col\na\n:::\n:::\n)) =~ "&lt;script&gt;"
    end
  end

  describe "markdown" do
    # Content is trusted (DESIGN.md §6), so prose may use inline HTML. This used to be
    # replaced with "<!-- raw HTML omitted -->".
    test "preserves inline HTML in prose" do
      assert body("Press <kbd>Esc</kbd> to close.\n") =~ "<kbd>Esc</kbd>"
    end

    test "renders GFM tables" do
      assert body("| a | b |\n| --- | --- |\n| 1 | 2 |\n") =~ "<table>"
    end

    test "gives headings ids and collects them into a table of contents" do
      out = render("# Top\n\n## Value formats\n")

      assert Output.body_html(out) =~ ~s(id="value-formats")
      assert [%{level: 1, id: "top", text: "Top"}, %{level: 2, id: "value-formats", text: "Value formats"}] = out.toc
    end
  end

  describe "code" do
    test "highlights a plain fence server-side with inline styles" do
      html = body("```js\nlet a = 1\n```\n")

      assert html =~ ~s(<div class="kd-code">)
      assert html =~ "style=\"color:"
      refute html =~ "highlight.js"
    end

    test "highlights an unlabelled fence without crashing" do
      assert body("```\nplain\n```\n") =~ "plain"
    end
  end

  describe "unknown directives" do
    test "keep their children rather than dropping the block" do
      html = body(":::totally-unknown\nKEEP_ME\n:::\n")

      assert html =~ "KEEP_ME"
      assert html =~ "kd-directive-totally-unknown"
    end
  end

  describe "determinism" do
    # Demo ids come from a per-document counter, not System.unique_integer/1: DESIGN.md
    # §4 relies on content hashing for upload dedup, which random ids would defeat.
    test "the same document renders to the same bytes every time" do
      source = "```html demo\n<b>x</b>\n```\n```js run\nout(1)\n```\n"

      first = render(source)
      second = render(source)

      assert Output.body_html(first) == Output.body_html(second)
      assert Output.footer_html(first) == Output.footer_html(second)
    end

    test "demo ids restart per document" do
      source = "```html demo\n<b>x</b>\n```\n"

      assert body(source) =~ ~s(id="kd-demo-1")
      assert body(source) =~ ~s(id="kd-demo-1")
    end

    test "ids increment within a document" do
      html = body("```html demo\n<b>x</b>\n```\n```html demo\n<b>y</b>\n```\n")

      assert html =~ ~s(id="kd-demo-1")
      assert html =~ ~s(id="kd-demo-2")
    end
  end
end
