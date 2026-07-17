defmodule MDEx.ComrakConverter do
  @moduledoc false

  def to_mdex(value), do: convert(value, ["MDExNative", "Comrak"], MDEx)
  def from_mdex(value), do: convert(value, ["MDEx"], MDExNative.Comrak)

  defp convert(nodes, from, to) when is_list(nodes), do: Enum.map(nodes, &convert(&1, from, to))

  defp convert(%module{} = node, from, to) do
    case convert_module(module, from, to) do
      {:ok, target} ->
        fields =
          node
          |> Map.from_struct()
          |> Map.new(fn
            {key, value} when key in [:nodes, :sourcepos, :attrs] ->
              {key, convert(value, from, to)}

            {key, value} ->
              {key, value}
          end)

        struct(target, fields)

      :error ->
        raise ArgumentError, "cannot convert #{inspect(module)}"
    end
  end

  defp convert(value, _from, _to), do: value

  defp convert_module(module, from, to) do
    parts = Module.split(module)

    case Enum.split(parts, length(from)) do
      {^from, [_name]} ->
        {:ok, Module.safe_concat([to, List.last(parts)])}

      _ ->
        :error
    end
  end
end
