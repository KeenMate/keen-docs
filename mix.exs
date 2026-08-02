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
      {:mdex, "~> 0.2"},
      {:lumis, "~> 0.1"},
      {:yaml_elixir, "~> 2.9"}
    ]
  end
end
