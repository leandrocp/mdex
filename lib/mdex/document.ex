# based on https://github.com/wojtekmach/easyhtml

defmodule MDEx.Document do
  @moduledoc """
  Tree representation of a CommonMark document.

  ```elixir
  %MDEx.Document{
    nodes: [
      %MDEx.Paragraph{
        nodes: [
          %MDEx.Code{num_backticks: 1, literal: "Elixir"}
        ]
      }
    ]
  }
  ```

  Each node may contain attributes and children nodes as in the example above where `MDEx.Document`
  contains a `MDEx.Paragraph` node which contains a `MDEx.Code` node with the attributes `:num_backticks` and `:literal`.

  You can check out each node's documentation in the `Document Nodes` section, for example `MDEx.HtmlBlock`.

  The wrapping `MDEx.Document` module represents the root of a document and it implements some behaviours and protocols
  to enable operations to fetch, update, and manipulate the document tree.

  Let's go through these operations in the examples below.

  In these examples we will be using the [~M](https://hexdocs.pm/mdex/MDEx.Sigil.html#sigil_M/2)
  and [~m](https://hexdocs.pm/mdex/MDEx.Sigil.html#sigil_m/2) to format the content,
  see their documentation for more info.

  ## String.Chars

  Calling `Kernel.to_string/1` or interpolating the document AST will format it as CommonMark text.

  ```elixir
  iex> to_string(~M[# Hello])
  "# Hello"
  ```

  Fragments (nodes without the parent `%Document{}`) are also formatted:

  ```elixir
  iex> to_string(%MDEx.Heading{nodes: [%MDEx.Text{literal: "Hello"}], level: 1})
  "# Hello"
  ```

  And finally interpolation as well:

  ```elixir
  iex> lang = "elixir"
  iex> to_string(~m[`\#\{lang\}`])
  "`elixir`"
  ```

  ## Access

  The `Access` behaviour gives you the ability to fetch and update nodes using different types of keys.

  Starting with a simple Markdown document with a single heading and a text,
  let's fetch only the text node by matching the `MDEx.Text` node:

  ```elixir
  iex> ~M[# Hello][%MDEx.Text{literal: "Hello"}]
  [%MDEx.Text{literal: "Hello"}]
  ```

  That's essentially the same as:

  ```elixir
  doc = %MDEx.Document{nodes: [%MDEx.Heading{nodes: [%MDEx.Text{literal: "Hello"}], level: 1, setext: false}]},

  Enum.filter(
    doc,
    fn node -> node == %MDEx.Text{literal: "Hello"} end
  )
  ```

  The key can also be modules, atoms, and even functions! For example:

  - Fetchs all Code nodes, either by `MDEx.Code` module or the `:code` atom representing the Code node

  ```elixir
  iex> doc = ~M\"""
  ...> # Languages
  ...>
  ...> `elixir`
  ...>
  ...> `rust`
  ...> \"""
  iex> doc[MDEx.Code]
  [%MDEx.Code{num_backticks: 1, literal: "elixir"}, %MDEx.Code{num_backticks: 1, literal: "rust"}]
  iex> doc[:code]
  [%MDEx.Code{num_backticks: 1, literal: "elixir"}, %MDEx.Code{num_backticks: 1, literal: "rust"}]
  ```

  - Dynamically fetch Code nodes where the `:literal` (node content) starts with `"eli"` using a function to filter the result

  ```elixir
  iex> doc = ~M\"""
  ...> # Languages
  ...>
  ...> `elixir`
  ...>
  ...> `rust`
  ...> \"""
  iex> doc[fn node -> String.starts_with?(Map.get(node, :literal, ""), "eli") end]
  [%MDEx.Code{num_backticks: 1, literal: "elixir"}]
  ```

  That's the most flexible option, in the case where struct, modules, or atoms are not enough to match the node you want.

  This protocol also allows us to update the node that matches a selector.
  In the example below we'll capitalize the content of the `MDEx.Code` that maches the literal `"rust"`:

  ```elixir
  iex> doc = ~M\"""
  ...> # Languages
  ...>
  ...> `elixir`
  ...>
  ...> `rust`
  ...>
  ...> Continue...
  ...> \"""
  iex> MDEx.Document.get_and_update(doc, %MDEx.Code{num_backticks: 1, literal: "rust"}, fn node ->
  ...>   {node, %{node | literal: String.upcase(node.literal)}}
  ...> end)
  {
    %MDEx.Code{num_backticks: 1, literal: "rust"},
    %MDEx.Document{nodes: [
      %MDEx.Heading{nodes: [%MDEx.Text{literal: "Languages"}], level: 1, setext: false},
      %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "elixir"}]},
      %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "RUST"}]},
      %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Continue…"}]}]}
  }
  ```

  We used a function selector in the example above but
  it also works with modules, atoms, and structs as shown in the previous examples.

  > #### Flat vs Tree {: .warning}
  >
  > Keep in mind this protocol works with flat data while the `MDEx.Document` is a tree structure,
  > so in some cases it might not return what you'd expect.

  For example:

  ```elixir
  iex> ~M[# Hello][fn _node -> true end]
  [
    %MDEx.Document{nodes: [%MDEx.Heading{nodes: [%MDEx.Text{literal: "Hello"}], level: 1, setext: false}]},
    %MDEx.Heading{nodes: [%MDEx.Text{literal: "Hello"}], level: 1, setext: false},
    %MDEx.Text{literal: "Hello"}
  ]
  ```

  In this case, all matches returned `true` so it returns all nodes but it doesn't know how to rebuild the tree structure
  and the result is a flat list of nodes.

  To manipulate and preserve the tree, use `traverse_and_update/2` or `traverse_and_update/3` instead (more about them below).

  ## Enumerable

  Probably the most used protocol in Elixir, it allows us to call `Enum` functions. Let's see some examples:

  * Count the nodes in a document:

  ```elixir
  iex> doc = ~M\"""
  ...> # Languages
  ...>
  ...> `elixir`
  ...>
  ...> `rust`
  ...> \"""
  iex> Enum.count(doc)
  7
  ```

  * Count how many nodes have the `:literal` attribute:

  ```elixir
  iex> doc = ~M\"""
  ...> # Languages
  ...>
  ...> `elixir`
  ...>
  ...> `rust`
  ...> \"""
  iex> Enum.reduce(doc, 0, fn
  ...>   %{literal: _literal}, acc -> acc + 1
  ...>
  ...>   _node, acc -> acc
  ...> end)
  3
  ```

  * Returns true if node is member of the document:

  ```elixir
  iex> doc = ~M\"""
  ...> # Languages
  ...>
  ...> `elixir`
  ...>
  ...> `rust`
  ...> \"""
  iex> Enum.member?(doc, %MDEx.Code{literal: "elixir", num_backticks: 1})
  true
  ```

  * Map each node:

  ```elixir
  iex> doc = ~M\"""
  ...> # Languages
  ...>
  ...> `elixir`
  ...>
  ...> `rust`
  ...> \"""
  iex> Enum.map(doc, fn %node{} -> inspect(node) end)
  ["MDEx.Document", "MDEx.Heading", "MDEx.Text", "MDEx.Paragraph", "MDEx.Code", "MDEx.Paragraph", "MDEx.Code"]
  ```

  > #### Flat vs Tree {: .warning}
  >
  > Similar to the `Access` protocol, the `Enumerable` protocol works with flat data and
  > it might not return the expected result as a tree.
  > To preserve the tree structure, use `traverse_and_update/2` or `traverse_and_update/3` instead.

  ## Traverse and Update

  Of all the examples seen so far, the tree structure format is not guaranteed
  since we're working with protocols that expect flat data in most of their operations.
  To overcome this situation, let's use the `traverse_and_update/2` and `traverse_and_update/3` functions
  that work similarly to `Enum.reduce/3` but preserve the tree structure.

  In the example below we'll traverse the tree and update the `MDEx.Code` nodes with the respective file extension of each language:

  ```elixir
  iex> doc = ~M\"""
  ...> # Languages
  ...>
  ...> `elixir`
  ...>
  ...> `rust`
  ...> \"""
  iex> traverse_and_update(doc, fn
  ...>   %MDEx.Code{literal: "elixir"} = node -> %{node | literal: "ex"}
  ...>   %MDEx.Code{literal: "rust"} = node -> %{node | literal: "rs"}
  ...>   node -> node
  ...> end)
  %MDEx.Document{
    nodes: [
      %MDEx.Heading{nodes: [%MDEx.Text{literal: "Languages"}], level: 1, setext: false},
      %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "ex"}]},
      %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "rs"}]}
    ]
  }
  ```

  By giving an accumulator we can preserve state during the operation,
  for example let's count how many nodes were updated:

  ```elixir
  iex> doc = ~M\"""
  ...> # Languages
  ...>
  ...> `elixir`
  ...>
  ...> `rust`
  ...> \"""
  iex> traverse_and_update(doc, 0, fn
  ...>   %MDEx.Code{literal: "elixir"} = node, acc -> {%{node | literal: "ex"}, acc + 1}
  ...>   %MDEx.Code{literal: "rust"} = node, acc -> {%{node | literal: "rs"}, acc + 1}
  ...>   node, acc -> {node, acc}
  ...> end)
  {%MDEx.Document{
     nodes: [
       %MDEx.Heading{nodes: [%MDEx.Text{literal: "Languages"}], level: 1, setext: false},
       %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "ex"}]},
       %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "rs"}]}
     ]
   }, 2}
  ```

  """

  @typedoc """
  Tree representation of a CommonMark document.
  """
  @type t :: %__MODULE__{nodes: [md_node()]}

  @typedoc """
  Fragment of a CommonMark document, a single node.
  """
  @type md_node ::
          MDEx.FrontMatter.t()
          | MDEx.BlockQuote.t()
          | MDEx.List.t()
          | MDEx.ListItem.t()
          | MDEx.DescriptionList.t()
          | MDEx.DescriptionItem.t()
          | MDEx.DescriptionTerm.t()
          | MDEx.DescriptionDetails.t()
          | MDEx.CodeBlock.t()
          | MDEx.HtmlBlock.t()
          | MDEx.Paragraph.t()
          | MDEx.Heading.t()
          | MDEx.ThematicBreak.t()
          | MDEx.FootnoteDefinition.t()
          | MDEx.FootnoteReference.t()
          | MDEx.Table.t()
          | MDEx.TableRow.t()
          | MDEx.TableCell.t()
          | MDEx.Text.t()
          | MDEx.TaskItem.t()
          | MDEx.SoftBreak.t()
          | MDEx.LineBreak.t()
          | MDEx.Code.t()
          | MDEx.HtmlInline.t()
          | MDEx.Emph.t()
          | MDEx.Strong.t()
          | MDEx.Strikethrough.t()
          | MDEx.Superscript.t()
          | MDEx.Link.t()
          | MDEx.Image.t()
          | MDEx.ShortCode.t()
          | MDEx.Math.t()
          | MDEx.MultilineBlockQuote.t()
          | MDEx.Escaped.t()
          | MDEx.WikiLink.t()
          | MDEx.Underline.t()
          | MDEx.SpoileredText.t()
          | MDEx.EscapedTag.t()

  @typedoc """
  Selector to match a node in a document.
  """
  @type selector :: md_node() | module() | atom() | (md_node() -> boolean())

  defstruct nodes: []

  @behaviour Access

  # FIXME: check fragments
  @doc false
  defguard is_fragment(fragment) when is_struct(fragment)

  @doc """
  Callback implementation for `Access.fetch/2`.

  See the [Access](#module-access) section for examples.
  """
  @spec fetch(t(), selector()) :: {:ok, md_node()} | :error
  def fetch(document, selector)

  def fetch(%MDEx.Document{} = document, selector) when is_struct(selector) do
    case Enum.filter(document, fn node -> node == selector end) do
      nil -> :error
      node -> {:ok, node}
    end
  end

  def fetch(%MDEx.Document{} = document, selector) when is_atom(selector) do
    selector = modulefy(selector)

    case Enum.filter(document, fn %node{} -> node == selector end) do
      nil -> :error
      node -> {:ok, node}
    end
  end

  def fetch(%MDEx.Document{} = document, selector) when is_function(selector, 1) do
    case Enum.filter(document, selector) do
      nil -> :error
      node -> {:ok, node}
    end
  end

  @doc """
  Callback implementation for `Access.get_and_update/3`.

  See the [Access](#module-access) section for examples.
  """
  def get_and_update(%MDEx.Document{} = document, selector, fun) when is_struct(selector) do
    {document, {_, old}} =
      MDEx.Document.traverse_and_update(document, {:cont, nil}, fn
        node, {:halted, old} ->
          {node, {:halted, old}}

        ^selector, {:cont, _old} ->
          {old, new} = fun.(selector)
          {new, {:halted, old}}

        node, acc ->
          {node, acc}
      end)

    {old, document}
  end

  def get_and_update(%MDEx.Document{} = document, selector, fun) when is_atom(selector) do
    selector = modulefy(selector)

    {document, {_, old}} =
      MDEx.Document.traverse_and_update(document, {:cont, nil}, fn
        node, {:halted, old} ->
          {node, {:halted, old}}

        %mod{} = node, {:cont, _old} = acc ->
          if mod == selector do
            {old, new} = fun.(node)
            {new, {:halted, old}}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    {old, document}
  end

  def get_and_update(%MDEx.Document{} = document, selector, fun) when is_function(selector) do
    {document, {_, old}} =
      MDEx.Document.traverse_and_update(document, {:cont, nil}, fn
        node, {:halted, old} ->
          {node, {:halted, old}}

        node, acc ->
          if selector.(node) do
            {old, new} = fun.(node)
            {new, {:halted, old}}
          else
            {node, acc}
          end
      end)

    {old, document}
  end

  @doc """
  Callback implementation for `Access.fetch/2`.

  See the [Access](#module-access) section for examples.
  """
  def pop(doc, key, default \\ nil)

  def pop(%MDEx.Document{} = doc, key, default) when is_struct(key) do
    {new, {_, old}} =
      MDEx.Document.traverse_and_update(doc, {:cont, nil}, fn
        node, {:halted, old} ->
          {node, {:halted, old}}

        ^key, {:cont, _} ->
          {:pop, {:halted, key}}

        node, acc ->
          {node, acc}
      end)

    {old || default, new}
  end

  def pop(%MDEx.Document{} = doc, key, default) when is_atom(key) do
    key = modulefy(key)

    {new, {_, old}} =
      MDEx.Document.traverse_and_update(doc, {:cont, nil}, fn
        node, {:halted, old} ->
          {node, {:halted, old}}

        %mod{} = node, {:cont, _} = acc ->
          if mod == key do
            {:pop, {:halted, node}}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    {old || default, new}
  end

  defp modulefy(selector) when is_atom(selector) do
    case Atom.to_string(selector) do
      "Elixir." <> name -> Module.concat([name])
      atom -> Module.concat(["MDEx", Macro.camelize(atom)])
    end
  end

  # traverse_and_update/{2/3} based on https://github.com/philss/floki/blob/96955f925d62989b6f0bfaf09ce6505e67e04fbb/lib/floki/traversal.ex
  @doc """
  Traverse and update the Markdown document preserving the tree structure format.

  See the [Traverse and Update](#module-traverse-and-update) section for examples.
  """
  @spec traverse_and_update(t(), (md_node() -> md_node())) :: t()
  def traverse_and_update(%MDEx.Document{nodes: nodes} = doc, fun) do
    fun.(%{doc | nodes: do_traverse_and_update(nodes, fun)})
  end

  defp do_traverse_and_update([], _fun), do: []

  defp do_traverse_and_update([node | rest], fun) do
    case do_traverse_and_update(node, fun) do
      :pop ->
        do_traverse_and_update(rest, fun)

      nil ->
        do_traverse_and_update(rest, fun)

      mapped_node ->
        [mapped_node | do_traverse_and_update(rest, fun)]
    end
  end

  defp do_traverse_and_update(%{nodes: nodes} = node, fun) do
    fun.(%{node | nodes: do_traverse_and_update(nodes, fun)})
  end

  defp do_traverse_and_update(%{} = node, fun) do
    fun.(node)
  end

  @doc """
  Traverse and update the Markdown document preserving the tree structure format and keeping an accumulator.

  See the [Traverse and Update](#module-traverse-and-update) section for examples.
  """
  @spec traverse_and_update(t(), term(), (md_node() -> md_node())) :: t()
  def traverse_and_update(%MDEx.Document{nodes: nodes} = doc, acc, fun) do
    {mapped_nodes, new_acc} = do_traverse_and_update(nodes, acc, fun)
    fun.(%{doc | nodes: mapped_nodes}, new_acc)
  end

  defp do_traverse_and_update([], acc, _fun), do: {[], acc}

  defp do_traverse_and_update([node | rest], acc, fun) do
    case do_traverse_and_update(node, acc, fun) do
      {:pop, new_acc} ->
        do_traverse_and_update(rest, new_acc, fun)

      {nil, new_acc} ->
        do_traverse_and_update(rest, new_acc, fun)

      {mapped_node, new_acc} ->
        {mapped_rest, new_acc_rest} = do_traverse_and_update(rest, new_acc, fun)
        {[mapped_node | mapped_rest], new_acc_rest}
    end
  end

  defp do_traverse_and_update(%{nodes: nodes} = node, acc, fun) do
    {mapped_nodes, new_acc} = do_traverse_and_update(nodes, acc, fun)
    fun.(%{node | nodes: mapped_nodes}, new_acc)
  end

  defp do_traverse_and_update(%{} = node, acc, fun) do
    fun.(node, acc)
  end

  defimpl String.Chars do
    def to_string(%MDEx.Document{} = doc) do
      MDEx.to_commonmark!(doc)
    end
  end

  defimpl Enumerable do
    def count(_), do: {:error, __MODULE__}
    def member?(_, _), do: {:error, __MODULE__}
    def slice(_), do: {:error, __MODULE__}

    def reduce(_list, {:halt, acc}, _fun), do: {:halted, acc}
    def reduce(list, {:suspend, acc}, fun), do: {:suspended, acc, &reduce(list, &1, fun)}
    def reduce([], {:cont, acc}, _fun), do: {:done, acc}

    def reduce(%{nodes: nodes} = node, {:cont, acc}, fun) do
      reduce(nodes, fun.(node, acc), fun)
    end

    def reduce([%{nodes: nodes} = node | tail], {:cont, acc}, fun) do
      acc = fun.(node, acc)

      case reduce(nodes, acc, fun) do
        {:done, acc} ->
          reduce(tail, {:cont, acc}, fun)

        {:halted, term} when term in [true, false] ->
          {:done, acc}

        {:halted, node} ->
          {:done, node}

        {:suspended, acc, fun} ->
          {:suspended, acc, fun}

        acc ->
          reduce(tail, acc, fun)
      end
    end

    def reduce([node | tail], {:cont, acc}, fun) do
      acc = fun.(node, acc)
      reduce(tail, acc, fun)
    end
  end

  defimpl Collectable do
    def into(%MDEx.Document{nodes: nodes}) do
      fun = fn
        acc, {:cont, node} when is_struct(node) ->
          [node | acc]

        acc, :done ->
          nodes = nodes ++ :lists.reverse(acc)
          %MDEx.Document{nodes: nodes}

        _acc, :halt ->
          :ok

        _acc, {:cont, other} ->
          raise ArgumentError,
                "collecting into MDEx.Document requires a MDEx node, got: #{inspect(other)}"
      end

      {[], fun}
    end
  end
end

defmodule MDEx.FrontMatter do
  @moduledoc """
  Document metadata.
  """

  @type t :: %__MODULE__{literal: String.t()}
  defstruct literal: ""
end

defmodule MDEx.BlockQuote do
  @moduledoc """
  A block quote marker.

  Spec: https://github.github.com/gfm/#block-quotes
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
end

defmodule MDEx.List do
  @moduledoc """
  A List that contains `MDEx.ListItem`.

  Spec: https://github.github.com/gfm/#lists
  """

  @type t :: %__MODULE__{
          nodes: [MDEx.Document.md_node()],
          list_type: :bullet | :ordered,
          marker_offset: non_neg_integer(),
          padding: non_neg_integer(),
          start: non_neg_integer(),
          delimiter: :period | :paren,
          bullet_char: String.t(),
          tight: boolean()
        }
  defstruct nodes: [], list_type: :bullet, marker_offset: 0, padding: 2, start: 1, delimiter: :period, bullet_char: "-", tight: true
end

defmodule MDEx.ListItem do
  @moduledoc """
  A List Item of a `MDEx.List`.

  Spec: https://github.github.com/gfm/#list-items
  """

  @type t :: %__MODULE__{
          nodes: [MDEx.Document.md_node()],
          list_type: :bullet | :ordered,
          marker_offset: non_neg_integer(),
          padding: non_neg_integer(),
          start: non_neg_integer(),
          delimiter: :period | :paren,
          bullet_char: String.t(),
          tight: boolean()
        }
  defstruct nodes: [], list_type: :bullet, marker_offset: 0, padding: 2, start: 1, delimiter: :period, bullet_char: "-", tight: true
end

defmodule MDEx.DescriptionList do
  @moduledoc """
  A description list.
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
end

defmodule MDEx.DescriptionItem do
  @moduledoc """
  A description item of a description list.

  See `MDEx.DescriptionList`
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()], marker_offset: non_neg_integer(), padding: non_neg_integer()}
  defstruct nodes: [], marker_offset: 0, padding: 0
end

defmodule MDEx.DescriptionTerm do
  @moduledoc """
  A description term of a description item.

  See `MDEx.DescriptionList`
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
end

defmodule MDEx.DescriptionDetails do
  @moduledoc """
  Description details of a description item.

  See `MDEx.DescriptionList`
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
end

defmodule MDEx.CodeBlock do
  @moduledoc """
  A code block, fenced or indented.

  Spec: https://github.github.com/gfm/#fenced-code-blocks and https://github.github.com/gfm/#indented-code-blocks
  """

  @type t :: %__MODULE__{
          nodes: [MDEx.Document.md_node()],
          fenced: boolean(),
          fence_char: String.t(),
          fence_length: non_neg_integer(),
          fence_offset: non_neg_integer(),
          info: String.t(),
          literal: String.t()
        }
  defstruct nodes: [], fenced: true, fence_char: "`", fence_length: 3, fence_offset: 0, info: "", literal: ""
end

defmodule MDEx.HtmlBlock do
  @moduledoc """
  A HTML block.

  Spec: https://github.github.com/gfm/#html-blocks
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()], block_type: non_neg_integer(), literal: String.t()}
  defstruct nodes: [], block_type: 0, literal: ""
