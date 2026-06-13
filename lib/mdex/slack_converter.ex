defmodule MDEx.SlackConverter do
  @moduledoc false

  alias MDEx.Document

  @typedoc "Conversion options"
  @type options :: keyword()

  @doc """
  Convert an MDEx document to Slack mrkdwn format.

  ## Examples

      iex> doc = %MDEx.Document{nodes: [%MDEx.Text{literal: "Hello"}]}
      iex> MDEx.SlackConverter.convert(doc, [])
      {:ok, "Hello"}

  """
  @spec convert(Document.t(), options()) :: {:ok, String.t()} | {:error, term()}
  def convert(%Document{nodes: nodes}, options) do
    try do
      result = convert_nodes(nodes, options)
      {:ok, result}
    rescue
      error -> {:error, error}
    catch
      error -> {:error, error}
    end
  end

  @spec convert_nodes([term()], options()) :: String.t()
  defp convert_nodes(nodes, options) do
    Enum.map_join(nodes, "", fn node -> convert_node(node, options) end)
  end

  @spec convert_node(term(), options()) :: String.t()
  defp convert_node(node, options) do
    custom_converters = Keyword.get(options, :custom_converters, %{})

    case Map.get(custom_converters, node.__struct__) do
      converter when is_function(converter, 2) ->
        case converter.(node, options) do
          :skip -> ""
          {:error, reason} -> throw({:custom_converter_error, reason})
          text when is_binary(text) -> text
          other -> throw({:custom_converter_error, "Custom converter returned invalid value: #{inspect(other)}"})
        end

      nil ->
        default_convert_node(node, options)
    end
  end

  @spec default_convert_node(term(), options()) :: String.t()
  defp default_convert_node(node, options)

  # Document
  defp default_convert_node(%MDEx.Document{nodes: nodes}, options) do
    convert_nodes(nodes, options)
  end

  # Paragraph
  defp default_convert_node(%MDEx.Paragraph{nodes: nodes}, options) do
    convert_nodes(nodes, options) <> "\n"
  end

  # Text
  defp default_convert_node(%MDEx.Text{literal: text}, _options) do
    text
  end

  # Strong (bold) -> *text*
  defp default_convert_node(%MDEx.Strong{nodes: nodes}, options) do
    "*" <> convert_nodes(nodes, options) <> "*"
  end

  # Emph (italic) -> _text_
  defp default_convert_node(%MDEx.Emph{nodes: nodes}, options) do
    "_" <> convert_nodes(nodes, options) <> "_"
  end

  # Inline code -> `code`
  defp default_convert_node(%MDEx.Code{literal: code}, _options) do
    "`" <> code <> "`"
  end

  # Code block -> triple backtick, no language tag
  defp default_convert_node(%MDEx.CodeBlock{literal: code}, _options) do
    "```\n" <> String.trim_trailing(code, "\n") <> "\n```\n"
  end

  # Headings -> *bold text* (Slack ignores # headings)
  defp default_convert_node(%MDEx.Heading{nodes: nodes}, options) do
    "*" <> convert_nodes(nodes, options) <> "*\n"
  end

  # Link -> <url|label>
  defp default_convert_node(%MDEx.Link{url: url, nodes: nodes}, options) do
    label = convert_nodes(nodes, options)
    "<" <> url <> "|" <> label <> ">"
  end

  # Strikethrough -> ~text~
  defp default_convert_node(%MDEx.Strikethrough{nodes: nodes}, options) do
    "~" <> convert_nodes(nodes, options) <> "~"
  end

  # BlockQuote -> > text
  defp default_convert_node(%MDEx.BlockQuote{nodes: nodes}, options) do
    inner = convert_nodes(nodes, options)

    inner
    |> String.split("\n")
    |> Enum.map_join("\n", fn
      "" -> ""
      line -> "> " <> line
    end)
  end

  # Unordered list
  defp default_convert_node(%MDEx.List{list_type: :bullet, nodes: items}, options) do
    convert_nodes(items, options)
  end

  # Ordered list
  defp default_convert_node(%MDEx.List{list_type: :ordered, tight: _tight, nodes: items}, options) do
    items
    |> Enum.with_index(1)
    |> Enum.map_join("", fn {item, index} ->
      convert_list_item(item, "#{index}. ", options)
    end)
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
    " "
  end

  # LineBreak -> newline
  defp default_convert_node(%MDEx.LineBreak{}, _options) do
    "\n"
  end

  # ThematicBreak -> horizontal separator text
  defp default_convert_node(%MDEx.ThematicBreak{}, _options) do
    "---\n"
  end

  # Image -> <url|alt>
  defp default_convert_node(%MDEx.Image{url: url, title: title}, _options) do
    label = if title && title != "", do: title, else: url
    "<" <> url <> "|" <> label <> ">"
  end

  # HtmlBlock and HtmlInline -> strip tags, pass through text
  defp default_convert_node(%MDEx.HtmlBlock{literal: html}, _options) do
    strip_html(html) <> "\n"
  end

  defp default_convert_node(%MDEx.HtmlInline{literal: html}, _options) do
    strip_html(html)
  end

  # Raw -> pass through
  defp default_convert_node(%MDEx.Raw{literal: content}, _options) do
    content
  end

  # ShortCode (emoji)
  defp default_convert_node(%MDEx.ShortCode{emoji: emoji}, _options) do
    emoji
  end

  # FrontMatter -> skip
  defp default_convert_node(%MDEx.FrontMatter{}, _options) do
    ""
  end

  # Fallback for unknown node types
  defp default_convert_node(node, options) do
    cond do
      is_map(node) && Map.has_key?(node, :literal) && is_binary(node.literal) ->
        node.literal

      is_map(node) && Map.has_key?(node, :nodes) && is_list(node.nodes) ->
        convert_nodes(node.nodes, options)

      true ->
        ""
    end
  end

  # Helper: convert a ListItem, prepending the given prefix
  defp convert_list_item(%{nodes: children}, prefix, options) do
    # Extract text content from paragraphs and nested lists
    {paragraph_nodes, nested_lists} =
      Enum.split_with(children, fn node -> not match?(%MDEx.List{}, node) end)

    text =
      Enum.map_join(paragraph_nodes, "", fn
        %MDEx.Paragraph{nodes: p_nodes} -> convert_nodes(p_nodes, options)
        node -> convert_node(node, options)
      end)

    item_line = prefix <> text <> "\n"

    nested =
      Enum.map_join(nested_lists, "", fn nested_list ->
        convert_node(nested_list, options)
      end)

    item_line <> nested
  end

  # Helper: strip HTML tags
  defp strip_html(html) do
    Regex.replace(~r/<[^>]+>/, html, "")
  end
end
