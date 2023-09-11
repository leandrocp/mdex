defmodule MDEx.MixProject do
  use Mix.Project

  @source_url "https://github.com/leandrocp/mdex"
  @version "0.1.0"

  def project do
    [
      app: :mdex,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      package: package(),
      docs: docs(),
      deps: deps(),
      aliases: aliases(),
      name: "MDEx",
      homepage_url: "https://github.com/leandrocp/mdex",
      description: "Markdown"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      maintainers: ["Leandro Pereira"],
      licenses: ["MIT"],
      links: %{
        Changelog: "https://hexdocs.pm/mdex/changelog.html",
        GitHub: @source_url
      },
      files: [
        "mix.exs",
        "lib",
        "priv",
        "native",
        "README.md",
        "LICENSE.md",
        "CHANGELOG.md",
        "checksum-*.exs"
      ]
    ]
  end

  defp docs do
    [
      main: "MDEx",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["CHANGELOG.md"]
    ]
  end

  defp deps do
    [
      {:rustler_precompiled, "~> 0.6"},
      {:rustler, ">= 0.0.0", optional: true},
      {:ex_doc, "~> 0.29", only: :dev}
    ]
  end

  defp aliases do
    [
      test: [fn _ -> System.put_env("MDEX_BUILD", "true") end, "test"]
    ]
  end
end
