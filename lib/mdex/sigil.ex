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
      _unsafe: true
    ]
  ]

  @moduledoc """
  Sigils for parsing and formatting Markdown between different formats.

  ## Modifiers

    * `HTML` - converts Markdown or `MDEx.Document` to HTML, equivalent to calling `MDEx.to_html!/2`
    * `XML` - converts Markdown or `MDEx.Document` to XML, equivalent to calling `MDEx.to_xml!/2`
    * `MD` - converts `MDEx.Document` to Markdown, equivalent to calling `MDEx.to_commonmark!/2`

  Without a modifier it converts Markdown to `MDEx.Document` (the default output of `~m` and `~M`), equivalent to calling `MDEx.parse_document!/2`.

  Note that you should `import MDEx.Sigil` to use the `~m` or `~M` sigil.

  ## Options

  In order to support the most common scenarios, all sigils use the following options by default:

  ```elixir
  #{inspect(@opts, pretty: true)}
  ```

  If you need a different set of options, you can call the regular functions in `MDEx` to pass the options you need.

  """

  @doc """
  The `~M` sigil converts to `MDEx.Document`, CommonMark, HTML, or XML without interpolation.

  ## Examples

  ### Markdown to `MDEx.Document`

  ```elixir
  iex> ~M[`lang = :elixir`]
  %MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "lang = :elixir"}]}]}
  ```

  ### Markdown to HTML

  ```elixir
  iex> ~M[`lang = :elixir`]HTML
  "<p><code>lang = :elixir</code></p>\\n"
  ```

  ### Markdown to XML

  ```elixir
  iex> ~M[`lang = :elixir`]XML
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE document SYSTEM \"CommonMark.dtd\">\n<document xmlns=\"http://commonmark.org/xml/1.0\">\n  <paragraph>\n    <code xml:space=\"preserve\">lang = :elixir</code>\n  </paragraph>\n</document>\n"
  ```

  ### `MDEx.Document` to Markdown

  ```elixir
  iex> ~M|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "lang = :elixir"}]}]}|MD
  "`lang = :elixir`"
  ```

  Other modifiers also convert from a document to the desired format.

  """
  defmacro sigil_M({:<<>>, _meta, [expr]}, modifiers) do
    expr = Macro.unescape_string(expr)
    doc = to_doc(expr, __CALLER__)

    doc =
      cond do
        modifiers == ~c"AST" ->
          IO.warn("""
          modifier AST is deprecated

          This sigil now returns a %MDEx.Document{} by default,
          so you can remove the AST suffix.
          """)

          MDEx.parse_document!(doc, @opts)

        modifiers == ~c"HTML" ->
          MDEx.to_html!(doc, @opts)

        modifiers == ~c"XML" ->
          MDEx.to_xml!(doc, @opts)

        modifiers == ~c"MD" ->
          MDEx.to_commonmark!(doc, @opts)

        :default ->
          MDEx.parse_document!(doc, @opts)
      end

    Macro.escape(doc)
  end

  @doc """
  The `~m` sigil converts to `MDEx.Document`, CommonMark, HTML, or XML with interpolation.

  ## Examples

  ### Markdown to `MDEx.Document`

      iex> lang = :elixir
      iex> ~m[`lang = \#{inspect(lang)}`]
      %MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "lang = :elixir"}]}]}

  ### `MDEx.Document` to Markdown

      iex> lang = :elixir
      iex> ~m|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "lang = \#{inspect(lang)}"}]}]}|
      "`lang = :elixir`"

  Other modifiers also accept interpolation.

  """
  defmacro sigil_m({:<<>>, _, [binary]}, modifiers) when is_binary(binary) do
    binary = Macro.unescape_string(binary)
    doc = to_doc(binary, __CALLER__)

    doc =
      cond do
        modifiers == ~c"AST" ->
          IO.warn("""
          modifier AST is deprecated

          This sigil now returns a %MDEx.Document{} by default,
          so you can remove the AST suffix.
          """)

          MDEx.parse_document!(doc, @opts)

        modifiers == ~c"HTML" ->
          MDEx.to_html!(doc, @opts)

        modifiers == ~c"XML" ->
          MDEx.to_xml!(doc, @opts)

        modifiers == ~c"MD" ->
          MDEx.to_commonmark!(doc, @opts)

        :default ->
          MDEx.parse_document!(doc, @opts)
      end

    Macro.escape(doc)
  end

  defmacro sigil_m({:<<>>, meta, pieces}, modifiers) do
    binary = {:<<>>, meta, unescape_tokens(pieces)}

    cond do
      modifiers == ~c"AST" ->
        IO.warn("""
        modifier AST is deprecated

        This sigil now returns a %MDEx.Document{} by default,
        so you can remove the AST suffix.
        """)

        quote do
          MDEx.parse_document!(unquote(binary), unquote(@opts))
        end

      modifiers == ~c"HTML" ->
        quote do
          MDEx.to_html!(to_doc(unquote(binary), __ENV__), unquote(@opts))
        end

      modifiers == ~c"XML" ->
        quote do
          MDEx.to_xml!(to_doc(unquote(binary), __ENV__), unquote(@opts))
        end

      modifiers == ~c"MD" ->
        quote do
          MDEx.to_commonmark!(to_doc(unquote(binary), __ENV__), unquote(@opts))
        end

      :default ->
        quote do
          MDEx.parse_document!(unquote(binary), unquote(@opts))
        end
    end
  end

  @doc false
  def to_doc(binary, env) do
    with {:ok, {:%, _, _} = quoted} <- Code.string_to_quoted(binary),
         quoted = expand_alias(quoted, env),
         {doc, _} <- Code.eval_quoted(quoted) do
      doc
    else
      _ -> binary
    end
  end

  defp expand_alias(ast, caller) do
    Macro.prewalk(ast, fn
      {:__aliases__, _, _} = module -> Macro.expand(module, caller)
      other -> other
    end)
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
