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

      #{found}

    """
  end
end

defmodule MDEx.DecodeError do
  @moduledoc """
  Failed to decode a Document.

  Usually this means that a `MDEx.Document` is invalid and cannot be decoded.
  """

  defexception [:document]

  @type t() :: %__MODULE__{document: term()}

  def message(%__MODULE__{document: document}) do
    """
    failed to decode the following Document

    Got:

      #{inspect(document)}

    """
  end
end
