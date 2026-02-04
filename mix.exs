defmodule PS3.MixProject do
  use Mix.Project

  def project do
    [
      app: :ps3,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {PS3.Application, []}
    ]
  end

  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, "~> 1.10", only: :test},
      {:benchee, "~> 1.5", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_aws, "~> 2.6", only: :test},
      {:ex_aws_s3, "~> 2.5", only: :test},
      {:plug, "~> 1.19"},
      {:req, "~> 0.5", only: :test},
      {:sweet_xml, "~> 0.7", only: :test}
    ]
  end
end
