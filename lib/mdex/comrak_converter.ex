defmodule MDEx.ComrakConverter do
  @moduledoc false

  @nodes ~w(
    Alert Attributes BlockDirective BlockQuote Callout CalloutTitle Code CodeBlock CommentInline DescriptionDetails
    DescriptionItem DescriptionList DescriptionTerm Document Emph Escaped EscapedTag
    FootnoteDefinition FootnoteReference FrontMatter Heading HeexBlock HeexInline
    Highlight HtmlBlock HtmlInline Image Insert LineBreak Link List ListItem Math
    MultilineBlockQuote MultilineComment Paragraph Raw ShortCode SoftBreak Sourcepos SpoileredText
    Strikethrough Strong Subscript Subtext Superscript Table TableCell TableRow
    TaskItem Text ThematicBreak Underline WikiLink
  )a

  # Fields that hold other convertible values.
  @nested [:nodes, :sourcepos, :attrs]

  def to_mdex(value), do: convert(value, :to_mdex)
  def from_mdex(value), do: convert(value, :from_mdex)

  defp convert(nodes, direction) when is_list(nodes), do: convert_list(nodes, direction)

  # One clause per node type and direction. When the node has exactly the
  # fields of a target struct with the same fields, which is the case for every
  # node built by a matching mdex_native, it is converted by swapping its
  # `__struct__` and the nested fields in a single map update. Otherwise
  # `struct/2` keeps only the fields the target knows about and defaults the rest.
  for name <- @nodes,
      {source, target, direction} <- [
        {Module.concat(MDExNative.Comrak, name), Module.concat(MDEx, name), :to_mdex},
        {Module.concat(MDEx, name), Module.concat(MDExNative.Comrak, name), :from_mdex}
      ] do
    source_keys = source |> struct() |> Map.keys() |> Enum.sort()
    target_keys = target |> struct() |> Map.keys() |> Enum.sort()

    if source_keys == target_keys do
      node = Macro.var(:node, __MODULE__)
      key_patterns = for key <- source_keys, key != :__struct__, do: {key, Macro.var(:_, nil)}
      pattern = {:%{}, [], [{:__struct__, source} | key_patterns]}
      nested = Enum.filter(@nested, &(&1 in source_keys))
      updates = for key <- nested, do: {key, quote(do: convert(unquote(node).unquote(key), unquote(direction)))}
      body = {:%{}, [], [{:|, [], [node, [{:__struct__, target} | updates]]}]}

      defp convert(unquote(pattern) = unquote(node), unquote(direction))
           when map_size(unquote(node)) == unquote(length(source_keys)),
           do: unquote(body)
    end

    defp convert(%unquote(source){} = node, unquote(direction)) do
      fields =
        Enum.reduce(unquote(@nested), Map.from_struct(node), fn key, fields ->
          case fields do
            %{^key => value} -> %{fields | key => convert(value, unquote(direction))}
            _ -> fields
          end
        end)

      struct(unquote(target), fields)
    end
  end

  defp convert(%module{}, _direction), do: raise(ArgumentError, "cannot convert #{inspect(module)}")

  defp convert(value, _direction), do: value

  defp convert_list([node | rest], direction), do: [convert(node, direction) | convert_list(rest, direction)]
  defp convert_list([], _direction), do: []
end
