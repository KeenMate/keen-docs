defmodule KeenDocs.Extensions.DemoTest do
  use ExUnit.Case, async: true

  alias KeenMarkdown.Output

  @extensions [KeenDocs.Extensions.Demo]

  # render_body threads the extensions' raw_directives into the parser, so `:::demo`/`:::run`
  # bodies are captured verbatim.
  defp render(source, opts \\ []),
    do: KeenMarkdown.render_body(source, Keyword.put_new(opts, :extensions, @extensions))

  defp body(source, opts \\ []), do: source |> render(opts) |> Output.body_html()

  describe "demo and run pairing" do
    test "a run block contributes to the footer, not the body" do
      out = render(":::demo\n<b>x</b>\n:::\n:::run\nout(1)\n:::\n")

      assert Output.footer_html(out) =~ "out(1)"
      assert Output.footer_html(out) =~ ~s|getElementById("kd-demo-1")|
      refute Output.body_html(out) =~ "out(1)"
    end

    # Regression for the process-dictionary leak: pairing used to live in Process.put/2,
    # so a run block with no demo of its own silently bound to a demo id from whatever
    # document had been rendered earlier in the same process.
    test "a run block with no preceding demo does not bind to an earlier document" do
      _first = render(":::demo\n<b>x</b>\n:::\n")
      second = render(":::run\nout(1)\n:::\n")

      assert Output.footer_html(second) == ""
      assert Output.body_html(second) =~ "kd-demo-orphan"
      refute Output.body_html(second) =~ "kd-demo-1"
    end

    test "each demo binds its own run block" do
      out =
        render(
          ":::demo\n<b>x</b>\n:::\n:::run\nfirst()\n:::\n" <>
            ":::demo\n<b>y</b>\n:::\n:::run\nsecond()\n:::\n"
        )

      footer = Output.footer_html(out)

      assert footer =~ ~s|getElementById("kd-demo-1")|
      assert footer =~ ~s|getElementById("kd-demo-2")|
      assert [_, after_first] = String.split(footer, "first()")
      assert after_first =~ ~s|getElementById("kd-demo-2")|
    end
  end

  describe "determinism" do
    # Demo ids come from a per-document counter, not System.unique_integer/1: content-hash
    # dedup on upload relies on stable output, which random ids would defeat.
    test "the same document renders to the same bytes every time" do
      source = ":::demo\n<b>x</b>\n:::\n:::run\nout(1)\n:::\n"

      first = render(source)
      second = render(source)

      assert Output.body_html(first) == Output.body_html(second)
      assert Output.footer_html(first) == Output.footer_html(second)
    end

    test "ids restart per document and increment within one" do
      assert body(":::demo\n<b>x</b>\n:::\n") =~ ~s(id="kd-demo-1")

      html = body(":::demo\n<b>x</b>\n:::\n:::demo\n<b>y</b>\n:::\n")
      assert html =~ ~s(id="kd-demo-1")
      assert html =~ ~s(id="kd-demo-2")
    end
  end
end
