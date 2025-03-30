defmodule MDEx.Pipe do
  @moduledoc """
  MDEx.Pipe is a Req-like API to transform Markdown documents through a series of steps in a pipeline.

  Its main use case it to enable plugins, for example:

      document = \"\"\"
      # Project Diagram

      \`\`\`mermaid
      graph TD
          A[Enter Chart Definition] --> B(Preview)
          B --> C{decide}
          C --> D[Keep]
          C --> E[Edit Definition]
          E --> B
          D --> F[Save Image and Code]
          F --> B
      \`\`\`
      \"\"\"

      MDEx.new(parse: [smart: true])
      |> MDExMermaid.attach(version: "11")
      |> MDEx.to_html(document: document)

  ## Writing Plugins

  To understand how it works, let's write that Mermaid plugin showed above.

  In order to render Mermaid diagrams, we need to inject this `<script>` into the document,
  as outlined in their [docs](https://mermaid.js.org/intro/#installation):

      <script type="module">
        import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
        mermaid.initialize({ startOnLoad: true });
      </script>

  The `:version` option will be options to let users load a specific version,
  but it will default to the latest version:

      MDEx.new() |> MDExMermaid.attach()

  Or to customize the version:

      MDEx.new() |> MDExMermaid.attach(version: "11")

  Let's get into the actual code, with comments to explain each part:

      defmodule MDExMermaid do
        alias MDEx.Pipe

        @latest_version "11"

        def attach(pipe, options \\ []) do
          pipe
          # register option with prefix `:mermaid_` to avoid conflicts with other plugins
          |> Pipe.register_options([:mermaid_version])
          #  merge all options given by users
          |> Pipe.merge_options(mermaid_version: options[:version])
          # actual steps to manipulate the document
          # see respective Pipe functions for more info
          |> Pipe.append_steps(enable_unsafe: &enable_unsafe/1)
          |> Pipe.append_steps(inject_script: &inject_script/1)
          |> Pipe.append_steps(update_code_blocks: &update_code_blocks/1)
        end

        defp enable_unsafe(pipe) do
          Pipe.put_render_options(pipe, unsafe_: true)
        end

        defp inject_script(pipe) do
          version = Pipe.get_option(pipe, :mermaid_version, @latest_version)

          script_node =
            %MDEx.HtmlBlock{
              literal: \"\"\"
              <script type="module">
                import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@\#\{version\}/dist/mermaid.esm.min.mjs';
                mermaid.initialize({ startOnLoad: true });
              </script>
              \"\"\"
            }

          Pipe.put_node_in_document_root(pipe, script_node)
        end

        defp update_code_blocks(pipe) do
          selector = fn
            %MDEx.CodeBlock{info: "mermaid"} -> true
            _ -> false
          end

          Pipe.update_nodes(
            pipe,
            selector,
            &%MDEx.HtmlBlock{literal: "<pre class=\"mermaid\">\#\{&1.literal}</pre>", nodes: &1.nodes}
          )
        end
      end

  Now whenever that plugin is attached to a pipeline,
  MDEx will run all functions defined in the `attach/1` function.
  """

  import MDEx.Document, only: [is_fragment: 1]

  @built_in_options [
    :document,
    :extension,
    :parse,
    :render,
    :features
  ]

  defstruct document: nil,
            options: [
              document: "",
              extension: [],
              parse: [],
              render: [],
              features: []
            ],
            registered_options: MapSet.new(),
            halted: false,
            steps: [],
            current_steps: [],
            private: %{}

  @typedoc """
  Pipeline state.
  """
  @type t :: %__MODULE__{
          document: MDEx.Document.t(),
          options: MDEx.options(),
          halted: boolean(),
          steps: keyword(),
          private: map()
        }

  @doc """
  Registers a list of valid options that can be used in the pipeline.

  This function is used by plugins to declare which options they accept. When options are merged
  later using `merge_options/2`, only registered options are allowed. If an unregistered option
  is provided, an `ArgumentError` will be raised with a helpful "did you mean?" suggestion.

  ## Examples

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Pipe.register_options(pipe, [:mermaid_version])
      iex> pipe = MDEx.Pipe.merge_options(pipe, mermaid_version: "11")
      iex> pipe.options
      [mermaid_version: "11"]

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Pipe.register_options(pipe, [:mermaid_version])
      iex> pipe = MDEx.Pipe.merge_options(pipe, invalid_option: "value")
      ** (ArgumentError) unknown option :invalid_option

  """
  @spec register_options(t(), [atom()]) :: t()
  def register_options(%MDEx.Pipe{} = pipe, options) when is_list(options) do
    update_in(pipe.registered_options, &MapSet.union(&1, MapSet.new(options)))
  end

  # TODO: merge put_options/merge_options

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
  def put_options(%MDEx.Pipe{} = pipe, options) when is_list(options) do
    Enum.reduce(options, pipe, fn
      {name, options}, acc when name in @built_in_options ->
        put_built_in_options(acc, [{name, options}])

      {name, value}, acc ->
        put_user_options(acc, [{name, value}])
    end)
  end

  @doc false
  def put_built_in_options(%MDEx.Pipe{} = pipe, options) when is_list(options) do
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
  def put_user_options(%MDEx.Pipe{} = pipe, options) when is_list(options) do
    options = Keyword.take(options, Keyword.keys(options) -- @built_in_options)
    validate_options(pipe, options)
    %{pipe | options: Keyword.merge(pipe.options, options)}
  end

  @doc """
  Merges new options into the pipeline's existing options.

  This function validates that all options being merged have been previously registered using
  `register_options/2`. If any unregistered options are provided, an `ArgumentError` will be raised.

  The options are merged using `Keyword.merge/2`, which means that if the same option is provided
  multiple times, the last value will be used.

  ## Examples

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Pipe.register_options(pipe, [:mermaid_version])
      iex> pipe = MDEx.Pipe.merge_options(pipe, mermaid_version: "11")
      iex> pipe = MDEx.Pipe.merge_options(pipe, mermaid_version: "12")
      iex> pipe.options
      [mermaid_version: "12"]

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Pipe.register_options(pipe, [:mermaid_version])
      iex> pipe = MDEx.Pipe.merge_options(pipe, [mermaid_version: "11", invalid_option: "value"])
      ** (ArgumentError) unknown option :invalid_option

  """
  @spec merge_options(t(), keyword()) :: t()
  def merge_options(%MDEx.Pipe{} = pipe, options) when is_list(options) do
    validate_options(pipe, options)
    update_in(pipe.options, &Keyword.merge(&1, options))
  end

  @doc false
  @spec validate_options(t(), keyword()) :: boolean()
  def validate_options(%MDEx.Pipe{} = pipe, options) do
    validate_options(options, pipe.registered_options)
  end

  def validate_options([{name, _value} | rest], registered) do
    if name in registered do
      validate_options(rest, registered)
    else
      case did_you_mean(Atom.to_string(name), registered) do
        {similar, score} when score > 0.8 ->
          raise ArgumentError, "unknown option #{inspect(name)}. Did you mean :#{similar}?"

        _ ->
          raise ArgumentError, "unknown option #{inspect(name)}"
      end
    end
  end

  def validate_options([], _registered) do
    true
  end

  defp did_you_mean(option, registered) do
    registered
    |> Enum.map(&to_string/1)
    |> Enum.reduce({nil, 0}, &max_similar(&1, option, &2))
  end

  defp max_similar(option, registered, {_, current} = best) do
    score = String.jaro_distance(option, registered)
    if score < current, do: best, else: {option, score}
  end

  @doc """
  Appends steps to the end of the pipeline's step list.

  This function is used to add transformation steps that will be executed after any existing steps.
  Each step can be either a function that takes a pipe as its argument, or a tuple of `{module, function, args}`.

  ## Examples

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Pipe.append_steps(pipe, transform: fn pipe -> %{pipe | document: "transformed"} end)
      iex> pipe.current_steps
      [:transform]

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Pipe.append_steps(pipe, [
      ...>   step1: fn pipe -> %{pipe | document: "step1"} end,
      ...>   step2: fn pipe -> %{pipe | document: "step2"} end
      ...> ])
      iex> pipe.current_steps
      [:step1, :step2]

  """
  @spec append_steps(t(), keyword((t() -> t()) | {module(), atom(), list()})) :: t()
  def append_steps(pipe, steps) do
    %{
      pipe
      | steps: pipe.steps ++ steps,
        current_steps: pipe.current_steps ++ Keyword.keys(steps)
    }
  end

  @doc """
  Prepends steps to the beginning of the pipeline's step list.

  This function is used to add transformation steps that will be executed before any existing steps.
  Each step can be either a function that takes a pipe as its argument, or a tuple of `{module, function, args}`.

  This is particularly useful for plugins that need to run their transformations before other steps,
  such as when they need to modify the document structure before other plugins process it.

  ## Examples

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Pipe.prepend_steps(pipe, transform: fn pipe -> %{pipe | document: "transformed"} end)
      iex> pipe.current_steps
      [:transform]

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Pipe.prepend_steps(pipe, [
      ...>   step1: fn pipe -> %{pipe | document: "step1"} end,
      ...>   step2: fn pipe -> %{pipe | document: "step2"} end
      ...> ])
      iex> pipe.current_steps
      [:step1, :step2]

  """
  @spec prepend_steps(t(), keyword((t() -> t()) | {module(), atom(), list()})) :: t()
  def prepend_steps(pipe, steps) do
    %{
      pipe
      | steps: steps ++ pipe.steps,
        current_steps: Keyword.keys(steps) ++ pipe.current_steps
    }
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
  def put_extension_options(%MDEx.Pipe{} = pipe, options) when is_list(options) do
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
  def put_render_options(%MDEx.Pipe{} = pipe, options) when is_list(options) do
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
  def put_parse_options(%MDEx.Pipe{} = pipe, options) when is_list(options) do
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
  def put_features_options(%MDEx.Pipe{} = pipe, options) when is_list(options) do
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

  def put_node_in_document_root(%MDEx.Pipe{document: %MDEx.Document{} = document} = pipe, node, :top = _position) do
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

  def put_node_in_document_root(%MDEx.Pipe{document: %MDEx.Document{} = document} = pipe, node, :bottom = _position) do
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
  def update_nodes(%MDEx.Pipe{} = pipe, selector, fun) when is_function(selector, 1) and is_function(fun, 1) do
    document =
      update_in(pipe.document, [:document, Access.key!(:nodes), Access.all(), selector], fn node ->
        fun.(node)
      end)

    %{pipe | document: document}
  end

  @doc """
  Halts the pipeline execution.

  This function is used to stop the pipeline from processing any further steps. Once a pipeline
  is halted, no more steps will be executed. This is useful for plugins that need to stop
  processing when certain conditions are met or when an error occurs.

  ## Examples

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Pipe.halt(pipe)
      iex> pipe.halted
      true

  """
  @spec halt(Pipe.t()) :: Pipe.t()
  def halt(%MDEx.Pipe{} = pipe) do
    put_in(pipe.halted, true)
  end

  @doc """
  Halts the pipeline execution with an exception.

  This function is used to stop the pipeline and return both the halted pipeline and the
  exception that caused the halt. This is particularly useful for error handling in plugins,
  allowing them to propagate errors up the pipeline while maintaining the pipeline's state.

  ## Examples

      iex> pipe = MDEx.Pipe.new()
      iex> exception = %RuntimeError{message: "Something went wrong"}
      iex> {pipe, error} = MDEx.Pipe.halt(pipe, exception)
      iex> pipe.halted
      true
      iex> error
      %RuntimeError{message: "Something went wrong"}

  """
  @spec halt(Pipe.t(), Exception.t()) :: {Pipe.t(), Exception.t()}
  def halt(%MDEx.Pipe{} = pipe, %_{__exception__: true} = exception) do
    {put_in(pipe.halted, true), exception}
  end

  @doc """
  Retrieves an option value from the pipeline.

  Returns the value of the option if it exists, otherwise returns the default value.
  This is typically used by plugins to access their configuration options.

  ## Examples

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Pipe.register_options(pipe, [:mermaid_version])
      iex> pipe = MDEx.Pipe.merge_options(pipe, mermaid_version: "11")
      iex> MDEx.Pipe.get_option(pipe, :mermaid_version)
      "11"

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Pipe.register_options(pipe, [:mermaid_version])
      iex> MDEx.Pipe.get_option(pipe, :mermaid_version, "latest")
      "latest"

  """
  @spec get_option(Pipe.t(), atom(), term()) :: term()
  def get_option(%MDEx.Pipe{} = pipe, key, default \\ nil) when is_atom(key) do
    Keyword.get(pipe.options, key, default)
  end

  @doc """
  Retrieves a value from the pipeline's private storage.

  The private storage is a map that can be used by plugins to store internal state or temporary
  data that shouldn't be exposed as options. Returns the value if it exists, otherwise returns
  the default value.

  This is typically used by plugins to maintain state between steps or store data that shouldn't
  be part of the public API.

  ## Examples

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Pipe.put_private(pipe, :cache_key, "abc123")
      iex> MDEx.Pipe.get_private(pipe, :cache_key)
      "abc123"

      iex> pipe = MDEx.Pipe.new()
      iex> MDEx.Pipe.get_private(pipe, :non_existent_key, :not_found)
      :not_found

  """
  @spec get_private(Pipe.t(), atom(), default) :: term() | default when default: var
  def get_private(%MDEx.Pipe{} = pipe, key, default \\ nil) when is_atom(key) do
    Map.get(pipe.private, key, default)
  end

  @doc """
  Updates a value in the pipeline's private storage using a function.

  If the key exists, the function is called with the current value and the result is stored.
  If the key doesn't exist, the default value is stored.

  This is typically used by plugins to maintain state that needs to be updated based on its
  current value, such as counters or accumulators.

  ## Examples

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Pipe.put_private(pipe, :counter, 1)
      iex> pipe = MDEx.Pipe.update_private(pipe, :counter, 0, &(&1 + 1))
      iex> MDEx.Pipe.get_private(pipe, :counter)
      2

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Pipe.update_private(pipe, :new_key, 0, &(&1 + 1))
      iex> MDEx.Pipe.get_private(pipe, :new_key)
      0

  """
  @spec update_private(Pipe.t(), key :: atom(), default :: term(), (term() -> term())) :: Pipe.t()
  def update_private(%MDEx.Pipe{} = pipe, key, default, fun) when is_atom(key) and is_function(fun, 1) do
    update_in(pipe.private, &Map.update(&1, key, default, fun))
  end

  @doc """
  Stores a value in the pipeline's private storage.

  This function is used to store values that shouldn't be exposed as options but need to be
  maintained between pipeline steps. The private storage is a map where plugins can store
  internal state or temporary data.

  ## Examples

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Pipe.put_private(pipe, :cache_key, "abc123")
      iex> MDEx.Pipe.get_private(pipe, :cache_key)
      "abc123"

      iex> pipe = MDEx.Pipe.new()
      iex> pipe = MDEx.Pipe.put_private(pipe, :temp_data, %{count: 1})
      iex> pipe = MDEx.Pipe.put_private(pipe, :temp_data, %{count: 2})
      iex> MDEx.Pipe.get_private(pipe, :temp_data)
      %{count: 2}

  """
  @spec put_private(Pipe.t(), atom(), term()) :: Pipe.t()
  def put_private(%MDEx.Pipe{} = pipe, key, value) when is_atom(key) do
    put_in(pipe.private[key], value)
  end

  @doc false
  # parse options.document and put into pipe.document
  def resolve_document(pipe) do
    case MDEx.parse_document(pipe.options[:document], pipe.options) do
      {:ok, document} ->
        %{pipe | document: document}

      {:error, error} ->
        raise """
        failed to parse document

        expected a valid String or %MDEx.Document{} in options.document

        Got:

          #{inspect(pipe.options.document)}

        Error:

          #{inspect(error)}

        """
    end
  end

  @doc false
  def run(%MDEx.Pipe{} = pipe) do
    pipe
    |> resolve_document()
    |> do_run()
  end

  defp do_run(%{current_steps: [step | rest]} = pipe) do
    step = Keyword.fetch!(pipe.steps, step)

    # TODO: run_error
    case run_step(step, pipe) do
      {%MDEx.Pipe{halted: true} = pipe, exception} ->
        {pipe, exception}

      %MDEx.Pipe{halted: true} = pipe ->
        pipe

      %MDEx.Pipe{} = pipe ->
        do_run(%{pipe | current_steps: rest})
    end
  end

  defp do_run(%{current_steps: []} = pipe) do
    pipe
  end

  defp run_step(step, state) when is_function(step, 1) do
    step.(state)
  end

  defp run_step({mod, fun, args}, state) when is_atom(mod) and is_atom(fun) and is_list(args) do
    apply(mod, fun, [state | args])
  end
end
