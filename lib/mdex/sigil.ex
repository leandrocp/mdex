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

    * `AST` - converts Markdown to AST, equivalent to calling `MDEx.parse_document!/2`
    * `MD` - converts AST to Markdown, equivalent to calling `MDEx.to_commonmark!/2`

  Without a modifier it converts the input (either Markdown or AST) to HTML, equivalent to calling `MDEx.to_html!/2`.

  Note that you should `import MDEx.Sigil` to use the `~M` or `~m` sigils.

  ## Options

  In order to support the most common scenarios, the sigils have the following options enabled by default:

      #{inspect(@opts)}

  If you need a different set of options, you can call the regular functions like `MDEx.to_html/2` to pass the options you need.

  """

  @doc """
  The `~M` sigil converts between CommonMark, HTML, and AST without interpolation.

  ## Examples

      # markdown to html
      iex> ~M|# Hello|
      "<h1>Hello</h1>"

      # markdown to ast
      iex> ~M|# Hello|AST
      [{"document", [], [{"heading", [{"level", 1}], ["Hello"]}]}]

      # ast to markdown
      iex> ~M|[{"document", [], [{"heading", [{"level", 1}], ["Hello"]}]}]|MD
      "# Hello"

      # ast to html
      iex> ~M|[{"document", [], [{"heading", [{"level", 1}], ["Hello"]}]}]|
      "<h1>Hello</h1>"

  """
  defmacro sigil_M({:<<>>, _meta, [expr]}, modifiers) do
    doc =
      cond do
        modifiers == ~c"AST" ->
          MDEx.parse_document!(expr, @opts)

        modifiers == ~c"MD" ->
          MDEx.Sigil.to_commonmark!(expr)

        # HTML
        :default ->
          MDEx.Sigil.to_html!(expr)
      end

    Macro.escape(doc)
  end

  @doc """
  The `~m` sigil converts between CommonMark, HTML, and AST with interpolation.

  ## Examples

      iex> lang = "elixir"

      # markdown to html
      iex> ~m|`lang = \#{lang}`|
      "<p><code>lang = elixir</code></p>"

      # markdown to ast
      iex> ~m|`lang = \#{lang}`|AST
      [{"document", [], [{"paragraph", [], [{"code", [{"num_backticks", 1}, {"literal", "lang = elixir"}], []}]}]}]

      # ast to markdown
      iex> ~m[{"document", [], [{"paragraph", [], [{"code", [{"num_backticks", 1}, {"literal", "lang = \#{lang}|"}], []}]}]}]|MD
      "`lang = elixir`"

      # ast to html
      iex> ~m[{"document", [], [{"paragraph", [], [{"code", [{"num_backticks", 1}, {"literal", "lang = \#{lang}|"}], []}]}]}]|
      "<p><code>lang = elixir</code></p>"

  """
  defmacro sigil_m({:<<>>, _, [binary]}, modifiers) when is_binary(binary) do
    cond do
      modifiers == ~c"AST" ->
        binary
        |> Macro.unescape_string()
        |> MDEx.parse_document!(@opts)
        |> Macro.escape()

      modifiers == ~c"MD" ->
        binary = Macro.unescape_string(binary)

        quote do
          MDEx.Sigil.to_commonmark!(unquote(binary))
        end

      # HTML
      :default ->
        binary
        |> Macro.unescape_string()
        |> MDEx.Sigil.to_html!()
        |> Macro.escape()
    end
  end

  defmacro sigil_m({:<<>>, meta, pieces}, modifiers) do
    binary = {:<<>>, meta, unescape_tokens(pieces)}

    cond do
      modifiers == ~c"AST" ->
        quote do
          MDEx.parse_document!(unquote(binary), unquote(@opts))
        end

      modifiers == ~c"MD" ->
        quote do
          MDEx.Sigil.to_commonmark!(unquote(binary))
        end

      # HTML
      :default ->
        quote do
          MDEx.Sigil.to_html!(unquote(binary))
        end
    end
  end

  @doc false
  def to_html!(expr) do
    with {:ok, [{:{}, _, _}] = quoted} <- Code.string_to_quoted(expr),
         {ast, _} <- Code.eval_quoted(quoted) do
      MDEx.to_html!(ast, @opts)
    else
      _ -> MDEx.to_html!(expr, @opts)
    end
    |> String.trim()
  end

  @doc false
  def to_commonmark!(expr) do
    # convert to quoted first before evaluating
    # so we can check if `expr` is a list of tuples instead of a function call for example
    case Code.string_to_quoted(expr) do
      {:ok, [{:{}, _, _}] = quoted} ->
        {ast, _} = Code.eval_quoted(quoted)

        ast
        |> MDEx.to_commonmark!(@opts)
        |> String.trim()

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
