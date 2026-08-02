defmodule KeenDocs.Markdown.DirectiveParserTest do
  use ExUnit.Case, async: true

  alias KeenDocs.Markdown.DirectiveParser

  describe "directives without attributes" do
    # Regression: `Regex.run/2` drops trailing groups that did not participate, so the
    # optional `{attrs}` group made an attribute-less directive match as 2 elements and
    # crash `handle_directive/4`. Every directive in the sample document happened to
    # carry attributes, so this never surfaced through the POC build.
    test "parse without crashing and carry an empty attribute map" do
      for name <- ~w(columns col card callout showcase) do
        assert [{:directive, ^name, %{}, [{:markdown, "x"}]}] =
                 DirectiveParser.parse(":::#{name}\nx\n:::\n")
      end
    end

    test "nest inside one another" do
      assert [{:directive, "columns", %{}, [{:directive, "col", %{}, [{:markdown, "x"}]}]}] =
               DirectiveParser.parse(":::columns\n:::col\nx\n:::\n:::\n")
    end

    test "mix with attributed siblings" do
      assert [{:directive, "columns", %{}, children}] =
               DirectiveParser.parse(":::columns\n:::col{title=A}\nx\n:::\n:::col\ny\n:::\n:::\n")

      assert [{:directive, "col", %{"title" => "A"}, _}, {:directive, "col", %{}, _}] = children
    end
  end

  describe "attribute parsing" do
    test "reads bare, double-quoted, single-quoted values and valueless flags" do
      assert [{:directive, "x", attrs, _}] =
               DirectiveParser.parse(~s(:::x{a=1 b="two words" c='three' tabs}\ny\n:::\n))

      assert attrs == %{"a" => "1", "b" => "two words", "c" => "three", "tabs" => true}
    end

    test "keeps hyphenated keys and slash-separated values" do
      assert [{:directive, "columns", %{"cols" => "80/20", "data-set" => "languages"}, _}] =
               DirectiveParser.parse(~s(:::columns{cols="80/20" data-set=languages}\nx\n:::\n))
    end
  end

  describe "fences" do
    test "capture language and flags" do
      assert [{:fence, "js", ["run"], "let a = 1"}] = DirectiveParser.parse("```js run\nlet a = 1\n```\n")
    end

    test "capture a language with no flags" do
      assert [{:fence, "mermaid", [], "graph TD"}] = DirectiveParser.parse("```mermaid\ngraph TD\n```\n")
    end

    # Regression: the closing test matched any run of >= 3 of the same character, so an
    # inner ``` terminated an outer ```` and truncated the sample.
    test "a longer fence is not closed by a shorter one inside it" do
      source = """
      ````md example
      before

      ```html demo
      <web-multiselect />
      ```

      after
      ````
      """

      assert [{:fence, "md", ["example"], code}] = DirectiveParser.parse(source)
      assert code =~ "```html demo"
      assert code =~ "<web-multiselect />"
      assert code =~ "after"
    end

    test "a directive marker inside a fence is code, not a directive" do
      assert [{:fence, "md", [], code}] = DirectiveParser.parse("```md\n:::columns\n:::\n```\n")

      assert code == ":::columns\n:::"
    end

    test "tilde fences work and are not closed by backticks" do
      assert [{:fence, "md", [], code}] = DirectiveParser.parse("~~~md\n```js\nx\n```\n~~~\n")

      assert code =~ "```js"
    end
  end

  describe "structure" do
    # A run terminated by a delimiter stops at it; a run terminated by end of input keeps
    # the document's trailing newline. Harmless inside a markdown text node.
    test "markdown runs accumulate between blocks" do
      assert [{:markdown, "intro"}, {:directive, "card", _, _}, {:markdown, "outro\n"}] =
               DirectiveParser.parse("intro\n:::card\nx\n:::\noutro\n")
    end

    test "blank-only markdown runs are dropped" do
      assert [{:directive, "card", _, _}] = DirectiveParser.parse("\n\n:::card\nx\n:::\n\n")
    end

    test "an unclosed directive at end of input keeps its children" do
      assert [{:directive, "card", %{}, [{:markdown, "x\n"}]}] = DirectiveParser.parse(":::card\nx\n")
    end

    test "an unclosed fence at end of input keeps its code" do
      assert [{:fence, "js", [], "let a = 1\n"}] = DirectiveParser.parse("```js\nlet a = 1\n")
    end
  end
end