end

defmodule MDEx.Paragraph do
  @moduledoc """
  A paragraph that contains nodes.

  Spec: https://github.github.com/gfm/#paragraphs
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
end

defmodule MDEx.Heading do
  @moduledoc """
  A heading, either ATX or setext.

  ATX is the most common heading, a line starting with 1-6 `#` characters,
  and setext is represented as one or more lines followed by a heading underline as `===` or `---`.

  Spec: https://github.github.com/gfm/#atx-headings and https://github.github.com/gfm/#setext-headings
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()], level: pos_integer(), setext: boolean()}
  defstruct nodes: [], level: 1, setext: false
end

defmodule MDEx.ThematicBreak do
  @moduledoc """
  A break between lines.

  Spec: https://github.github.com/gfm/#thematic-breaks
  """

  @type t :: %__MODULE__{}
  defstruct []
end

defmodule MDEx.FootnoteDefinition do
  @moduledoc """
  A footnote definition.
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()], name: String.t(), total_references: non_neg_integer()}
  defstruct nodes: [], name: "", total_references: 0
end

defmodule MDEx.FootnoteReference do
  @moduledoc """
  The reference to a footnote.
  """

  @type t :: %__MODULE__{name: String.t(), ref_num: non_neg_integer(), ix: non_neg_integer()}
  defstruct name: "", ref_num: nil, ix: nil
end

defmodule MDEx.Table do
  @moduledoc """
  A table with rows and columns.

  Spec: https://github.github.com/gfm/#tables-extension-
  """

  @type t :: %__MODULE__{
          nodes: [MDEx.Document.md_node()],
          alignments: [:none | :left | :right | :center],
          num_columns: non_neg_integer(),
          num_rows: non_neg_integer(),
          num_nonempty_cells: non_neg_integer()
        }
  defstruct nodes: [], alignments: [], num_columns: 0, num_rows: 0, num_nonempty_cells: 0
end

defmodule MDEx.TableRow do
  @moduledoc """
  A table row.

  See `MDEx.Table`
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()], header: boolean()}
  defstruct nodes: [], header: false
