defmodule KeenDocs.Markdown.DirectiveParser do
  @moduledoc """
  Parses the keen-docs markdown superset into a nested block tree.

  Grammar (line-oriented, code-fence-aware):

    * `:::name{attrs}` opens a container directive; a lone `:::` closes it.
      Directives nest (e.g. `columns` > `col` > `card`).
    * ```` ```lang flags ```` opens a fenced code block; content up to the closing
      fence is captured verbatim (so `:::` *inside* code is NOT treated as a directive).
    * Everything else accumulates into `{:markdown, text}` runs.

  Node shapes returned by `parse/1`:

    * `{:directive, name, attrs_map, children}`
    * `{:markdown, text}`
    * `{:fence, lang, flags_list, code}`
  """

  @type node_t ::
          {:directive, String.t(), map(), [node_t]}
          | {:markdown, String.t()}
          | {:fence, String.t(), [String.t()], String.t()}

  @open_re ~r/^:::+\s*([a-zA-Z][\w-]*)\s*(\{.*\})?\s*$/
  @close_re ~r/^:::+\s*$/
  @fence_re ~r/^\s*(`{3,}|~{3,})\s*(\S*)\s*(.*?)\s*$/

  @spec parse(String.t()) :: [node_t]
  def parse(body) when is_binary(body) do
    lines = String.split(body, ~r/\r?\n/)
    {nodes, _rest} = do_parse(lines, [], [])
    nodes
  end

  # do_parse(lines, acc_nodes_reversed, md_buf_reversed) -> {nodes, remaining_lines}
  # Returns when it consumes a closing `:::` line (nested) or runs out of lines (top level).
  defp do_parse([], acc, md), do: {finish(acc, md), []}

  defp do_parse([line | rest], acc, md) do
    cond do
      Regex.match?(@close_re, line) ->
        {finish(acc, md), rest}

      match = Regex.run(@fence_re, line) ->
        handle_fence(match, rest, acc, md)

      match = Regex.run(@open_re, line) ->
        handle_directive(match, rest, acc, md)

      true ->
        do_parse(rest, acc, [line | md])
    end
  end

  defp handle_fence([_, marker, lang, info], rest, acc, md) do
    {code_lines, after_fence} = take_until_fence(rest, marker, [])
    flags = info |> String.split(~r/\s+/, trim: true)
    fence = {:fence, lang, flags, Enum.join(code_lines, "\n")}
    acc = [fence | flush_md(md, acc)]
    do_parse(after_fence, acc, [])
  end

  defp handle_directive([_, name, attrs_str], rest, acc, md) do
    {children, after_children} = do_parse(rest, [], [])
    directive = {:directive, name, parse_attrs(attrs_str), children}
    acc = [directive | flush_md(md, acc)]
    do_parse(after_children, acc, [])
  end

  # A closing fence is a line whose only non-space content is the same fence char.
  defp take_until_fence([], _marker, code), do: {Enum.reverse(code), []}

  defp take_until_fence([line | rest], marker, code) do
    fence_char = String.first(marker)

    if Regex.match?(~r/^\s*#{Regex.escape(fence_char)}{3,}\s*$/, line) do
      {Enum.reverse(code), rest}
    else
      take_until_fence(rest, marker, [line | code])
    end
  end

  # ---- markdown buffer helpers ----

  defp finish(acc, md), do: Enum.reverse(flush_md(md, acc))

  defp flush_md([], acc), do: acc

  defp flush_md(md, acc) do
    text = md |> Enum.reverse() |> Enum.join("\n")

    if String.trim(text) == "" do
      acc
    else
      [{:markdown, text} | acc]
    end
  end

  # ---- {key=val key2="v2" bare} attribute parser ----

  @doc false
  def parse_attrs(nil), do: %{}

  def parse_attrs(str) do
    inner =
      str
      |> String.trim()
      |> String.trim_leading("{")
      |> String.trim_trailing("}")

    # 5 capture groups -> each scan match is [full, key, dquoted, squoted, bare, flag]
    ~r/([\w-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|(\S+))|([\w-]+)/
    |> Regex.scan(inner)
    |> Enum.reduce(%{}, fn match, m ->
      case pad(match) do
        [_, k, dq, sq, bare, ""] when k != "" -> Map.put(m, k, first_present([dq, sq, bare]))
        [_, "", "", "", "", flag] when flag != "" -> Map.put(m, flag, true)
        _ -> m
      end
    end)
  end

  # Regex.scan omits trailing unmatched groups; pad to a fixed 6-element shape.
  defp pad(match) do
    match ++ List.duplicate("", 6 - length(match))
  end

  defp first_present(vals), do: Enum.find(vals, "", &(&1 != ""))
end
