defmodule MDEx.Tree do
  @moduledoc false

  def is_block_node?(%MDEx.Document{}), do: true
  def is_block_node?(%MDEx.BlockQuote{}), do: true
  def is_block_node?(%MDEx.List{}), do: true
  def is_block_node?(%MDEx.ListItem{}), do: true
  def is_block_node?(%MDEx.DescriptionList{}), do: true
  def is_block_node?(%MDEx.DescriptionItem{}), do: true
  def is_block_node?(%MDEx.DescriptionTerm{}), do: true
  def is_block_node?(%MDEx.DescriptionDetails{}), do: true
  def is_block_node?(%MDEx.CodeBlock{}), do: true
  def is_block_node?(%MDEx.HtmlBlock{}), do: true
  def is_block_node?(%MDEx.Paragraph{}), do: true
  def is_block_node?(%MDEx.Heading{}), do: true
  def is_block_node?(%MDEx.ThematicBreak{}), do: true
  def is_block_node?(%MDEx.FootnoteDefinition{}), do: true
  def is_block_node?(%MDEx.Table{}), do: true
  def is_block_node?(%MDEx.TableRow{}), do: true
  def is_block_node?(%MDEx.TableCell{}), do: true
  def is_block_node?(%MDEx.TaskItem{}), do: true
  def is_block_node?(%MDEx.MultilineBlockQuote{}), do: true
  def is_block_node?(%MDEx.Alert{}), do: true
  def is_block_node?(_), do: false

  def is_inline_node?(node), do: !is_block_node?(node)
end
