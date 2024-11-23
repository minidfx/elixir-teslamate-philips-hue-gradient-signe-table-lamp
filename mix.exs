defmodule TeslamatePhilipsHueGradientSigneTableLamp.MixProject do
  use Mix.Project

  def project do
    [
      app: :teslamate_philips_hue_gradient_signe_table_lamp,
      version: "0.8.2",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: [
        teslamate_philips_hue_gradient_signe_table_lamp: [
          include_executables_for: [:unix]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {TeslamatePhilipsHueGradientSigneTableLamp.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:tesla, "~> 1.9"},
      {:tortoise311, "~> 0.12.0"},
      {:jason, "~> 1.4"},
      {:finch, "~> 0.18.0"},
      {:recode, "~> 0.7", only: :dev},
      {:mock, "~> 0.3.8", only: :test}
    ]
  end

  defp aliases do
    [
      test: "test --no-start",
      "auto-test": "cmd fswatch lib test | mix test --listen-on-stdin"
    ]
  end
end
