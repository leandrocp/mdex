defmodule MDEx.Tree do
  @moduledoc false

  alias MDEx.Alert
  alias MDEx.BlockQuote
  alias MDEx.Code
  alias MDEx.CodeBlock
  alias MDEx.DescriptionDetails
  alias MDEx.DescriptionItem
  alias MDEx.DescriptionList
  alias MDEx.DescriptionTerm
  alias MDEx.Document
  alias MDEx.Emph
  alias MDEx.EscapedTag
  alias MDEx.FootnoteDefinition
  alias MDEx.FootnoteReference
  alias MDEx.FrontMatter
  alias MDEx.Heading
  alias MDEx.HtmlBlock
  alias MDEx.HtmlInline
  alias MDEx.Image
  alias MDEx.Link
  alias MDEx.List
  alias MDEx.ListItem
  alias MDEx.Math
  alias MDEx.MultilineBlockQuote
  alias MDEx.Paragraph
  alias MDEx.SpoileredText
  alias MDEx.Strikethrough
  alias MDEx.Strong
  alias MDEx.Subscript
  alias MDEx.Superscript
  alias MDEx.Table
  alias MDEx.TableCell
  alias MDEx.TableRow
  alias MDEx.TaskItem
  alias MDEx.Text
  alias MDEx.ThematicBreak
  alias MDEx.Underline
  alias MDEx.WikiLink

  def append(%Document{} = document, nodes) when is_list(nodes) do
    Enum.reduce(nodes, document, &append(&2, &1))
  end

  def append(%Document{} = document, node) when is_struct(node), do: append_into(document, node)

  def append(parent, node) when is_struct(parent), do: append_into(%Document{nodes: [parent]}, node)

  defp append_into(%Document{nodes: []} = doc, node) do
    cond do
      list_item?(node) -> %{doc | nodes: [list_from_item(node)]}
      block?(node) -> %{doc | nodes: [node]}
      true -> %{doc | nodes: [%Paragraph{nodes: [normalize_inline(node)]}]}
    end
  end

  defp append_into(%Document{nodes: nodes} = doc, node) do
    last = :lists.last(nodes)

    case {last, node} do
      {%CodeBlock{fenced: f, fence_char: ch, fence_length: len, fence_offset: off, info: info, literal: a} = lb,
       %CodeBlock{fenced: f, fence_char: ch, fence_length: len, fence_offset: off, info: info, literal: b}} ->
        %{doc | nodes: replace_last(nodes, %{lb | literal: merge_codeblock_literals(a, b)})}

      {parent, child} ->
        cond do
          can_contain?(parent, child) ->
            %{doc | nodes: replace_last(nodes, append_child(parent, child))}

          match?(%List{}, parent) and not block?(child) ->
            %List{nodes: items} = parent
            last_item = :lists.last(items)
            updated_item = append_child(last_item, child)
            updated_list = %{parent | nodes: replace_last(items, updated_item)}
            %{doc | nodes: replace_last(nodes, updated_list)}

          list_item?(child) ->
            %{doc | nodes: nodes ++ [list_from_item(child)]}

          block?(child) ->
            %{doc | nodes: nodes ++ [child]}

          true ->
            %{doc | nodes: nodes ++ [%Paragraph{nodes: [normalize_inline(child)]}]}
        end
    end
  end

  defp append_child(%{nodes: nodes} = parent, child) do
    child = normalize_inline(child)

    case nodes do
      [] ->
        %{parent | nodes: [child]}

      _ ->
        last = :lists.last(nodes)

        case {last, child} do
          {%Text{literal: a}, %Text{literal: b}} ->
            %{parent | nodes: replace_last(nodes, %Text{literal: a <> b})}

          {%Code{num_backticks: nb, literal: a}, %Code{num_backticks: nb2, literal: b}} ->
            %{parent | nodes: replace_last(nodes, %Code{num_backticks: max(nb, nb2), literal: a <> b})}

          _ ->
            %{parent | nodes: nodes ++ [child]}
        end
    end
  end

  defp replace_last([_], new), do: [new]
  defp replace_last([h | t], new), do: [h | replace_last(t, new)]

  defp merge_codeblock_literals(a, b) do
    if ends_with_nl?(a), do: a <> b, else: a <> "\n" <> b
  end

  defp ends_with_nl?(<<>>), do: false

  defp ends_with_nl?(bin) do
    :binary.part(bin, byte_size(bin) - 1, 1) == "\n"
  end

  defp normalize_inline(%Code{num_backticks: 0} = n), do: %{n | num_backticks: 1}
  defp normalize_inline(n), do: n

  # Returns true if `parent` can directly contain `child` as per CommonMark rules.
  defp can_contain?(_, %Document{}), do: false
  defp can_contain?(%Document{}, %FrontMatter{}), do: true
  defp can_contain?(%Document{}, child), do: block?(child) and not list_item?(child)

  defp can_contain?(%BlockQuote{}, child), do: block?(child) and not list_item?(child)
  defp can_contain?(%FootnoteDefinition{}, child), do: block?(child) and not list_item?(child)
  defp can_contain?(%DescriptionTerm{}, child), do: block?(child) and not list_item?(child)
  defp can_contain?(%DescriptionDetails{}, child), do: block?(child) and not list_item?(child)
  defp can_contain?(%MultilineBlockQuote{}, child), do: block?(child) and not list_item?(child)
  defp can_contain?(%Alert{}, child), do: block?(child) and not list_item?(child)

  defp can_contain?(%List{}, %ListItem{}), do: true
  defp can_contain?(%List{}, %TaskItem{}), do: true

  defp can_contain?(%DescriptionList{}, %DescriptionItem{}), do: true
  defp can_contain?(%DescriptionItem{}, %DescriptionTerm{}), do: true
  defp can_contain?(%DescriptionItem{}, %DescriptionDetails{}), do: true

  defp can_contain?(%Paragraph{}, child), do: not block?(child)
  defp can_contain?(%Heading{}, child), do: not block?(child)
  defp can_contain?(%Emph{}, child), do: not block?(child)
  defp can_contain?(%Strong{}, child), do: not block?(child)
  defp can_contain?(%Link{}, child), do: not block?(child)
  defp can_contain?(%Image{}, child), do: not block?(child)
  defp can_contain?(%WikiLink{}, child), do: not block?(child)
  defp can_contain?(%Strikethrough{}, child), do: not block?(child)
  defp can_contain?(%Superscript{}, child), do: not block?(child)
  defp can_contain?(%SpoileredText{}, child), do: not block?(child)
  defp can_contain?(%Underline{}, child), do: not block?(child)
  defp can_contain?(%Subscript{}, child), do: not block?(child)
  defp can_contain?(%EscapedTag{}, child), do: not block?(child)

  defp can_contain?(%Table{}, %TableRow{}), do: true
  defp can_contain?(%TableRow{}, %TableCell{}), do: true
  defp can_contain?(%TableCell{}, %Text{}), do: true
  defp can_contain?(%TableCell{}, %Code{}), do: true
  defp can_contain?(%TableCell{}, %Emph{}), do: true
  defp can_contain?(%TableCell{}, %Strong{}), do: true
  defp can_contain?(%TableCell{}, %Link{}), do: true
  defp can_contain?(%TableCell{}, %Image{}), do: true
  defp can_contain?(%TableCell{}, %Strikethrough{}), do: true
  defp can_contain?(%TableCell{}, %HtmlInline{}), do: true
  defp can_contain?(%TableCell{}, %Math{}), do: true
  defp can_contain?(%TableCell{}, %WikiLink{}), do: true
  defp can_contain?(%TableCell{}, %FootnoteReference{}), do: true
  defp can_contain?(%TableCell{}, %Superscript{}), do: true
  defp can_contain?(%TableCell{}, %SpoileredText{}), do: true
  defp can_contain?(%TableCell{}, %Underline{}), do: true
  defp can_contain?(%TableCell{}, %Subscript{}), do: true

  defp can_contain?(_, _), do: false

  defp block?(%Alert{}), do: true
  defp block?(%BlockQuote{}), do: true
  defp block?(%CodeBlock{}), do: true
  defp block?(%DescriptionDetails{}), do: true
  defp block?(%DescriptionItem{}), do: true
  defp block?(%DescriptionList{}), do: true
  defp block?(%DescriptionTerm{}), do: true
  defp block?(%Document{}), do: true
  defp block?(%FootnoteDefinition{}), do: true
  defp block?(%Heading{}), do: true
  defp block?(%HtmlBlock{}), do: true
  defp block?(%ListItem{}), do: true
  defp block?(%List{}), do: true
  defp block?(%MultilineBlockQuote{}), do: true
  defp block?(%Paragraph{}), do: true
  defp block?(%TableCell{}), do: true
  defp block?(%TableRow{}), do: true
  defp block?(%Table{}), do: true
  defp block?(%TaskItem{}), do: true
  defp block?(%ThematicBreak{}), do: true
  defp block?(_), do: false

  defp list_item?(%ListItem{}), do: true
  defp list_item?(%TaskItem{}), do: true
  defp list_item?(_), do: false

  defp list_from_item(%ListItem{} = item) do
    %List{
      nodes: [item],
      list_type: item.list_type,
      marker_offset: item.marker_offset,
      padding: item.padding,
      start: item.start,
      delimiter: item.delimiter,
      bullet_char: item.bullet_char,
      tight: item.tight,
      is_task_list: item.is_task_list
    }
  end

  defp list_from_item(%TaskItem{} = task) do
    %List{nodes: [task], tight: false, is_task_list: true}
  end
end
