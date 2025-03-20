defmodule MDEx.Pipe do
  @moduledoc """
  MDEx.Pipe is a Req-like API to transform Markdown documents.

  In short, plugins:

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

  As an example, let's write that Mermaid plugin to see how it works:

  ## Writing Plugins

  In order to render Mermaid diagrams, we need to inject this `<script>` into the document,
  as outlined in their [docs](https://mermaid.js.org/intro/#installation):

      <script type="module">
        import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
        mermaid.initialize({ startOnLoad: true });
      </script>

  And we'll also make the `:version` option available to let users load a specific version,
  but defaults to latest:

      MDEx.new() |> MDExMermaid.attach()

  Or to customize the version:

      MDEx.new() |> MDExMermaid.attach(version: "11")

  Let's get into the actual code, with comments to explain each part:

  ```elixir
  defmodule MDExMermaid do
    alias MDEx.Pipe

    @latest_version "11"

    def attach(pipe, options \\ []) do
      pipe
      # register with prefix `:mermaid_` to avoid conflicts with other plugins
      |> Pipe.register_options([:mermaid_version])
      # and merge it so we can access it later with `get_option/2`
      |> Pipe.merge_options(options)
      |> Pipe.prepend_steps(transform: &transform/1)
    end

    # where the actual transformation happens when the pipeline is executed:
    #   - injects the script node into the document
    #   - transforms code blocks starting with `mermaid` into `<pre class="mermaid">` to the mermaid script can find and render the diagrams
    defp transform(pipe) do
      script_node = script_node(pipe)

      document = 
        MDEx.traverse_and_update(pipe.document, fn
          # inject the mermaid script into the document
          %MDEx.Document{nodes: nodes} = document ->
            nodes = [script_node | nodes]
            %{document | nodes: nodes}

          # pattern match code blocks tagged as "mermaid"
          # and inject the mermaid <pre> block without escaping the content
          %MDEx.CodeBlock{info: "mermaid", literal: code, nodes: nodes} ->
            %MDEx.HtmlBlock{
              literal: "<pre class=\\"mermaid\\">\#\{code\}</pre>",
              nodes: nodes
            }

          # ignore other nodes
          node ->
            node
        end)

      %{pipe | document: document}
    end

    defp script_node(pipe) do
      # get the version, either passed in `attach/2` or the default one
      version = Pipe.get_option(pipe, :mermaid_version, @latest_version)

      # will inject a raw html block into the document
      %MDEx.HtmlBlock{
        literal: \"\"\"
        <script type="module">
          import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@\#\{version\}/dist/mermaid.esm.min.mjs';
          mermaid.initialize({ startOnLoad: true });
        </script>
        \"\"\"}
    end
  end
  ```

  Now whenever that plugin is attached to the pipeline, it will inject run the `transform/1` function before other steps.

  """

  defstruct document: "",
            options: [],
            registered_options: MapSet.new(),
            halted: false,
            steps: [],
            current_steps: [],
            private: %{}

  @type t :: %__MODULE__{
          document: String.t() | MDEx.Document.t(),
          options: MDEx.options(),
          halted: boolean(),
          steps: keyword(),
          private: map()
        }

  @doc false
  def new(options) do
    {document, options} = Keyword.pop(options, :document)

    %__MODULE__{
      document: document,
      options: options
    }
  end

  @spec register_options(t(), [atom()]) :: t()
  def register_options(%MDEx.Pipe{} = pipe, options) when is_list(options) do
    update_in(pipe.registered_options, &MapSet.union(&1, MapSet.new(options)))
  end

  @spec merge_options(t(), keyword()) :: t()
  def merge_options(%MDEx.Pipe{} = pipe, options) when is_list(options) do
    validate_options(pipe, options)
    update_in(pipe.options, &Keyword.merge(&1, options))
  end

  @doc false
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
    :ok
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

  @spec get_option(t(), atom(), term()) :: term()
  def get_option(%MDEx.Pipe{} = pipe, key, default \\ nil) when is_atom(key) do
    Keyword.get(pipe.options, key, default)
  end

  @spec get_private(t(), atom(), default) :: term() | default when default: var
  def get_private(%MDEx.Pipe{} = pipe, key, default \\ nil) when is_atom(key) do
    Map.get(pipe.private, key, default)
  end

  @spec update_private(t(), key :: atom(), default :: term(), (term() -> term())) :: t()
  def update_private(%MDEx.Pipe{} = pipe, key, default, fun) when is_atom(key) and is_function(fun, 1) do
    update_in(pipe.private, &Map.update(&1, key, default, fun))
  end

  @spec put_private(t(), atom(), term()) :: t()
  def put_private(%MDEx.Pipe{} = pipe, key, value) when is_atom(key) do
    put_in(pipe.private[key], value)
  end

  # TODO: error steps?
  # @spec append_request_steps(t(), keyword(request_step())) :: t()
  def append_steps(pipe, steps) do
    %{
      pipe
      | steps: pipe.steps ++ steps,
        current_steps: pipe.current_steps ++ Keyword.keys(steps)
    }
  end

  # @spec prepend_request_steps(t(), keyword(request_step())) :: t()
  def prepend_steps(pipe, steps) do
    %{
      pipe
      | steps: steps ++ pipe.steps,
        current_steps: Keyword.keys(steps) ++ pipe.current_steps
    }
  end

  @spec halt(t()) :: t()
  def halt(%MDEx.Pipe{} = pipe) do
    put_in(pipe.halted, true)
  end

  @spec halt(t(), Exception.t()) :: {t(), Exception.t()}
  def halt(%MDEx.Pipe{} = pipe, %_{__exception__: true} = exception) do
    {put_in(pipe.halted, true), exception}
  end

  @doc false
  @spec run(t()) :: {t(), formatted :: String.t() | error :: Exception.t()}
  def run(pipe)

  def run(%MDEx.Pipe{document: document} = pipe) when is_binary(document) do
    do_run(%{pipe | document: MDEx.parse_document!(document, pipe.options)})
  end

  def run(%MDEx.Pipe{document: %MDEx.Document{}} = pipe) do
    do_run(pipe)
  end

  def run(%MDEx.Pipe{document: document} = pipe) do
    do_run(%{pipe | document: MDEx.Document.wrap(document)})
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
        run(%{pipe | current_steps: rest})
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
