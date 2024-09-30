defmodule MDEx.Sigil do
  @doc """
  The `~M` sigil for parsing and formatting Markdown.

  Most options are enabled by default, otherwise use the regular `MDEx.to_html/2` function to customize them for particular cases.

  ## Modifiers

    * `a` - calls `MDEx.parse_document!/2` to return the document AST instead of HTML

  ## Examples

      iex> ~M|# Hello|
      "<h1>Hello</h1>"

      iex> ~M|# Hello|a
      [{"document", [], [{"heading", [{"level", 1}, {"setext", false}], ["Hello"]}]}]

  Note that you should `import MDEx.Sigil` to use the `~M` sigil.
  """
  # TODO: deprecated ~M and add ~MD when we start requiring min Elixir 1.15
  defmacro sigil_M({:<<>>, _meta, [md]}, modifiers) do
    opts = [
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

    doc =
      cond do
        ?a in modifiers -> MDEx.parse_document!(md, opts)
        :default -> MDEx.to_html!(md, opts)
      end

    Macro.escape(doc)
  end
end
