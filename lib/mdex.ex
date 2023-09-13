defmodule MDEx do
  @moduledoc """
  A fast 100% CommonMark-compatible GitHub Flavored Markdown parser and formatter.

  Use Rust's [comrak crate](https://crates.io/crates/comrak) under the hood.
  """

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

  Accepts all available [Comrak Options](https://docs.rs/comrak/latest/comrak/struct.ComrakOptions.html) as keyword lists.

  * `:extension` - https://docs.rs/comrak/latest/comrak/struct.ComrakExtensionOptions.html
  * `:parse` - https://docs.rs/comrak/latest/comrak/struct.ComrakParseOptions.html
  * `:render` - https://docs.rs/comrak/latest/comrak/struct.ComrakRenderOptions.html
  * `:features` - see the available options below

  ### Features Options

  * `:sanitize` (default `false`) - sanitize output using [ammonia](https://crates.io/crates/ammonia).\n Recommended if passing `render: [unsafe_: true]`
  * `:syntax_highlight_theme` (default `Dracula`) - syntax highlight code fences using [syntect](https://crates.io/crates/syntect).
  See a list of available themes at [syntect-assets#supported-themes](https://github.com/ttys3/syntect-assets#supported-themes)

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

    opts = %MDEx.Options{
      extension: struct(MDEx.ExtensionOptions, extension),
      parse: struct(MDEx.ParseOptions, parse),
      render: struct(MDEx.RenderOptions, render),
      features: struct(MDEx.FeaturesOptions, features)
    }

    Native.to_html_with_options(markdown, opts)
  end
end
