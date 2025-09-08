# based on https://github.com/wojtekmach/easyhtml

defmodule MDEx.Document do
  @moduledoc """
  Tree representation of a Markdown document.

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

  The `MDEx.Document` module represents the root of a document and implements several behaviours and protocols
  to enable operations to fetch, update, and manipulate the document tree.

  In these examples we will be using the [~MD](https://hexdocs.pm/mdex/MDEx.Sigil.html#sigil_MD/2) sigil.

  ## Tree Traversal

  **Understanding tree traversal is fundamental to working with MDEx documents**, as it affects how all 
  `Enum` functions, `Access` operations, and other protocols behave.

  The document tree is enumerated using **depth-first pre-order traversal**. This means:

  1. The parent node is visited first
  2. Then each child node is visited recursively
  3. Children are processed in the order they appear in the `:nodes` list

  This traversal order affects all `Enum` functions, including `Enum.at/2`, `Enum.map/2`, `Enum.find/2`, etc.

  ```elixir
  iex> doc = ~MD[# Hello]
  iex> Enum.at(doc, 0)
  %MDEx.Document{nodes: [%MDEx.Heading{nodes: [%MDEx.Text{literal: "Hello"}], level: 1, setext: false}]}
  iex> Enum.at(doc, 1)
  %MDEx.Heading{nodes: [%MDEx.Text{literal: "Hello"}], level: 1, setext: false}
  iex> Enum.at(doc, 2)
  %MDEx.Text{literal: "Hello"}
  ```

  More complex traversal with nested elements:

  ```elixir
  iex> doc = ~MD[**bold** text]
  iex> Enum.at(doc, 0)
  %MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Strong{nodes: [%MDEx.Text{literal: "bold"}]}, %MDEx.Text{literal: " text"}]}]}
  iex> Enum.at(doc, 1)
  %MDEx.Paragraph{nodes: [%MDEx.Strong{nodes: [%MDEx.Text{literal: "bold"}]}, %MDEx.Text{literal: " text"}]}
  iex> Enum.at(doc, 2)
  %MDEx.Strong{nodes: [%MDEx.Text{literal: "bold"}]}
  iex> Enum.at(doc, 3)
  %MDEx.Text{literal: "bold"}
  iex> Enum.at(doc, 4)
  %MDEx.Text{literal: " text"}
  ```

  ## Enumerable

  The `Enumerable` protocol allows us to call `Enum` functions to iterate over and manipulate the document tree.
  All enumeration follows the depth-first traversal order described above.

  Count the nodes in a document:

  ```elixir
  iex> doc = ~MD\"""
  ...> # Languages
  ...>
  ...> `elixir`
  ...>
  ...> `rust`
  ...> \"""
  iex> Enum.count(doc)
  7
  ```

  Count how many nodes have the `:literal` attribute:

  ```elixir
  iex> doc = ~MD\"""
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

  Check if a node is member of the document:

  ```elixir
  iex> doc = ~MD\"""
  ...> # Languages
  ...>
  ...> `elixir`
  ...>
  ...> `rust`
  ...> \"""
  iex> Enum.member?(doc, %MDEx.Code{literal: "elixir", num_backticks: 1})
  true
  ```

  Map each node to its module name:

  ```elixir
  iex> doc = ~MD\"""
  ...> # Languages
  ...>
  ...> `elixir`
  ...>
  ...> `rust`
  ...> \"""
  iex> Enum.map(doc, fn %node{} -> inspect(node) end)
  ["MDEx.Document", "MDEx.Heading", "MDEx.Text", "MDEx.Paragraph", "MDEx.Code", "MDEx.Paragraph", "MDEx.Code"]
  ```

  ## Access

  The `Access` behaviour gives you the ability to fetch and update nodes using different types of keys.
  Access operations also follow the depth-first traversal order when searching through nodes.

  Starting with a simple Markdown document, let's fetch only the text node by matching the `MDEx.Text` node:

  ```elixir
  iex> ~MD[# Hello][%MDEx.Text{literal: "Hello"}]
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

  Fetch all Code nodes, either by `MDEx.Code` module or the `:code` atom representing the Code node:

  ```elixir
  iex> doc = ~MD\"""
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

  Dynamically fetch Code nodes where the `:literal` (node content) starts with `"eli"` using a function to filter the result:

  ```elixir
  iex> doc = ~MD\"""
  ...> # Languages
  ...>
  ...> `elixir`
  ...>
  ...> `rust`
  ...> \"""
  iex> doc[fn node -> String.starts_with?(Map.get(node, :literal, ""), "eli") end]
  [%MDEx.Code{num_backticks: 1, literal: "elixir"}]
  ```

  That's the most flexible option, in case struct, modules, or atoms are not enough to match the node you want.

  The Access protocol also allows us to update nodes that match a selector.
  In the example below we'll capitalize the content of all `MDEx.Code` nodes:

  ```elixir
  iex> doc = ~MD\"""
  ...> # Languages
  ...>
  ...> `elixir`
  ...>
  ...> `rust`
  ...>
  ...> Continue...
  ...> \"""
  iex> update_in(doc, [:document, Access.key!(:nodes), Access.all(), :code, Access.key!(:literal)], fn literal ->
  ...>   String.upcase(literal)
  ...> end)
  %MDEx.Document{
    nodes: [
      %MDEx.Heading{nodes: [%MDEx.Text{literal: "Languages"}], level: 1, setext: false},
      %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "ELIXIR"}]},
      %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "RUST"}]},
      %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Continue..."}]}
    ]
  }
  ```

  ## String.Chars

  Calling `Kernel.to_string/1` will format it as CommonMark text:

  ```elixir
  iex> to_string(~MD[# Hello])
  "# Hello"
  ```

  Fragments (nodes without the parent `%Document{}`) are also formatted:

  ```elixir
  iex> to_string(%MDEx.Heading{nodes: [%MDEx.Text{literal: "Hello"}], level: 1})
  "# Hello"
  ```

  ## Traverse and Update

  You can also use the low-level `MDEx.traverse_and_update/2` and `MDEx.traverse_and_update/3` APIs
  to traverse each node of the AST and either update the nodes or do some calculation with an accumulator.

  ## Practical Examples

  Here are some common patterns for working with MDEx documents that combine the protocols described above.

  ### Update all code block nodes filtered by the `selector` function

  _Add line "// Modified" in Rust block codes_:

  ```elixir
  iex> doc = ~MD\"""
  ...> # Code Examples
  ...>
  ...> ```elixir
  ...> def hello do
  ...>   :world
  ...> end
  ...> ```
  ...>
  ...> ```rust
  ...> fn main() {
  ...>   println!(\"Hello\");
  ...> }
  ...> ```
  ...> \"""
  iex> selector = fn
  ...>   %MDEx.CodeBlock{info: "rust"} -> true
  ...>   _ -> false
  ...> end
  iex> update_in(doc, [:document, Access.key!(:nodes), Access.all(), selector], fn node ->
  ...>   %{node | literal: "// Modified\\n" <> node.literal}
  ...> end)
  %MDEx.Document{
    nodes: [
      %MDEx.Heading{
        nodes: [%MDEx.Text{literal: "Code Examples"}],
        level: 1,
        setext: false
      },
      %MDEx.CodeBlock{
        info: "elixir",
        literal: "def hello do\\n  :world\\nend\\n"
      },
      %MDEx.CodeBlock{
        info: "rust",
        literal: "// Modified\\nfn main() {\\n  println!(\\\"Hello\\\");\\n}\\n"
      }
    ]
  }
  ```

  ### Collect headings by level

  ```elixir
  iex> doc = ~MD\"""
  ...> # Main Title
  ...>
  ...> ## Section 1
  ...>
  ...> ### Subsection
  ...>
  ...> ## Section 2
  ...> \"""
  iex> Enum.reduce(doc, %{}, fn
  ...>   %MDEx.Heading{level: level, nodes: [%MDEx.Text{literal: text}]}, acc ->
  ...>     Map.update(acc, level, [text], &[text | &1])
  ...>   _node, acc -> acc
  ...> end)
  %{
    1 => ["Main Title"],
    2 => ["Section 2", "Section 1"],
    3 => ["Subsection"]
  }
  ```

  ### Extract and transform task list items

  ```elixir
  iex> doc = ~MD\"""
  ...> # Todo List
  ...>
  ...> - [ ] Buy groceries
  ...> - [x] Call mom
  ...> - [ ] Read book
  ...> \"""
  iex> Enum.map(doc, fn
  ...>   %MDEx.TaskItem{checked: checked, nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: text}]}]} ->
  ...>     {checked, text}
  ...>   _ -> nil
  ...> end)
  ...> |> Enum.reject(&is_nil/1)
  [
    {false, "Buy groceries"},
    {true, "Call mom"},
    {false, "Read book"}
  ]
  ```

  ### Bump all heading levels, except level 6

  ```elixir
  iex> doc = ~MD\"""
  ...> # Main Title
  ...>
  ...> ## Subtitle
  ...>
  ...> ###### Notes
  ...> \"""
  iex> selector = fn
  ...>   %MDEx.Heading{level: level} when level < 6 -> true
  ...>   _ -> false
  ...> end
  iex> update_in(doc, [:document, Access.key!(:nodes), Access.all(), selector], fn node ->
  ...>   %{node | level: node.level + 1}
  ...> end)
  %MDEx.Document{
    nodes: [
      %MDEx.Heading{nodes: [%MDEx.Text{literal: "Main Title"}], level: 2, setext: false},
      %MDEx.Heading{nodes: [%MDEx.Text{literal: "Subtitle"}], level: 3, setext: false},
      %MDEx.Heading{nodes: [%MDEx.Text{literal: "Notes"}], level: 6, setext: false}
    ]
  }
  ```
  """

  @typedoc """
  Tree root of a Markdown document, including all children nodes.
  """
  @type t :: %__MODULE__{nodes: [md_node()]}

  @typedoc """
  Fragment of a Markdown document, a single node. May contain children nodes.
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
          | MDEx.Raw.t()
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
          | MDEx.Subscript.t()
          | MDEx.SpoileredText.t()
          | MDEx.EscapedTag.t()
          | MDEx.Alert.t()

  @typedoc """
  Selector used to match nodes in the document.

  Valid selectors can be the module or struct, an atom representing the node name, or a function that receives a node and returns a boolean.

  See `MDEx.Document` for more info and examples.
  """
  @type selector :: md_node() | module() | atom() | (md_node() -> boolean())

  defstruct nodes: []

  @behaviour Access

  @doc false
  def is_fragment([fragment | _]), do: is_fragment(fragment)

  def is_fragment(%node{}) do
    node in [
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
      MDEx.Raw,
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
      MDEx.Subscript,
      MDEx.SpoileredText,
      MDEx.EscapedTag,
      MDEx.Alert
    ]
  end

  def is_fragment(_), do: false

  def wrap(%MDEx.Document{} = document), do: document
  def wrap(nodes), do: %MDEx.Document{nodes: List.wrap(nodes)}

  @doc """
  Callback implementation for `Access.fetch/2`.

  See the [Access](#module-access) section for examples.
  """
  @spec fetch(t(), selector()) :: {:ok, [md_node()]} | :error
  def fetch(document, selector), do: MDEx.Document.Access.fetch(document, selector)

  @doc """
  Callback implementation for `Access.get_and_update/3`.

  See the [Access](#module-access) section for examples.
  """
  def get_and_update(%MDEx.Document{} = document, selector, fun), do: MDEx.Document.Access.get_and_update(document, selector, fun)

  @doc """
  Callback implementation for `Access.fetch/2`.

  See the [Access](#module-access) section for examples.
  """
  def pop(%MDEx.Document{} = document, key, default \\ nil), do: MDEx.Document.Access.pop(document, key, default)

  defimpl Collectable do
    def into(%MDEx.Document{nodes: nodes}) do
      fun = fn
        acc, {:cont, node} when is_struct(node) ->
          [node | acc]

        acc, :done ->
          %MDEx.Document{nodes: nodes ++ :lists.reverse(acc)}

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
  use MDEx.Document.Access
end

defmodule MDEx.BlockQuote do
  @moduledoc """
  A block quote marker.

  Spec: https://github.github.com/gfm/#block-quotes
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
  use MDEx.Document.Access
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
          tight: boolean(),
          is_task_list: boolean()
        }
  defstruct nodes: [],
            list_type: :bullet,
            marker_offset: 0,
            padding: 2,
            start: 1,
            delimiter: :period,
            bullet_char: "-",
            tight: true,
            is_task_list: false

  use MDEx.Document.Access
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
          tight: boolean(),
          is_task_list: boolean()
        }
  defstruct nodes: [],
            list_type: :bullet,
            marker_offset: 0,
            padding: 2,
            start: 1,
            delimiter: :period,
            bullet_char: "-",
            tight: true,
            is_task_list: false

  use MDEx.Document.Access
end

defmodule MDEx.DescriptionList do
  @moduledoc """
  A description list.
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
  use MDEx.Document.Access
end

defmodule MDEx.DescriptionItem do
  @moduledoc """
  A description item of a description list.

  See `MDEx.DescriptionList`
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()], marker_offset: non_neg_integer(), padding: non_neg_integer(), tight: boolean()}
  defstruct nodes: [], marker_offset: 0, padding: 0, tight: false
  use MDEx.Document.Access
