defmodule MDEx.Document.Access do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      @doc false
      defdelegate fetch(document, selector), to: MDEx.Document.Access

      @doc false
      defdelegate get_and_update(paragraph, selector, fun), to: MDEx.Document.Access

      @doc false
      defdelegate pop(document, key, default), to: MDEx.Document.Access
    end
  end

  def fetch(document, selector)

  def fetch(document, selector) when is_struct(selector) do
    case Enum.filter(document, fn node -> node == selector end) do
      [] -> :error
      node -> {:ok, node}
    end
  end

  def fetch(document, selector) when is_atom(selector) do
    selector = modulefy!(selector)

    case Enum.filter(document, fn %{__struct__: mod} -> mod == selector end) do
      [] -> :error
      node -> {:ok, node}
    end
  end

  def fetch(document, selector) when is_function(selector, 1) do
    case Enum.filter(document, selector) do
      [] -> :error
      node -> {:ok, node}
    end
  end

  def fetch(document, selector) when is_integer(selector) do
    case Enum.at(document, selector) do
      nil -> :error
      node -> {:ok, node}
    end
  end

  def get_and_update(document, selector, fun) when is_struct(selector) do
    {document, {_, old}} =
      MDEx.Document.Traversal.traverse_and_update(document, {:cont, nil}, fn
        node, {:halted, old} ->
          {node, {:halted, old}}

        ^selector, {:cont, _old} ->
          {old, new} = fun.(selector)
          {new, {:halted, old}}

        node, acc ->
          {node, acc}
      end)

    {old, document}
  end

  def get_and_update(document, selector, fun) when is_atom(selector) do
    selector = modulefy!(selector)

    {document, {_, old}} =
      MDEx.Document.Traversal.traverse_and_update(document, {:cont, nil}, fn
        node, {:halted, old} ->
          {node, {:halted, old}}

        %{__struct__: mod} = node, {:cont, _old} = acc ->
          if mod == selector do
            {old, new} = fun.(node)
            {new, {:halted, old}}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    {old, document}
  end

  def get_and_update(document, selector, fun) when is_function(selector) do
    {document, {_, old}} =
      MDEx.Document.Traversal.traverse_and_update(document, {:cont, nil}, fn
        node, {:halted, old} ->
          {node, {:halted, old}}

        node, acc ->
          if selector.(node) do
            {old, new} = fun.(node)
            {new, {:halted, old}}
          else
            {node, acc}
          end
      end)

    {old, document}
  end

  def get_and_update(document, selector, fun) when is_integer(selector) do
    node = Enum.at(document, selector)

    if node do
      {old, _new} = fun.(node)
      {old, document}
    else
      {nil, document}
    end
  end

  def pop(document, key, default \\ nil)

  def pop(document, key, default) when is_struct(key) do
    {new, {_, old}} =
      MDEx.Document.Traversal.traverse_and_update(document, {:cont, nil}, fn
        node, {:halted, old} ->
          {node, {:halted, old}}

        ^key, {:cont, _} ->
          {:pop, {:halted, key}}

        node, acc ->
          {node, acc}
      end)

    {old || default, new}
  end

  def pop(document, key, default) when is_atom(key) do
    key = modulefy!(key)

    {new, {_, old}} =
      MDEx.Document.Traversal.traverse_and_update(document, {:cont, nil}, fn
        node, {:halted, old} ->
          {node, {:halted, old}}

        %{__struct__: mod} = node, {:cont, _} = acc ->
          if mod == key do
            {:pop, {:halted, node}}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    {old || default, new}
  end

  def pop(document, key, default) when is_integer(key) do
    node = Enum.at(document, key)
    {node || default, document}
  end

  @doc false
  def modulefy!(nil = _selector), do: raise(%MDEx.InvalidSelector{selector: nil})

  def modulefy!(selector) when is_atom(selector) do
    case Atom.to_string(selector) do
      "Elixir." <> name -> Module.concat([name])
      atom -> Module.concat(["MDEx", Macro.camelize(atom)])
    end
  end

  def modulefy!(selector), do: raise(%MDEx.InvalidSelector{selector: selector})
end
