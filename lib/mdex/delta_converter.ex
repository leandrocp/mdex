defmodule MDEx.DeltaConverter do
  @moduledoc """
  Converts MDEx documents to Quill Delta format.

  Quill Delta is a format for describing rich text documents as a series of
  operations. Each operation can insert text with optional formatting attributes.

  This module implements the Phase 1 conversion for core CommonMark nodes:
  - Document (root container)
  - Paragraph
  - Text content
  - Basic formatting: Strong (bold), Emphasis (italic), Code (inline code)
  - Headings (1-6)
  - Line breaks (SoftBreak, LineBreak)
  """

  alias MDEx.Document

  @typedoc "Delta operation map"
  @type delta_op :: %{
    required(:insert) => String.t(),
    optional(:attributes) => map()
  }

  @typedoc "Complete Delta document"
  @type delta :: %{ops: [delta_op()]}

  @typedoc "Conversion options"
  @type options :: %{
    custom_converters: %{atom() => function()}
  }

  @doc """
  Convert an MDEx document to Quill Delta format.

  ## Examples

      iex> doc = %MDEx.Document{nodes: [%MDEx.Text{literal: "Hello"}]}
      iex> MDEx.DeltaConverter.convert(doc, %{})
      {:ok, %{"ops" => [%{"insert" => "Hello"}]}}

  """
  @spec convert(Document.t(), options()) :: {:ok, delta()} | {:error, term()}
  def convert(%Document{nodes: nodes}, options) do
    try do
      ops = convert_nodes(nodes, [], options)
      {:ok, %{"ops" => ops}}
    rescue
      error -> {:error, error}
    catch
      error -> {:error, error}
    end
  end

  # Convert a list of nodes, accumulating operations and current formatting state
  @spec convert_nodes([term()], [map()], options()) :: [delta_op()]
  defp convert_nodes([], _current_attrs, _options), do: []

  defp convert_nodes([node | rest], current_attrs, options) do
    node_ops = convert_node(node, current_attrs, options)
    rest_ops = convert_nodes(rest, current_attrs, options)
    node_ops ++ rest_ops
  end

  # Convert individual nodes to delta operations
  @spec convert_node(term(), [map()], options()) :: [delta_op()]
  defp convert_node(node, current_attrs, options)

  # Document - process child nodes
  defp convert_node(%MDEx.Document{nodes: nodes}, current_attrs, options) do
    convert_nodes(nodes, current_attrs, options)
  end

  # Paragraph - process children, add paragraph break at end
  defp convert_node(%MDEx.Paragraph{nodes: nodes}, current_attrs, options) do
    child_ops = convert_nodes(nodes, current_attrs, options)
    child_ops ++ [%{"insert" => "\n"}]
  end

  # Text - insert literal content
  defp convert_node(%MDEx.Text{literal: text}, current_attrs, _options) do
    attrs = merge_attributes(current_attrs)
    if map_size(attrs) == 0 do
      [%{"insert" => text}]
    else
      [%{"insert" => text, "attributes" => attrs}]
    end
  end

  # Strong (bold) - add bold attribute to children
  defp convert_node(%MDEx.Strong{nodes: nodes}, current_attrs, options) do
    new_attrs = [%{"bold" => true} | current_attrs]
    convert_nodes(nodes, new_attrs, options)
  end

  # Emph (italic) - add italic attribute to children
  defp convert_node(%MDEx.Emph{nodes: nodes}, current_attrs, options) do
    new_attrs = [%{"italic" => true} | current_attrs]
    convert_nodes(nodes, new_attrs, options)
  end

  # Code (inline) - add code attribute to children
  defp convert_node(%MDEx.Code{literal: code}, current_attrs, _options) do
    attrs = merge_attributes([%{"code" => true} | current_attrs])
    [%{"insert" => code, "attributes" => attrs}]
  end

  # Headings - process children with header attribute on line break
  defp convert_node(%MDEx.Heading{nodes: nodes, level: level}, current_attrs, options) do
    child_ops = convert_nodes(nodes, current_attrs, options)
    header_attrs = merge_attributes([%{"header" => level} | current_attrs])
    child_ops ++ [%{"insert" => "\n", "attributes" => header_attrs}]
  end

  # SoftBreak - insert space (Quill doesn't distinguish soft/hard breaks in plain text)
  defp convert_node(%MDEx.SoftBreak{}, _current_attrs, _options) do
    [%{"insert" => " "}]
  end

  # LineBreak - insert explicit line break
  defp convert_node(%MDEx.LineBreak{}, _current_attrs, _options) do
    [%{"insert" => "\n"}]
  end

  # Custom converter fallback
  defp convert_node(node, current_attrs, %{custom_converters: converters}) do
    node_type = node.__struct__
    case Map.get(converters, node_type) do
      nil ->
        # Unknown node type - try to extract text content or skip
        extract_text_content(node, current_attrs)
      converter when is_function(converter, 3) ->
        converter.(node, current_attrs, %{custom_converters: converters})
      _ ->
        []
    end
  end

  defp convert_node(node, current_attrs, _options) do
    # Unknown node type without custom converters
    extract_text_content(node, current_attrs)
  end

  # Helper to extract text content from unknown nodes
  defp extract_text_content(%{literal: text}, current_attrs) when is_binary(text) do
    attrs = merge_attributes(current_attrs)
    if map_size(attrs) == 0 do
      [%{"insert" => text}]
    else
      [%{"insert" => text, "attributes" => attrs}]
    end
  end

  defp extract_text_content(%{nodes: nodes}, current_attrs) when is_list(nodes) do
    # Try to process child nodes for containers we don't explicitly handle
    convert_nodes(nodes, current_attrs, %{custom_converters: %{}})
  end

  defp extract_text_content(_node, _current_attrs) do
    # Unknown node structure - skip it
    []
  end

  # Merge attribute maps from the attribute stack
  @spec merge_attributes([map()]) :: map()
  defp merge_attributes(attr_list) do
    Enum.reduce(attr_list, %{}, fn attrs, acc ->
      Map.merge(acc, attrs)
    end)
  end
end