end

defmodule MDEx.DescriptionTerm do
  @moduledoc """
  A description term of a description item.

  See `MDEx.DescriptionList`
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
  use MDEx.Document.Access
end

defmodule MDEx.DescriptionDetails do
  @moduledoc """
  Description details of a description item.

  See `MDEx.DescriptionList`
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
  use MDEx.Document.Access
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
  use MDEx.Document.Access
end

defmodule MDEx.HtmlBlock do
  @moduledoc """
  A HTML block.

  Spec: https://github.github.com/gfm/#html-blocks
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()], block_type: non_neg_integer(), literal: String.t()}
  defstruct nodes: [], block_type: 0, literal: ""
  use MDEx.Document.Access
end

defmodule MDEx.Paragraph do
  @moduledoc """
  A paragraph that contains nodes.

  Spec: https://github.github.com/gfm/#paragraphs
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
  use MDEx.Document.Access
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
  use MDEx.Document.Access
end

defmodule MDEx.ThematicBreak do
  @moduledoc """
  A break between lines.

  Spec: https://github.github.com/gfm/#thematic-breaks
  """

  @type t :: %__MODULE__{}
  defstruct []
  use MDEx.Document.Access
end

defmodule MDEx.FootnoteDefinition do
  @moduledoc """
  A footnote definition.
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()], name: String.t(), total_references: non_neg_integer()}
  defstruct nodes: [], name: "", total_references: 0
  use MDEx.Document.Access
end

defmodule MDEx.FootnoteReference do
  @moduledoc """
  The reference to a footnote.
  """

  @type t :: %__MODULE__{name: String.t(), ref_num: non_neg_integer(), ix: non_neg_integer()}
  defstruct name: "", ref_num: nil, ix: nil
  use MDEx.Document.Access
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
  use MDEx.Document.Access
end

defmodule MDEx.TableRow do
  @moduledoc """
  A table row.

  See `MDEx.Table`
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()], header: boolean()}
  defstruct nodes: [], header: false
  use MDEx.Document.Access
