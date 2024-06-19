defmodule MDEx do
  @external_resource "README.md"

  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC -->")
             |> Enum.fetch!(1)

  alias MDEx.Native

  @doc """
  Convert `markdown` to HTML.

  ## Examples

      iex> MDEx.to_html("# MDEx")
      "<h1>MDEx</h1>\\n"

      iex> MDEx.to_html("Implemented with:\\n1. Elixir\\n2. Rust")
      "<p>Implemented with:</p>\\n<ol>\\n<li>Elixir</li>\\n<li>Rust</li>\\n</ol>\\n"

  """
  @spec to_html(String.t()) :: String.t()
  def to_html(markdown) when is_binary(markdown) do
    Native.to_html(markdown)
  end

  @doc """
  Convert `markdown` to HTML with custom `opts`.

  ## Options

  Accepts all available [Comrak Options](https://docs.rs/comrak/latest/comrak/struct.Options.html) as keyword lists and an extra `:features` option:

  * `:extension` - https://docs.rs/comrak/latest/comrak/struct.ExtensionOptions.html
  * `:parse` - https://docs.rs/comrak/latest/comrak/struct.ParseOptions.html
  * `:render` - https://docs.rs/comrak/latest/comrak/struct.RenderOptions.html
  * `:features` - see the available options below

  ### Features Options

  * `:sanitize` (default `false`) - sanitize output using [ammonia](https://crates.io/crates/ammonia).\n Recommended if passing `render: [unsafe_: true]`
  * `:syntax_highlight_theme` (default `"onedark"`) - syntax highlight code fences using [autumn themes](https://github.com/leandrocp/autumn/tree/main/priv/themes),
  you should pass the filename without special chars and without extension, for example you should pass `syntax_highlight_theme: "adwaita_dark"` to use the [Adwaita Dark](https://github.com/leandrocp/autumn/blob/main/priv/themes/adwaita-dark.toml) theme
  * `:syntax_highlight_inline_style` (default `true`) - embed styles in the output for each generated token. You'll need to [serve CSS themes](https://github.com/leandrocp/autumn?tab=readme-ov-file#linked) if inline styles are disabled to properly highlight code

  ## Examples

      iex> MDEx.to_html("# MDEx")
      "<h1>MDEx</h1>\\n"

      iex> MDEx.to_html("Implemented with:\\n1. Elixir\\n2. Rust")
      "<p>Implemented with:</p>\\n<ol>\\n<li>Elixir</li>\\n<li>Rust</li>\\n</ol>\\n"

      iex> MDEx.to_html("Hello ~world~ there", extension: [strikethrough: true])
      "<p>Hello <del>world</del> there</p>\\n"

      iex> MDEx.to_html("<marquee>visit https://https://beaconcms.org</marquee>", extension: [autolink: true], render: [unsafe_: true])
      "<p><marquee>visit <a href=\\"https://https://beaconcms.org\\">https://https://beaconcms.org</a></marquee></p>\\n"

      iex> MDEx.to_html("# Title with <script>console.log('dangerous script')</script>", render: [unsafe_: true], features: [sanitize: true])
      "<h1>Title with </h1>\\n"

  """
  @spec to_html(String.t(), keyword()) :: String.t()
  def to_html(markdown, opts) when is_binary(markdown) do
    extension = Keyword.get(opts, :extension, %{})
    parse = Keyword.get(opts, :parse, %{})
    render = Keyword.get(opts, :render, %{})
    features = Keyword.get(opts, :features, %{})

    opts = %MDEx.Types.Options{
      extension: struct(MDEx.Types.ExtensionOptions, extension),
      parse: struct(MDEx.Types.ParseOptions, parse),
      render: struct(MDEx.Types.RenderOptions, render),
      features: struct(MDEx.Types.FeaturesOptions, features)
    }

    Native.to_html_with_options(markdown, opts)
  end
end
