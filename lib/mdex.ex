defmodule MDEx do
  @external_resource "README.md"

  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC -->")
             |> Enum.fetch!(1)

  alias MDEx.Native

  @typedoc """
  The AST (Abstract Syntax Tree) representation of a Markdown document.

  It's composed by a list of nodes starting with the `document` root node.

  ## Example

      [
        {"document", [], [
          {"heading", [{"level", 1}], ["Elixir"]}
        ]}
      ]

  See `t:md_node/0` for more info.

  """
  @type md_ast :: [md_node()]

  @typedoc """
  Each node of the AST document.

  Represented either as a tuple or a string.
  """
  @type md_node :: md_element() | md_text()

  @typedoc """
  Elements are composed by a name, a list of attributes and a list of children.

  ## Example

      {"heading", [{"level", 1}, {"setext", false}], children}
  """
  @type md_element :: {name :: String.t(), attributes :: [md_attribute()], children :: [md_node()]}

  @typedoc """
  Attributes of node elements are key-value pairs where key is always a string and value can be of multiple different types.

  ## Examples

      {"level", 1}
      {"delimiter", "period"}
  """
  @type md_attribute :: {String.t(), term()}

  @typedoc """
  Text element. It has no attributes or children so it's represented just as a string.
  """
  @type md_text :: String.t()

  @doc """
  Parse a `markdown` binary and returns the AST.

  ## Options

  See the [Options](#module-options) section for the available options.

  ## Example

      iex> MDEx.parse_document!("# Languages\\n Elixir and Rust")
      [
        {"document", [], [
          {"heading", [{"level", 1}, {"setext", false}], ["Languages"]},
          {"paragraph", [], ["Elixir and Rust"]}
        ]}
      ]

      iex> MDEx.parse_document!("Darth Vader is ||Luke's father||", extension: [spoiler: true])
      [
        {"document", [], [
          {"paragraph", [], [
            "Darth Vader is ",
            {"spoilered_text", [], ["Luke's father"]}
        ]}]}
      ]

  """
  @spec parse_document(String.t(), keyword()) :: {:ok, md_ast()} | {:error, term()}
  def parse_document(markdown, opts \\ []) do
    Native.parse_document(markdown, comrak_options(opts))
  end

  @doc """
  Same as `parse_document/2` but raises if the parsing fails.
  """
  @spec parse_document!(String.t(), keyword()) :: md_ast()
  def parse_document!(markdown, opts \\ []) do
    case Native.parse_document(markdown, comrak_options(opts)) do
      {:ok, ast} -> ast
      {:error, error} -> raise error
    end
  end

  @doc """
  Convert either markdown or an AST to HTML using default options.

  To customize the output, use `to_html/2`.

  ## Examples

      iex> MDEx.to_html("# MDEx")
      {:ok, "<h1>MDEx</h1>\\n"}

      iex> MDEx.to_html("Implemented with:\\n1. Elixir\\n2. Rust")
      {:ok, "<p>Implemented with:</p>\\n<ol>\\n<li>Elixir</li>\\n<li>Rust</li>\\n</ol>\\n"}

  """
  @spec to_html(md_or_ast :: String.t() | md_ast()) :: {:ok, String.t()} | {:error, MDEx.DecodeError.t()}
  def to_html(md_or_ast)

  def to_html(md_or_ast) when is_binary(md_or_ast) do
    Native.markdown_to_html(md_or_ast)
  end

  def to_html(md_or_ast) when is_list(md_or_ast) do
    md_or_ast
    |> maybe_wrap_document()
    |> Native.ast_to_html()
  end

  @doc """
  Same as `to_html/1` but raises `MDEx.DecodeError` if the conversion fails.
  """
  @spec to_html!(md_or_ast :: String.t() | md_ast()) :: String.t()
  def to_html!(md_or_ast) do
    case to_html(md_or_ast) do
      {:ok, html} -> html
      {:error, error} -> raise error
    end
  end

  @doc """
  Convert `markdown` to HTML with custom `opts`.

  ## Options

  See the [Options](#module-options) section for the available options.

  ## Examples

      iex> MDEx.to_html("Hello ~world~ there", extension: [strikethrough: true])
      {:ok, "<p>Hello <del>world</del> there</p>\\n"}

      iex> MDEx.to_html("<marquee>visit https://https://beaconcms.org</marquee>", extension: [autolink: true], render: [unsafe_: true])
      {:ok, "<p><marquee>visit <a href=\\"https://https://beaconcms.org\\">https://https://beaconcms.org</a></marquee></p>\\n"}

      iex> MDEx.to_html("# Title with <script>console.log('dangerous script')</script>", render: [unsafe_: true], features: [sanitize: true])
      {:ok, "<h1>Title with </h1>\\n"}

  """
  @spec to_html(md_or_ast :: String.t() | md_ast(), keyword()) :: String.t()
  def to_html(md_or_ast, opts)

  def to_html(md_or_ast, opts) when is_binary(md_or_ast) and is_list(opts) do
    md_or_ast
    |> Native.markdown_to_html_with_options(comrak_options(opts))
    |> maybe_wrap_error()
  end

  def to_html(md_or_ast, opts) when is_list(md_or_ast) and is_list(opts) do
    md_or_ast
    |> maybe_wrap_document()
    |> Native.ast_to_html_with_options(comrak_options(opts))
    |> maybe_wrap_error()
  end

  @doc """
  Same as `to_html/2` but raises `MDEx.DecodeError` if the conversion fails.
  """
  @spec to_html!(md_or_ast :: String.t() | md_ast(), keyword()) :: String.t()
  def to_html!(md_or_ast, opts) do
    case to_html(md_or_ast, opts) do
      {:ok, html} -> html
      {:error, error} -> raise error
    end
  end

  @doc """
  Convert an AST to CommonMark using default options.

  To customize the output, use `to_commonmark/2`.

  ## Examples

      iex> MDEx.parse_document!("# MDEx") |> MDEx.to_commonmark()
      {:ok, "# MDEx\\n"}
  """
  @spec to_commonmark(ast :: md_ast()) :: {:ok, String.t()} | {:error, MDEx.DecodeError.t()}
  def to_commonmark(ast) do
    ast
    |> Native.ast_to_commonmark()
    |> maybe_wrap_error()
  end

  @doc """
  Same as `to_commonmark/1` but raises `MDEx.DecodeError` if the conversion fails.
  """
  @spec to_commonmark!(ast :: md_ast()) :: String.t()
  def to_commonmark!(ast) do
    case to_commonmark(ast) do
      {:ok, md} -> md
      {:error, error} -> raise error
    end
  end

  @doc """
  Convert an AST to CommonMark with custom options.

  ## Options

  See the [Options](#module-options) section for the available options.

  ## Examples

      iex> MDEx.parse_document!("# MDEx", []) |> MDEx.to_commonmark()
      {:ok, "# MDEx\\n"}

  """
  @spec to_commonmark(ast :: md_ast(), keyword()) :: {:ok, String.t()} | {:error, MDEx.DecodeError.t()}
  def to_commonmark(ast, opts) when is_list(opts) do
    ast
    |> maybe_wrap_document()
    |> Native.ast_to_commonmark_with_options(comrak_options(opts))
    |> maybe_wrap_error()
  end

  @doc """
  Same as `to_commonmark/2` but raises `MDEx.DecodeError` if the conversion fails.
  """
  @spec to_commonmark!(ast :: md_ast(), keyword()) :: String.t()
  def to_commonmark!(ast, opts) do
    case to_commonmark(ast, opts) do
      {:ok, md} -> md
      {:error, error} -> raise error
    end
  end

  defp comrak_options(opts) do
    extension = Keyword.get(opts, :extension, %{})
    parse = Keyword.get(opts, :parse, %{})
    render = Keyword.get(opts, :render, %{})
    features = Keyword.get(opts, :features, %{})

    %MDEx.Types.Options{
      extension: struct(MDEx.Types.ExtensionOptions, extension),
      parse: struct(MDEx.Types.ParseOptions, parse),
      render: struct(MDEx.Types.RenderOptions, render),
      features: struct(MDEx.Types.FeaturesOptions, features)
    }
  end

  # TODO: check if comrak is able to format ast without wrapping it in a document
  defp maybe_wrap_document([{"document", _, _} | _] = tree), do: tree

  defp maybe_wrap_document([fragment]) when is_tuple(fragment) do
    [{"document", [], [fragment]}]
  end

  defp maybe_wrap_document(fragment) when is_list(fragment) do
    Enum.all?(fragment, &is_binary/1) ||
      raise """
      expected a list of nodes as [{"paragraph", [], ["text"]}] or ["text"]

      Got:

        #{inspect(fragment)}

      """

    [{"document", [], [{"paragraph", [], fragment}]}]
  end

  defp maybe_wrap_error({:ok, result}), do: {:ok, result}

  defp maybe_wrap_error({:error, {reason, found}}),
    do: {:error, %MDEx.DecodeError{reason: reason, found: found}}

  defp maybe_wrap_error({:error, {reason, found, node}}),
    do: {:error, %MDEx.DecodeError{reason: reason, found: found, node: node}}

  defp maybe_wrap_error({:error, {reason, found, node, kind}}),
    do: {:error, %MDEx.DecodeError{reason: reason, found: found, node: node, kind: kind}}

  defp maybe_wrap_error({:error, {reason, found, node, attr, kind}}),
    do: {:error, %MDEx.DecodeError{reason: reason, found: found, node: node, attr: attr, kind: kind}}

  @doc """
  Traverses and updates a Markdown AST.

  ## Examples

      iex> ast = [{"document", [], [{"heading", [{"level", 1}, {"setext", false}], ["Hello"]}]}]
      iex> MDEx.traverse_and_update(ast, fn
      ...>   {"heading", _attrs, children} -> {"heading", [{"level", 2}], children}
      ...>   other -> other
      ...> end)
      [{"document", [], [{"heading", [{"level", 2}], ["Hello"]}]}]

  See more on the [examples](https://github.com/leandrocp/mdex/tree/main/examples) directory.
  """
  @spec traverse_and_update(
          md_node() | md_ast(),
          (md_node() -> md_node() | [md_node()] | nil)
        ) :: md_node() | md_ast()
  defdelegate traverse_and_update(ast, fun), to: MDEx.Traversal

  # https://github.com/philss/floki/blob/28c9ed8d10d851b63ec87fb8ab9c5acd3c7ea90c/lib/floki.ex#L670
  @doc """
  Returns a list with attribute values for a given `attribute_name`.

  ## Example

      iex> MDEx.attribute({
      ...>   "code_block",
      ...>   [{"info", "mermaid"}, {"literal", "graph TD;\\n  A-->B;"}],
      ...>   []
      ...> }, "literal")
      ["graph TD;\\n  A-->B;"]

  """
  @spec attribute(md_ast() | md_node(), String.t()) :: list()
  def attribute(ast_or_node, attribute_name) do
    attribute_values(ast_or_node, attribute_name)
  end

  defp attribute_values(element, attr_name) when is_tuple(element) do
    attribute_values([element], attr_name)
  end

  defp attribute_values(elements, attr_name) do
    values =
      Enum.reduce(
        elements,
        [],
        fn
          {_, attributes, _}, acc ->
            case attribute_match?(attributes, attr_name) do
              {_attr_name, value} ->
                [value | acc]

              _ ->
                acc
            end

          _, acc ->
            acc
        end
      )

    Enum.reverse(values)
  end

  defp attribute_match?(attributes, attribute_name) do
    Enum.find(
      attributes,
      fn {attr_name, _} ->
        attr_name == attribute_name
      end
    )
  end
end
