defmodule MDEx.Tree do
  @moduledoc false

  def append_node(%MDEx.Document{} = document, new_node) do
    append_nodes(document, [new_node])
  end

  def append_nodes(%MDEx.Document{nodes: nodes} = document, new_nodes) when is_list(new_nodes) do
    new_nodes = List.flatten(new_nodes)

    updated_nodes =
      Enum.reduce(new_nodes, nodes, fn
        new_node, [] ->
          [wrap_node(new_node)]

        new_node, acc when is_struct(new_node) ->
          {rightmost, remaining} = List.pop_at(acc, -1)

          case maybe_append_to_node(rightmost, new_node) do
            {:ok, updated_node} -> remaining ++ [updated_node]
            :error -> acc ++ [wrap_node(new_node)]
          end
      end)

    %{document | nodes: updated_nodes}
  end

  def merge(%MDEx.Document{} = document, %MDEx.Document{nodes: nodes}) do
    append_nodes(document, nodes)
  end

  defp maybe_append_to_node(%MDEx.List{list_type: type, nodes: parent_nodes} = parent, %MDEx.List{list_type: type, nodes: new_nodes}) do
    {:ok, %{parent | nodes: parent_nodes ++ new_nodes}}
  end

  defp maybe_append_to_node(%MDEx.ListItem{nodes: child_nodes} = parent, %MDEx.Text{literal: new_text}) do
    case List.last(child_nodes) do
      %MDEx.Text{literal: existing_text} = last_text ->
        updated_text = %{last_text | literal: existing_text <> new_text}
        updated_nodes = List.replace_at(child_nodes, -1, updated_text)
        {:ok, %{parent | nodes: updated_nodes}}

      _ ->
        case try_append_recursive(child_nodes, %MDEx.Text{literal: new_text}) do
          {:ok, updated_children} -> {:ok, %{parent | nodes: updated_children}}
          :error -> :error
        end
    end
  end

  defp maybe_append_to_node(%{nodes: child_nodes} = parent, new_node) do
    if can_contain?(parent, new_node) do
      {:ok, %{parent | nodes: child_nodes ++ [new_node]}}
    else
      case try_append_recursive(child_nodes, new_node) do
        {:ok, updated_children} -> {:ok, %{parent | nodes: updated_children}}
        :error -> :error
      end
    end
  end

  defp maybe_append_to_node(_parent, _new_node), do: :error

  defp try_append_recursive([], _new_node), do: :error

  defp try_append_recursive(nodes, new_node) do
    {rightmost, remaining} = List.pop_at(nodes, -1)

    case maybe_append_to_node(rightmost, new_node) do
      {:ok, updated_node} -> {:ok, remaining ++ [updated_node]}
      :error -> :error
    end
  end

  defp wrap_node(item) when is_struct(item, MDEx.ListItem) or is_struct(item, MDEx.TaskItem) do
    %MDEx.List{nodes: [item]}
  end

  defp wrap_node(%MDEx.DescriptionItem{} = item) do
    %MDEx.DescriptionList{nodes: [item]}
  end

  defp wrap_node(%MDEx.TableRow{nodes: row_nodes} = row) do
    %MDEx.Table{nodes: [row], num_columns: length(row_nodes), num_rows: 1}
  end

  defp wrap_node(new_node), do: new_node

  @doc false
  # https://github.com/kivikakk/comrak/blob/d2dd7c1140a869c5041e8fa9a9a96fbca83374a7/src/nodes.rs#L749
  def can_contain?(_, %MDEx.Document{}), do: false
  def can_contain?(%MDEx.Document{}, %MDEx.FrontMatter{}), do: true
  def can_contain?(%MDEx.Document{}, node), do: is_block_node?(node)

  def can_contain?(%MDEx.List{list_type: type}, %MDEx.List{list_type: type}), do: true
  def can_contain?(%MDEx.List{list_type: type}, %MDEx.ListItem{list_type: type}), do: true
  def can_contain?(%MDEx.List{}, %MDEx.TaskItem{}), do: true
  def can_contain?(%MDEx.List{}, _), do: false

  def can_contain?(%MDEx.ListItem{list_type: type}, %MDEx.List{list_type: type}), do: true
  def can_contain?(%MDEx.ListItem{}, %MDEx.List{}), do: false

  def can_contain?(%MDEx.DescriptionList{}, %MDEx.DescriptionItem{}), do: true
  def can_contain?(%MDEx.DescriptionList{}, _), do: false

  def can_contain?(%MDEx.DescriptionItem{}, %MDEx.DescriptionTerm{}), do: true
  def can_contain?(%MDEx.DescriptionItem{}, %MDEx.DescriptionDetails{}), do: true
  def can_contain?(%MDEx.DescriptionItem{}, _), do: false

  def can_contain?(%MDEx.Table{}, %MDEx.TableRow{}), do: true
  def can_contain?(%MDEx.Table{}, _), do: false

  def can_contain?(%MDEx.TableRow{}, %MDEx.TableCell{}), do: true
  def can_contain?(%MDEx.TableRow{}, _), do: false

  def can_contain?(%MDEx.TableCell{}, child), do: is_inline_node?(child)

  def can_contain?(%MDEx.BlockQuote{}, child), do: is_block_node?(child)
  def can_contain?(%MDEx.FootnoteDefinition{}, child), do: is_block_node?(child)
  def can_contain?(%MDEx.DescriptionTerm{}, child), do: is_block_node?(child)
  def can_contain?(%MDEx.DescriptionDetails{}, child), do: is_block_node?(child)
  def can_contain?(%MDEx.ListItem{}, child), do: is_block_node?(child)
  def can_contain?(%MDEx.TaskItem{}, child), do: is_block_node?(child)

  def can_contain?(%MDEx.Paragraph{}, child), do: is_inline_node?(child)
  def can_contain?(%MDEx.Heading{}, child), do: is_inline_node?(child)
  def can_contain?(%MDEx.Emph{}, child), do: is_inline_node?(child)
  def can_contain?(%MDEx.Strong{}, child), do: is_inline_node?(child)
  def can_contain?(%MDEx.Link{}, child), do: is_inline_node?(child)
  def can_contain?(%MDEx.Image{}, child), do: is_inline_node?(child)
  def can_contain?(%MDEx.Strikethrough{}, child), do: is_inline_node?(child)
  def can_contain?(%MDEx.Superscript{}, child), do: is_inline_node?(child)
  def can_contain?(%MDEx.Underline{}, child), do: is_inline_node?(child)
  def can_contain?(%MDEx.Subscript{}, child), do: is_inline_node?(child)
  def can_contain?(%MDEx.SpoileredText{}, child), do: is_inline_node?(child)
  def can_contain?(%MDEx.WikiLink{}, child), do: is_inline_node?(child)
  def can_contain?(%MDEx.EscapedTag{}, child), do: is_inline_node?(child)

  def can_contain?(_, _), do: false

  defp is_block_node?(%MDEx.Document{}), do: true
  defp is_block_node?(%MDEx.BlockQuote{}), do: true
  defp is_block_node?(%MDEx.List{}), do: true
  defp is_block_node?(%MDEx.ListItem{}), do: true
  defp is_block_node?(%MDEx.DescriptionList{}), do: true
  defp is_block_node?(%MDEx.DescriptionItem{}), do: true
  defp is_block_node?(%MDEx.DescriptionTerm{}), do: true
  defp is_block_node?(%MDEx.DescriptionDetails{}), do: true
  defp is_block_node?(%MDEx.CodeBlock{}), do: true
  defp is_block_node?(%MDEx.HtmlBlock{}), do: true
  defp is_block_node?(%MDEx.Paragraph{}), do: true
  defp is_block_node?(%MDEx.Heading{}), do: true
  defp is_block_node?(%MDEx.ThematicBreak{}), do: true
  defp is_block_node?(%MDEx.FootnoteDefinition{}), do: true
  defp is_block_node?(%MDEx.Table{}), do: true
  defp is_block_node?(%MDEx.TableRow{}), do: true
  defp is_block_node?(%MDEx.TableCell{}), do: true
  defp is_block_node?(%MDEx.TaskItem{}), do: true
  defp is_block_node?(%MDEx.MultilineBlockQuote{}), do: true
  defp is_block_node?(%MDEx.Alert{}), do: true
  defp is_block_node?(_), do: false

  defp is_inline_node?(%MDEx.Text{}), do: true
  defp is_inline_node?(%MDEx.SoftBreak{}), do: true
  defp is_inline_node?(%MDEx.LineBreak{}), do: true
  defp is_inline_node?(%MDEx.Code{}), do: true
  defp is_inline_node?(%MDEx.HtmlInline{}), do: true
  defp is_inline_node?(%MDEx.Raw{}), do: true
  defp is_inline_node?(%MDEx.Emph{}), do: true
  defp is_inline_node?(%MDEx.Strong{}), do: true
  defp is_inline_node?(%MDEx.Strikethrough{}), do: true
  defp is_inline_node?(%MDEx.Superscript{}), do: true
  defp is_inline_node?(%MDEx.Link{}), do: true
  defp is_inline_node?(%MDEx.Image{}), do: true
  defp is_inline_node?(%MDEx.FootnoteReference{}), do: true
  defp is_inline_node?(%MDEx.Math{}), do: true
  defp is_inline_node?(%MDEx.Escaped{}), do: true
  defp is_inline_node?(%MDEx.WikiLink{}), do: true
  defp is_inline_node?(%MDEx.Underline{}), do: true
  defp is_inline_node?(%MDEx.Subscript{}), do: true
  defp is_inline_node?(%MDEx.SpoileredText{}), do: true
  defp is_inline_node?(%MDEx.EscapedTag{}), do: true
  defp is_inline_node?(%MDEx.ShortCode{}), do: true
  defp is_inline_node?(_), do: false
end
