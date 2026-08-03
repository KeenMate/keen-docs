defmodule KeenDocs.Content do
  @moduledoc """
  The content API — the db-gen-generated wrappers over the `public.*` stored functions,
  bound to `KeenDocs.Repo`. `use KeenDocs.Database` injects `list_doc_sets/0`,
  `list_doc_variants/1`, `get_default_variant/1`, `get_document/3`, `resolve_doc_variant/2`,
  `search_documents/4`, and the `ensure_*` publishers.

  Small conveniences on top: `rows/1` unwraps `{:ok, rows}`, and `one/1` takes the first.
  """
  use KeenDocs.Database, repo: KeenDocs.Repo

  @doc "Unwrap `{:ok, rows}` from a generated wrapper (raises on error)."
  def rows({:ok, rows}), do: rows
  def rows({:error, err}), do: raise(err)

  @doc "First row, or nil."
  def one(result), do: result |> rows() |> List.first()
end
