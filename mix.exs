defmodule MDEx.MixProject do
  use Mix.Project

  @source_url "https://github.com/leandrocp/mdex"
  @version "0.1.16-dev"
  @dev? String.ends_with?(@version, "-dev")
  @force_build? System.get_env("MDEX_BUILD") in ["1", "true"]

  def project do
    [
      app: :mdex,
      version: @version,
      elixir: "~> 1.14",
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
        GitHub: @source_url,
        comrak: "https://crates.io/crates/comrak"
      },
      files: ~w[
        lib/mdex.ex
        lib/mdex
        native/comrak_nif/src
        native/comrak_nif/vendor
        native/comrak_nif/.cargo
        native/comrak_nif/Cargo.*
        native/comrak_nif/Cross.toml
        checksum-Elixir.MDEx.Native.exs
        mix.exs
        README.md
        LICENSE.md
        CHANGELOG.md
      ]
    ]
  end

  defp docs do
    [
      main: "MDEx",
      assets: "assets/images",
      logo: "assets/images/mdex_icon.png",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["CHANGELOG.md"],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp deps do
    [
      {:rustler, "~> 0.32", optional: not (@dev? or @force_build?)},
      {:rustler_precompiled, "~> 0.7"},
      {:ex_doc, "~> 0.29", only: :dev}
    ]
  end

  defp aliases do
    [
      generate_checksum: "rustler_precompiled.download MDEx.Native --all --print",
      "format.all": ["format", "rust.fmt"],
      "rust.lint": ["cmd cargo clippy --manifest-path=native/comrak_nif/Cargo.toml -- -Dwarnings"],
      "rust.fmt": ["cmd cargo fmt --manifest-path=native/comrak_nif/Cargo.toml --all"],
      vendorize_deps: ["cmd cp -rv ../autumn/native/autumn native/comrak_nif/vendor"]
    ]
  end
end
