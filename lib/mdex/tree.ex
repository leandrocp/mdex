defmodule MDEx.Tree do
  @moduledoc false

  def block_node?(%MDEx.Document{}), do: true
  def block_node?(%MDEx.BlockQuote{}), do: true
  def block_node?(%MDEx.List{}), do: true
  def block_node?(%MDEx.ListItem{}), do: true
  def block_node?(%MDEx.DescriptionList{}), do: true
  def block_node?(%MDEx.DescriptionItem{}), do: true
  def block_node?(%MDEx.DescriptionTerm{}), do: true
  def block_node?(%MDEx.DescriptionDetails{}), do: true
  def block_node?(%MDEx.CodeBlock{}), do: true
  def block_node?(%MDEx.HtmlBlock{}), do: true
  def block_node?(%MDEx.Paragraph{}), do: true
  def block_node?(%MDEx.Heading{}), do: true
  def block_node?(%MDEx.ThematicBreak{}), do: true
  def block_node?(%MDEx.FootnoteDefinition{}), do: true
  def block_node?(%MDEx.Table{}), do: true
  def block_node?(%MDEx.TableRow{}), do: true
  def block_node?(%MDEx.TableCell{}), do: true
  def block_node?(%MDEx.TaskItem{}), do: true
  def block_node?(%MDEx.MultilineBlockQuote{}), do: true
  def block_node?(%MDEx.Alert{}), do: true
  def block_node?(%MDEx.BlockDirective{}), do: true
  def block_node?(_), do: false

  def inline_node?(node), do: !block_node?(node)
end