end

defmodule MDEx.TableCell do
  @moduledoc """
  A table cell inside a table row.

  See `MDEx.Table`
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
  use MDEx.Document.Access
end

defmodule MDEx.Text do
  @moduledoc """
  Literal text.

  Spec: https://github.github.com/gfm/#textual-content
  """

  @type t :: %__MODULE__{literal: String.t()}
  defstruct literal: ""
  use MDEx.Document.Access
end

defmodule MDEx.TaskItem do
  @moduledoc """
  A task item inside a list.

  Spec: https://github.github.com/gfm/#task-list-items-extension-
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()], checked: boolean(), marker: String.t()}
  defstruct nodes: [], checked: false, marker: ""
  use MDEx.Document.Access
end

defmodule MDEx.SoftBreak do
  @moduledoc """
  A soft line break.

  Spec: https://github.github.com/gfm/#soft-line-breaks
  """

  @type t :: %__MODULE__{}
  defstruct []
  use MDEx.Document.Access
end

defmodule MDEx.LineBreak do
  @moduledoc """
  A hard line break.

  Spec: https://github.github.com/gfm/#hard-line-breaks
  """

  @type t :: %__MODULE__{}
  defstruct []
  use MDEx.Document.Access
end

defmodule MDEx.Code do
  @moduledoc """
  Inline code span.

  Spec: https://github.github.com/gfm/#code-spans
  """

  @type t :: %__MODULE__{num_backticks: non_neg_integer(), literal: String.t()}
  defstruct num_backticks: 0, literal: ""
  use MDEx.Document.Access
