defmodule MDEx.Document.Traversal do
  @moduledoc false
  # traverse_and_update/{2/3} based on https://github.com/philss/floki/blob/96955f925d62989b6f0bfaf09ce6505e67e04fbb/lib/floki/traversal.ex

  def traverse_and_update(%{nodes: nodes} = doc, fun) do
    fun.(%{doc | nodes: do_traverse_and_update(nodes, fun)})
  end

  def traverse_and_update(doc, fun) do
    fun.(doc)
  end

  defp do_traverse_and_update([], _fun), do: []

  defp do_traverse_and_update([node | rest], fun) do
    case do_traverse_and_update(node, fun) do
      :pop ->
        do_traverse_and_update(rest, fun)

      nil ->
        do_traverse_and_update(rest, fun)

      mapped_node ->
        [mapped_node | do_traverse_and_update(rest, fun)]
    end
  end

  defp do_traverse_and_update(%{nodes: nodes} = node, fun) do
    fun.(%{node | nodes: do_traverse_and_update(nodes, fun)})
  end

  defp do_traverse_and_update(%{} = node, fun) do
    fun.(node)
  end

  def traverse_and_update(%{nodes: nodes} = doc, acc, fun) do
    {mapped_nodes, new_acc} = do_traverse_and_update(nodes, acc, fun)
    fun.(%{doc | nodes: mapped_nodes}, new_acc)
  end

  def traverse_and_update(doc, acc, fun) do
    {node, new_acc} = do_traverse_and_update(doc, acc, fun)
    fun.(node, new_acc)
  end

  defp do_traverse_and_update([], acc, _fun), do: {[], acc}

  defp do_traverse_and_update([node | rest], acc, fun) do
    case do_traverse_and_update(node, acc, fun) do
      {:pop, new_acc} ->
        do_traverse_and_update(rest, new_acc, fun)

      {nil, new_acc} ->
        do_traverse_and_update(rest, new_acc, fun)

      {mapped_node, new_acc} ->
        {mapped_rest, new_acc_rest} = do_traverse_and_update(rest, new_acc, fun)
        {[mapped_node | mapped_rest], new_acc_rest}
    end
  end

  defp do_traverse_and_update(%{nodes: nodes} = node, acc, fun) do
    {mapped_nodes, new_acc} = do_traverse_and_update(nodes, acc, fun)
    fun.(%{node | nodes: mapped_nodes}, new_acc)
  end

  defp do_traverse_and_update(%{} = node, acc, fun) do
    fun.(node, acc)
  end
end
