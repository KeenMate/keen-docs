defmodule KeenDocs.Repo do
  @moduledoc """
  The database connection — a thin wrapper over Postgrex, **not** Ecto.

  This mirrors keen-auth-permissions' repo pattern: the db-gen-generated
  `KeenDocs.Database` context does `use KeenDocs.Database, repo: KeenDocs.Repo` and
  `import repo, only: [query: 2]`, so all a "repo" must provide is `query/2` returning
  `{:ok, %Postgrex.Result{}} | {:error, %Postgrex.Error{}}`. Keeping the whole DB layer
  on stored functions + Postgrex (no Ecto schemas/queries) is a deliberate KeenMate
  convention — the SQL lives in the database (managed by debee), and db-gen generates
  the typed Elixir wrappers around it.

  Connection settings come from `config :keen_docs, KeenDocs.Repo, ...`. `start_link/1`
  starts a named connection (`__MODULE__`); it is not started in a supervision tree yet
  — start it where a live DB is actually needed (the eventual Phoenix app's supervisor,
  or a test helper), so plain `mix`/POC builds stay free of a DB dependency.
  """

  @doc "Child spec so the connection can be dropped straight into a supervision tree."
  def child_spec(opts) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}, type: :worker}
  end

  @doc "Start the named Postgrex connection from config (overridable via `opts`)."
  def start_link(opts \\ []) do
    config = Application.get_env(:keen_docs, __MODULE__, [])

    merged =
      Keyword.merge(
        [
          hostname: config[:hostname] || "localhost",
          port: config[:port] || 5432,
          username: config[:username] || "keen_docs",
          password: config[:password] || "keen_docs",
          database: config[:database] || "keen_docs",
          name: __MODULE__,
          types: KeenDocs.PostgrexTypes,
          after_connect: fn conn ->
            Postgrex.query!(
              conn,
              "SET search_path TO public, const, ext, stage, helpers, internal, unsecure, auth, triggers",
              []
            )
          end
        ],
        opts
      )

    Postgrex.start_link(merged)
  end

  @doc "Run a query. Returns `{:ok, %Postgrex.Result{}} | {:error, %Postgrex.Error{}}`."
  def query(sql, params \\ []), do: Postgrex.query(__MODULE__, sql, params)

  @doc "Run a query, raising on error."
  def query!(sql, params \\ []), do: Postgrex.query!(__MODULE__, sql, params)
end
