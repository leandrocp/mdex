defmodule MDEx.DecodeError do
  @moduledoc """
  Represents an error decoding the AST from the Elixir data structure into Rust.

  This module is defined as an exception so a message can be generated calling `Exception.message/1`
  or it can be raised.

  ## Fields

    * `:reason` - an atom representing the type of decode error:

        * `:invalid_ast` - AST node format is invalid or not in the expected format as `[name, attributes, children]`.

        * `:invalid_ast_node_name` - Node name is invalid, either not a `String` or not encoded as UTF-8.

        * `:invalid_ast_node_attr_key` - Attribute name is invalid, either not a `String` or not encoded as UTF-8.

        * `:invalid_ast_node_attr_value` - Attribute value is different from expected, invalid, or missing.

    * `:found` - the source that caused the error, either the node or attribute.
                 Most of the times it's displayed as the raw [Term](https://docs.rs/rustler/latest/rustler/struct.Term.html) value as a string (debug).
                 That's because the error was caused due to malformed or unexpected data and we can't decode it to a human-readable format.

  """

  defexception [:reason, :found]

  @type t() :: %__MODULE__{reason: atom(), found: String.t()}

  def message(%__MODULE__{reason: :invalid_ast, found: found}) do
    """
    invalid AST found.

    Expected a list of nodes in the format {name, attributes, children}

    Examples:

        [{"paragraph", [], ["Hello, world!"]}]
        [{"list", [{"type", "bullet"}], [["item", [], ["Hello, world!"]]]}

    See the types in the main MDEx module for more info.

    Got:

      #{found}

    """
  end

  def message(%__MODULE__{reason: :invalid_ast_node_name, found: found}) do
    """
    invalid node name found.

    Expected a UTF-8 encoded string representing one of the available node names.

    Got:

      #{found}

    """
  end

  def message(%__MODULE__{reason: :invalid_node_attr_key, found: found}) do
    """
    invalid node attribute key found.

    Expected a UTF-8 encoded string representing a node attribute key.

    Got:

      #{found}

    """
  end

  def message(%__MODULE__{reason: :invalid_node_attr_value, found: found}) do
    """
    invalid node attribute value found.

    Expected a valid node attribute value.

    Got:

      #{found}

    """
  end
end