end

defmodule MDEx.TableCell do
  @moduledoc """
  A table cell inside a table row.

  See `MDEx.Table`
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
end

defmodule MDEx.Text do
  @moduledoc """
  Literal text.

  Spec: https://github.github.com/gfm/#textual-content
  """

  @type t :: %__MODULE__{literal: String.t()}
  defstruct literal: ""
end

defmodule MDEx.TaskItem do
  @moduledoc """
  A task item inside a list.

  Spec: https://github.github.com/gfm/#task-list-items-extension-
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()], checked: boolean(), marker: String.t()}
  defstruct nodes: [], checked: false, marker: ""
end

defmodule MDEx.SoftBreak do
  @moduledoc """
  A soft line break.

  Spec: https://github.github.com/gfm/#soft-line-breaks
  """

  @type t :: %__MODULE__{}
  defstruct []
end

defmodule MDEx.LineBreak do
  @moduledoc """
  A hard line break.

  Spec: https://github.github.com/gfm/#hard-line-breaks
  """

  @type t :: %__MODULE__{}
  defstruct []
end

defmodule MDEx.Code do
  @moduledoc """
  Inline code span.

  Spec: https://github.github.com/gfm/#code-spans
  """

  @type t :: %__MODULE__{num_backticks: non_neg_integer(), literal: String.t()}
  defstruct num_backticks: 0, literal: ""
