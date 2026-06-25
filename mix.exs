defmodule MDEx.MixProject do
  use Mix.Project

  @source_url "https://github.com/leandrocp/mdex"
  @version "0.13.3"

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
        lumis: "https://lumis.sh"
      },
      files: ~w[
        lib/mdex.ex
        lib/mdex
        examples
        guides
        mix.exs
        benchmark.exs
        README.md
        LICENSE.md
        CHANGELOG.md
        usage-rules.md
      ]
    ]
  end

  defp docs do
    [
      main: "MDEx",
      logo: "assets/images/mdex_icon.png",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        "CHANGELOG.md",
        "examples/gfm.livemd",
        "examples/syntax_highlight.livemd",
        "examples/lumis.livemd",
        "examples/syntect.livemd",
        "examples/light_dark_theme.livemd",
        "examples/custom_theme.livemd",
        "examples/code_block_decorators.livemd",
        "examples/mermaid.livemd",
        "examples/highlight_words.livemd",
        "examples/liquid.livemd",
        "examples/phoenix_live_view_heex.livemd",
        "examples/sigil_md.livemd",
        "examples/codefence_renderers.livemd",
        {"guides/streaming.md", title: "Streaming"},
        {"guides/plugins.md", title: "Plugins"},
        {"guides/heex.md", title: "HEEx Integration"},
        {"guides/compilation.md", title: "Compilation"},
        {"guides/earmark_to_mdex.livemd", title: "Earmark to MDEx Migration"},
        {"guides/safety.md", title: "Safety"},
        {"guides/code_block_decorators.md", title: "Code Block Decorators"}
      ],
      groups_for_modules: [
        "Document Nodes": [
          MDEx.Alert,
          MDEx.BlockQuote,
          MDEx.Code,
          MDEx.CodeBlock,
          MDEx.DescriptionDetails,
          MDEx.DescriptionItem,
          MDEx.DescriptionList,
          MDEx.DescriptionTerm,
          MDEx.Emph,
          MDEx.Escaped,
          MDEx.EscapedTag,
          MDEx.FootnoteDefinition,
          MDEx.FootnoteReference,
          MDEx.FrontMatter,
          MDEx.Heading,
          MDEx.Highlight,
          MDEx.HtmlBlock,
          MDEx.HtmlInline,
          MDEx.Image,
          MDEx.LineBreak,
          MDEx.Link,
          MDEx.List,
          MDEx.ListItem,
          MDEx.Math,
          MDEx.MultilineBlockQuote,
          MDEx.Paragraph,
          MDEx.Raw,
          MDEx.ShortCode,
          MDEx.SoftBreak,
          MDEx.SpoileredText,
          MDEx.Strikethrough,
          MDEx.Strong,
          MDEx.Subscript,
          MDEx.Subtext,
          MDEx.Superscript,
          MDEx.Table,
          MDEx.TableCell,
          MDEx.TableRow,
          MDEx.TaskItem,
          MDEx.Text,
          MDEx.ThematicBreak,
          MDEx.Underline,
          MDEx.WikiLink,
          MDEx.HeexBlock,
          MDEx.HeexInline
        ]
      ],
      groups_for_extras: [
        Examples: [
          "examples/gfm.livemd",
          "examples/syntax_highlight.livemd",
          "examples/lumis.livemd",
          "examples/syntect.livemd",
          "examples/light_dark_theme.livemd",
          "examples/custom_theme.livemd",
          "examples/code_block_decorators.livemd",
          "examples/mermaid.livemd",
          "examples/highlight_words.livemd",
          "examples/liquid.livemd",
          "examples/phoenix_live_view_heex.livemd",
          "examples/sigil_md.livemd",
          "examples/codefence_renderers.livemd"
        ],
        Guides: [
          "guides/streaming.md",
          "guides/plugins.md",
          "guides/heex.md",
          "guides/compilation.md",
          "guides/earmark_to_mdex.livemd",
          "guides/safety.md",
          "guides/code_block_decorators.md"
        ]
      ],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp deps do
    [
      mdex_native_dep(),
      {:nimble_options, "~> 1.0"},
      {:nimble_parsec, "~> 1.0"},
      {:jason, "~> 1.0"},
      {:lumis, "~> 0.1", optional: true},
      {:phoenix_live_view, "~> 1.2.0", optional: true},
      {:ex_doc, ">= 0.0.0", only: :docs},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp mdex_native_dep do
    if path = System.get_env("MDEX_NATIVE_PATH") do
      {:mdex_native, path: path}
    else
      {:mdex_native, ">= 0.2.4"}
    end
  end

  defp aliases do
    [
      setup: ["deps.get", "compile"],
      "gen.samples": "mdex.generate_samples"
    ]
  end
end
