defmodule MDEx.ComrakConverter do
  @moduledoc false

  # Both namespaces declare the same fields, so a node converts by swapping
  # `__struct__`. The table is compile-time: resolving it per node used to cost more
  # than parsing and rendering combined.

  # `Document` has its own clause because `MDEx.Document` also carries pipeline state.
  @nodes ~w(
    Alert Attributes BlockDirective BlockQuote Code CodeBlock DescriptionDetails
    DescriptionItem DescriptionList DescriptionTerm Emph Escaped EscapedTag
    FootnoteDefinition FootnoteReference FrontMatter Heading HeexBlock HeexInline
    Highlight HtmlBlock HtmlInline Image Insert LineBreak Link List ListItem Math
    MultilineBlockQuote Paragraph Raw ShortCode SoftBreak Sourcepos SpoileredText
    Strikethrough Strong Subscript Subtext Superscript Table TableCell TableRow
    TaskItem Text ThematicBreak Underline WikiLink
  )a

  def to_mdex(value), do: convert(value, :to_mdex)
  def from_mdex(value), do: convert(value, :from_mdex)

  defp convert(nodes, direction) when is_list(nodes), do: Enum.map(nodes, &convert(&1, direction))

  defp convert(%MDExNative.Comrak.Document{} = document, :to_mdex = direction) do
    %MDEx.Document{
      nodes: convert(document.nodes, direction),
      sourcepos: convert(document.sourcepos, direction)
    }
  end

  defp convert(%MDEx.Document{} = document, :from_mdex = direction) do
    %MDExNative.Comrak.Document{
      nodes: convert(document.nodes, direction),
      sourcepos: convert(document.sourcepos, direction)
    }
  end

  defp convert(%module{} = node, direction) do
    {target, size} = translate!(module, direction)

    node
    |> rename(target, size)
    |> convert_nested(:nodes, direction)
    |> convert_nested(:sourcepos, direction)
    |> convert_nested(:attrs, direction)
  end

  defp convert(value, _direction), do: value

  # A mismatched `mdex_native` may decode a different set of fields.
  defp rename(node, target, size) when map_size(node) == size, do: Map.replace!(node, :__struct__, target)
  defp rename(node, target, _size), do: struct(target, Map.from_struct(node))

  defp convert_nested(node, key, direction) do
    case node do
      %{^key => nil} -> node
      %{^key => value} -> %{node | key => convert(value, direction)}
      _ -> node
    end
  end

  for name <- @nodes do
    native = Module.concat(MDExNative.Comrak, name)
    mdex = Module.concat(MDEx, name)
    size = map_size(native.__struct__())

    defp translate!(unquote(native), :to_mdex), do: {unquote(mdex), unquote(size)}
    defp translate!(unquote(mdex), :from_mdex), do: {unquote(native), unquote(size)}
  end

  defp translate!(module, _direction), do: raise(ArgumentError, "cannot convert #{inspect(module)}")
end
