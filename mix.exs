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
      description:
        "A fast 100% CommonMark-compatible GitHub Flavored Markdown parser and formatter."
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
      {:rustler, ">= 0.0.0", optional: true},
      {:rustler_precompiled, "~> 0.6"},
      {:ex_doc, "~> 0.29", only: :dev}
    ]
  end

  defp aliases do
    [
      "rust.lint": ["cmd cargo clippy --manifest-path=native/comrak_nif/Cargo.toml -- -Dwarnings"],
      "rust.fmt": ["cmd cargo fmt --manifest-path=native/comrak_nif/Cargo.toml --all"]
    ]
  end
end
