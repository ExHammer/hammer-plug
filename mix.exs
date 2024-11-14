defmodule Hammer.Plug.MixProject do
  use Mix.Project

  @version "4.0.0-rc.0"

  def project do
    [
      app: :hammer_plug,
      description: "A plug to apply rate-limiting, using Hammer.",
      source_url: "https://github.com/ExHammer/hammer-plug",
      homepage_url: "https://github.com/ExHammer/hammer-plug",
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      test_coverage: [summary: [threshold: 75]]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def docs do
    [
      main: "overview",
      extras: ["guides/Overview.md", "CHANGELOG.md"],
      source_ref: "v#{@version}",
      source_url: "https://github.com/ExHammer/hammer-plug",
      main: "overview",
      formatters: ["html", "epub"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.6", only: [:dev, :test]},
      {:dialyxir, "~> 1.1", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.28", only: :dev},
      {:hammer, github: "ruslandoga/hammer", branch: "just-use"},
      {:plug, "~> 1.0"}
    ]
  end

  defp package do
    [
      name: :hammer_plug,
      maintainers: ["Emmanuel Pinault", "June Kelly"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/ExHammer/hammer-plug",
        "Changelog" => "https://github.com/ExHammer/hammer-plug/blob/master/CHANGELOG.md"
      }
    ]
  end
end
