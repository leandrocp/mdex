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
      {:ok, [%{"insert" => "Hello"}]}

  """
  @spec convert(Document.t(), options()) :: {:ok, [delta_op()]} | {:error, term()}
  def convert(%Document{nodes: nodes}, options) do
    try do
      ops = convert_nodes(nodes, [], options)
      {:ok, ops}
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
  defp convert_node(node, current_attrs, options) do
    # Check for custom converters first
    case get_in(options, [:custom_converters, node.__struct__]) do
      converter when is_function(converter, 2) ->
        case converter.(node, options) do
          :skip -> []
          {:error, reason} -> throw({:custom_converter_error, reason})
          ops when is_list(ops) -> ops
          other -> throw({:custom_converter_error, "Custom converter returned invalid value: #{inspect(other)}"})
        end

      nil ->
        # Use default conversion
        default_convert_node(node, current_attrs, options)
    end
  end

  # Default conversion for all node types
  @spec default_convert_node(term(), [map()], options()) :: [delta_op()]
  defp default_convert_node(node, current_attrs, options)

  # Document - process child nodes
  defp default_convert_node(%MDEx.Document{nodes: nodes}, current_attrs, options) do
    convert_nodes(nodes, current_attrs, options)
  end

  # Paragraph - process children, add paragraph break at end
  defp default_convert_node(%MDEx.Paragraph{nodes: nodes}, current_attrs, options) do
    child_ops = convert_nodes(nodes, current_attrs, options)
    child_ops ++ [%{"insert" => "\n"}]
  end

  # Text - insert literal content
  defp default_convert_node(%MDEx.Text{literal: text}, current_attrs, _options) do
    attrs = merge_attributes(current_attrs)

    if map_size(attrs) == 0 do
      [%{"insert" => text}]
    else
      [%{"insert" => text, "attributes" => attrs}]
    end
  end

  # Strong (bold) - add bold attribute to children
  defp default_convert_node(%MDEx.Strong{nodes: nodes}, current_attrs, options) do
    new_attrs = [%{"bold" => true} | current_attrs]
    convert_nodes(nodes, new_attrs, options)
  end

  # Emph (italic) - add italic attribute to children
  defp default_convert_node(%MDEx.Emph{nodes: nodes}, current_attrs, options) do
    new_attrs = [%{"italic" => true} | current_attrs]
    convert_nodes(nodes, new_attrs, options)
  end

  # Code (inline) - add code attribute to children
  defp default_convert_node(%MDEx.Code{literal: code}, current_attrs, _options) do
    attrs = merge_attributes([%{"code" => true} | current_attrs])
    [%{"insert" => code, "attributes" => attrs}]
  end

  # Headings - process children with header attribute on line break
  defp default_convert_node(%MDEx.Heading{nodes: nodes, level: level}, current_attrs, options) do
    child_ops = convert_nodes(nodes, current_attrs, options)
    header_attrs = merge_attributes([%{"header" => level} | current_attrs])
    child_ops ++ [%{"insert" => "\n", "attributes" => header_attrs}]
  end

  # SoftBreak - insert space (Quill doesn't distinguish soft/hard breaks in plain text)
  defp default_convert_node(%MDEx.SoftBreak{}, _current_attrs, _options) do
    [%{"insert" => " "}]
  end

  # LineBreak - insert explicit line break
  defp default_convert_node(%MDEx.LineBreak{}, _current_attrs, _options) do
    [%{"insert" => "\n"}]
  end

  # Phase 2: Exotic Nodes with Custom Attributes

  # Strikethrough - add strike attribute to children
  defp default_convert_node(%MDEx.Strikethrough{nodes: nodes}, current_attrs, options) do
    new_attrs = [%{"strike" => true} | current_attrs]
    convert_nodes(nodes, new_attrs, options)
  end

  # Underline - add underline attribute to children
  defp default_convert_node(%MDEx.Underline{nodes: nodes}, current_attrs, options) do
    new_attrs = [%{"underline" => true} | current_attrs]
    convert_nodes(nodes, new_attrs, options)
  end

  # Link - add link attribute to children
  defp default_convert_node(%MDEx.Link{url: url, nodes: nodes}, current_attrs, options) do
    new_attrs = [%{"link" => url} | current_attrs]
    convert_nodes(nodes, new_attrs, options)
  end

  # Image - use custom insert object
  defp default_convert_node(%MDEx.Image{url: url, title: title}, _current_attrs, _options) do
    image_data = %{"image" => url}
    image_data = if title, do: Map.put(image_data, "alt", title), else: image_data
    [%{"insert" => image_data}]
  end

  # BlockQuote - apply blockquote attribute to newlines
  defp default_convert_node(%MDEx.BlockQuote{nodes: nodes}, current_attrs, options) do
    child_ops = convert_nodes(nodes, current_attrs, options)
    apply_block_format(child_ops, %{"blockquote" => true})
  end

  # CodeBlock - insert code with code-block attribute
  defp default_convert_node(%MDEx.CodeBlock{literal: code, info: info}, _current_attrs, _options) do
    attrs = %{"code-block" => true}
    attrs = if info && info != "", do: Map.put(attrs, "code-block-lang", info), else: attrs

    [
      %{"insert" => code},
      %{"insert" => "\n", "attributes" => attrs}
    ]
  end

  # ThematicBreak (HR) - convert to text representation
  defp default_convert_node(%MDEx.ThematicBreak{}, _current_attrs, _options) do
    [%{"insert" => "---\n"}]
  end

  # Lists - support for bullet and ordered
  defp default_convert_node(%MDEx.List{nodes: items}, current_attrs, options) do
    convert_nodes(items, current_attrs, options)
  end

  defp default_convert_node(%MDEx.ListItem{list_type: list_type, nodes: children}, current_attrs, options) do
    # Extract content and apply list formatting
    child_ops =
      Enum.flat_map(children, fn
        %MDEx.Paragraph{nodes: paragraph_children} ->
          convert_nodes(paragraph_children, current_attrs, options)

        node ->
          convert_node(node, current_attrs, options)
      end)

    list_attr =
      case list_type do
        :bullet -> "bullet"
        :ordered -> "ordered"
        _ -> "bullet"
      end

    child_ops ++ [%{"insert" => "\n", "attributes" => %{"list" => list_attr}}]
  end

  # TaskItem - block-level attribute on newline
  defp default_convert_node(%MDEx.TaskItem{checked: checked, nodes: children}, current_attrs, options) do
    # Extract content from children (usually paragraphs)
    child_ops =
      Enum.flat_map(children, fn
        %MDEx.Paragraph{nodes: paragraph_children} ->
          convert_nodes(paragraph_children, current_attrs, options)

        node ->
          convert_node(node, current_attrs, options)
      end)

    # Apply task attribute as block-level on the newline
    task_attrs = %{"list" => "bullet", "task" => checked}
    child_ops ++ [%{"insert" => "\n", "attributes" => task_attrs}]
  end

  # FootnoteReference - inline attribute
  defp default_convert_node(%MDEx.FootnoteReference{name: name}, current_attrs, _options) do
    attrs = merge_attributes([%{"footnote_ref" => name} | current_attrs])
    [%{"insert" => "[^#{name}]", "attributes" => attrs}]
  end

  # FootnoteDefinition - block-level attribute on newline
  defp default_convert_node(%MDEx.FootnoteDefinition{name: name, nodes: children}, current_attrs, options) do
    child_ops = convert_nodes(children, current_attrs, options)

    # Apply footnote definition to the final newline
    case List.last(child_ops) do
      %{"insert" => "\n"} ->
        List.replace_at(child_ops, -1, %{
          "insert" => "\n",
          "attributes" => %{"footnote_definition" => name}
        })

      %{"insert" => "\n", "attributes" => attrs} ->
        List.replace_at(child_ops, -1, %{
          "insert" => "\n",
          "attributes" => Map.put(attrs, "footnote_definition", name)
        })

      _ ->
        # No trailing newline, add one with the attribute
        child_ops ++ [%{"insert" => "\n", "attributes" => %{"footnote_definition" => name}}]
    end
  end

  # Subscript and superscript - inline attributes
  defp default_convert_node(%MDEx.Subscript{nodes: children}, current_attrs, options) do
    new_attrs = [%{"subscript" => true} | current_attrs]
    convert_nodes(children, new_attrs, options)
  end

  defp default_convert_node(%MDEx.Superscript{nodes: children}, current_attrs, options) do
    new_attrs = [%{"superscript" => true} | current_attrs]
    convert_nodes(children, new_attrs, options)
  end

  # Math - inline attribute with type
  defp default_convert_node(%MDEx.Math{literal: math, display_math: display?}, current_attrs, _options) do
    math_type = if display?, do: "display", else: "inline"
    attrs = merge_attributes([%{"math" => math_type} | current_attrs])
    [%{"insert" => math, "attributes" => attrs}]
  end

  # Alerts - custom attributes for type and styling
  defp default_convert_node(%MDEx.Alert{alert_type: type, title: title, nodes: children}, current_attrs, options) do
    child_ops = convert_nodes(children, current_attrs, options)

    alert_attrs = %{"alert" => Atom.to_string(type)}
    alert_attrs = if title, do: Map.put(alert_attrs, "alert_title", title), else: alert_attrs

    apply_block_format(child_ops, alert_attrs)
  end

  # SpoileredText - inline attribute
  defp default_convert_node(%MDEx.SpoileredText{nodes: children}, current_attrs, options) do
    new_attrs = [%{"spoiler" => true} | current_attrs]
    convert_nodes(children, new_attrs, options)
  end

  # WikiLinks - link with wikilink attribute
  defp default_convert_node(%MDEx.WikiLink{url: url, nodes: children}, current_attrs, options) do
    new_attrs = [%{"link" => url, "wikilink" => true} | current_attrs]
    convert_nodes(children, new_attrs, options)
  end

  # Tables - simplified tab-separated text with table attributes
  defp default_convert_node(%MDEx.Table{nodes: rows}, current_attrs, options) do
    convert_nodes(rows, current_attrs, options)
  end

  defp default_convert_node(%MDEx.TableRow{header: is_header, nodes: cells}, current_attrs, options) do
    cell_ops =
      Enum.flat_map(cells, fn cell ->
        cell_content = convert_node(cell, current_attrs, options)
        cell_content ++ [%{"insert" => "\t"}]
      end)

    # Remove last tab, add newline with table attributes
    cell_ops = List.delete_at(cell_ops, -1)
    row_attrs = if is_header, do: %{"table" => "header"}, else: %{"table" => "row"}

    cell_ops ++ [%{"insert" => "\n", "attributes" => row_attrs}]
  end

  defp default_convert_node(%MDEx.TableCell{nodes: children}, current_attrs, options) do
    convert_nodes(children, current_attrs, options)
  end

  # HTML nodes - block vs inline attributes
  defp default_convert_node(%MDEx.HtmlBlock{literal: html}, _current_attrs, _options) do
    [
      %{"insert" => html},
      %{"insert" => "\n", "attributes" => %{"html" => "block"}}
    ]
  end

  defp default_convert_node(%MDEx.HtmlInline{literal: html}, current_attrs, _options) do
    attrs = merge_attributes([%{"html" => "inline"} | current_attrs])
    [%{"insert" => html, "attributes" => attrs}]
  end

  # ShortCode - already processed to emoji, treat as text
  defp default_convert_node(%MDEx.ShortCode{emoji: emoji}, current_attrs, _options) do
    attrs = merge_attributes(current_attrs)

    if map_size(attrs) == 0 do
      [%{"insert" => emoji}]
    else
      [%{"insert" => emoji, "attributes" => attrs}]
    end
  end

  # Raw - pass through as-is
  defp default_convert_node(%MDEx.Raw{literal: content}, current_attrs, _options) do
    attrs = merge_attributes(current_attrs)

    if map_size(attrs) == 0 do
      [%{"insert" => content}]
    else
      [%{"insert" => content, "attributes" => attrs}]
    end
  end

  # FrontMatter - block-level attribute
  defp default_convert_node(%MDEx.FrontMatter{literal: content}, _current_attrs, _options) do
    [
      %{"insert" => content},
      %{"insert" => "\n", "attributes" => %{"front_matter" => true}}
    ]
  end

  # Fallback for unknown node types
  defp default_convert_node(node, current_attrs, _options) do
    # Unknown node type - try to extract text content or skip
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

  # Apply block formatting to newline characters
  @spec apply_block_format([delta_op()], map()) :: [delta_op()]
  defp apply_block_format(ops, block_attributes) do
    Enum.map(ops, fn op ->
      case op do
        %{"insert" => "\n"} ->
          %{"insert" => "\n", "attributes" => block_attributes}

        %{"insert" => "\n", "attributes" => attrs} ->
          %{"insert" => "\n", "attributes" => Map.merge(attrs, block_attributes)}

        other ->
          other
      end
    end)
  end
end
