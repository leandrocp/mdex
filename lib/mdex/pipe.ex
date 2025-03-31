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

      MDEx.new()
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
          |> Pipe.put_options(mermaid_version: options[:version])
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

  @typedoc """
  Step in a pipeline.

  It's a function that receives a `t:MDEx.Pipe.t/0` struct and must return either one of the following:

    - a `t:MDEx.Pipe.t/0` struct
    - a tuple with a `t:MDEx.Pipe.t/0` struct and an `t:Exception.t/0` as `{pipe, exception}`
    - a tuple with a module, function and arguments which will be invoked with `apply/3`
  """
  @type step() ::
          (t() -> t())
          | (t() -> {t(), Exception.t()})
          | (t() -> {module(), atom(), [term()]})

  @doc """
  Registers a list of valid options that can be used by steps in the pipeline.

  ## Examples

      iex> pipe = MDEx.new()
      iex> pipe = MDEx.Pipe.register_options(pipe, [:mermaid_version])
      iex> pipe = MDEx.Pipe.put_options(pipe, mermaid_version: "11")
      iex> pipe.options[:mermaid_version]
      "11"

      iex> MDEx.new(rendr: [unsafe_: true])
      ** (ArgumentError) unknown option :rendr. Did you mean :render?

  """
  @spec register_options(t(), [atom()]) :: t()
  def register_options(%MDEx.Pipe{} = pipe, options) when is_list(options) do
    update_in(pipe.registered_options, &MapSet.union(&1, MapSet.new(options)))
  end

  @doc """
  Merges options into the pipeline's existing options.

  This function handles both built-in options (like `:document`, `:extension`, `:parse`, `:render`, `:features`)
  and user-defined options that have been registered with `register_options/2`.

  ## Examples

      iex> pipe = MDEx.Pipe.register_options(MDEx.new(), [:custom_option])
      iex> pipe = MDEx.Pipe.put_options(pipe, [
      ...>   document: "# Hello",
      ...>   extension: [table: true],
      ...>   custom_option: "value"
      ...> ])
      iex> MDEx.Pipe.get_option(pipe, :document)
      "# Hello"
      iex> MDEx.Pipe.get_option(pipe, :extension)[:table]
      true
      iex> MDEx.Pipe.get_option(pipe, :custom_option)
      "value"

  """
  @spec put_options(t(), keyword()) :: t()
  def put_options(%MDEx.Pipe{} = pipe, options) when is_list(options) do
    validate_options(pipe, options)

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
  Appends steps to the end of the existing pipeline's step list.

  ## Examples

  * Update an `:extension` option:

        iex> pipe = MDEx.new()
        iex> pipe = MDEx.Pipe.append_steps(
        ...>   pipe,
        ...>   enable_tables: fn pipe -> MDEx.Pipe.put_extension_options(pipe, table: true) end
        ...> )
        iex> pipe |> MDEx.Pipe.run() |> MDEx.Pipe.get_option(:extension)
        [table: true]

  """
  @spec append_steps(t(), keyword(step())) :: t()
  def append_steps(pipe, steps) do
    %{
      pipe
      | steps: pipe.steps ++ steps,
        current_steps: pipe.current_steps ++ Keyword.keys(steps)
    }
  end

  @doc """
  Prepends steps to the beginning of the existing pipeline's step list.
  """
  @spec prepend_steps(t(), keyword(step())) :: t()
  def prepend_steps(pipe, steps) do
    %{
      pipe
      | steps: steps ++ pipe.steps,
        current_steps: Keyword.keys(steps) ++ pipe.current_steps
    }
  end

  @doc """
  Updates the pipeline's `:extension` options.

  ## Examples

      iex> pipe = MDEx.Pipe.put_extension_options(MDEx.new(), table: true)
      iex> MDEx.Pipe.get_option(pipe, :extension)[:table]
      true

  """
  @spec put_extension_options(t(), MDEx.extension_options()) :: t()
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
  Updates the pipeline's `:render` options.

  ## Examples

      iex> pipe = MDEx.Pipe.put_render_options(MDEx.new(), escape: true)
      iex> MDEx.Pipe.get_option(pipe, :render)[:escape]
      true

  """
  @spec put_render_options(t(), MDEx.render_options()) :: t()
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
  Updates the pipeline's `:parse` options.

  ## Examples

      iex> pipe = MDEx.Pipe.put_parse_options(MDEx.new(), smart: true)
      iex> MDEx.Pipe.get_option(pipe, :parse)[:smart]
      true

  """
  @spec put_parse_options(t(), MDEx.parse_options()) :: t()
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
  Updates the pipeline's `:features` options.

  ## Examples

      iex> pipe = MDEx.Pipe.put_features_options(MDEx.new(), sanitize: [add_tags: ["MyComponent"]])
      iex> MDEx.Pipe.get_option(pipe, :features)[:sanitize][:add_tags]
      ["MyComponent"]

  """
  @spec put_features_options(t(), MDEx.features_options()) :: t()
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
  Inserts `node` into the document root at the specified `position`.

    - By default, the node is inserted at the top of the document.
    - Node must be a valid fragment node like a `MDEx.Heading`, `MDEx.HtmlBlock`, etc.

  ## Examples

      iex> pipe = MDEx.new()
      iex> pipe = MDEx.Pipe.append_steps(
      ...>   pipe,
      ...>   append_node: fn pipe ->
      ...>     html_block = %MDEx.HtmlBlock{literal: "<p>Hello</p>"}
      ...>     MDEx.Pipe.put_node_in_document_root(pipe, html_block, :bottom)
      ...>   end)
      iex> MDEx.to_html(pipe, document: "# Doc", render: [unsafe_: true])
      {:ok, "<h1>Doc</h1>\\n<p>Hello</p>"}

  """
  @spec put_node_in_document_root(t(), MDEx.Document.md_node(), position :: :top | :bottom) :: t()
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
  Updates nodes in the document that match `selector`.
  """
  @spec update_nodes(t(), MDEx.Document.selector(), (MDEx.Document.md_node() -> MDEx.Document.md_node())) :: t()
  def update_nodes(%MDEx.Pipe{} = pipe, selector, fun) when is_function(fun, 1) do
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

      iex> pipe = MDEx.Pipe.halt(MDEx.new())
      iex> pipe.halted
      true

  """
  @spec halt(t()) :: t()
  def halt(%MDEx.Pipe{} = pipe) do
    put_in(pipe.halted, true)
  end

  @doc """
  Halts the pipeline execution with an exception.
  """
  @spec halt(t(), Exception.t()) :: {t(), Exception.t()}
  def halt(%MDEx.Pipe{} = pipe, %_{__exception__: true} = exception) do
    {put_in(pipe.halted, true), exception}
  end

  @doc """
  Retrieves an option value from the pipeline.
  """
  @spec get_option(t(), atom(), term()) :: term()
  def get_option(%MDEx.Pipe{} = pipe, key, default \\ nil) when is_atom(key) do
    Keyword.get(pipe.options, key, default)
  end

  @doc """
  Retrieves a private value from the pipeline.
  """
  @spec get_private(t(), atom(), default) :: term() | default when default: var
  def get_private(%MDEx.Pipe{} = pipe, key, default \\ nil) when is_atom(key) do
    Map.get(pipe.private, key, default)
  end

  @doc """
  Updates a value in the pipeline's private storage using a function.
  """
  @spec update_private(t(), key :: atom(), default :: term(), (term() -> term())) :: t()
  def update_private(%MDEx.Pipe{} = pipe, key, default, fun) when is_atom(key) and is_function(fun, 1) do
    update_in(pipe.private, &Map.update(&1, key, default, fun))
  end

  @doc """
  Stores a value in the pipeline's private storage.
  """
  @spec put_private(t(), atom(), term()) :: t()
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

  @doc """
  Executes the pipeline steps in order.

  This function is usually not called directly,
  prefer calling one of the `to_*` functions in `MDEx` module.
  """
  @spec run(t()) :: t()
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