end

defmodule MDEx.HtmlInline do
  @moduledoc """
  Raw HTML.

  Spec: https://github.github.com/gfm/#raw-html
  """

  @type t :: %__MODULE__{literal: String.t()}
  defstruct literal: ""
end

defmodule MDEx.Emph do
  @moduledoc """
  Emphasis.

  Spec: https://github.github.com/gfm/#emphasis-and-strong-emphasis
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
end

defmodule MDEx.Strong do
  @moduledoc """
  Strong emphasis.

  Spec: https://github.github.com/gfm/#emphasis-and-strong-emphasis
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
end

defmodule MDEx.Strikethrough do
  @moduledoc """
  Strikethrough.

  Spec: https://github.github.com/gfm/#strikethrough-extension-
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
end

defmodule MDEx.Superscript do
  @moduledoc """
  Superscript.
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
end

defmodule MDEx.Link do
  @moduledoc """
  Link to a URL.

  Spec: https://github.github.com/gfm/#links
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()], url: String.t(), title: String.t() | nil}
  defstruct nodes: [], url: "", title: nil
end

defmodule MDEx.Image do
  @moduledoc """
  An image.

  Spec: https://github.github.com/gfm/#images
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()], url: String.t(), title: String.t() | nil}
  defstruct nodes: [], url: "", title: nil
