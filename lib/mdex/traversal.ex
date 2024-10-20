# Based on https://github.com/philss/floki/blob/28c9ed8d10d851b63ec87fb8ab9c5acd3c7ea90c/lib/floki/traversal.ex
defmodule MDEx.Traversal do
  @moduledoc false

  def traverse_and_update(node, fun)

  def traverse_and_update([], _fun), do: []

  def traverse_and_update([head | tail], fun) do
    case traverse_and_update(head, fun) do
      nil ->
        traverse_and_update(tail, fun)

      mapped_head ->
        mapped_tail = traverse_and_update(tail, fun)

        mapped =
          if is_list(mapped_head) do
            mapped_head ++ mapped_tail
          else
            [mapped_head | mapped_tail]
          end

        mapped
    end
  end

  def traverse_and_update(%{nodes: nodes} = node, fun) do
    mapped_nodes = traverse_and_update(nodes, fun)
    fun.(%{node | nodes: mapped_nodes})
  end

  def traverse_and_update(%{} = node, fun) do
    fun.(node)
  end

  def traverse_and_update(node, acc, fun)

  def traverse_and_update([], acc, _fun), do: {[], acc}

  def traverse_and_update([head | tail], acc, fun) do
    case traverse_and_update(head, acc, fun) do
      {nil, new_acc} ->
        traverse_and_update(tail, new_acc, fun)

      {mapped_head, new_acc} ->
        {mapped_tail, new_acc2} = traverse_and_update(tail, new_acc, fun)

        mapped =
          if is_list(mapped_head) do
            mapped_head ++ mapped_tail
          else
            [mapped_head | mapped_tail]
          end

        {mapped, new_acc2}
    end
  end

  def traverse_and_update(%{nodes: nodes} = node, acc, fun) do
    {mapped_nodes, new_acc} = traverse_and_update(nodes, acc, fun)
    fun.(%{node | nodes: mapped_nodes}, new_acc)
  end

  def traverse_and_update(node, acc, fun) do
    fun.(node, acc)
  end
end
