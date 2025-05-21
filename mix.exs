defmodule MDEx.MixProject do
  use Mix.Project

  @source_url "https://github.com/leandrocp/mdex"
  @version "0.6.2"
  @dev? String.ends_with?(@version, "-dev")
  @force_build? System.get_env("MDEX_BUILD") in ["1", "true"]

  def project do
    [
      app: :mdex,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      package: package(),
      docs: docs(),
      deps: deps(),
      aliases: aliases(),
      name: "MDEx",
      homepage_url: "https://github.com/leandrocp/mdex",
      description: "Fast and extensible Markdown for Elixir"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [
        docs: :docs,
        "hex.publish": :docs
      ]
    ]
  end

  defp package do
    [
      maintainers: ["Leandro Pereira"],
      licenses: ["MIT"],
      links: %{
        GitHub: @source_url,
        Changelog: "https://hexdocs.pm/mdex/changelog.html",
        Site: "https://mdelixir.dev",
        comrak: "https://crates.io/crates/comrak",
        ammonia: "https://crates.io/crates/ammonia",
        autumnus: "https://autumnus.dev"
      },
      files: ~w[
        lib/mdex.ex
        lib/mdex
        native/comrak_nif/src
        native/comrak_nif/.cargo
        native/comrak_nif/Cargo.*
        native/comrak_nif/Cross.toml
        examples
        mix.exs
        benchmark.exs
        README.md
        LICENSE.md
        CHANGELOG.md
        checksum-Elixir.MDEx.Native.exs
      ]
    ]
  end

  defp docs do
    [
      main: "MDEx",
      logo: "assets/images/mdex_icon.png",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["CHANGELOG.md", "playground.livemd", "comparison.livemd"],
      groups_for_modules: [
        "Document Nodes": [
          MDEx.Alert,
          MDEx.FrontMatter,
          MDEx.BlockQuote,
          MDEx.List,
          MDEx.ListItem,
          MDEx.DescriptionList,
          MDEx.DescriptionItem,
          MDEx.DescriptionTerm,
          MDEx.DescriptionDetails,
          MDEx.CodeBlock,
          MDEx.HtmlBlock,
          MDEx.Paragraph,
          MDEx.Heading,
          MDEx.ThematicBreak,
          MDEx.FootnoteDefinition,
          MDEx.FootnoteReference,
          MDEx.Table,
          MDEx.TableRow,
          MDEx.TableCell,
          MDEx.Text,
          MDEx.TaskItem,
          MDEx.SoftBreak,
          MDEx.LineBreak,
          MDEx.Code,
          MDEx.HtmlInline,
          MDEx.Raw,
          MDEx.Emph,
          MDEx.Strong,
          MDEx.Strikethrough,
          MDEx.Superscript,
          MDEx.Link,
          MDEx.Image,
          MDEx.ShortCode,
          MDEx.Math,
          MDEx.MultilineBlockQuote,
          MDEx.Escaped,
          MDEx.WikiLink,
          MDEx.Underline,
          MDEx.Subscript,
          MDEx.SpoileredText,
          MDEx.EscapedTag
        ]
      ],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp deps do
    [
      {:rustler, "~> 0.32", optional: not (@dev? or @force_build?)},
      {:rustler_precompiled, "~> 0.7"},
      {:nimble_options, "~> 1.0"},
      {:autumn, ">= 0.3.1"},
      {:jason, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :docs}
    ]
  end

  defp aliases do
    [
      "deps.vendorize": ["cmd cp -rv ../autumn/native/autumn native/comrak_nif/vendor"],
      "gen.checksum": "rustler_precompiled.download MDEx.Native --all --print",
      "gen.samples": "mdex.generate_samples",
      "format.all": ["format", "rust.fmt"],
      "rust.lint": ["cmd cargo clippy --manifest-path=native/comrak_nif/Cargo.toml -- -Dwarnings"],
      "rust.fmt": ["cmd cargo fmt --manifest-path=native/comrak_nif/Cargo.toml --all"]
    ]
  end
end