end

defmodule MDEx.ShortCode do
  @moduledoc """
  Emoji generated from a shortcode.
  """

  @type t :: %__MODULE__{code: String.t(), emoji: String.t()}
  defstruct code: "", emoji: ""
end

defmodule MDEx.Math do
  @moduledoc """
  Inline math span.
  """

  @type t :: %__MODULE__{dollar_math: boolean(), display_math: boolean(), literal: String.t()}
  defstruct dollar_math: false, display_math: false, literal: ""
end

defmodule MDEx.MultilineBlockQuote do
  @moduledoc """
  A multiline block quote.

  Spec: https://github.github.com/gfm/#block-quotes
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()], fence_length: non_neg_integer(), fence_offset: non_neg_integer()}
  defstruct nodes: [], fence_length: 0, fence_offset: 0
end

defmodule MDEx.Escaped do
  @moduledoc """
  An escaped character.

  Spec: https://github.github.com/gfm/#backslash-escapes
  """

  @type t :: %__MODULE__{}
  defstruct []
end

defmodule MDEx.WikiLink do
  @moduledoc """
  A link in the form of a wiki link.
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()], url: String.t()}
  defstruct nodes: [], url: ""
end

defmodule MDEx.Underline do
  @moduledoc """
  Underline.
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
end

defmodule MDEx.SpoileredText do
  @moduledoc """
  Spoilered text.
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
end

