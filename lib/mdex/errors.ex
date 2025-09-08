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

defmodule MDEx.DecodeError do
  @moduledoc """
  Failed to decode a Document.

  Usually this means that a `MDEx.Document` is invalid and cannot be decoded.
  """

  defexception [:document, :error]

  @type t() :: %__MODULE__{document: term(), error: Exception.t()}

  def message(%__MODULE__{document: document, error: error}) when is_nil(error) do
    """
    failed to decode the following Document

    Document:

      #{inspect(document)}

    """
  end

  def message(%__MODULE__{document: document, error: error}) do
    """
    failed to decode the following Document

    Document:

      #{inspect(document)}

    Got:

      #{inspect(error)}

    """
  end
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
