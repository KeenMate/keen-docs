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
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      # The markdown-superset engine, extracted so a portal app can render content too.
      # Brings mdex/lumis/yaml_elixir transitively; keen-docs adds only its own extensions.
      {:keen_markdown, path: "../keen-markdown"},
      # Used directly for island props / runtime JSON (KeenDocs.Extensions.App).
      {:jason, "~> 1.4"}
    ]
  end
end
