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
  def to_html(markdown) do
    Native.to_html(markdown)
  end

  @doc """
  Convert `markdown` to HTML with custom `opts`.

  ## Options

  Accepts all available [Comrak Options](https://docs.rs/comrak/latest/comrak/struct.ComrakOptions.html) as keyword lists.

  * `:extension` - https://docs.rs/comrak/latest/comrak/struct.ComrakExtensionOptions.html
  * `:parse` - https://docs.rs/comrak/latest/comrak/struct.ComrakParseOptions.html
  * `:render` - https://docs.rs/comrak/latest/comrak/struct.ComrakRenderOptions.html

  ## Examples

      iex> MDEx.to_html("# MDEx")
      "<h1>MDEx</h1>\\n"

      iex> MDEx.to_html("Implemented with:\\n1. Elixir\\n2. Rust")
      "<p>Implemented with:</p>\\n<ol>\\n<li>Elixir</li>\\n<li>Rust</li>\\n</ol>\\n"

      iex> MDEx.to_html("Hello ~world~ there", extension: [strikethrough: true])
      "<p>Hello <del>world</del> there</p>\\n"

      iex> MDEx.to_html("<marquee>visit https://https://beaconcms.org</marquee>", extension: [autolink: true], render: [unsafe_: true])
      "<p><marquee>visit <a href=\\"https://https://beaconcms.org\\">https://https://beaconcms.org</a></marquee></p>\\n"

  """
  def to_html(markdown, opts) do
    extension = Keyword.get(opts, :extension, %{})
    parse = Keyword.get(opts, :parse, %{})
    render = Keyword.get(opts, :render, %{})

    options = %MDEx.Options{
      extension: struct(MDEx.ExtensionOptions, extension),
      parse: struct(MDEx.ParseOptions, parse),
      render: struct(MDEx.RenderOptions, render)
    }

    Native.to_html_with_options(markdown, options)
  end
end
