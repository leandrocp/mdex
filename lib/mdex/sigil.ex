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
      # need both multiline block quotes and alerts to enable github/gitlab multiline alerts
      multiline_block_quotes: true,
      alerts: true,
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
      unsafe_: true
    ]
  ]

  @moduledoc """
  Sigils for parsing and formatting Markdown between different formats.

  ## Modifiers

    * `HTML` - converts Markdown or `MDEx.Document` to HTML, equivalent to calling `MDEx.to_html!/2`
    * `JSON` - converts Markdown or `MDEx.Document` to JSON, equivalent to calling `MDEx.to_json!/2`
    * `XML` - converts Markdown or `MDEx.Document` to XML, equivalent to calling `MDEx.to_xml!/2`
    * `MD` - converts `MDEx.Document` to Markdown, equivalent to calling `MDEx.to_markdown!/2`

  Defaults to generating a `MDEx.Document` when no modifier is provided.

  Note that you should `import MDEx.Sigil` to use the `~MD` sigil.

  ## Options

  In order to support the most common scenarios, all sigils use the following options by default:

  ```elixir
  #{inspect(@opts, pretty: true)}
  ```

  If you need a different set of options, you can call the regular functions in `MDEx` to pass the options you need.

  """

  @doc """
  The `~MD` sigil converts a Markdown string or a `%MDEx.Document{}` struct to either one of these formats: `MDEx.Document`, Markdown (CommonMark), HTML, JSON or XML.

  ## Assigns

  You can define a variable `assigns` in the context of the sigil to pass values to the Markdown string, for example:

      assigns = %{lang: ":elixir"}
      iex> ~MD|`lang = <%= @lang %>`|
      %MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "lang = :elixir"}]}]}

  ## Examples

  ### Markdown to `MDEx.Document`

  No modifier defaults to generating a `MDEx.Document`:

  ```elixir
  iex> ~MD[`lang = :elixir`]
  %MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "lang = :elixir"}]}]}
  ```

  ### Markdown to HTML

  ```elixir
  iex> ~MD[`lang = :elixir`]HTML
  "<p><code>lang = :elixir</code></p>\\n"
  ```

  ### Markdown to JSON

  ```elixir
  iex> ~MD[`lang = :elixir`]JSON
  "{\"nodes\":[{\"nodes\":[{\"literal\":\"lang = :elixir\",\"num_backticks\":1,\"node_type\":\"MDEx.Code\"}],\"node_type\":\"MDEx.Paragraph\"}],\"node_type\":\"MDEx.Document\"}"
  ```

  ### Markdown to XML

  ```elixir
  iex> ~MD[`lang = :elixir`]XML
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE document SYSTEM \"CommonMark.dtd\">\n<document xmlns=\"http://commonmark.org/xml/1.0\">\n  <paragraph>\n    <code xml:space=\"preserve\">lang = :elixir</code>\n  </paragraph>\n</document>\n"
  ```

  ### `MDEx.Document` to Markdown

  ```elixir
  iex> ~MD|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "lang = :elixir"}]}]}|MD
  "`lang = :elixir`"
  ```

  ### Elixir Expressions

  ```elixir
  iex> ~MD[## Section <%= 1 + 1 %>]
  %MDEx.Document{nodes: [%MDEx.Heading{nodes: [%MDEx.Text{literal: "Section 2"}], level: 2, setext: false}]}
  ```

  """
  defmacro sigil_MD({:<<>>, _meta, [expr]}, modifiers) do
    expr = expr(expr, __CALLER__)

    quote generated: true do
      cond do
        unquote(modifiers) == [] -> MDEx.parse_document!(unquote(expr), unquote(@opts))
        unquote(modifiers) == ~c"HTML" -> MDEx.to_html!(unquote(expr), unquote(@opts))
        unquote(modifiers) == ~c"JSON" -> MDEx.to_json!(unquote(expr), unquote(@opts))
        unquote(modifiers) == ~c"XML" -> MDEx.to_xml!(unquote(expr), unquote(@opts))
        unquote(modifiers) == ~c"MD" -> MDEx.to_markdown!(unquote(expr), unquote(@opts))
      end
    end
  end

  defp expr(expr, env) do
    with {:ok, {:%, _, _} = quoted} <- Code.string_to_quoted(expr) do
      expand_alias(quoted, env)
    else
      _ -> EEx.compile_string(expr)
    end
  end

  @deprecated "Use the ~MD sigil instead"
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

        modifiers == ~c"JSON" ->
          MDEx.to_json!(doc, @opts)

        modifiers == ~c"XML" ->
          MDEx.to_xml!(doc, @opts)

        modifiers == ~c"MD" ->
          MDEx.to_markdown!(doc, @opts)

        :default ->
          MDEx.parse_document!(doc, @opts)
      end

    Macro.escape(doc)
  end

  @deprecated "Use the ~MD sigil instead"
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

        modifiers == ~c"JSON" ->
          MDEx.to_json!(doc, @opts)

        modifiers == ~c"XML" ->
          MDEx.to_xml!(doc, @opts)

        modifiers == ~c"MD" ->
          MDEx.to_markdown!(doc, @opts)

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

      modifiers == ~c"JSON" ->
        quote do
          MDEx.to_json!(to_doc(unquote(binary), __ENV__), unquote(@opts))
        end

      modifiers == ~c"XML" ->
        quote do
          MDEx.to_xml!(to_doc(unquote(binary), __ENV__), unquote(@opts))
        end

      modifiers == ~c"MD" ->
        quote do
          MDEx.to_markdown!(to_doc(unquote(binary), __ENV__), unquote(@opts))
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