end

defmodule MDEx.HtmlInline do
  @moduledoc """
  Raw HTML.

  Spec: https://github.github.com/gfm/#raw-html
  """

  @type t :: %__MODULE__{literal: String.t()}
  defstruct literal: ""
  use MDEx.Document.Access
end

defmodule MDEx.Raw do
  @moduledoc """
  A Raw output node. This will be inserted verbatim into CommonMark and HTML output. It can only be created programmatically, and is never parsed from input.
  """

  @type t :: %__MODULE__{literal: String.t()}
  defstruct literal: ""
  use MDEx.Document.Access
end

defmodule MDEx.Emph do
  @moduledoc """
  Emphasis.

  Spec: https://github.github.com/gfm/#emphasis-and-strong-emphasis
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
  use MDEx.Document.Access
end

defmodule MDEx.Strong do
  @moduledoc """
  Strong emphasis.

  Spec: https://github.github.com/gfm/#emphasis-and-strong-emphasis
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
  use MDEx.Document.Access
end

defmodule MDEx.Strikethrough do
  @moduledoc """
  Strikethrough.

  Spec: https://github.github.com/gfm/#strikethrough-extension-
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
  use MDEx.Document.Access
end

defmodule MDEx.Superscript do
  @moduledoc """
  Superscript.
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
  use MDEx.Document.Access
