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

    # |> Pipe.prepend_steps(put_default_options: &put_default_options/1)
  end

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

  def put_node_in_document_root(pip, node, position \\ :top)

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

  def update_node(%Pipe{} = pipe, selector, fun) when is_function(selector, 1) and is_function(fun, 1) do
    document =
      update_in(pipe.document, [:document, Access.key!(:nodes), Access.all(), selector], fn node ->
        fun.(node)
      end)

    %{pipe | document: document}
  end
end
