defmodule MDEx.Sigil do
  @opts [
    extension: [
      strikethrough: true,
      table: true,
      autolink: true,
      tasklist: true,
      superscript: true,
      footnotes: true,
      description_lists: true,
      multiline_block_quotes: true,
      math_dollars: true,
      math_code: true,
      shortcodes: true,
      underline: true,
      spoiler: true
    ],
    parse: [
      smart: true,
      relaxed_tasklist_matching: true,
      relaxed_autolinks: true
    ],
    render: [
      _unsafe: true,
      escape: true
    ]
  ]

  @moduledoc """
  Sigils for parsing and formatting Markdown.

  ## Modifiers

    * `a` - converts Markdown to AST, equivalent to calling `MDEx.parse_document!/2`
    * `c` - converts AST to Markdown, equivalent to calling `MDEx.to_commonmark!/2`

  Without a modifier it converts Markdown to HTML, equivalent to calling `MDEx.to_html!/2`.

  Note that you should `import MDEx.Sigil` to use the `~M` or `~m` sigils.

  ## Options

  In order to support the most common scenarios, the sigils have the following options enabled by default:

      #{inspect(@opts)}

  If you need a different set of options, you can call the regular functions like `MDEx.to_html/2` to pass the options you need.

  """

  @doc """
  The `~M` sigil converts between CommonMark, HTML, and AST without interpolation or escaping.

  ## Examples

      # markdown to html
      iex> ~M|# Hello|
      "<h1>Hello</h1>"

      # markdown to AST
      iex> ~M|# Hello|AST
      [{"document", [], [{"heading", [{"level", 1}], ["Hello"]}]}]

      # AST to markdown
      iex> ~M|[{"document", [], [{"heading", [{"level", 1}], ["Hello"]}]}]|MD
      "# Hello"

  """
  defmacro sigil_M({:<<>>, _meta, [expr]}, modifiers) do
    doc =
      cond do
        ?a in modifiers ->
          MDEx.parse_document!(expr, @opts)

        ?c in modifiers ->
          MDEx.Sigil.to_commonmark!(expr) |> String.trim()

        :default ->
          MDEx.to_html!(expr, @opts) |> String.trim()
      end

    Macro.escape(doc)
  end

  @doc """
  The `~m` sigil converts between CommonMark, HTML, and AST with interpolation.

  ## Examples

      iex> ~M|# Hello|
      "<h1>Hello</h1>"

      iex> ~M|# Hello|a
      [{"document", [], [{"heading", [{"level", 1}], ["Hello"]}]}]

      iex> ~M|[{"document", [], [{"heading", [{"level", 1}], ["Hello"]}]}]|c
      "# Hello"

  """
  defmacro sigil_m({:<<>>, _, [binary]}, modifiers) when is_binary(binary) do
    if ?c in modifiers do
      binary = Macro.unescape_string(binary)

      quote do
        MDEx.Sigil.to_commonmark!(unquote(binary))
      end
    else
      binary
      |> Macro.unescape_string()
      |> convert(modifiers)
      |> Macro.escape()
    end
  end

  defmacro sigil_m({:<<>>, meta, pieces}, modifiers) do
    binary = {:<<>>, meta, unescape_tokens(pieces)}

    if ?c in modifiers do
      quote do
        MDEx.Sigil.to_commonmark!(unquote(binary))
      end
    else
      quote do
        MDEx.Sigil.convert(unquote(binary), unquote(modifiers))
      end
    end
  end

  @doc false
  def to_commonmark!(expr) do
    # convert to quoted first before evaluating
    # so we can check if `expr` is a list of tuples instead of a function call for example
    case Code.string_to_quoted(expr) do
      {:ok, [{:{}, _, _}] = quoted} ->
        {ast, _} = Code.eval_quoted(quoted)
        MDEx.to_commonmark!(ast, @opts)

      {:ok, quoted} ->
        other =
          quoted
          |> Code.quoted_to_algebra()
          |> Inspect.Algebra.format(90)
          |> IO.iodata_to_binary()

        raise """
        expected a CommonMark AST

        Got:

          #{other}

        """

      error ->
        error
    end
  end

  @doc false
  def convert(expr, modifiers) do
    cond do
      ?a in modifiers ->
        MDEx.parse_document!(expr, @opts)

      :default ->
        MDEx.to_html!(expr, @opts)
    end
  end

  defp unescape_tokens(tokens) do
    :lists.map(
      fn token ->
        case is_binary(token) do
          true -> :elixir_interpolation.unescape_string(token)
          false -> token
        end
      end,
      tokens
    )
  end
end
