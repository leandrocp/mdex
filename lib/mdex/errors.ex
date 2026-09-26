defmodule MDEx.InvalidInputError do
  @moduledoc """
  Given input is invalid.

  Usually this means that the input is not a string or a MDEx.Document struct.
  """

  defexception [:found]

  @type t() :: %__MODULE__{found: term()}

  def message(%__MODULE__{found: found}) do
    """
    expected either a Markdown string or a MDEx.Document struct

    Got:

      #{inspect(found)}

    """
  end
end

# credo:disable-for-next-line Credo.Check.Consistency.ExceptionNames
defmodule MDEx.DecodeError do
  @moduledoc """
  Failed to decode a Document.

  Usually this means that a `MDEx.Document` is invalid and cannot be decoded.
  The message names the first node field holding a value of the wrong type, when there is one.
  """

  defexception [:document, :error]

  @type t() :: %__MODULE__{document: term(), error: Exception.t()}

  def message(%__MODULE__{document: document, error: error}) when is_nil(error) do
    """
    failed to decode the following Document
    #{invalid_value(document)}
    Document:

      #{inspect(document)}

    """
  end

  def message(%__MODULE__{document: document, error: error}) do
    """
    failed to decode the following Document
    #{invalid_value(document)}
    Document:

      #{inspect(document)}

    Got:

      #{inspect(error)}

    """
  end

  # Every node struct renders with its defaults, so a field holding a value
  # of a different type than its default is one the NIF can't decode.
  defp invalid_value(%MDEx.Document{nodes: nodes}) do
    case invalid_nodes(MDEx.Document, nodes) do
      nil -> ""
      reason -> "\n" <> reason <> "\n"
    end
  end

  defp invalid_value(_document), do: ""

  defp invalid_nodes(module, nodes) when is_list(nodes) do
    Enum.find_value(nodes, fn
      %_{} = node -> invalid_node(node)
      node -> "#{inspect(module)} :nodes must contain only nodes, got: #{inspect(node)}"
    end)
  end

  defp invalid_nodes(module, nodes) do
    "#{inspect(module)} :nodes must be a list, got: #{inspect(nodes)}"
  end

  defp invalid_node(%module{} = node) do
    defaults = module.__struct__()

    invalid_field =
      Enum.find_value(Map.from_struct(node), fn
        {:nodes, _nodes} ->
          nil

        {field, value} ->
          expected = type(Map.get(defaults, field))

          if expected != "nil" and type(value) != expected do
            "#{inspect(module)} #{inspect(field)} must be #{expected}, got: #{inspect(value)}"
          end
      end)

    invalid_field || invalid_nodes(module, Map.get(node, :nodes, []))
  end

  defp type(nil), do: "nil"
  defp type(value) when is_boolean(value), do: "a boolean"
  defp type(value) when is_atom(value), do: "an atom"
  defp type(value) when is_binary(value), do: if(String.valid?(value), do: "a string", else: "a binary")
  defp type(value) when is_integer(value) and value >= 0, do: "a non-negative integer"
  defp type(value) when is_list(value), do: "a list"
  defp type(%module{}), do: "%#{inspect(module)}{}"
  defp type(value) when is_map(value), do: "a map"
  defp type(_value), do: "unknown"
end

defmodule MDEx.InvalidSelector do
  @moduledoc """
  Invalid Access key selector.
  """

  defexception [:selector]

  @type t() :: %__MODULE__{selector: term()}

  def message(%__MODULE__{selector: selector}) do
    """
    invalid Access key selector

    Got:

      #{inspect(selector)}

    """
  end
end
