defmodule MDEx.Sigil do
  @opts Keyword.merge(
          MDEx.Document.default_options(),
          [
            extension: [
              strikethrough: true,
              table: true,
              autolink: false,
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
              spoiler: true,
              phoenix_heex: true
            ],
            parse: [
              relaxed_tasklist_matching: true,
              relaxed_autolinks: true
            ],
            render: [
              unsafe: true,
              escape: false,
              # github_pre_lang and full_info_string are required to enable code block decorators
              github_pre_lang: true,
              full_info_string: true
            ]
          ],
          fn _key, v1, v2 ->
            if is_list(v1) and is_list(v2), do: Keyword.merge(v1, v2), else: v2
          end
        )

  @doc false
  def default_sigil_opts, do: @opts

  @doc false
  def merge_sigil_opts(user_opts) when is_list(user_opts) and user_opts != [] do
    Keyword.merge(
      @opts,
      user_opts,
      fn _key, v1, v2 ->
        if is_list(v1) and is_list(v2), do: Keyword.merge(v1, v2), else: v2
      end
    )
  end

  def merge_sigil_opts(_), do: @opts

  @moduledoc """
  Sigils for parsing and formatting Markdown between different formats.

  ## Examples

  With no modifier, `~MD` defaults to converting a Markdown string into a `MDEx.Document` struct:

      iex> import MDEx.Sigil
      iex> ~MD|# Hello from `~MD` sigil|
      %MDEx.Document{
        nodes: [
          %MDEx.Heading{
            nodes: [
              %MDEx.Text{literal: "Hello from "},
              %MDEx.Code{num_backticks: 1, literal: "~MD"},
              %MDEx.Text{literal: " sigil"}
            ],
            level: 1,
            setext: false
          }
        ]
      }

  You can also convert Markdown to HTML, JSON or XML:

      iex> import MDEx.Sigil
      iex> ~MD|`~MD` also converts to HTML format|HTML
      "<p><code>~MD</code> also converts to HTML format</p>"

      iex> import MDEx.Sigil
      iex> ~MD|and to XML as well|XML
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\\n<!DOCTYPE document SYSTEM \"CommonMark.dtd\">\\n<document xmlns=\"http://commonmark.org/xml/1.0\">\\n  <paragraph>\\n    <text xml:space=\"preserve\">and to XML as well</text>\\n  </paragraph>\\n</document>"

  Assigns in the context can be referenced in the Markdown content using `<%= ... %>` syntax, which is evaluated at runtime. `~MD`
  accepts an `assigns` map to pass variables to the document when rendering HTML or Markdown:

      iex> import MDEx.Sigil
      iex> assigns = %{lang: "Elixir"}
      iex> ~MD|Running <%= @lang %>|HTML
      "<p>Running Elixir</p>"

      iex> import MDEx.Sigil
      iex> assigns = %{lang: "Elixir"}
      iex> ~MD|Running <%= @lang %>|MD
      "Running Elixir"

  The `HEEX` modifier can render component and Elixir expressions:

      iex> import MDEx.Sigil
      iex> assigns = %{lang: "Elixir"}
      iex> rendered = ~MD|Learn <Phoenix.Component.link href="https://elixir-lang.org">{@lang}</Phoenix.Component.link>|HEEX
      %Phoenix.LiveView.Rendered{...}
      iex> rendered |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()
      "<p>Learn <a href="https://elixir-lang.org">Elixir</a></p>"

  ## Modifiers

    * `HTML` - converts Markdown or `MDEx.Document` to HTML

        Use [EEx.SmartEngine](https://hexdocs.pm/eex/EEx.SmartEngine.html) to convert the document into HTML. It does support `assigns` but only the old `<%= ... %>` syntax,
        and it doesn't support components. It's useful if you want to generate static HTML from Markdown or don't need components or don't want to define an `assigns` variable (it's optional).

        Prefer using the `HEEX` modifier if you need full Phoenix LiveView support with components and expressions.

    * `HEEX` - converts Markdown to [Phoenix HEEx](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Rendered.html) for LiveView templates

        Enables LiveView components, `phx-*` bindings, and Elixir expressions inside Markdown.
        Requires Phoenix LiveView and an `assigns` variable in scope.

        See [Phoenix LiveView HEEx example](https://hexdocs.pm/mdex/phoenix_live_view_heex.html) for a demo.

    * `JSON` - converts Markdown or `MDEx.Document` to JSON

    * `XML` - converts Markdown or `MDEx.Document` to XML

    * `MD` - converts `MDEx.Document` to Markdown and can interpolate assigns in Markdown strings

    * `DELTA` - converts Markdown or `MDEx.Document` to Quill Delta format

    * No modifier (default) - parses a Markdown string into a `MDEx.Document` struct

  Note that you should `import MDEx.Sigil` to use the `~MD` sigil.

  ## HTML/EEx Format Order

  In order to generate the final result, the Markdown string or `MDEx.Document` (initial input) is first converted into a static HTML without escaping
  the content, then the HTML is passed to the appropriate engine to generate the final output.

  ## Assigns and Expressions

  The `HTML` and `HEEX` modifiers evaluate assigns and expressions at runtime.
  Other modifiers preserve them as literal text in the output.

  > #### Expressions inside code blocks are preserved {: .warning}
  > Expressions like `<%= ... %>` or `{ ... }` inside code blocks are escaped, not evaluated:
  > ```elixir
  > assigns = %{title: "Hello"}
  > ~MD"`{@title}`"HTML
  > #=> "<p><code>&lbrace;@title&rbrace;</code></p>"
  > ```

  ## Options

  All modifiers use these options by default:

  ```elixir
  #{inspect(@opts, pretty: true)}
  ```

  If you need a different set of options, you can either pass options to [use MDEx](https://hexdocs.pm/mdex/MDEx.html#__using__/1) or call the regular functions in `MDEx`.

  """

  @doc """
  The `~MD` sigil converts a Markdown string or a `%MDEx.Document{}` struct to either one of these formats: `MDEx.Document`, Markdown (CommonMark), HTML, [HEEx](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Rendered.html) JSON or XML.

  ## Assigns

  You can define a variable `assigns` in the context of the sigil to evaluate expressions:

      iex> assigns = %{lang: ":elixir"}
      iex> ~MD|`lang = <%= @lang %>`|HTML
      "<p><code>lang = :elixir</code></p>"

      iex> assigns = %{lang: ":elixir"}
      iex> ~MD|`lang = <%= @lang %>`|MD
      "`lang = :elixir`"

  Note that only the `HTML` and `MD` modifiers support assigns.

  ## Examples

  ### Markdown to `MDEx.Document`

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

  ### Markdown to Quill Delta

  ```elixir
  iex> ~MD|`lang = :elixir`|DELTA
  [%{"insert" => "lang = :elixir", "attributes" => %{"code" => true}}, %{"insert" => "\\n"}]
  ```

  ### Elixir Expressions

  ```elixir
  iex> ~MD[## Section <%= 1 + 1 %>]HTML
  "<h2>Section 2</h2>"
  ```

  """
  defmacro sigil_MD({:<<>>, _meta, [expr]}, modifiers) do
    expr = expr(expr, __CALLER__)
    user_opts = Module.get_attribute(__CALLER__.module, :__mdex_opts__) || []
    opts = MDEx.Sigil.merge_sigil_opts(user_opts)

    case modifiers do
      [] ->
        expr
        |> MDEx.parse_document!(opts)
        |> Macro.escape()

      ~c"HTML" ->
        if Macro.Env.has_var?(__CALLER__, {:assigns, nil}) do
          expr
          |> MDEx.to_html!(opts)
          |> EEx.compile_string(
            engine: EEx.SmartEngine,
            file: __CALLER__.file,
            line: __CALLER__.line + 1,
            indentation: 0
          )
        else
          MDEx.to_html!(expr, opts)
        end

      ~c"HEEX" ->
        if Code.ensure_loaded?(Phoenix.LiveView) do
          if not Macro.Env.has_var?(__CALLER__, {:assigns, nil}) do
            raise "~MD[...]HEEX requires a variable named \"assigns\" to exist and be set to a map"
          end

          heex_opts =
            opts
            |> Keyword.update(:extension, [phoenix_heex: true], &Keyword.put(&1, :phoenix_heex, true))
            |> Keyword.update(:render, [unsafe: true], &Keyword.put(&1, :unsafe, true))

          expr
          |> MDEx.to_html!(heex_opts)
          |> EEx.compile_string(
            engine: Phoenix.LiveView.TagEngine,
            file: __CALLER__.file,
            line: __CALLER__.line + 1,
            caller: __CALLER__,
            indentation: 0,
            source: expr,
            tag_handler: Phoenix.LiveView.HTMLEngine
          )
        else
          IO.warn("Phoenix LiveView is required to use the HEEX modifier with ~MD sigil")
        end

      ~c"MD" ->
        cond do
          is_binary(expr) && Macro.Env.has_var?(__CALLER__, {:assigns, nil}) ->
            EEx.compile_string(expr,
              engine: EEx.SmartEngine,
              file: __CALLER__.file,
              line: __CALLER__.line + 1,
              indentation: 0
            )

          is_binary(expr) ->
            expr

          :else ->
            MDEx.to_markdown!(expr, opts)
        end

      ~c"JSON" ->
        expr
        |> MDEx.to_json!(opts)
        |> Macro.escape()

      ~c"XML" ->
        expr
        |> MDEx.to_xml!(opts)
        |> Macro.escape()

      ~c"DELTA" ->
        expr
        |> MDEx.to_delta!(opts)
        |> Macro.escape()

      _ ->
        raise "unsupported modifier #{inspect(modifiers)} for sigil_MD"
    end
  end

  @deprecated "Use the ~MD sigil instead"
  defmacro sigil_M({:<<>>, _meta, [expr]}, modifiers) do
    expr = Macro.unescape_string(expr)
    doc = expr(expr, __CALLER__)

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
    doc = expr(binary, __CALLER__)

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
    opts = Macro.escape(@opts)

    cond do
      modifiers == ~c"AST" ->
        IO.warn("""
        modifier AST is deprecated

        This sigil now returns a %MDEx.Document{} by default,
        so you can remove the AST suffix.
        """)

        quote do
          MDEx.parse_document!(unquote(binary), unquote(opts))
        end

      modifiers == ~c"HTML" ->
        quote do
          MDEx.to_html!(expr(unquote(binary), __ENV__), unquote(opts))
        end

      modifiers == ~c"JSON" ->
        quote do
          MDEx.to_json!(expr(unquote(binary), __ENV__), unquote(opts))
        end

      modifiers == ~c"XML" ->
        quote do
          MDEx.to_xml!(expr(unquote(binary), __ENV__), unquote(opts))
        end

      modifiers == ~c"MD" ->
        quote do
          MDEx.to_markdown!(expr(unquote(binary), __ENV__), unquote(opts))
        end

      :default ->
        quote do
          MDEx.parse_document!(unquote(binary), unquote(opts))
        end
    end
  end

  @doc false
  def expr(binary, env) do
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
