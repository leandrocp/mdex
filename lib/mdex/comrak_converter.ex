defmodule MDEx.ComrakConverter do
  @moduledoc false

  @nodes ~w(
    Alert Attributes BlockDirective BlockQuote Code CodeBlock DescriptionDetails
    DescriptionItem DescriptionList DescriptionTerm Document Emph Escaped EscapedTag
    FootnoteDefinition FootnoteReference FrontMatter Heading HeexBlock HeexInline
    Highlight HtmlBlock HtmlInline Image Insert LineBreak Link List ListItem Math
    MultilineBlockQuote Paragraph Raw ShortCode SoftBreak Sourcepos SpoileredText
    Strikethrough Strong Subscript Subtext Superscript Table TableCell TableRow
    TaskItem Text ThematicBreak Underline WikiLink
  )a

  def to_mdex(value), do: convert(value, :to_mdex)
  def from_mdex(value), do: convert(value, :from_mdex)

  defp convert(nodes, direction) when is_list(nodes), do: Enum.map(nodes, &convert(&1, direction))

  defp convert(%module{} = node, direction) do
    target = translate!(module, direction)

    fields =
      node
      |> Map.from_struct()
      |> convert_nested(:nodes, direction)
      |> convert_nested(:sourcepos, direction)
      |> convert_nested(:attrs, direction)

    struct(target, fields)
  end

  defp convert(value, _direction), do: value

  defp convert_nested(fields, key, direction) do
    case fields do
      %{^key => value} -> %{fields | key => convert(value, direction)}
      _ -> fields
    end
  end

  for name <- @nodes do
    native = Module.concat(MDExNative.Comrak, name)
    mdex = Module.concat(MDEx, name)

    defp translate!(unquote(native), :to_mdex), do: unquote(mdex)
    defp translate!(unquote(mdex), :from_mdex), do: unquote(native)
  end

  defp translate!(module, _direction), do: raise(ArgumentError, "cannot convert #{inspect(module)}")
end
