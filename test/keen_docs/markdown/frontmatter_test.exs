defmodule KeenDocs.Markdown.FrontmatterTest do
  use ExUnit.Case, async: true

  alias KeenDocs.Markdown.Frontmatter

  describe "split/1" do
    test "parses a leading YAML block and returns the remaining body" do
      {meta, body} = Frontmatter.split("---\ntitle: Hello\norder: 5\n---\n# Body\n")

      assert meta == %{"title" => "Hello", "order" => 5}
      assert body == "# Body\n"
    end

    test "parses nested and quoted values" do
      {meta, _body} =
        Frontmatter.split("---\nuses: \"@keenmate/web-multiselect\"\nnav:\n  section: Features\n---\nx")

      assert meta["uses"] == "@keenmate/web-multiselect"
      assert meta["nav"] == %{"section" => "Features"}
    end

    test "returns the document unchanged when there is no front matter" do
      assert Frontmatter.split("# Just markdown\n") == {%{}, "# Just markdown\n"}
    end

    test "handles CRLF line endings" do
      {meta, body} = Frontmatter.split("---\r\ntitle: Hello\r\n---\r\nbody\r\n")

      assert meta == %{"title" => "Hello"}
      assert body == "body\r\n"
    end

    test "falls back to an empty map when the YAML is malformed" do
      {meta, _body} = Frontmatter.split("---\n: : not valid\n---\nbody")

      assert meta == %{}
    end

    test "ignores a `---` that is not at the very start" do
      raw = "intro\n---\ntitle: Hello\n---\n"

      assert {%{}, ^raw} = Frontmatter.split(raw)
    end
  end
end
