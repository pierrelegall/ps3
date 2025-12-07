defmodule S3x.MixProject do
  use Mix.Project

  def project do
    [
      app: :s3x,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {S3x.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, "~> 1.8", only: :test},
      {:benchee, "~> 1.5", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_aws, "~> 2.5", only: :test},
      {:ex_aws_s3, "~> 2.5", only: :test},
      {:plug, "~> 1.15"},
      {:req, "~> 0.5", only: :test},
      {:sweet_xml, "~> 0.7", only: :test}
    ]
  end
end
