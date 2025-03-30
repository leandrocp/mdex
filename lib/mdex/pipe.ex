defmodule MDEx.Pipe do
  @moduledoc """
  MDEx.Pipe is a Req-like API to transform Markdown documents.

  It enables plugins, for example:

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

  ```elixir
  TODO: copy from test
  ```

  Now whenever that plugin is attached to a pipeline,
  MDEx will run all functions defined in the `attach/1` function.
  """

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
  @spec get_option(t(), atom(), term()) :: term()
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
  @spec get_private(t(), atom(), default) :: term() | default when default: var
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
  @spec update_private(t(), key :: atom(), default :: term(), (term() -> term())) :: t()
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
  @spec put_private(t(), atom(), term()) :: t()
  def put_private(%MDEx.Pipe{} = pipe, key, value) when is_atom(key) do
    put_in(pipe.private[key], value)
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
  @spec halt(t()) :: t()
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
  @spec halt(t(), Exception.t()) :: {t(), Exception.t()}
  def halt(%MDEx.Pipe{} = pipe, %_{__exception__: true} = exception) do
    {put_in(pipe.halted, true), exception}
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
