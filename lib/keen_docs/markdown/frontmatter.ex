defmodule KeenDocs.Markdown.Frontmatter do
  @moduledoc """
  Splits a leading YAML front-matter block (`---\\n ... \\n---`) from a markdown
  document and parses it into a plain map. Returns `{meta_map, body}`.

  If there is no front matter, `meta_map` is `%{}` and `body` is the input unchanged.
  """

  @doc "Split `{meta, body}` from a raw document string."
  @spec split(String.t()) :: {map(), String.t()}
  def split(raw) when is_binary(raw) do
    case Regex.run(~r/\A---\r?\n(.*?)\r?\n---\r?\n?(.*)\z/s, raw, capture: :all_but_first) do
      [yaml, body] ->
        {parse_yaml(yaml), body}

      _ ->
        {%{}, raw}
    end
  end

  defp parse_yaml(yaml) do
    case YamlElixir.read_from_string(yaml) do
      {:ok, map} when is_map(map) -> map
      _ -> %{}
    end
  end
end