defmodule MDEx.EscapedTag do
  @moduledoc """
  Escaped tag.
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()], literal: String.t()}
  defstruct nodes: [], literal: ""
end

defimpl String.Chars,
  for: [
    MDEx.FrontMatter,
    MDEx.BlockQuote,
    MDEx.List,
    MDEx.ListItem,
    MDEx.DescriptionList,
    MDEx.DescriptionItem,
    MDEx.DescriptionTerm,
    MDEx.DescriptionDetails,
    MDEx.CodeBlock,
    MDEx.HtmlBlock,
    MDEx.Paragraph,
    MDEx.Heading,
    MDEx.ThematicBreak,
    MDEx.FootnoteDefinition,
    MDEx.FootnoteReference,
    MDEx.Table,
    MDEx.TableRow,
    MDEx.TableCell,
    MDEx.Text,
    MDEx.TaskItem,
    MDEx.SoftBreak,
    MDEx.LineBreak,
    MDEx.Code,
    MDEx.HtmlInline,
    MDEx.Emph,
    MDEx.Strong,
    MDEx.Strikethrough,
    MDEx.Superscript,
    MDEx.Link,
    MDEx.Image,
    MDEx.ShortCode,
    MDEx.Math,
    MDEx.MultilineBlockQuote,
    MDEx.Escaped,
    MDEx.WikiLink,
    MDEx.Underline,
    MDEx.SpoileredText,
    MDEx.EscapedTag
  ] do
  def to_string(node) do
    Kernel.to_string(%MDEx.Document{nodes: [node]})
  end
end