end

defmodule MDEx.Link do
  @moduledoc """
  Link to a URL.

  Spec: https://github.github.com/gfm/#links
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()], url: String.t(), title: String.t() | nil}
  defstruct nodes: [], url: "", title: nil
  use MDEx.Document.Access
end

defmodule MDEx.Image do
  @moduledoc """
  An image.

  Spec: https://github.github.com/gfm/#images
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()], url: String.t(), title: String.t() | nil}
  defstruct nodes: [], url: "", title: nil
  use MDEx.Document.Access
end

defmodule MDEx.ShortCode do
  @moduledoc """
  Emoji generated from a shortcode.
  """

  @type t :: %__MODULE__{code: String.t(), emoji: String.t()}
  defstruct code: "", emoji: ""
  use MDEx.Document.Access
end

defmodule MDEx.Math do
  @moduledoc """
  Inline math span.
  """

  @type t :: %__MODULE__{dollar_math: boolean(), display_math: boolean(), literal: String.t()}
  defstruct dollar_math: false, display_math: false, literal: ""
  use MDEx.Document.Access
end

defmodule MDEx.MultilineBlockQuote do
  @moduledoc """
  A multiline block quote.

  Spec: https://github.github.com/gfm/#block-quotes
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()], fence_length: non_neg_integer(), fence_offset: non_neg_integer()}
  defstruct nodes: [], fence_length: 0, fence_offset: 0
  use MDEx.Document.Access
end

defmodule MDEx.Escaped do
  @moduledoc """
  An escaped character.

  Spec: https://github.github.com/gfm/#backslash-escapes
  """

  @type t :: %__MODULE__{}
  defstruct []
  use MDEx.Document.Access
end

defmodule MDEx.WikiLink do
  @moduledoc """
  A link in the form of a wiki link.
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()], url: String.t()}
  defstruct nodes: [], url: ""
  use MDEx.Document.Access
end

defmodule MDEx.Underline do
  @moduledoc """
  Underline.
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
  use MDEx.Document.Access
end

defmodule MDEx.Subscript do
  @moduledoc """
  Subscript.
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
  use MDEx.Document.Access
end

