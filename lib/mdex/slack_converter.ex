defmodule MDEx.SlackConverter do
  @moduledoc false

  alias MDEx.Document

  @typedoc "Conversion options"
  @type options :: keyword()
  @typep conversion_result :: {:ok, String.t()} | {:error, term()}

  @doc """
  Convert an MDEx document to Slack mrkdwn format.

  ## Examples

      iex> doc = %MDEx.Document{nodes: [%MDEx.Text{literal: "Hello"}]}
      iex> MDEx.SlackConverter.convert(doc, [])
      {:ok, "Hello"}

  """
  @spec convert(Document.t(), options()) :: {:ok, String.t()} | {:error, term()}
  def convert(%Document{nodes: nodes}, options) do
    convert_nodes(nodes, options)
  end

  @spec convert_nodes([term()], options()) :: conversion_result()
  defp convert_nodes(nodes, options) do
    reduce_text(nodes, fn node -> convert_node(node, options) end)
  end

  @spec convert_node(term(), options()) :: conversion_result()
  defp convert_node(node, options) do
    custom_converters = Keyword.get(options, :custom_converters, %{})
    node_type = if is_map(node), do: Map.get(node, :__struct__)

    case Map.get(custom_converters, node_type) do
      converter when is_function(converter, 2) ->
        case converter.(node, options) do
          :skip -> {:ok, ""}
          {:error, reason} -> {:error, {:custom_converter_error, reason}}
          text when is_binary(text) -> {:ok, text}
          other -> {:error, {:custom_converter_error, "Custom converter returned invalid value: #{inspect(other)}"}}
        end

      nil ->
        default_convert_node(node, options)
    end
  end

  @spec reduce_text(Enumerable.t(), (term() -> conversion_result())) :: conversion_result()
  defp reduce_text(items, converter) do
    items
    |> Enum.reduce_while([], fn item, acc ->
      case converter.(item) do
        {:ok, text} -> {:cont, [text | acc]}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:error, _reason} = error -> error
      parts -> {:ok, parts |> Enum.reverse() |> IO.iodata_to_binary()}
    end
  end

  @spec default_convert_node(term(), options()) :: conversion_result()
  defp default_convert_node(node, options)

  # Document
  defp default_convert_node(%MDEx.Document{nodes: nodes}, options) do
    convert_nodes(nodes, options)
  end

  # Paragraph
  defp default_convert_node(%MDEx.Paragraph{nodes: nodes}, options) do
    with {:ok, text} <- convert_nodes(nodes, options) do
      {:ok, text <> "\n"}
    end
  end

  # Text
  defp default_convert_node(%MDEx.Text{literal: text}, _options) do
    {:ok, text}
  end

  # Strong (bold) -> *text*
  defp default_convert_node(%MDEx.Strong{nodes: nodes}, options) do
    with {:ok, text} <- convert_nodes(nodes, options) do
      {:ok, "*" <> text <> "*"}
    end
  end

  # Emph (italic) -> _text_
  defp default_convert_node(%MDEx.Emph{nodes: nodes}, options) do
    with {:ok, text} <- convert_nodes(nodes, options) do
      {:ok, "_" <> text <> "_"}
    end
  end

  # Inline code -> `code`
  defp default_convert_node(%MDEx.Code{literal: code}, _options) do
    {:ok, "`" <> code <> "`"}
  end

  # Code block -> triple backtick, no language tag
  defp default_convert_node(%MDEx.CodeBlock{literal: code}, _options) do
    {:ok, "```\n" <> String.trim_trailing(code, "\n") <> "\n```\n"}
  end

  # Headings -> *bold text* (Slack ignores # headings)
  defp default_convert_node(%MDEx.Heading{nodes: nodes}, options) do
    with {:ok, text} <- convert_nodes(nodes, options) do
      {:ok, "*" <> text <> "*\n"}
    end
  end

  # Link -> <url|label>
  defp default_convert_node(%MDEx.Link{url: url, nodes: nodes}, options) do
    with {:ok, label} <- convert_nodes(nodes, options) do
      {:ok, "<" <> url <> "|" <> label <> ">"}
    end
  end

  # Strikethrough -> ~text~
  defp default_convert_node(%MDEx.Strikethrough{nodes: nodes}, options) do
    with {:ok, text} <- convert_nodes(nodes, options) do
      {:ok, "~" <> text <> "~"}
    end
  end

  # BlockQuote -> > text
  defp default_convert_node(%MDEx.BlockQuote{nodes: nodes}, options) do
    with {:ok, inner} <- convert_nodes(nodes, options) do
      text =
        inner
        |> String.split("\n")
        |> Enum.map_join("\n", fn
          "" -> ""
          line -> "> " <> line
        end)

      {:ok, text}
    end
  end

  # Unordered list
  defp default_convert_node(%MDEx.List{list_type: :bullet, nodes: items}, options) do
    convert_nodes(items, options)
  end

  # Ordered list
  defp default_convert_node(%MDEx.List{list_type: :ordered, tight: _tight, nodes: items}, options) do
    items
    |> Enum.with_index(1)
    |> reduce_text(fn {item, index} -> convert_list_item(item, "#{index}. ", options) end)
  end

  # Generic list fallback
  defp default_convert_node(%MDEx.List{nodes: items}, options) do
    convert_nodes(items, options)
  end

  # ListItem for bullet lists
  defp default_convert_node(%MDEx.ListItem{list_type: :bullet, nodes: children}, options) do
    convert_list_item(%MDEx.ListItem{nodes: children}, "- ", options)
  end

  # ListItem for ordered lists (index unknown at this level; handled by List above)
  defp default_convert_node(%MDEx.ListItem{nodes: children}, options) do
    convert_list_item(%MDEx.ListItem{nodes: children}, "- ", options)
  end

  # SoftBreak -> space
  defp default_convert_node(%MDEx.SoftBreak{}, _options) do
    {:ok, " "}
  end

  # LineBreak -> newline
  defp default_convert_node(%MDEx.LineBreak{}, _options) do
    {:ok, "\n"}
  end

  # ThematicBreak -> horizontal separator text
  defp default_convert_node(%MDEx.ThematicBreak{}, _options) do
    {:ok, "---\n"}
  end

  # Image -> <url|alt>
  defp default_convert_node(%MDEx.Image{url: url, title: title}, _options) do
    label = if title && title != "", do: title, else: url
    {:ok, "<" <> url <> "|" <> label <> ">"}
  end

  # HtmlBlock and HtmlInline -> strip tags, pass through text
  defp default_convert_node(%MDEx.HtmlBlock{literal: html}, _options) do
    {:ok, strip_html(html) <> "\n"}
  end

  defp default_convert_node(%MDEx.HtmlInline{literal: html}, _options) do
    {:ok, strip_html(html)}
  end

  # Raw -> pass through
  defp default_convert_node(%MDEx.Raw{literal: content}, _options) do
    {:ok, content}
  end

  # ShortCode (emoji)
  defp default_convert_node(%MDEx.ShortCode{emoji: emoji}, _options) do
    {:ok, emoji}
  end

  # FrontMatter -> skip
  defp default_convert_node(%MDEx.FrontMatter{}, _options) do
    {:ok, ""}
  end

  # Fallback for unknown node types
  defp default_convert_node(node, options) do
    cond do
      is_map(node) && Map.has_key?(node, :literal) && is_binary(node.literal) ->
        {:ok, node.literal}

      is_map(node) && Map.has_key?(node, :nodes) && is_list(node.nodes) ->
        convert_nodes(node.nodes, options)

      true ->
        {:ok, ""}
    end
  end

  # Helper: convert a ListItem, prepending the given prefix
  defp convert_list_item(%{nodes: children}, prefix, options) do
    # Extract text content from paragraphs and nested lists
    {paragraph_nodes, nested_lists} =
      Enum.split_with(children, fn node -> not match?(%MDEx.List{}, node) end)

    with {:ok, text} <-
           reduce_text(paragraph_nodes, fn
             %MDEx.Paragraph{nodes: p_nodes} -> convert_nodes(p_nodes, options)
             node -> convert_node(node, options)
           end),
         {:ok, nested} <- convert_nodes(nested_lists, options) do
      {:ok, prefix <> text <> "\n" <> nested}
    end
  end

  # Helper: strip HTML tags
  defp strip_html(html) do
    Regex.replace(~r/<[^>]+>/, html, "")
  end
end
