defmodule KeenDocs.Markdown.HTML do
  @moduledoc """
  Small HTML helpers shared by the renderer, the extensions and the page shell.

  Exists so escaping is defined once — `KeenDocs.POC` and the extensions need the
  same `esc/1` the renderer uses for directive attributes.
  """

  @doc "Escape a value for interpolation into HTML text or a double-quoted attribute."
  @spec esc(term()) :: String.t()
  def esc(nil), do: ""

  def esc(value) when is_binary(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  def esc(value), do: value |> to_string() |> esc()
end
