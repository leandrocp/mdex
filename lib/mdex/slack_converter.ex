defmodule MDEx.SlackConverter do
  @moduledoc false

  alias MDEx.Document

  @typedoc "Conversion options"
  @type options :: keyword()

  @spec convert(Document.t(), options()) :: {:ok, String.t()} | {:error, term()}
  def convert(%Document{nodes: nodes}, options) do
    context = %{list_depth: 0, link_label: false, unsafe: Keyword.get(options, :unsafe, false), styles: MapSet.new()}
    {:ok, nodes |> render_nodes(context) |> IO.iodata_to_binary()}
  end

  defp render_nodes(nodes, context), do: Enum.map(nodes, &render_node(&1, context))

  defp render_node(node, context)

  defp render_node(%MDEx.Document{nodes: nodes}, context), do: render_nodes(nodes, context)
  defp render_node(%MDEx.Paragraph{nodes: nodes}, context), do: [render_nodes(nodes, context), "\n"]
  defp render_node(%MDEx.Text{literal: text}, _context), do: escape_text(text)
  defp render_node(%MDEx.Strong{nodes: nodes}, context), do: render_style(:strong, "*", nodes, context)
  defp render_node(%MDEx.Emph{nodes: nodes}, context), do: render_style(:emph, "_", nodes, context)
  defp render_node(%MDEx.Code{literal: code}, _context), do: ["`", escape_text(code), "`"]

  defp render_node(%MDEx.CodeBlock{literal: code}, _context) do
    ["```\n", String.trim_trailing(code, "\n"), "\n```\n"]
  end

  defp render_node(%MDEx.Heading{nodes: nodes}, context), do: [render_style(:strong, "*", nodes, context), "\n"]

  defp render_node(%MDEx.Link{url: url, nodes: nodes}, context) do
    label = render_nodes(nodes, %{context | link_label: true})

    case render_url(url, context) do
      nil -> label
      url -> ["<", escape_link_part(url), "|", label, ">"]
    end
  end

  defp render_node(%MDEx.WikiLink{url: url, nodes: nodes}, context) do
    label = render_nodes(nodes, %{context | link_label: true})

    case render_url(url, context) do
      nil -> label
      url -> ["<", escape_link_part(url), "|", label, ">"]
    end
  end

  defp render_node(%MDEx.Strikethrough{nodes: nodes}, context), do: render_style(:strike, "~", nodes, context)
  defp render_node(%MDEx.Underline{nodes: nodes}, context), do: render_nodes(nodes, context)
  defp render_node(%MDEx.Highlight{nodes: nodes}, context), do: render_nodes(nodes, context)
  defp render_node(%MDEx.Insert{nodes: nodes}, context), do: render_nodes(nodes, context)
  defp render_node(%MDEx.Subscript{nodes: nodes}, context), do: render_nodes(nodes, context)
  defp render_node(%MDEx.Superscript{nodes: nodes}, context), do: render_nodes(nodes, context)
  defp render_node(%MDEx.Subtext{nodes: nodes}, context), do: render_nodes(nodes, context)
  defp render_node(%MDEx.SpoileredText{nodes: nodes}, context), do: render_nodes(nodes, context)

  defp render_node(%MDEx.BlockQuote{nodes: nodes}, context), do: render_quote(nodes, context)
  defp render_node(%MDEx.MultilineBlockQuote{nodes: nodes}, context), do: render_quote(nodes, context)

  defp render_node(%MDEx.List{nodes: items}, context), do: render_list(items, context)

  defp render_node(%MDEx.ListItem{} = item, context), do: render_list_item(item, context, "- ")

  defp render_node(%MDEx.TaskItem{checked: checked, nodes: nodes}, context) do
    marker = if checked, do: "[x] ", else: "[ ] "
    render_list_item(%MDEx.ListItem{nodes: nodes}, context, "- " <> marker)
  end

  defp render_node(%MDEx.SoftBreak{}, _context), do: " "
  defp render_node(%MDEx.LineBreak{}, _context), do: "\n"
  defp render_node(%MDEx.ThematicBreak{}, _context), do: "---\n"

  defp render_node(%MDEx.Image{url: url, title: title, nodes: nodes}, context) do
    label = if title in [nil, ""], do: render_nodes(nodes, %{context | link_label: true}), else: escape_text(title)

    case render_url(url, context) do
      nil -> label
      url -> ["<", escape_link_part(url), "|", label, ">"]
    end
  end

  defp render_node(%MDEx.HtmlBlock{literal: html}, _context), do: [escape_text(html), "\n"]
  defp render_node(%MDEx.HtmlInline{literal: html}, _context), do: escape_text(html)
  defp render_node(%MDEx.HeexBlock{literal: heex}, _context), do: [escape_text(heex), "\n"]
  defp render_node(%MDEx.HeexInline{literal: heex}, _context), do: escape_text(heex)
  defp render_node(%MDEx.Raw{literal: content}, _context), do: escape_text(content)
  defp render_node(%MDEx.ShortCode{emoji: emoji}, _context), do: emoji
  defp render_node(%MDEx.Math{literal: math}, _context), do: escape_text(math)
  defp render_node(%MDEx.FrontMatter{}, _context), do: ""
  defp render_node(%MDEx.FootnoteReference{name: name}, _context), do: ["[^", escape_text(name), "]"]
  defp render_node(%MDEx.FootnoteDefinition{nodes: nodes}, context), do: render_nodes(nodes, context)
  defp render_node(%MDEx.Alert{title: title, nodes: nodes}, context), do: render_alert(title, nodes, context)
  defp render_node(%MDEx.Table{nodes: rows}, context), do: render_nodes(rows, context)
  defp render_node(%MDEx.TableRow{nodes: cells}, context), do: [cells |> Enum.map(&render_node(&1, context)) |> Enum.intersperse(" | "), "\n"]
  defp render_node(%MDEx.TableCell{nodes: nodes}, context), do: render_nodes(nodes, context)
  defp render_node(%MDEx.DescriptionList{nodes: nodes}, context), do: render_nodes(nodes, context)
  defp render_node(%MDEx.DescriptionItem{nodes: nodes}, context), do: render_nodes(nodes, context)
  defp render_node(%MDEx.DescriptionTerm{nodes: nodes}, context), do: [render_nodes(nodes, context), "\n"]
  defp render_node(%MDEx.DescriptionDetails{nodes: nodes}, context), do: [": ", render_nodes(nodes, context), "\n"]
  defp render_node(%MDEx.Escaped{}, _context), do: ""
  defp render_node(%MDEx.EscapedTag{literal: literal}, _context), do: escape_text(literal)
  defp render_node(%MDEx.BlockDirective{info: info, nodes: nodes}, context), do: ["*", escape_text(info), "*\n", render_nodes(nodes, context)]

  defp render_node(%{literal: literal}, _context) when is_binary(literal), do: escape_text(literal)
  defp render_node(%{nodes: nodes}, context) when is_list(nodes), do: render_nodes(nodes, context)
  defp render_node(_node, _context), do: ""

  defp render_quote(nodes, context) do
    nodes
    |> render_nodes(context)
    |> IO.iodata_to_binary()
    |> String.split("\n", trim: false)
    |> Enum.map_join("\n", fn
      "" -> ""
      line -> "> " <> line
    end)
  end

  defp render_alert(title, nodes, context) do
    title = if title in [nil, ""], do: [], else: ["*", escape_text(title), "*\n"]
    [title, render_quote(nodes, context)]
  end

  defp render_list(items, context) do
    items
    |> Enum.with_index(1)
    |> Enum.map(fn
      {%MDEx.ListItem{list_type: :ordered} = item, index} -> render_list_item(item, context, "#{index}. ")
      {item, _index} -> render_node(item, context)
    end)
  end

  defp render_list_item(%{nodes: children}, context, marker) do
    {content, nested_lists} = Enum.split_with(children, &(not match?(%MDEx.List{}, &1)))
    indent = String.duplicate("  ", context.list_depth)

    text =
      content
      |> Enum.map(fn
        %MDEx.Paragraph{nodes: paragraph_nodes} -> render_nodes(paragraph_nodes, context)
        node -> render_node(node, context)
      end)

    nested_context = %{context | list_depth: context.list_depth + 1}
    nested = render_nodes(nested_lists, nested_context)

    [indent, marker, text, "\n", nested]
  end

  defp render_style(style, marker, nodes, context) do
    if context.link_label or MapSet.member?(context.styles, style) do
      render_nodes(nodes, context)
    else
      context = %{context | styles: MapSet.put(context.styles, style)}
      [marker, render_nodes(nodes, context), marker]
    end
  end

  defp escape_text(text), do: escape_text(text, [])

  defp escape_text(<<>>, acc), do: Enum.reverse(acc)
  defp escape_text(<<"&", rest::binary>>, acc), do: escape_text(rest, ["&amp;" | acc])
  defp escape_text(<<"<", rest::binary>>, acc), do: escape_text(rest, ["&lt;" | acc])
  defp escape_text(<<">", rest::binary>>, acc), do: escape_text(rest, ["&gt;" | acc])
  defp escape_text(<<char, rest::binary>>, acc), do: escape_text(rest, [<<char>> | acc])

  defp escape_link_part(text), do: text |> to_string() |> escape_link_part([])

  defp escape_link_part(<<>>, acc), do: Enum.reverse(acc)
  defp escape_link_part(<<"&", rest::binary>>, acc), do: escape_link_part(rest, ["&amp;" | acc])
  defp escape_link_part(<<"<", rest::binary>>, acc), do: escape_link_part(rest, ["&lt;" | acc])
  defp escape_link_part(<<">", rest::binary>>, acc), do: escape_link_part(rest, ["&gt;" | acc])
  defp escape_link_part(<<"|", rest::binary>>, acc), do: escape_link_part(rest, ["%7C" | acc])
  defp escape_link_part(<<char, rest::binary>>, acc), do: escape_link_part(rest, [<<char>> | acc])

  defp render_url(url, %{unsafe: true}) when is_binary(url), do: url

  defp render_url(url, _context) when is_binary(url) do
    if MDExNative.Comrak.dangerous_url?(url), do: nil, else: url
  end

  defp render_url(url, _context), do: url
end
