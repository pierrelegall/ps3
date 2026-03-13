defmodule PS3.MixProject do
  use Mix.Project

  def project do
    [
      app: :ps3,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: ["lib"],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      config_path: "config/config.exs"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {PS3.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, "~> 1.10", only: :test},
      {:benchee, "~> 1.5", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: :dev, runtime: false},
      {:plug, "~> 1.19"},
      {:req, "~> 0.5"},
      {:sweet_xml, "~> 0.7"}
    ]
  end
end
