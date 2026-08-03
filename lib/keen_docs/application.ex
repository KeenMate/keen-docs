defmodule KeenDocs.Application do
  @moduledoc """
  Boots the minimal web layer: the DB connection (`KeenDocs.Repo`) + the Bandit HTTP
  server serving `KeenDocs.Web.Router`. Start with `mix run --no-halt` (or `iex -S mix`).

  Port comes from `config :keen_docs, KeenDocs.Web, port: 4000`.
  """
  use Application

  @impl true
  def start(_type, _args) do
    port = get_in(Application.get_env(:keen_docs, KeenDocs.Web, []), [:port]) || 4000

    children = [
      KeenDocs.Repo,
      {Bandit, plug: KeenDocs.Web.Router, port: port}
    ]

    Logger.put_module_level(KeenDocs.Application, :info)
    IO.puts("keen-docs test harness → http://localhost:#{port}")

    Supervisor.start_link(children, strategy: :one_for_one, name: KeenDocs.Supervisor)
  end
end
