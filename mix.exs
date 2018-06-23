defmodule Hammer.Plug.MixProject do
  use Mix.Project

  def project do
    [
      app: :hammer_plug,
      description: "A plug to apply rate-limiting, using Hammer."
      package: [
        name: :hammer_plug,
        maintainers: ["Shane Kilkelly (shane@kilkelly.me)"],
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/ExHammer/hammer-plug"}
      ],
      source_url: "https://github.com/ExHammer/hammer-plug",
      homepage_url: "https://github.com/ExHammer/hammer-plug",
      version: "1.0.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [
        extras: ["README.md"],
        main: "readme",
        source_url: "https://github.com/elixir-plug/plug"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:plug]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:hammer, "~> 5.0"},
      {:plug, "~> 1.0"},
      {:ex_doc, "~> 0.16", only: :dev},
      {:mock, "~> 0.2.0", only: :test}
    ]
  end
end