defmodule MDEx.SpoileredText do
  @moduledoc """
  Spoilered text.
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()]}
  defstruct nodes: []
  use MDEx.Document.Access
end

defmodule MDEx.EscapedTag do
  @moduledoc """
  Escaped tag.
  """

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()], literal: String.t()}
  defstruct nodes: [], literal: ""
  use MDEx.Document.Access
end

defmodule MDEx.Alert do
  @moduledoc """
  GitHub and GitLab style alerts / admonitions.

  See [GitHub](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#alerts)
  and [GitLab](https://docs.gitlab.com/user/markdown/#alerts) docs.
  """

  @type t :: %__MODULE__{
          nodes: [MDEx.Document.md_node()],
          alert_type: :note | :tip | :important | :warning | :caution,
          title: String.t() | nil,
          multiline: boolean(),
          fence_length: non_neg_integer(),
          fence_offset: non_neg_integer()
        }
  defstruct nodes: [],
            alert_type: :note,
            title: nil,
            multiline: false,
            fence_length: 0,
            fence_offset: 0

  use MDEx.Document.Access
end

defimpl Enumerable,
  for: [
    MDEx.Document,
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
    MDEx.FootnoteDefinition,
    MDEx.Table,
    MDEx.TableRow,
    MDEx.TableCell,
    MDEx.TaskItem,
    MDEx.Emph,
    MDEx.Strong,
    MDEx.Strikethrough,
    MDEx.Superscript,
    MDEx.Link,
    MDEx.Image,
    MDEx.MultilineBlockQuote,
    MDEx.WikiLink,
    MDEx.Underline,
    MDEx.Subscript,
    MDEx.SpoileredText,
    MDEx.EscapedTag,
    MDEx.Alert
  ] do
  def count(_), do: {:error, __MODULE__}
  def member?(_, _), do: {:error, __MODULE__}
  def slice(_), do: {:error, __MODULE__}

  def reduce(_node, {:halt, acc}, _fun), do: {:halted, acc}
  def reduce(node, {:suspend, acc}, fun), do: {:suspended, acc, &reduce(node, &1, fun)}

  def reduce(%{nodes: nodes} = node, {:cont, acc}, fun) do
    reduce_nodes(nodes, fun.(node, acc), fun)
  end

  defp reduce_nodes([], acc, _fun), do: acc

  defp reduce_nodes([%{nodes: inner_nodes} = node | tail], {:cont, acc}, fun) do
    case reduce_nodes(inner_nodes, fun.(node, acc), fun) do
      {:cont, acc} -> reduce_nodes(tail, {:cont, acc}, fun)
      result -> result
    end
  end

  defp reduce_nodes([%{nodes: _inner_nodes} = node | tail], {:suspend, acc}, fun) do
    {:suspended, acc, &reduce_nodes([node | tail], &1, fun)}
  end

  defp reduce_nodes([%{nodes: _inner_nodes} = _node | _tail], acc, _fun), do: acc

  defp reduce_nodes([node | tail], {:cont, acc}, fun) do
    reduce_nodes(tail, fun.(node, acc), fun)
  end

  defp reduce_nodes([node | tail], {:suspend, acc}, fun) do
    {:suspended, acc, &reduce_nodes([node | tail], &1, fun)}
  end

  defp reduce_nodes([_node | _tail], acc, _fun), do: acc
end

defimpl Enumerable,
  for: [
    MDEx.FrontMatter,
    MDEx.ThematicBreak,
    MDEx.FootnoteReference,
    MDEx.Text,
    MDEx.SoftBreak,
    MDEx.LineBreak,
    MDEx.Code,
    MDEx.HtmlInline,
    MDEx.Raw,
    MDEx.ShortCode,
    MDEx.Math,
    MDEx.Escaped
  ] do
  def count(_), do: {:error, __MODULE__}
  def member?(_, _), do: {:error, __MODULE__}
  def slice(_), do: {:error, __MODULE__}

  def reduce(_node, {:halt, acc}, _fun), do: {:halted, acc}
  def reduce(node, {:suspend, acc}, fun), do: {:suspended, acc, &reduce(node, &1, fun)}
  def reduce(node, {:cont, acc}, fun), do: {:done, fun.(node, acc)}
end

defimpl String.Chars, for: [MDEx.Document] do
  def to_string(%MDEx.Document{} = doc) do
    MDEx.to_markdown!(doc)
  end
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
    MDEx.Raw,
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
    MDEx.Subscript,
    MDEx.SpoileredText,
    MDEx.EscapedTag,
    MDEx.Alert
  ] do
  def to_string(node) do
    Kernel.to_string(%MDEx.Document{nodes: [node]})
  end
end

defimpl Inspect, for: MDEx.Document do
  import Inspect.Algebra

  def inspect(%MDEx.Document{} = doc, _opts) do
    node_count = Enum.count(doc) - 1
    header = "#MDEx.Document(#{node_count} nodes)<"

    content =
      case doc.nodes do
        [] ->
          empty()

        nodes ->
          tree_content = build_tree_lines(nodes, [], 1, true)
          concat([line(), tree_content])
      end

    concat([
      header,
      content,
      line(),
      ">"
    ])
  end

  defp build_tree_lines([], _prefix_acc, _index, _is_last), do: empty()

  defp build_tree_lines([node], prefix_acc, index, _is_last) do
    prefix = build_prefix(prefix_acc, true)
    line_content = build_node_line(node, index, prefix)

    case get_child_nodes(node) do
      [] ->
        line_content

      children ->
        child_content = build_tree_lines(children, [true | prefix_acc], index + 1, true)
        concat([line_content, line(), child_content])
    end
  end

  defp build_tree_lines([node | rest], prefix_acc, index, _is_last) do
    prefix = build_prefix(prefix_acc, false)
    line_content = build_node_line(node, index, prefix)

    case get_child_nodes(node) do
      [] ->
        next_index = index + 1
        rest_content = build_tree_lines(rest, prefix_acc, next_index, length(rest) == 0)
        concat([line_content, line(), rest_content])

      children ->
        child_count = count_nodes_in_subtree(children)
        child_content = build_tree_lines(children, [false | prefix_acc], index + 1, true)
        next_index = index + child_count + 1
        rest_content = build_tree_lines(rest, prefix_acc, next_index, length(rest) == 0)
        concat([line_content, line(), child_content, line(), rest_content])
    end
  end

  defp build_prefix(prefix_acc, is_last) do
    prefix_parts =
      prefix_acc
      |> Enum.reverse()
      |> Enum.map(fn
        true -> "    "
        false -> "│   "
      end)

    connector = if is_last, do: "└── ", else: "├── "

    concat([concat(prefix_parts), connector])
  end

  defp build_node_line(node, index, prefix) do
    node_name = get_node_name(node)
    attributes = get_node_attributes(node)

    line_parts = [
      prefix,
      "#{index} [#{node_name}]"
    ]

    line_parts = if attributes == "", do: line_parts, else: line_parts ++ [" #{attributes}"]

    concat(line_parts)
  end

  defp get_node_name(node) do
    node.__struct__
    |> to_string()
    |> String.replace_prefix("Elixir.MDEx.", "")
    |> Macro.underscore()
  end

  defp get_node_attributes(%{literal: literal} = node) when is_binary(literal) do
    other_attrs = get_other_attributes(node, [:literal, :nodes])

    if other_attrs == "" and literal != "" do
      "\"#{literal}\""
    else
      literal_attr = if literal != "", do: "literal: #{inspect(literal)}", else: ""
      [literal_attr, other_attrs] |> Enum.reject(&(&1 == "")) |> Enum.join(", ")
    end
  end

  defp get_node_attributes(node) do
    get_other_attributes(node, [:nodes])
  end

  defp get_other_attributes(node, exclude_keys) do
    node
    |> Map.from_struct()
    |> Map.drop(exclude_keys)
    |> Enum.map(fn {k, v} -> "#{k}: #{inspect(v)}" end)
    |> Enum.join(", ")
  end

  defp get_child_nodes(%{nodes: nodes}) when is_list(nodes), do: nodes
  defp get_child_nodes(_), do: []

  defp count_nodes_in_subtree(nodes) do
    Enum.reduce(nodes, 0, fn node, acc ->
      children = get_child_nodes(node)
      acc + 1 + count_nodes_in_subtree(children)
    end)
  end
end

defimpl Jason.Encoder,
  for: [
    MDEx.Document,
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
    MDEx.Raw,
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
    MDEx.Subscript,
    MDEx.SpoileredText,
    MDEx.EscapedTag,
    MDEx.Alert
  ] do
  def encode(%type{} = node, opts) do
    map =
      node
      |> Map.from_struct()
      |> Map.put("node_type", inspect(type))

    Jason.Encode.map(map, opts)
  end
end
