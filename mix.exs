defmodule KeenDocs.MixProject do
  use Mix.Project

  def project do
    [
      app: :keen_docs,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger], mod: {KeenDocs.Application, []}]
  end

  defp deps do
    [
      # The markdown-superset engine, extracted so a portal app can render content too.
      # Brings mdex/lumis/yaml_elixir transitively; keen-docs adds only its own extensions.
      {:keen_markdown, path: "../keen-markdown"},
      # Used directly for island props / runtime JSON (KeenDocs.Extensions.App).
      {:jason, "~> 1.4"},
      # Raw Postgrex is the DB layer — no Ecto. The db-gen-generated KeenDocs.Database
      # context imports a `query/2` and its parsers match %Postgrex.Result{}. Mirrors
      # keen-auth-permissions (postgrex-only). See lib/keen_docs/repo.ex.
      {:postgrex, "~> 0.19"},
      # Minimal web layer for the test harness — Plug router on Bandit. This is the same
      # substrate Phoenix runs on, so it promotes to full Phoenix later without rework.
      {:plug, "~> 1.16"},
      {:bandit, "~> 1.0"}
    ]
  end
end
