defmodule MDEx.DecodeError do
  @moduledoc """
  Represents an error decoding the AST from the Elixir data structure into Rust.

  This module is defined as an exception so a message can be generated calling `Exception.message/1`
  or it can be raised.

  ## Fields

    * `:reason` - an atom representing the type of decode error:

        * `:invalid_structure` - AST structure is invalid or malformed.

        * `:empty` - AST is empty, no nodes found.

        * `:missing_node_field` - one or more fields of a node is missing, it should contain `{name, attributes, children}`.

        * `:missing_attr_field` - either the key or value of an attribute is missing.

        * `:node_name_not_string` - node name is not a UTF-8 encoded string.

        * `:unknown_node_name` - node name is not one of the available node names.

        * `:attr_key_not_string` - attribute key is not a UTF-8 encoded string.

        * `:unknown_attr_value` - attribute value doesn't match any expected type.

    * `:found` - the source that caused the error, either the node or attribute.
        Most of the times it's displayed as the raw [Term](https://docs.rs/rustler/latest/rustler/struct.Term.html) value as a string (debug).
        That's because the error may be caused by malformed or unexpected data and we can't decode it to a human-readable format.

    * `:node` - the node where the error was found, usually when the error is in an attribute or children.

    * `:attr` - the attribute where the error was found.

    * `:kind` - the type of the field that caused the error.

  """

  defexception [:reason, :found, :node, :attr, :kind]

  @type t() :: %__MODULE__{
          reason: atom(),
          found: String.t(),
          node: nil | String.t(),
          attr: nil | String.t(),
          kind: nil | String.t()
        }

  def message(%__MODULE__{reason: :invalid_structure, found: found}) do
    """
    AST structure is invalid or malformed.

    Expected a list of nodes in the format [{name :: binary(), attributes :: [{name :: binary(), value :: term()}], children :: [node()]}]

    Got:

      #{found}

    """
  end

  def message(%__MODULE__{reason: :empty, found: found}) do
    """
    AST is empty, no nodes found.

    Expected a list of nodes in the format [{name :: binary(), attributes :: [{name :: binary(), value :: term()}], children :: [node()]}]

    Got:

      #{found}

    """
  end

  def message(%__MODULE__{reason: :missing_node_field, found: found}) do
    """
    missing one or more fields in the node.

    Expected a list of nodes in the format {name :: binary(), attributes :: [{name :: binary(), value :: term()}], children :: [node()]}

    Got:

      #{found}

    """
  end

  def message(%__MODULE__{reason: :missing_attr_field, found: found, node: node}) do
    """
    missing either the key or value in the attribute.

    Expected an attribute in the format {name :: String.t(), value :: term()}

    Got:

      #{found}

    In this node:

      #{node}

    """
  end

  def message(%__MODULE__{reason: :node_name_not_string, found: found, node: node, kind: kind}) do
    """
    invalid node name

    Expected a node name encoded as UTF-8 binary

    Got:

      #{found}

    Type:

      #{kind}

    In this node:

      #{node}

    """
  end

  def message(%__MODULE__{reason: :unknown_node_name, node: node, found: found}) do
    """
    unknown node name

    Expected one of the available node names listed at https://docs.rs/comrak/latest/comrak/nodes/enum.NodeValue.html

    Got:

      #{found}

    In this node:

      #{node}

    """
  end

  def message(%__MODULE__{reason: :attr_key_not_string, found: found, node: node, attr: attr, kind: kind}) do
    """
    invalid attribute key

    Expected an attribute key encoded as UTF-8 binary

    Got:

      #{found}

    Type:

      #{kind}

    In this node:

      #{node}

    In this attribute:

      #{attr}

    """
  end

  def message(%__MODULE__{reason: :unknown_attr_value, found: found, node: node, attr: attr}) do
    """
    unknown attribute value

    Attribute value doesn't match any expected type.

    Got:

      #{found}

    In this node:

      #{node}

    In this attribute:

      #{attr}

    """
  end
end
