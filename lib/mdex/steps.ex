defmodule MDEx.Steps do
  import MDEx.Document, only: [is_fragment: 1]
  alias MDEx.Pipe

  @built_in_options [
    :document,
    :extension,
    :parse,
    :render,
    :features
  ]

  @doc false
  def attach(pipe) do
    pipe
    |> Pipe.register_options([
      :document,
      :extension,
      :parse,
      :render,
      :features
    ])
  end

  @doc """
  Updates the pipeline's options with new values.

  This function handles both built-in options (like `:document`, `:extension`, `:parse`, `:render`, `:features`)
  and user-defined options that have been registered with `Pipe.register_options/2`.

  For built-in options, it validates them against their respective schemas and merges them appropriately.
  For user options, it validates that they have been registered and merges them into the options list.

  ## Examples

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Pipe.register_options(pipe, [:custom_option])
      iex> pipe = MDEx.Steps.put_options(pipe, [
      ...>   document: "# Hello",
      ...>   extension: [table: true],
      ...>   custom_option: "value"
      ...> ])
      iex> pipe.options[:document]
      "# Hello"
      iex> pipe.options[:extension][:table]
      true
      iex> pipe.options[:custom_option]
      "value"
  """
  def put_options(%Pipe{} = pipe, options) when is_list(options) do
    Enum.reduce(options, pipe, fn
      {name, options}, acc when name in @built_in_options ->
        put_built_in_options(acc, [{name, options}])

      {name, value}, acc ->
        put_user_options(acc, [{name, value}])
    end)
  end

  @doc false
  def put_built_in_options(%Pipe{} = pipe, options) when is_list(options) do
    options = Keyword.take(options, @built_in_options)

    Enum.reduce(options, pipe, fn
      {:document, value}, acc ->
        NimbleOptions.validate!([{:document, value}], MDEx.options_schema())
        %{acc | options: put_in(pipe.options, [:document], value)}

      {:extension, options}, acc ->
        put_extension_options(acc, options)

      {:render, options}, acc ->
        put_render_options(acc, options)

      {:parse, options}, acc ->
        put_parse_options(acc, options)

      {:features, options}, acc ->
        put_features_options(acc, options)
    end)
  end

  @doc false
  def put_user_options(%Pipe{} = pipe, options) when is_list(options) do
    options = Keyword.take(options, Keyword.keys(options) -- @built_in_options)
    MDEx.Pipe.validate_options(pipe, options)
    %{pipe | options: Keyword.merge(pipe.options, options)}
  end

  @doc """
  Updates the pipeline's extension options with new values.

  This function validates and merges extension options into the pipeline's existing options.
  Extension options control various Markdown parsing features like tables, strikethrough, tasklists, etc.

  ## Examples

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Steps.put_extension_options(pipe, [table: true, strikethrough: true])
      iex> pipe.options[:extension][:table]
      true
      iex> pipe.options[:extension][:strikethrough]
      true

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Steps.put_extension_options(pipe, [table: true])
      iex> pipe = MDEx.Steps.put_extension_options(pipe, [strikethrough: true])
      iex> pipe.options[:extension]
      [table: true, strikethrough: true]

  ## Options

  The function accepts a keyword list of extension options. See `MDEx.extension_options_schema/0` for the full list of available options.

  Some common options include:
  - `:table` - Enables table parsing
  - `:strikethrough` - Enables strikethrough text using `~~text~~`
  - `:tasklist` - Enables task list items
  - `:autolink` - Enables automatic link detection
  - `:footnotes` - Enables footnotes support
  - `:math_dollars` - Enables math using dollar syntax
  - `:math_code` - Enables math code blocks

  ## Raises

  - `NimbleOptions.ValidationError` if an invalid extension option is provided

  """
  def put_extension_options(%Pipe{} = pipe, options) when is_list(options) do
    NimbleOptions.validate!(options, MDEx.extension_options_schema())

    %{
      pipe
      | options:
          update_in(pipe.options, [:extension], fn extension ->
            Keyword.merge(extension || [], options)
          end)
    }
  end

  @doc """
  Updates the pipeline's render options with new values.

  This function validates and merges render options into the pipeline's existing options.
  Render options control how the Markdown is converted to HTML, XML, or CommonMark output.

  ## Examples

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Steps.put_render_options(pipe, [hardbreaks: true, unsafe_: true])
      iex> pipe.options[:render][:hardbreaks]
      true
      iex> pipe.options[:render][:unsafe_]
      true

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Steps.put_render_options(pipe, [hardbreaks: true])
      iex> pipe = MDEx.Steps.put_render_options(pipe, [unsafe_: true])
      iex> pipe.options[:render]
      [hardbreaks: true, unsafe_: true]

  ## Options

  The function accepts a keyword list of render options. See `MDEx.render_options_schema/0` for the full list of available options.

  Some common options include:
  - `:hardbreaks` - Converts soft line breaks to hard line breaks
  - `:unsafe_` - Allows rendering of raw HTML and potentially dangerous links
  - `:escape` - Escapes raw HTML instead of clobbering it
  - `:width` - Sets the wrap column when outputting CommonMark
  - `:list_style` - Sets the bullet list marker type (`:dash`, `:plus`, or `:star`)
  - `:sourcepos` - Includes source position attributes in HTML/XML output
  - `:prefer_fenced` - Prefers fenced code blocks when outputting CommonMark

  ## Raises

  - `NimbleOptions.ValidationError` if an invalid render option is provided

  """
  def put_render_options(%Pipe{} = pipe, options) when is_list(options) do
    NimbleOptions.validate!(options, MDEx.render_options_schema())

    %{
      pipe
      | options:
          update_in(pipe.options, [:render], fn render ->
            Keyword.merge(render || [], options)
          end)
    }
  end

  @doc """
  Updates the pipeline's parse options with new values.

  This function validates and merges parse options into the pipeline's existing options.
  Parse options control how the Markdown input is parsed into an AST, including features like smart punctuation
  and task list matching.

  ## Examples

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Steps.put_parse_options(pipe, [smart: true, relaxed_tasklist_matching: true])
      iex> pipe.options[:parse][:smart]
      true
      iex> pipe.options[:parse][:relaxed_tasklist_matching]
      true

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Steps.put_parse_options(pipe, [smart: true])
      iex> pipe = MDEx.Steps.put_parse_options(pipe, [relaxed_tasklist_matching: true])
      iex> pipe.options[:parse]
      [smart: true, relaxed_tasklist_matching: true]

  ## Options

  The function accepts a keyword list of parse options. See `MDEx.parse_options_schema/0` for the full list of available options.

  Some common options include:
  - `:smart` - Converts punctuation (quotes, full-stops, hyphens) into "smart" punctuation
  - `:default_info_string` - Sets the default info string for fenced code blocks
  - `:relaxed_tasklist_matching` - Allows any symbol for tasklist items, not just `x` or `X`
  - `:relaxed_autolinks` - Relaxes parsing of autolinks, allowing links inside brackets and all URL schemes

  ## Raises

  - `NimbleOptions.ValidationError` if an invalid parse option is provided

  """
  def put_parse_options(%Pipe{} = pipe, options) when is_list(options) do
    NimbleOptions.validate!(options, MDEx.parse_options_schema())

    %{
      pipe
      | options:
          update_in(pipe.options, [:parse], fn parse ->
            Keyword.merge(parse || [], options)
          end)
    }
  end

  @doc """
  Updates the pipeline's features options with new values.

  This function validates and merges features options into the pipeline's existing options.
  Features options control extra functionality like HTML sanitization and syntax highlighting.

  ## Examples

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Steps.put_features_options(pipe, [
      ...>   sanitize: true,
      ...>   syntax_highlight_theme: "adwaita_dark"
      ...> ])
      iex> pipe.options[:features][:sanitize]
      true
      iex> pipe.options[:features][:syntax_highlight_theme]
      "adwaita_dark"

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Steps.put_features_options(pipe, [sanitize: true])
      iex> pipe = MDEx.Steps.put_features_options(pipe, [syntax_highlight_theme: "adwaita_dark"])
      iex> pipe.options[:features]
      [sanitize: true, syntax_highlight_theme: "adwaita_dark"]

  ## Options

  The function accepts a keyword list of features options. See `MDEx.features_options_schema/0` for the full list of available options.

  Some common options include:
  - `:sanitize` - Sanitizes output using [ammonia](https://crates.io/crates/ammonia) for security
  - `:syntax_highlight_theme` - Sets the theme for syntax highlighting code blocks (default: "onedark")
  - `:syntax_highlight_inline_style` - Embeds styles in the output for each generated token (default: true)

  ## Raises

  - `NimbleOptions.ValidationError` if an invalid features option is provided

  """
  def put_features_options(%Pipe{} = pipe, options) when is_list(options) do
    NimbleOptions.validate!(options, MDEx.features_options_schema())

    %{
      pipe
      | options:
          update_in(pipe.options, [:features], fn features ->
            Keyword.merge(features || [], options)
          end)
    }
  end

  @doc """
  Inserts a node into the root of the document at the specified position.

  This function adds a node to either the beginning (`:top`) or end (`:bottom`) of the document's node list.
  The node must be a valid fragment node (like a heading, paragraph, etc.).

  ## Examples

      iex> pipe = MDEx.new(document: "# Test") |> MDEx.Pipe.resolve_document()
      iex> node = %MDEx.HtmlBlock{literal: "<p>Hello</p>"}
      iex> pipe = MDEx.Steps.put_node_in_document_root(pipe, node, :top)
      iex> pipe.document.nodes
      [%MDEx.HtmlBlock{literal: "<p>Hello</p>"}, %MDEx.Heading{level: 1}]

      iex> pipe = MDEx.new(document: "# Test") |> MDEx.Pipe.resolve_document()
      iex> node = %MDEx.HtmlBlock{literal: "<p>Hello</p>"}
      iex> pipe = MDEx.Steps.put_node_in_document_root(pipe, node, :bottom)
      iex> pipe.document.nodes
      [%MDEx.Heading{level: 1}, %MDEx.HtmlBlock{literal: "<p>Hello</p>"}]

  ## Arguments

  - `pipe` - The pipeline containing the document to modify
  - `node` - The node to insert (must be a valid fragment node)
  - `position` - Where to insert the node (`:top` or `:bottom`, defaults to `:top`)

  ## Raises

  - `RuntimeError` if trying to insert a non-fragment node at the bottom of the document

  """
  def put_node_in_document_root(pipe, node, position \\ :top)

  def put_node_in_document_root(%Pipe{document: %MDEx.Document{} = document} = pipe, node, :top = _position) do
    document =
      case is_fragment(node) do
        true ->
          nodes = [node | document.nodes]
          %{document | nodes: nodes}

        false ->
          document
      end

    %{pipe | document: document}
  end

  def put_node_in_document_root(%Pipe{document: %MDEx.Document{} = document} = pipe, node, :bottom = _position) do
    document =
      case is_fragment(node) do
        true ->
          nodes = document.nodes ++ [node]
          %{document | nodes: nodes}

        false ->
          raise """
          expected a fragment node as %MDEx.Heading{}

          Got:

            #{inspect(node)}
          """
      end

    %{pipe | document: document}
  end

  @doc """
  Updates nodes in the document that match a selector function.

  This function traverses all nodes in the document and applies a transformation function to nodes
  that match the selector function. The selector function should return `true` for nodes that should
  be updated.
  """
  def update_node(%Pipe{} = pipe, selector, fun) when is_function(selector, 1) and is_function(fun, 1) do
    document =
      update_in(pipe.document, [:document, Access.key!(:nodes), Access.all(), selector], fn node ->
        fun.(node)
      end)

    %{pipe | document: document}
  end
end
