defmodule MDEx.Tree do
  @moduledoc false

  def append_node(%MDEx.Document{} = document, new_node) do
    append_nodes(document, [new_node])
  end

  def append_nodes(%MDEx.Document{nodes: nodes} = document, new_nodes) when is_list(new_nodes) do
    new_nodes = List.flatten(new_nodes)

    updated_nodes =
      Enum.reduce(new_nodes, nodes, fn node, acc when is_struct(node) ->
        append_to_nodes(acc, node)
      end)

    %{document | nodes: updated_nodes}
  end

  def merge(%MDEx.Document{} = document, %MDEx.Document{nodes: nodes}) do
    append_nodes(document, nodes)
  end

  @doc false
  # https://github.com/kivikakk/comrak/blob/d2dd7c1140a869c5041e8fa9a9a96fbca83374a7/src/nodes.rs#L749
  def can_contain?(_, %MDEx.Document{}), do: false
  def can_contain?(%MDEx.Document{}, %MDEx.FrontMatter{}), do: true
  def can_contain?(%MDEx.Document{}, node), do: is_block_node?(node)

  def can_contain?(parent, child_node)
      when (is_struct(parent, MDEx.BlockQuote) or
              is_struct(parent, MDEx.FootnoteDefinition) or
              is_struct(parent, MDEx.DescriptionTerm) or
              is_struct(parent, MDEx.DescriptionDetails) or
              is_struct(parent, MDEx.ListItem) or
              is_struct(parent, MDEx.TaskItem)) and
             not (is_struct(child_node, MDEx.ListItem) or
                    is_struct(child_node, MDEx.TaskItem)) do
    is_block_node?(child_node)
  end

  def can_contain?(%MDEx.List{}, %MDEx.ListItem{}), do: true
  def can_contain?(%MDEx.List{}, %MDEx.TaskItem{}), do: true
  def can_contain?(%MDEx.List{}, _), do: false

  def can_contain?(%MDEx.DescriptionList{}, %MDEx.DescriptionItem{}), do: true
  def can_contain?(%MDEx.DescriptionList{}, _), do: false

  def can_contain?(%MDEx.DescriptionItem{}, child)
      when is_struct(child, MDEx.DescriptionTerm) or
             is_struct(child, MDEx.DescriptionDetails),
      do: true

  def can_contain?(%MDEx.DescriptionItem{}, _), do: false

  def can_contain?(%MDEx.Table{}, %MDEx.TableRow{}), do: true
  def can_contain?(%MDEx.Table{}, _), do: false

  def can_contain?(%MDEx.TableRow{}, %MDEx.TableCell{}), do: true
  def can_contain?(%MDEx.TableRow{}, _), do: false

  def can_contain?(parent, child)
      when is_struct(parent, MDEx.Paragraph) or
             is_struct(parent, MDEx.Heading) or
             is_struct(parent, MDEx.Emph) or
             is_struct(parent, MDEx.Strong) or
             is_struct(parent, MDEx.Link) or
             is_struct(parent, MDEx.Image) or
             is_struct(parent, MDEx.Strikethrough) or
             is_struct(parent, MDEx.Superscript) or
             is_struct(parent, MDEx.Underline) or
             is_struct(parent, MDEx.Subscript) or
             is_struct(parent, MDEx.SpoileredText) or
             is_struct(parent, MDEx.WikiLink) or
             is_struct(parent, MDEx.EscapedTag) do
    is_inline_node?(child)
  end

  def can_contain?(%MDEx.TableCell{}, child), do: is_inline_node?(child)

  def can_contain?(_, _), do: false

  defp append_to_nodes([], %MDEx.ListItem{} = item), do: [%MDEx.List{nodes: [item]}]
  defp append_to_nodes([], %MDEx.TaskItem{} = item), do: [%MDEx.List{nodes: [item]}]
  defp append_to_nodes([], %MDEx.DescriptionItem{} = item), do: [%MDEx.DescriptionList{nodes: [item]}]
  defp append_to_nodes([], %MDEx.TableRow{nodes: nodes} = row), do: [%MDEx.Table{nodes: [row], num_columns: length(nodes), num_rows: 1}]
  defp append_to_nodes([], new_node), do: [new_node]

  defp append_to_nodes(nodes, %MDEx.Text{} = new_node) do
    case try_append_to_rightmost(nodes, new_node) do
      {:ok, updated_nodes} -> updated_nodes
      {:consumed} -> nodes
      :error -> nodes ++ [new_node]
    end
  end

  defp append_to_nodes(nodes, %MDEx.ListItem{} = item) do
    case try_append_to_rightmost(nodes, item) do
      {:ok, updated_nodes} -> updated_nodes
      :error -> nodes ++ [%MDEx.List{nodes: [item]}]
    end
  end

  defp append_to_nodes(nodes, %MDEx.TaskItem{} = item) do
    case try_append_to_rightmost(nodes, item) do
      {:ok, updated_nodes} -> updated_nodes
      :error -> nodes ++ [%MDEx.List{nodes: [item]}]
    end
  end

  defp append_to_nodes(nodes, %MDEx.DescriptionItem{} = item) do
    case try_append_to_rightmost(nodes, item) do
      {:ok, updated_nodes} -> updated_nodes
      :error -> nodes ++ [%MDEx.DescriptionList{nodes: [item]}]
    end
  end

  defp append_to_nodes(nodes, %MDEx.TableRow{nodes: row_nodes} = row) do
    case try_append_to_rightmost(nodes, row) do
      {:ok, updated_nodes} -> updated_nodes
      :error -> nodes ++ [%MDEx.Table{nodes: [row], num_columns: length(row_nodes), num_rows: 1}]
    end
  end

  defp append_to_nodes(nodes, new_node) do
    case try_append_to_rightmost(nodes, new_node) do
      {:ok, updated_nodes} -> updated_nodes
      :error -> nodes ++ [new_node]
    end
  end

  defp try_append_to_rightmost([], _new_node), do: :error

  defp try_append_to_rightmost([single], new_node) do
    cond do
      can_append_as_sibling?(single, new_node) ->
        {:ok, [single, new_node]}

      true ->
        case try_append_to_node(single, new_node) do
          {:ok, updated_node} -> {:ok, [updated_node]}
          {:consumed} -> {:consumed}
          :error -> :error
        end
    end
  end

  defp try_append_to_rightmost(nodes, new_node) do
    {rightmost, remaining} = List.pop_at(nodes, -1)

    cond do
      can_append_as_sibling?(rightmost, new_node) ->
        {:ok, remaining ++ [rightmost, new_node]}

      true ->
        case try_append_to_node(rightmost, new_node) do
          {:ok, updated_node} -> {:ok, remaining ++ [updated_node]}
          {:consumed} -> {:consumed}
          :error -> :error
        end
    end
  end

  defp try_append_to_node(%{nodes: child_nodes} = parent, new_node) do
    cond do
      can_contain?(parent, new_node) ->
        updated_children = child_nodes ++ [new_node]
        {:ok, %{parent | nodes: updated_children}}

      has_nodes?(parent) ->
        case try_append_to_rightmost(child_nodes, new_node) do
          {:ok, updated_children} -> {:ok, %{parent | nodes: updated_children}}
          {:consumed} -> {:consumed}
          :error -> :error
        end

      true ->
        :error
    end
  end

  defp try_append_to_node(_parent, _new_node), do: :error

  defp can_append_as_sibling?(%MDEx.List{}, %MDEx.CodeBlock{}), do: true
  defp can_append_as_sibling?(_, _), do: false

  defp has_nodes?(%{nodes: _}), do: true
  defp has_nodes?(_), do: false

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
