# based on https://github.com/wojtekmach/easyhtml

defmodule MDEx.Document do
  @moduledoc """
  Document is the core structure to store, manipulate, and render Markdown documents.

  ## Tree

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

  ### Tree Traversal

  **Understanding tree traversal is fundamental to working with MDEx documents**, as it affects how all 
  `Enum` functions, `Access` operations, and other protocols behave.

  The document tree is enumerated using **depth-first pre-order traversal**. This means:

  1. The parent node is visited first
  2. Then each child node is visited recursively
  3. Children are processed in the order they appear in the `:nodes` list

  This traversal order affects all `Enum` functions, including `Enum.at/2`, `Enum.map/2`, `Enum.find/2`, and friends.

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

  ### Traverse and Update

  You can also use the low-level `MDEx.traverse_and_update/2` and `MDEx.traverse_and_update/3` APIs
  to traverse each node of the AST and either update the nodes or do some calculation with an accumulator.

  ## Streaming

  > #### Experimental {: .warning}
  >
  > Streaming is still experimental and subject to change in future releases.
  >
  > It's **disabled by default** until the API is stabilized. Enable it with the option `streaming: true`.

  Streaming ties together `MDEx.new(streaming: true)`, `MDEx.Document.put_markdown/3`, and `MDEx.Document.run/1` or `MDEx.to_*`
  so you can feed complete or incomplete Markdown fragments into the Document which will be completed on demand to render valid output.

  Typical usage:

    1. Start with `MDEx.new(streaming: true)` — the document enables streaming and buffers fragments.
    2. Call `MDEx.Document.put_markdown/3` as fragments arrive — the text is buffered and parsing/rendering is deferred.
    3. Call `MDEx.Document.run/1` or any `MDEx.to_*` — buffered fragments are parsed completing nodes to ensure valid output.

  This is ideal for AI or chat apps where Markdown comes in bursts but must stay renderable.

  For example, feeding `**Fol` produces a temporary `MDEx.Strong` node then adding `low**` replaces it with the final content on the next run.

      iex> doc = MDEx.new(streaming: true) |> MDEx.Document.put_markdown("**Fol")
      iex> MDEx.to_html!(doc)
      "<p><strong>Fol</strong></p>"
      iex> doc |> MDEx.Document.put_markdown("low**") |> MDEx.to_html!()
      "<p><strong>Follow</strong></p>"

  You can find a demo application in `examples/streaming.exs`.

  ## Protocols

  ### Enumerable

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

  ### Collectable

  The `Collectable` protocol allows you to build documents by collecting nodes or merging multiple documents together.
  This is particularly useful for programmatically constructing documents from various sources.

  Merge two documents together using `Enum.into/2`:

  ```elixir
  iex> first_doc = ~MD[# First Document]
  iex> second_doc = ~MD[# Second Document]
  iex> Enum.into(second_doc, first_doc)
  %MDEx.Document{
    nodes: [
      %MDEx.Heading{nodes: [%MDEx.Text{literal: "First Document"}], level: 1, setext: false},
      %MDEx.Heading{nodes: [%MDEx.Text{literal: "Second Document"}], level: 1, setext: false}
    ]
  }
  ```

  Collect individual nodes into a document:

  ```elixir
  iex> chunks = [
  ...>   %MDEx.Text{literal: "Hello "},
  ...>   %MDEx.Code{literal: "world", num_backticks: 1}
  ...> ]
  iex> document = Enum.into(chunks, %MDEx.Document{})
  %MDEx.Document{
    nodes: [
      %MDEx.Text{literal: "Hello "},
      %MDEx.Code{literal: "world", num_backticks: 1}
    ]
  }
  iex> MDEx.to_html!(document)
  "Hello <code>world</code>"
  ```

  Build a document incrementally by collecting mixed content:

  ```elixir
  iex> chunks = [
  ...>   %MDEx.Heading{nodes: [%MDEx.Text{literal: "Title"}], level: 1, setext: false},
  ...>   %MDEx.Paragraph{nodes: []},
  ...>   %MDEx.Text{literal: "Some text"},
  ...>   %MDEx.ListItem{nodes: [%MDEx.Text{literal: "Item 1"}]},
  ...>   %MDEx.Text{literal: " - WIP"},
  ...> ]
  iex> document = Enum.into(chunks, %MDEx.Document{})
  %MDEx.Document{
    nodes: [
      %MDEx.Heading{
        level: 1,
        nodes: [%MDEx.Text{literal: "Title"}],
        setext: false
      },
      %MDEx.Paragraph{
        nodes: [%MDEx.Text{literal: "Some text"}]
      },
      %MDEx.List{
        bullet_char: "-",
        delimiter: :period,
        is_task_list: false,
        list_type: :bullet,
        marker_offset: 0,
        nodes: [%MDEx.ListItem{nodes: [%MDEx.Text{literal: "Item 1 - WIP"}], list_type: :bullet, marker_offset: 0, padding: 2, start: 1, delimiter: :period, bullet_char: "-", tight: true, is_task_list: false}],
        padding: 2,
        start: 1,
        tight: true
      }
    ]
  }
  iex> MDEx.to_html!(document)
  "<h1>Title</h1>\\n<p>Some text</p>\\n<ul>\\n<li>Item 1 - WIP</li>\\n</ul>"
  ```

  ### Access

  The `Access` behaviour gives you the ability to fetch and update nodes using different types of keys.
  Access operations also follow the depth-first traversal order when searching through nodes.

  #### Access by Index

  You can access nodes by their position in the depth-first traversal using integer indices:

  ```elixir
  iex> doc = ~MD[# Hello]
  iex> doc[0]
  %MDEx.Document{nodes: [%MDEx.Heading{nodes: [%MDEx.Text{literal: "Hello"}], level: 1, setext: false}]}
  iex> doc[1]
  %MDEx.Heading{nodes: [%MDEx.Text{literal: "Hello"}], level: 1, setext: false}
  iex> doc[2]
  %MDEx.Text{literal: "Hello"}
  ```

  Negative indices access nodes from the end:

  ```elixir
  iex> doc = ~MD[# Hello **world**]
  iex> doc[-1]  # Last node
  %MDEx.Text{literal: "world"}
  ```

  #### Access by Node Type

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

  ### String.Chars

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

  ### Inspect

  The `Inspect` protocol provides two display formats for documents:

  **Tree format (default)**: Shows the document structure as a visual tree, making it easy to understand the hierarchy and relationships between nodes.

  ```elixir
  iex> ~MD[# Hello :smile:]
  #MDEx.Document(3 nodes)<
  └── 1 [heading] level: 1, setext: false
      ├── 2 [text] literal: "Hello "
      └── 3 [short_code] code: "smile", emoji: "😄"
  >
  ```

  **Struct format**: Shows the raw struct representation, useful for debugging and testing. To enable this format:

  ```elixir
  iex> Application.put_env(:mdex, :inspect_format, :struct)
  iex> ~MD[# Hello :smile:]
  %MDEx.Document{
    nodes: [
      %MDEx.Heading{
        nodes: [%MDEx.Text{literal: "Hello "}, %MDEx.ShortCode{code: "smile", emoji: "😄"}],
        level: 1,
        setext: false
      }
    ],
    # ... other fields
  }
  ```

  The struct format is particularly useful in tests where you need to see exact differences between expected and actual values. You can set this in your `test/test_helper.exs`:

  ```elixir
  Application.put_env(:mdex, :inspect_format, :struct)
  ```

  ## Pipeline and Plugins

  MDEx.Document is a Req-like API to transform Markdown documents through a series of steps in a pipeline.

  Its main use case it to enable plugins, for example:

      markdown = \"\"\"
      # Project Diagram

      \`\`\`mermaid
      graph TD
          A[Enter Chart Definition] --> B(Preview)
          B --> C{decide}
          C --> D[Keep]
          C --> E[Edit Definition]
          E --> B
          D --> F[Save Image and Code]
          F --> B
      \`\`\`
      \"\"\"

      MDEx.new(markdown: markdown)
      |> MDExMermaid.attach(mermaid_version: "11")
      |> MDEx.to_html!()

  To understand how it works, let's write that Mermaid plugin.

  ### Writing Plugins

  Let's start with a simple plugin as example to render Mermaid diagrams.

  In order to render Mermaid diagrams, we need to inject a `<script>` into the document,
  as outlined in their [docs](https://mermaid.js.org/intro/#installation):

      <script type="module">
        import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
        mermaid.initialize({ startOnLoad: true });
      </script>

  Note that the package version is specified in the URL, so we'll add an option
  `:mermaid_version` to the plugin to let users specify the version they want to use.

  By default, we'll use the latest version:

      MDEx.new() |> MDExMermaid.attach()

  But users can override it:

      MDEx.new() |> MDExMermaid.attach(mermaid_version: "11")

  Let's get into the actual code, with comments to explain each part:

      defmodule MDExMermaid do
        alias MDEx.Document

        @latest_version "11"

        def attach(document, options \\ []) do
          document
          # register option with prefix `:mermaid_` to avoid conflicts with other plugins
          |> Document.register_options([:mermaid_version])
          #  merge all options given by users
          |> Document.put_options(options)
          # actual steps to manipulate the document
          # see respective Document functions for more info
          |> Document.append_steps(enable_unsafe: &enable_unsafe/1)
          |> Document.append_steps(inject_script: &inject_script/1)
          |> Document.append_steps(update_code_blocks: &update_code_blocks/1)
        end

        # to render raw html and <script> tags
        defp enable_unsafe(document) do
          Document.put_render_options(document, unsafe: true)
        end

        defp inject_script(document) do
          version = Document.get_option(document, :mermaid_version, @latest_version)

          script_node =
            %MDEx.HtmlBlock{
              literal: \"\"\"
              <script type="module">
                import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@\#\{version\}/dist/mermaid.esm.min.mjs';
                mermaid.initialize({ startOnLoad: true });
              </script>
              \"\"\"
            }

          Document.put_node_in_document_root(document, script_node)
        end

        defp update_code_blocks(document) do
          selector = fn
            %MDEx.CodeBlock{info: "mermaid"} -> true
            _ -> false
          end

          Document.update_nodes(
            document,
            selector,
            &%MDEx.HtmlBlock{literal: "<pre class=\"mermaid\">\#\{&1.literal}</pre>", nodes: &1.nodes}
          )
        end
      end

  Now we can `attach/1` that plugin into any MDEx document to render Mermaid diagrams.

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

  @behaviour Access
  alias __MODULE__
  alias MDEx.Native
  alias Autumn

  @built_in_options [
    :extension,
    :parse,
    :render,
    :syntax_highlight,
    :sanitize,
    :streaming
  ]

  @extension_options_schema [
    strikethrough: [
      type: :boolean,
      default: false,
      doc: "Enables the [strikethrough extension](https://github.github.com/gfm/#strikethrough-extension-) from the GFM spec."
    ],
    tagfilter: [
      type: :boolean,
      default: false,
      doc: "Enables the [tagfilter extension](https://github.github.com/gfm/#disallowed-raw-html-extension-) from the GFM spec."
    ],
    table: [
      type: :boolean,
      default: false,
      doc: "Enables the [table extension](https://github.github.com/gfm/#tables-extension-) from the GFM spec."
    ],
    autolink: [
      type: :boolean,
      default: false,
      doc: "Enables the [autolink extension](https://github.github.com/gfm/#autolinks-extension-) from the GFM spec."
    ],
    tasklist: [
      type: :boolean,
      default: false,
      doc: "Enables the [task list extension](https://github.github.com/gfm/#task-list-items-extension-) from the GFM spec."
    ],
    superscript: [
      type: :boolean,
      default: false,
      doc: "Enables the superscript Comrak extension."
    ],
    header_ids: [
      type: {:or, [:string, nil]},
      default: nil,
      doc: "Enables the header IDs Comrak extension."
    ],
    footnotes: [
      type: :boolean,
      default: false,
      doc: "Enables the footnotes extension per cmark-gfm"
    ],
    inline_footnotes: [
      type: :boolean,
      default: false,
      doc: "Enables inline footnotes with ^[footnote content] syntax"
    ],
    description_lists: [
      type: :boolean,
      default: false,
      doc: "Enables the description lists extension."
    ],
    front_matter_delimiter: [
      type: {:or, [:string, nil]},
      default: nil,
      doc: "Enables the front matter extension."
    ],
    multiline_block_quotes: [
      type: :boolean,
      default: false,
      doc: "Enables the multiline block quotes extension."
    ],
    alerts: [
      type: :boolean,
      default: false,
      doc: "Enables GitHub style alerts."
    ],
    math_dollars: [
      type: :boolean,
      default: false,
      doc: "Enables math using dollar syntax."
    ],
    math_code: [
      type: :boolean,
      default: false,
      doc: "Enables the [math code extension](https://github.github.com/gfm/#math-code) from the GFM spec."
    ],
    shortcodes: [
      type: :boolean,
      default: false,
      doc: "Phrases wrapped inside of ':' blocks will be replaced with emojis."
    ],
    wikilinks_title_after_pipe: [
      type: :boolean,
      default: false,
      doc: "Enables wikilinks using title after pipe syntax."
    ],
    wikilinks_title_before_pipe: [
      type: :boolean,
      default: false,
      doc: "Enables wikilinks using title before pipe syntax."
    ],
    underline: [
      type: :boolean,
      default: false,
      doc: "Enables underlines using double underscores."
    ],
    subscript: [
      type: :boolean,
      default: false,
      doc: "Enables subscript text using single tildes."
    ],
    spoiler: [
      type: :boolean,
      default: false,
      doc: "Enables spoilers using double vertical bars."
    ],
    greentext: [
      type: :boolean,
      default: false,
      doc: "Requires at least one space after a > character to generate a blockquote, and restarts blockquote nesting across unique lines of input."
    ],
    subtext: [
      type: :boolean,
      default: false,
      doc: "Enables Discord-style subtext using curly braces with hyphens: {-text-}."
    ],
    highlight: [
      type: :boolean,
      default: false,
      doc: "Enables the highlight extension using double equals ==highlighted text== (wraps text in <mark> tags)."
    ],
    image_url_rewriter: [
      type: {:or, [:string, nil]},
      default: nil,
      doc: """
        Wraps embedded image URLs using a string template.

        Example:

        Given this image `![alt text](http://unsafe.com/image.png)` and this rewriter:

          image_url_rewriter: "https://example.com?url={@url}"

        Renders `<p><img src="https://example.com?url=http://unsafe.com/image.png" alt="alt text" /></p>`

        Notes:

        - Assign `@url` is always passed to the template.
        - Function callback is not supported, only string templates.
          Transform the Document AST for more complex cases.
      """
    ],
    link_url_rewriter: [
      type: {:or, [:string, nil]},
      default: nil,
      doc: """
        Wraps link URLs using a string template.

        Example:

        Given this link `[my link](http://unsafe.example.com/bad)` and this rewriter:

          link_url_rewriter: "https://safe.example.com/norefer?url={@url}"

        Renders `<p><a href="https://safe.example.com/norefer?url=http://unsafe.example.com/bad">my link</a></p>`

        Notes:

        - Assign `@url` is always passed to the template.
        - Function callback is not supported, only string templates.
          Transform the Document AST for more complex cases.
      """
    ],
    cjk_friendly_emphasis: [
      type: :boolean,
      default: false,
      doc: "Recognizes many emphasis that appear in CJK contexts but are not recognized by plain CommonMark."
    ]
  ]

  @parse_options_schema [
    smart: [
      type: :boolean,
      default: false,
      doc: "Punctuation (quotes, full-stops and hyphens) are converted into 'smart' punctuation."
    ],
    default_info_string: [
      type: {:or, [:string, nil]},
      default: nil,
      doc: "The default info string for fenced code blocks."
    ],
    relaxed_tasklist_matching: [
      type: :boolean,
      default: false,
      doc: "Whether or not a simple `x` or `X` is used for tasklist or any other symbol is allowed."
    ],
    relaxed_autolinks: [
      type: :boolean,
      default: true,
      doc:
        "Relax parsing of autolinks, allow links to be detected inside brackets and allow all url schemes. It is intended to allow a very specific type of autolink detection, such as `[this http://and.com that]` or `{http://foo.com}`, on a best can basis."
    ],
    ignore_setext: [
      type: :boolean,
      default: false,
      doc: "Ignore setext headings in input."
    ],
    tasklist_in_table: [
      type: :boolean,
      default: false,
      doc: "Parse a tasklist item if it's the only content of a table cell."
    ],
    leave_footnote_definitions: [
      type: :boolean,
      default: false,
      doc: "Leave footnote definitions inline instead of moving them to the end of the document."
    ],
    escaped_char_spans: [
      type: :boolean,
      default: false,
      doc: "Track escaped characters with their source positions."
    ]
  ]

  @render_options_schema [
    hardbreaks: [
      type: :boolean,
      default: false,
      doc: "[Soft line breaks](http://spec.commonmark.org/0.27/#soft-line-breaks) in the input translate into hard line breaks in the output."
    ],
    github_pre_lang: [
      type: :boolean,
      default: false,
      doc: "GitHub-style `<pre lang=\"xyz\">` is used for fenced code blocks with info tags."
    ],
    full_info_string: [
      type: :boolean,
      default: false,
      doc: "Enable full info strings for code blocks."
    ],
    width: [
      type: :integer,
      default: 0,
      doc: "The wrap column when outputting CommonMark."
    ],
    unsafe: [
      type: :boolean,
      default: false,
      doc: "Allow rendering of raw HTML and potentially dangerous links."
    ],
    escape: [
      type: :boolean,
      default: false,
      doc: "Escape raw HTML instead of clobbering it."
    ],
    list_style: [
      type: {:in, [:dash, :plus, :star]},
      default: :dash,
      doc: """
      Set the type of [bullet list marker](https://spec.commonmark.org/0.30/#bullet-list-marker) to use.
      Either one of `:dash`, `:plus`, or `:star`.
      """
    ],
    sourcepos: [
      type: :boolean,
      default: false,
      doc: "Include source position attributes in HTML and XML output."
    ],
    escaped_char_spans: [
      type: :boolean,
      default: false,
      doc: "Wrap escaped characters in a `<span>` to allow any post-processing to recognize them."
    ],
    ignore_empty_links: [
      type: :boolean,
      default: false,
      doc: "Ignore empty links in input."
    ],
    gfm_quirks: [
      type: :boolean,
      default: false,
      doc: "Enables GFM quirks in HTML output which break CommonMark compatibility."
    ],
    prefer_fenced: [
      type: :boolean,
      default: false,
      doc: "Prefer fenced code blocks when outputting CommonMark."
    ],
    figure_with_caption: [
      type: :boolean,
      default: false,
      doc: "Render the image as a figure element with the title as its caption."
    ],
    tasklist_classes: [
      type: :boolean,
      default: false,
      doc: "Add classes to the output of the tasklist extension. This allows tasklists to be styled."
    ],
    ol_width: [
      type: :integer,
      default: 1,
      doc: "Render ordered list with a minimum marker width. Having a width lower than 3 doesn't do anything."
    ],
    experimental_minimize_commonmark: [
      type: :boolean,
      default: false,
      doc: """
      Minimise escapes used in CommonMark output (`-t commonmark`) by removing each individually and seeing if the resulting document roundtrips.
      Brute-force and expensive, but produces nicer output.
      Note that the result may not in fact be minimal.
      """
    ]
  ]

  @syntax_highlight_options_schema [
    formatter: [
      type: {:custom, Autumn, :formatter_type, []},
      type_spec: quote(do: Autumn.formatter()),
      type_doc: "`t:Autumn.formatter/0`",
      default: {:html_inline, theme: "onedark"},
      doc: "Syntax highlight code blocks using this formatter. See the type doc for more info."
    ]
  ]

  @sanitize_options_schema [
    tags: [
      type: {:list, :string},
      default:
        ~w(a abbr acronym area article aside b bdi bdo blockquote br caption center cite code col colgroup data dd del details dfn div dl dt em figcaption figure footer h1 h2 h3 h4 h5 h6 header hgroup hr i img ins kbd li map mark nav ol p pre q rp rt rtc ruby s samp small span strike strong sub summary sup table tbody td th thead time tr tt u ul var wbr),
      doc: "Sets the tags that are allowed."
    ],
    add_tags: [
      type: {:list, :string},
      default: [],
      doc: "Add additional whitelisted tags without overwriting old ones."
    ],
    rm_tags: [
      type: {:list, :string},
      default: [],
      doc: "Remove already-whitelisted tags."
    ],
    clean_content_tags: [
      type: {:list, :string},
      default: ~w(script style),
      doc: "Sets the tags whose contents will be completely removed from the output."
    ],
    add_clean_content_tags: [
      type: {:list, :string},
      default: [],
      doc: "Add additional blacklisted clean-content tags without overwriting old ones."
    ],
    rm_clean_content_tags: [
      type: {:list, :string},
      default: [],
      doc: "Remove already-blacklisted clean-content tags."
    ],
    tag_attributes: [
      type: {:map, :string, {:list, :string}},
      default: %{
        "a" => ~w(href hreflang),
        "bdo" => ~w(dir),
        "blockquote" => ~w(cite),
        "code" => ~w(class translate tabindex),
        "col" => ~w(align char charoff span),
        "colgroup" => ~w(align char charoff span),
        "del" => ~w(cite datetime),
        "hr" => ~w(align size width),
        "img" => ~w(align alt height src width),
        "ins" => ~w(cite datetime),
        "ol" => ~w(start),
        "pre" => ~w(class style),
        "q" => ~w(cite),
        "span" => ~w(class style data-line),
        "table" => ~w(align char charoff summary),
        "tbody" => ~w(align char charoff),
        "td" => ~w(align char charoff colspan headers rowspan),
        "tfoot" => ~w(align char charoff),
        "th" => ~w(align char charoff colspan headers rowspan scope),
        "thead" => ~w(align char charoff),
        "tr" => ~w(align char charoff)
      },
      doc: "Sets the HTML attributes that are allowed on specific tags."
    ],
    add_tag_attributes: [
      type: {:map, :string, {:list, :string}},
      default: %{},
      doc: "Add additional whitelisted tag-specific attributes without overwriting old ones."
    ],
    rm_tag_attributes: [
      type: {:map, :string, {:list, :string}},
      default: %{},
      doc: "Remove already-whitelisted tag-specific attributes."
    ],
    tag_attribute_values: [
      type: {:map, :string, {:map, :string, {:list, :string}}},
      default: %{},
      doc: "Sets the values of HTML attributes that are allowed on specific tags."
    ],
    add_tag_attribute_values: [
      type: {:map, :string, {:map, :string, {:list, :string}}},
      default: %{},
      doc: "Add additional whitelisted tag-specific attribute values without overwriting old ones."
    ],
    rm_tag_attribute_values: [
      type: {:map, :string, {:map, :string, {:list, :string}}},
      default: %{},
      doc: "Remove already-whitelisted tag-specific attribute values."
    ],
    set_tag_attribute_values: [
      type: {:map, :string, {:map, :string, :string}},
      default: %{},
      doc: "Sets the values of HTML attributes that are to be set on specific tags."
    ],
    set_tag_attribute_value: [
      type: {:map, :string, {:map, :string, :string}},
      default: %{},
      doc: "Add an attribute value to set on a specific element."
    ],
    rm_set_tag_attribute_value: [
      type: {:map, :string, :string},
      default: %{},
      doc: "Remove existing tag-specific attribute values to be set."
    ],
    generic_attribute_prefixes: [
      type: {:list, :string},
      default: [],
      doc: "Sets the prefix of attributes that are allowed on any tag."
    ],
    add_generic_attribute_prefixes: [
      type: {:list, :string},
      default: [],
      doc: "Add additional whitelisted attribute prefix without overwriting old ones."
    ],
    rm_generic_attribute_prefixes: [
      type: {:list, :string},
      default: [],
      doc: "Remove already-whitelisted attribute prefixes."
    ],
    generic_attributes: [
      type: {:list, :string},
      default: ~w(lang title),
      doc: "Sets the attributes that are allowed on any tag."
    ],
    add_generic_attributes: [
      type: {:list, :string},
      default: [],
      doc: "Add additional whitelisted attributes without overwriting old ones."
    ],
    rm_generic_attributes: [
      type: {:list, :string},
      default: [],
      doc: "Remove already-whitelisted attributes."
    ],
    url_schemes: [
      type: {:list, :string},
      default: ~w(bitcoin ftp ftps geo http https im irc ircs magnet mailto mms mx news nntp openpgp4fpr sip sms smsto ssh tel url webcal wtai xmpp),
      doc: "Sets the URL schemes permitted on href and src attributes."
    ],
    add_url_schemes: [
      type: {:list, :string},
      default: [],
      doc: "Add additional whitelisted URL schemes without overwriting old ones."
    ],
    rm_url_schemes: [
      type: {:list, :string},
      default: [],
      doc: "Remove already-whitelisted attributes."
    ],
    url_relative: [
      type: {:or, [{:in, [:deny, :passthrough]}, {:tuple, [:atom, :string]}, {:tuple, [:atom, {:tuple, [:string, :string]}]}]},
      default: :passthrough,
      doc: "Configures the behavior for relative URLs: pass-through, resolve-with-base, or deny."
    ],
    link_rel: [
      type: {:or, [:string, nil]},
      default: "noopener noreferrer",
      doc: "Configures a `rel` attribute that will be added on links."
    ],
    allowed_classes: [
      type: {:map, :string, {:list, :string}},
      default: %{},
      doc: "Sets the CSS classes that are allowed on specific tags."
    ],
    add_allowed_classes: [
      type: {:map, :string, {:list, :string}},
      default: %{},
      doc: "Add additional whitelisted classes without overwriting old ones."
    ],
    rm_allowed_classes: [
      type: {:map, :string, {:list, :string}},
      default: %{},
      doc: "Remove already-whitelisted attributes."
    ],
    strip_comments: [
      type: :boolean,
      default: true,
      doc: "Configures the handling of HTML comments."
    ],
    id_prefix: [
      type: {:or, [:string, nil]},
      default: nil,
      doc: "Prefixes all `id` attribute values with a given string. Note that the tag and attribute themselves must still be whitelisted."
    ]
  ]

  @options_schema [
    extension: [
      type: :keyword_list,
      type_spec: quote(do: extension_options()),
      default: [],
      doc:
        "Enable extensions. See comrak's [ExtensionOptions](https://docs.rs/comrak/latest/comrak/struct.ExtensionOptions.html) for more info and examples.",
      keys: @extension_options_schema
    ],
    parse: [
      type: :keyword_list,
      type_spec: quote(do: parse_options()),
      default: [],
      doc:
        "Configure parsing behavior. See comrak's [ParseOptions](https://docs.rs/comrak/latest/comrak/struct.ParseOptions.html) for more info and examples.",
      keys: @parse_options_schema
    ],
    render: [
      type: :keyword_list,
      type_spec: quote(do: render_options()),
      default: [],
      doc:
        "Configure rendering behavior. See comrak's [RenderOptions](https://docs.rs/comrak/latest/comrak/struct.RenderOptions.html) for more info and examples.",
      keys: @render_options_schema
    ],
    syntax_highlight: [
      type: {:or, [{:keyword_list, @syntax_highlight_options_schema}, nil]},
      type_spec: quote(do: syntax_highlight_options() | nil),
      default: [formatter: {:html_inline, theme: "onedark"}],
      doc: """
        Apply syntax highlighting to code blocks.

        Examples:

            syntax_highlight: [formatter: {:html_inline, theme: "github_dark"}]

            syntax_highlight: [formatter: {:html_linked, theme: "github_light"}]

        See [Autumn](https://hexdocs.pm/autumn) for more info and examples.
      """
    ],
    sanitize: [
      type: {:or, [{:keyword_list, @sanitize_options_schema}, nil]},
      type_spec: quote(do: sanitize_options() | nil),
      default: nil,
      doc: """
      Cleans HTML using [ammonia](https://crates.io/crates/ammonia) after rendering.

      It's disabled by default but you can enable its [conservative set of default options](https://docs.rs/ammonia/latest/ammonia/fn.clean.html) as:

          [sanitize: MDEx.Document.default_sanitize_options()]

      Or customize one of the options. For example, to disallow `<a>` tags:

          [sanitize: [rm_tags: ["a"]]]

      In the example above it will append `rm_tags: ["a"]` into the default set of options, essentially the same as:

          sanitize = Keyword.put(MDEx.Document.default_sanitize_options(), :rm_tags, ["a"])
          [sanitize: sanitize]

      See the [Safety](#module-safety) section for more info.
      """
    ],
    streaming: [
      type: :boolean,
      default: false,
      doc: "Enables streaming (experimental)."
    ]
  ]

  @typedoc """
  Tree root of a Markdown document, including all children nodes.
  """
  @type t :: %__MODULE__{
          nodes: [md_node()],
          options: options(),
          registered_options: MapSet.t(),
          halted: boolean(),
          steps: [step()],
          private: %{}
        }

  defstruct nodes: [],
            buffer: [],
            options: [],
            registered_options: MapSet.new(@built_in_options),
            halted: false,
            steps: [],
            current_steps: [],
            private: %{}

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
  Step in a pipeline.

  It's a function that receives a `t:MDEx.Document.t/0` struct and must return either one of the following:

    - a `t:MDEx.Document.t/0` struct
    - a tuple with a `t:MDEx.Document.t/0` struct and an `t:Exception.t/0` as `{document, exception}`
    - a tuple with a module, function and arguments which will be invoked with `apply/3`
  """
  @type step() ::
          (t() -> t())
          | (t() -> {t(), Exception.t()})
          | (t() -> {module(), atom(), [term()]})

  @typedoc """
  Selector used to match nodes in the document.

  Valid selectors can be the module or struct, an atom representing the node name, or a function that receives a node and returns a boolean.

  See `MDEx.Document` for more info and examples.
  """
  @type selector :: md_node() | module() | atom() | (md_node() -> boolean())

  @doc """
  Returns all default options.

  ```elixir
  #{inspect(NimbleOptions.validate!([], @options_schema), pretty: true, limit: :infinity, printable_limit: :infinity)}
  ```
  """
  @spec default_options() :: options()
  def default_options, do: NimbleOptions.validate!([], @options_schema)

  @doc """
  Returns the default `:extension` options.

  ```elixir
  #{inspect(NimbleOptions.validate!([], @extension_options_schema), pretty: true, limit: :infinity, printable_limit: :infinity)}
  ```
  """
  @spec default_extension_options() :: extension_options()
  def default_extension_options, do: NimbleOptions.validate!([], @extension_options_schema)

  @doc """
  Returns the default `:parse` options.

  ```elixir
  #{inspect(NimbleOptions.validate!([], @parse_options_schema), pretty: true, limit: :infinity, printable_limit: :infinity)}
  ```
  """
  @spec default_parse_options() :: parse_options()
  def default_parse_options, do: NimbleOptions.validate!([], @parse_options_schema)

  @doc """
  Returns the default `:render` options.

  ```elixir
  #{inspect(NimbleOptions.validate!([], @render_options_schema), pretty: true, limit: :infinity, printable_limit: :infinity)}
  ```
  """
  @spec default_render_options() :: render_options()
  def default_render_options, do: NimbleOptions.validate!([], @render_options_schema)

  @doc """
  Returns the default `:syntax_highlight` options.

  ```elixir
  #{inspect(NimbleOptions.validate!([], @syntax_highlight_options_schema), pretty: true, limit: :infinity, printable_limit: :infinity)}
  ```
  """
  @spec default_syntax_highlight_options() :: syntax_highlight_options()
  def default_syntax_highlight_options, do: NimbleOptions.validate!([], @syntax_highlight_options_schema)

  @doc """
  Returns the default `:sanitize` options.

  ```elixir
  #{inspect(NimbleOptions.validate!([], @sanitize_options_schema), pretty: true, limit: :infinity, printable_limit: :infinity)}
  ```
  """
  @spec default_sanitize_options() :: sanitize_options()
  def default_sanitize_options, do: NimbleOptions.validate!([], @sanitize_options_schema)

  @doc false
  def sanitize_options_schema, do: @sanitize_options_schema

  @doc """
  Registers a list of valid options that can be used by steps in the document pipeline.

  ## Examples

      iex> document = MDEx.new()
      iex> document = MDEx.Document.register_options(document, [:mermaid_version])
      iex> document = MDEx.Document.put_options(document, mermaid_version: "11")
      iex> document.options[:mermaid_version]
      "11"

      iex> MDEx.new(rendr: [unsafe: true])
      ** (ArgumentError) unknown option :rendr. Did you mean :render?

  """
  @spec register_options(t(), [atom()]) :: t()
  def register_options(%MDEx.Document{} = document, options) when is_list(options) do
    update_in(document.registered_options, &MapSet.union(&1, MapSet.new(options)))
  end

  @doc """
  Merges options into the document options.

  This function handles both built-in options (`:extension`, `:parse`, `:render`, `:syntax_highlight`, and `:sanitize`)
  and user-defined options that have been registered with `register_options/2`.

  ## Examples

      iex> document = MDEx.Document.register_options(MDEx.new(), [:custom_option])
      iex> document = MDEx.Document.put_options(document, [
      ...>   extension: [table: true],
      ...>   custom_option: "value"
      ...> ])
      iex> MDEx.Document.get_option(document, :extension)[:table]
      true
      iex> MDEx.Document.get_option(document, :custom_option)
      "value"

  Built-in options are validated against their respective schemas:

      iex> try do
      ...>   MDEx.Document.put_options(MDEx.new(), [extension: [invalid: true]])
      ...> rescue
      ...>   NimbleOptions.ValidationError -> :error
      ...> end
      :error

  """
  @spec put_options(t(), keyword()) :: t()
  def put_options(%MDEx.Document{} = document, [] = _options) do
    document
  end

  def put_options(%MDEx.Document{} = document, options) when is_list(options) do
    Enum.reduce(options, document, fn
      {name, options}, acc when name in @built_in_options ->
        put_built_in_options(acc, [{name, options}])

      {name, value}, acc ->
        put_user_options(acc, [{name, value}])
    end)
  end

  @doc false
  def put_built_in_options(document, options) when is_list(options) do
    options = Keyword.take(options, @built_in_options)

    Enum.reduce(options, document, fn
      {:extension, options}, acc ->
        put_extension_options(acc, options)

      {:render, options}, acc ->
        put_render_options(acc, options)

      {:parse, options}, acc ->
        put_parse_options(acc, options)

      {:syntax_highlight, options}, acc ->
        put_syntax_highlight_options(acc, options)

      {:sanitize, options}, acc ->
        put_sanitize_options(acc, options)

      {:streaming, value}, acc ->
        %{acc | options: Keyword.put(acc.options || [], :streaming, value)}
    end)
  end

  @doc false
  def put_user_options(document, options) when is_list(options) do
    options = Keyword.take(options, Keyword.keys(options) -- @built_in_options)
    validate_user_options(options, document.registered_options)
    %{document | options: Keyword.merge(document.options, options)}
  end

  defp validate_user_options([{name, _value} | rest], registered) do
    if name in registered do
      validate_user_options(rest, registered)
    else
      case did_you_mean(Atom.to_string(name), registered) do
        {similar, score} when score > 0.8 ->
          raise ArgumentError, "unknown option #{inspect(name)}. Did you mean :#{similar}?"

        _ ->
          raise ArgumentError, "unknown option #{inspect(name)}"
      end
    end
  end

  defp validate_user_options([], _registered) do
    true
  end

  defp did_you_mean(option, registered) do
    registered
    |> Enum.map(&to_string/1)
    |> Enum.reduce({nil, 0}, &max_similar(&1, option, &2))
  end

  defp max_similar(option, registered, {_, current} = best) do
    score = String.jaro_distance(option, registered)
    if score < current, do: best, else: {option, score}
  end

  @doc """
  Updates the document's `:extension` options.

  ## Examples

      iex> document = MDEx.Document.put_extension_options(MDEx.new(), table: true)
      iex> MDEx.Document.get_option(document, :extension)[:table]
      true

  """
  @spec put_extension_options(t(), extension_options()) :: t()
  def put_extension_options(%MDEx.Document{} = document, options) when is_list(options) do
    NimbleOptions.validate!(options, @extension_options_schema)

    %{
      document
      | options:
          update_in(document.options, [:extension], fn extension ->
            Keyword.merge(extension || [], options)
          end)
    }
  end

  @doc """
  Updates the document's `:render` options.

  ## Examples

      iex> document = MDEx.Document.put_render_options(MDEx.new(), escape: true)
      iex> MDEx.Document.get_option(document, :render)[:escape]
      true

  """
  @spec put_render_options(t(), render_options()) :: t()
  def put_render_options(%MDEx.Document{} = document, options) when is_list(options) do
    {unsafe_, options} = Keyword.pop(options, :unsafe_, false)
    options = Keyword.put_new(options, :unsafe, unsafe_)

    NimbleOptions.validate!(options, @render_options_schema)

    %{
      document
      | options:
          update_in(document.options, [:render], fn render ->
            Keyword.merge(render || [], options)
          end)
    }
  end

  @doc """
  Updates the document's `:parse` options.

  ## Examples

      iex> document = MDEx.Document.put_parse_options(MDEx.new(), smart: true)
      iex> MDEx.Document.get_option(document, :parse)[:smart]
      true

  """
  @spec put_parse_options(t(), parse_options()) :: t()
  def put_parse_options(%MDEx.Document{} = document, options) when is_list(options) do
    NimbleOptions.validate!(options, @parse_options_schema)

    %{
      document
      | options:
          update_in(document.options, [:parse], fn parse ->
            Keyword.merge(parse || [], options)
          end)
    }
  end

  @doc """
  Updates the document's `:syntax_highlight` options.

  ## Examples

      iex> document = MDEx.Document.put_syntax_highlight_options(MDEx.new(), formatter: :html_linked)
      iex> MDEx.Document.get_option(document, :syntax_highlight)[:formatter]
      :html_linked

  """
  @spec put_syntax_highlight_options(t(), syntax_highlight_options()) :: t()
  def put_syntax_highlight_options(%MDEx.Document{} = document, nil = _options) do
    %{
      document
      | options:
          update_in(document.options, [:syntax_highlight], fn _syntax_highlight ->
            nil
          end)
    }
  end

  def put_syntax_highlight_options(%MDEx.Document{} = document, options) when is_list(options) do
    NimbleOptions.validate!(options, @syntax_highlight_options_schema)

    %{
      document
      | options:
          update_in(document.options, [:syntax_highlight], fn syntax_highlight ->
            Keyword.merge(syntax_highlight || [], options)
          end)
    }
  end

  @doc """
  Updates the document's `:sanitize` options.

  ## Examples

      iex> document = MDEx.Document.put_sanitize_options(MDEx.new(), add_tags: ["MyComponent"])
      iex> MDEx.Document.get_option(document, :sanitize)[:add_tags]
      ["MyComponent"]

  """
  @spec put_sanitize_options(t(), sanitize_options()) :: t()
  def put_sanitize_options(%MDEx.Document{} = document, nil = _options) do
    %{
      document
      | options:
          update_in(document.options, [:sanitize], fn _syntax_highlight ->
            nil
          end)
    }
  end

  def put_sanitize_options(%MDEx.Document{} = document, options) when is_list(options) do
    NimbleOptions.validate!(options, @sanitize_options_schema)

    %{
      document
      | options:
          update_in(document.options, [:sanitize], fn sanitize ->
            Keyword.merge(sanitize || [], options)
          end)
    }
  end

  def put_sanitize_options(%MDEx.Document{} = document, true = _options) do
    IO.warn("""
    sanitize: true is deprecated. Pass :sanitize options instead, for example:

      sanitize: MDEx.default_sanitize_options()

    MDEx.default_sanitize_options() is the same behavior as [sanitize: true]

    """)

    put_sanitize_options(document, default_sanitize_options())
  end

  def put_sanitize_options(%MDEx.Document{} = document, false = _options) do
    IO.warn("""
    sanitize: false is deprecated. Pass :sanitize options instead, for example:

      sanitize: nil

    """)

    put_sanitize_options(document, nil)
  end

  @doc """
  Retrieves an option value from the document.

  ## Examples

      iex> document = MDEx.new(render: [escape: true])
      iex> MDEx.Document.get_option(document, :render)[:escape]
      true
  """
  @spec get_option(t(), atom(), term()) :: term()
  def get_option(%MDEx.Document{} = document, key, default \\ nil) when is_atom(key) do
    Keyword.get(document.options, key, default)
  end

  @doc """
  Retrieves one of the `t:sanitize_options/0` options from the document.

  ## Examples

      iex> document =
      ...>   MDEx.new()
      ...>   |> MDEx.Document.put_sanitize_options(add_tags: ["x-component"])
      iex> MDEx.Document.get_sanitize_option(document, :add_tags)
      ["x-component"]
  """
  @spec get_sanitize_option(t(), atom(), term()) :: term()
  def get_sanitize_option(%MDEx.Document{} = document, key, default \\ nil) when is_atom(key) do
    document
    |> get_option(:sanitize, [])
    |> Keyword.get(key, default)
  end

  @doc """
  Returns `true` if the document has the `:sanitize` option set, otherwise `false`.
  """
  @spec is_sanitize_enabled(t()) :: boolean()
  def is_sanitize_enabled(%MDEx.Document{} = document) do
    case get_option(document, :sanitize) do
      nil -> false
      _ -> true
    end
  end

  @doc """
  Retrieves a private value from the document.

  ## Examples

      iex> document = MDEx.new() |> MDEx.Document.put_private(:count, 2)
      iex> MDEx.Document.get_private(document, :count)
      2
  """
  @spec get_private(t(), atom(), default) :: term() | default when default: var
  def get_private(%MDEx.Document{} = document, key, default \\ nil) when is_atom(key) do
    Map.get(document.private, key, default)
  end

  @doc """
  Updates a value in the document's private storage using a function.

  ## Examples

      iex> document = MDEx.new() |> MDEx.Document.put_private(:count, 1)
      iex> document = MDEx.Document.update_private(document, :count, 0, &(&1 + 1))
      iex> MDEx.Document.get_private(document, :count)
      2
  """
  @spec update_private(t(), key :: atom(), default :: term(), (term() -> term())) :: t()
  def update_private(%MDEx.Document{} = document, key, default, fun) when is_atom(key) and is_function(fun, 1) do
    update_in(document.private, &Map.update(&1, key, default, fun))
  end

  @doc """
  Stores a value in the document's private storage.

  ## Examples

      iex> document = MDEx.Document.put_private(MDEx.new(), :mermaid_version, "11")
      iex> MDEx.Document.get_private(document, :mermaid_version)
      "11"
  """
  @spec put_private(t(), atom(), term()) :: t()
  def put_private(%MDEx.Document{} = document, key, value) when is_atom(key) do
    put_in(document.private[key], value)
  end

  @doc """
  Appends steps to the end of the existing document's step list.

  ## Examples

      iex> document = MDEx.new()
      iex> document = MDEx.Document.append_steps(
      ...>   document,
      ...>   enable_tables: fn doc -> MDEx.Document.put_extension_options(doc, table: true) end
      ...> )
      iex> document
      ...> |> MDEx.Document.run()
      ...> |> MDEx.Document.get_option(:extension)
      ...> |> Keyword.get(:table)
      true

  """
  @spec append_steps(t(), keyword(step())) :: t()
  def append_steps(%MDEx.Document{} = document, steps) do
    %{
      document
      | steps: document.steps ++ steps,
        current_steps: document.current_steps ++ Keyword.keys(steps)
    }
  end

  @doc """
  Prepends steps to the beginning of the existing document's step list.
  """
  @spec prepend_steps(t(), keyword(step())) :: t()
  def prepend_steps(%MDEx.Document{} = document, steps) do
    %{
      document
      | steps: steps ++ document.steps,
        current_steps: Keyword.keys(steps) ++ document.current_steps
    }
  end

  @doc """
  Halts the document pipeline execution.

  This function is used to stop the pipeline from processing any further steps. Once a pipeline
  is halted, no more steps will be executed. This is useful for plugins that need to stop
  processing when certain conditions are met or when an error occurs.

  ## Examples

      iex> document = MDEx.Document.halt(MDEx.new())
      iex> document.halted
      true

  """
  @spec halt(t()) :: t()
  def halt(%MDEx.Document{} = document) do
    put_in(document.halted, true)
  end

  @doc """
  Halts the document pipeline execution with an exception.
  """
  @spec halt(t(), Exception.t()) :: {t(), Exception.t()}
  def halt(%MDEx.Document{} = document, %_{__exception__: true} = exception) do
    {put_in(document.halted, true), exception}
  end

  @doc """
  Executes the document pipeline.

  This function performs some main operations:

  1. Processes buffered markdown: If there are any markdown chunks in the buffer (added via `put_markdown/3` for example),
     they are parsed and added to the document. If the document already has nodes, they are combined with the buffer.

  2. Completes any buffered fragments: If streaming is enabled, it completes any buffered fragments to ensure valid Markdown.

  3. Executes pipeline steps: All registered steps (added via `append_steps/2` or `prepend_steps/2`) are
     executed in order. Steps can transform the document or halt the pipeline.

  See `MDEx.new/1` for more info.

  ## Examples

  Processing buffered markdown:

      iex> document =
      ...>   MDEx.new(markdown: "# First\\n")
      ...>   |> MDEx.Document.put_markdown("# Second")
      ...>   |> MDEx.Document.run()
      iex> document.nodes
      [
        %MDEx.Heading{nodes: [%MDEx.Text{literal: "First"}], level: 1, setext: false},
        %MDEx.Heading{nodes: [%MDEx.Text{literal: "Second"}], level: 1, setext: false}
      ]

  Executing pipeline steps:

      iex> document =
      ...>   MDEx.new()
      ...>   |> MDEx.Document.append_steps(add_heading: fn doc ->
      ...>     heading = %MDEx.Heading{nodes: [%MDEx.Text{literal: "Intro"}], level: 1, setext: false}
      ...>     MDEx.Document.put_node_in_document_root(doc, heading, :top)
      ...>   end)
      ...>   |> MDEx.Document.run()
      iex> document.nodes
      [%MDEx.Heading{nodes: [%MDEx.Text{literal: "Intro"}], level: 1, setext: false}]

  Streaming:

      iex> document =
      ...>   MDEx.new(streaming: true, markdown: "```elixir\\n")
      ...>   |> MDEx.Document.put_markdown("IO.inspect(:mdex)")
      ...>   |> MDEx.Document.run()
      iex> document.nodes
      [
        %MDEx.CodeBlock{
          info: "elixir",
          literal: "IO.inspect(:mdex)\\n"
        }
      ]

  """
  @spec run(t()) :: t()
  def run(%MDEx.Document{} = document) do
    document
    |> process_buffer()
    |> do_run()
  end

  defp do_run(%{current_steps: [step | rest]} = document) do
    step = Keyword.fetch!(document.steps, step)

    # TODO: run_error
    case run_step(step, document) |> process_buffer() do
      {%MDEx.Document{} = document, exception} ->
        {document, exception}

      %MDEx.Document{halted: true} = document ->
        document

      %MDEx.Document{} = document ->
        do_run(%{document | current_steps: rest})
    end
  end

  defp do_run({%MDEx.Document{} = document, exception}) do
    {document, exception}
  end

  defp do_run(%{current_steps: []} = document) do
    process_buffer(document)
  end

  defp run_step(step, state) when is_function(step, 1) do
    step.(state)
  end

  defp run_step({mod, fun, args}, state) when is_atom(mod) and is_atom(fun) and is_list(args) do
    apply(mod, fun, [state | args])
  end

  defp process_buffer({%MDEx.Document{}, _} = halted), do: halted

  defp process_buffer(%MDEx.Document{halted: true} = halted), do: halted

  defp process_buffer(%{buffer: []} = document), do: document

  defp process_buffer(%{nodes: []} = document) do
    buffer = buffer_to_binary(document.buffer)
    flush_buffer(document, buffer)
  end

  defp process_buffer(%{nodes: [_ | _]} = document) do
    case render_existing_nodes(document) do
      {:ok, existing_markdown} ->
        buffer = merge_with_existing(document, existing_markdown)
        flush_buffer(document, buffer)

      {:error, halted} ->
        halted
    end
  end

  defp process_buffer(document), do: document

  defp flush_buffer(document, buffer) do
    buffer =
      if Document.get_option(document, :streaming) do
        MDEx.FragmentParser.complete(buffer)
      else
        buffer
      end

    case Native.parse_document(buffer, rust_options!(document.options)) do
      {:ok, %{nodes: nodes}} -> %{document | nodes: nodes, buffer: []}
      {:error, error} -> halt(document, error)
    end
  end

  defp render_existing_nodes(document) do
    document = %{document | buffer: [], current_steps: [], steps: []}

    case Native.document_to_commonmark_with_options(document, rust_options!(document.options)) do
      {:ok, markdown} -> {:ok, markdown}
      {:error, error} -> {:error, halt(document, error)}
    end
  end

  defp buffer_to_binary(buffer) do
    buffer
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end

  defp merge_with_existing(%{nodes: nodes, buffer: buffer}, existing_markdown) do
    last_node = List.last(nodes)
    MDEx.FragmentParser.merge_stream_buffer(existing_markdown, buffer, last_node)
  end

  @deprecated "Use MDEx.parse_document/2 or MDEx.Document.put_markdown/1 instead"
  def parse_markdown(%Document{} = document, markdown) when is_binary(markdown) do
    document
    |> put_markdown(markdown)
    |> run()
  end

  @deprecated "Use MDEx.parse_document/2 or MDEx.Document.put_markdown/1 instead"
  def parse_markdown!(%Document{} = document, markdown) when is_binary(markdown) do
    case parse_markdown(document, markdown) do
      {%Document{}, exception} -> raise exception
      %Document{} = document -> document
    end
  end

  @doc """
  Inserts `node` into the document root at the specified `position`.

    - By default, the node is inserted at the top of the document.
    - Node must be a valid fragment node like a `MDEx.Heading`, `MDEx.HtmlBlock`, etc.

  ## Examples

      iex> document =
      ...>   MDEx.new(markdown: "# Doc")
      ...>   |> MDEx.Document.append_steps(append_node: fn document ->
      ...>     html_block = %MDEx.HtmlBlock{literal: "<p>Hello</p>"}
      ...>     MDEx.Document.put_node_in_document_root(document, html_block, :bottom)
      ...>   end)
      iex> MDEx.to_html(document, render: [unsafe: true])
      {:ok, "<h1>Doc</h1>\\n<p>Hello</p>"}

  """
  @spec put_node_in_document_root(t(), MDEx.Document.md_node(), position :: :top | :bottom) :: t()
  def put_node_in_document_root(document, node, position \\ :top)

  def put_node_in_document_root(%MDEx.Document{} = document, node, :top = _position) do
    case is_fragment(node) do
      true ->
        nodes = [node | document.nodes]
        %{document | nodes: nodes}

      false ->
        document
    end
  end

  def put_node_in_document_root(%MDEx.Document{} = document, node, :bottom = _position) do
    case is_fragment(node) do
      true ->
        nodes = document.nodes ++ [node]
        %{document | nodes: nodes}

      false ->
        raise """
        expected a Document node, for example a %MDEx.Heading{}

        Got:

          #{inspect(node)}

        """
    end
  end

  @doc """
  Adds `markdown` chunks into the `document` buffer.

  ## Examples

      iex> document =
      ...>   MDEx.new(markdown: "# First\\n")
      ...>   |> MDEx.Document.put_markdown("# Second")
      ...>   |> MDEx.Document.run()
      iex> document.nodes
      [
        %MDEx.Heading{nodes: [%MDEx.Text{literal: "First"}], level: 1, setext: false},
        %MDEx.Heading{nodes: [%MDEx.Text{literal: "Second"}], level: 1, setext: false}
      ]

      iex> document =
      ...>   MDEx.new(markdown: "# Last")
      ...>   |> MDEx.Document.put_markdown("# First\\n", :top)
      ...>   |> MDEx.Document.run()
      iex> document.nodes
      [
        %MDEx.Heading{nodes: [%MDEx.Text{literal: "First"}], level: 1, setext: false},
        %MDEx.Heading{nodes: [%MDEx.Text{literal: "Last"}], level: 1, setext: false}
      ]

      iex> document = MDEx.new(streaming: true) |> MDEx.Document.put_markdown("`let x =")
      iex> MDEx.to_html!(document)
      "<p><code>let x =</code></p>"

  """
  @spec put_markdown(t(), String.t() | [String.t()], position :: :top | :bottom) :: t()
  def put_markdown(document, markdown, position \\ :bottom)

  def put_markdown(%MDEx.Document{} = document, markdown, _position) when markdown in [nil, ""] do
    document
  end

  def put_markdown(%MDEx.Document{} = document, markdown, :top = _position) when is_binary(markdown) or is_list(markdown) do
    %{document | buffer: document.buffer ++ List.wrap(markdown)}
  end

  def put_markdown(%MDEx.Document{} = document, markdown, :bottom = _position) when is_binary(markdown) or is_list(markdown) do
    %{document | buffer: [markdown | document.buffer]}
  end

  @doc """
  Updates all nodes in the document that match `selector`.

  ## Example

      iex> markdown = \"""
      ...> # Hello
      ...> ## World
      ...> \"""
      iex> document =
      ...>   MDEx.new(markdown: markdown)
      ...>   |> MDEx.Document.run()
      ...>   |> MDEx.Document.update_nodes(MDEx.Text, fn node -> %{node | literal: String.upcase(node.literal)} end)
      iex> document.nodes
      [
        %MDEx.Heading{nodes: [%MDEx.Text{literal: "HELLO"}], level: 1, setext: false},
        %MDEx.Heading{nodes: [%MDEx.Text{literal: "WORLD"}], level: 2, setext: false}
      ]

  """
  @spec update_nodes(t(), MDEx.Document.selector(), (MDEx.Document.md_node() -> MDEx.Document.md_node())) :: t()
  def update_nodes(%MDEx.Document{} = document, selector, fun) when is_function(fun, 1) do
    # document = maybe_resolve_document(document)

    MDEx.Document.Traversal.traverse_and_update(document, fn node ->
      if match_selector?(node, selector) do
        fun.(node)
      else
        node
      end
    end)
  end

  defp match_selector?(node, selector) when is_struct(selector), do: node == selector
  defp match_selector?(%mod{} = _node, selector) when is_atom(selector), do: mod == MDEx.Document.Access.modulefy!(selector)
  defp match_selector?(node, selector) when is_function(selector, 1), do: selector.(node)

  @typedoc """
  List of [comrak extension options](https://docs.rs/comrak/latest/comrak/options/struct.Extension.html).

  ## Example

      MDEx.to_html!("~~strikethrough~~", extension: [strikethrough: true])
      #=> "<p><del>strikethrough</del></p>"

  """
  @type extension_options() :: [unquote(NimbleOptions.option_typespec(@extension_options_schema))]

  @typedoc """
  List of [comrak parse options](https://docs.rs/comrak/latest/comrak/options/struct.Parse.html).

  ## Example

      MDEx.to_html!("\"Hello\" -- world...", parse: [smart: true])
      #=> "<p>“Hello” – world…</p>"

  """
  @type parse_options() :: [unquote(NimbleOptions.option_typespec(@parse_options_schema))]

  @typedoc """
  List of [comrak render options](https://docs.rs/comrak/latest/comrak/options/struct.Render.html).

  ## Example

      MDEx.to_html!("<script>alert('xss')</script>", render: [unsafe: true])
      #=> "<script>alert('xss')</script>"

  """
  @type render_options() :: [unquote(NimbleOptions.option_typespec(@render_options_schema))]

  @typedoc """
  Syntax Highlight code blocks using [autumn](https://hexdocs.pm/autumn).

  ## Example

      MDEx.to_html!(\"""
      ...> ```elixir
      ...> {:mdex, "~> 0.1"}
      ...> ```
      ...> \""", syntax_highlight: [formatter: {:html_inline, theme: "nord"}])
      #=> <pre class="athl" style="color: #d8dee9; background-color: #2e3440;"><code class="language-elixir" translate="no" tabindex="0"><span class="line" data-line="1"><span style="color: #88c0d0;">&lbrace;</span><span style="color: #ebcb8b;">:mdex</span><span style="color: #88c0d0;">,</span> <span style="color: #a3be8c;">&quot;~&gt; 0.1&quot;</span><span style="color: #88c0d0;">&rbrace;</span>
      #=> </span></code></pre>
  """
  @type syntax_highlight_options() :: [unquote(NimbleOptions.option_typespec(@syntax_highlight_options_schema))]

  @typedoc """
  List of [ammonia options](https://docs.rs/ammonia/latest/ammonia/struct.Builder.html).

  ## Example

      iex> MDEx.to_html!("<h1>Title</h1><p>Content</p>", sanitize: [rm_tags: ["h1"]], render: [unsafe: true])
      "Title<p>Content</p>"

  """
  @type sanitize_options() :: [unquote(NimbleOptions.option_typespec(@sanitize_options_schema))]

  @typedoc """
  Options to customize the parsing and rendering of Markdown documents.

  ## Examples

  - Enable the `table` extension:

      ````elixir
      MDEx.to_html!(\"""
      | lang |
      |------|
      | elixir |
      \""",
      extension: [table: true]
      )
      ````

  - Syntax highlight using inline style and the `github_light` theme:

      ````elixir
      MDEx.to_html!(\"""
      ## Code Example

      ```elixir
      Atom.to_string(:elixir)
      ```
      \""",
      syntax_highlight: [
        formatter: {:html_inline, theme: "github_light"}
      ])
      ````

  - Sanitize HTML output, in this example disallow `<a>` tags:

      ````elixir
      MDEx.to_html!(\"""
      ## Links won't be displayed

      <a href="https://example.com">Example</a>
      ```
      \""",
      sanitize: [
        rm_tags: ["a"],
      ])
      ````

  ## Options

  #{NimbleOptions.docs(@options_schema)}
  """
  @type options() :: [unquote(NimbleOptions.option_typespec(@options_schema))]

  @doc false
  def options_schema, do: @options_schema

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

  @doc """
  Wraps nodes in a `MDEx.Document`.

  * Passing an existing document returns it unchanged.
  * Passing a node or list of nodes builds a new document with default options.

  ## Examples

      iex> document = MDEx.Document.wrap(MDEx.new(markdown: "# Title") |> MDEx.Document.run())
      iex> document.nodes
      [%MDEx.Heading{nodes: [%MDEx.Text{literal: "Title"}], level: 1, setext: false}]

      iex> document = MDEx.Document.wrap(%MDEx.Text{literal: "Hello"})
      iex> document.nodes
      [%MDEx.Text{literal: "Hello"}]
  """
  @spec wrap(t() | md_node() | [md_node()]) :: t()
  def wrap(%MDEx.Document{} = document), do: document

  def wrap(nodes) do
    %{MDEx.new() | nodes: List.wrap(nodes)}
  end

  @doc false
  @spec rust_options!(Keyword.t()) :: map()
  def rust_options!([] = _options) do
    rust_options!(default_options())
  end

  def rust_options!(options) do
    {unsafe, render} = Keyword.pop(options[:render] || [], :unsafe, false)
    render = Keyword.put_new(render, :unsafe, unsafe)

    syntax_highlight =
      case options[:syntax_highlight] do
        nil ->
          nil

        options ->
          options
          |> Autumn.validate_options!()
          |> Autumn.rust_options!()
      end

    sanitize =
      case options[:sanitize] do
        nil -> nil
        opts -> adapt_sanitize_options(opts)
      end

    %{
      extension: Map.new(options[:extension]),
      parse: Map.new(options[:parse]),
      render: Map.new(render),
      syntax_highlight: syntax_highlight,
      sanitize: sanitize
    }
  end

  @doc false
  def adapt_sanitize_options(nil = _options), do: nil

  def adapt_sanitize_options(options) do
    {:custom,
     %{
       link_rel: options[:link_rel],
       tags: %{
         set: options[:tags],
         add: options[:add_tags],
         rm: options[:rm_tags]
       },
       clean_content_tags: %{
         set: options[:clean_content_tags],
         add: options[:add_clean_content_tags],
         rm: options[:rm_clean_content_tags]
       },
       tag_attributes: %{
         set: options[:tag_attributes],
         add: options[:add_tag_attributes],
         rm: options[:rm_tag_attributes]
       },
       tag_attribute_values: %{
         set: options[:tag_attribute_values],
         add: options[:add_tag_attribute_values],
         rm: options[:rm_tag_attribute_values]
       },
       set_tag_attribute_values: %{
         set: options[:set_tag_attribute_values],
         add: options[:set_tag_attribute_value],
         rm: options[:rm_set_tag_attribute_value]
       },
       generic_attribute_prefixes: %{
         set: options[:generic_attribute_prefixes],
         add: options[:add_generic_attribute_prefixes],
         rm: options[:rm_generic_attribute_prefixes]
       },
       generic_attributes: %{
         set: options[:generic_attributes],
         add: options[:add_generic_attributes],
         rm: options[:rm_generic_attributes]
       },
       url_schemes: %{
         set: options[:url_schemes],
         add: options[:add_url_schemes],
         rm: options[:rm_url_schemes]
       },
       url_relative: options[:url_relative],
       allowed_classes: %{
         set: options[:allowed_classes],
         add: options[:add_allowed_classes],
         rm: options[:rm_allowed_classes]
       },
       strip_comments: options[:strip_comments],
       id_prefix: options[:id_prefix]
     }}
  end

  @doc """
  Callback implementation for `Access.fetch/2`.

  See the [Access](#module-access) section for more info.
  """
  @spec fetch(t(), selector()) :: {:ok, [md_node()]} | :error
  def fetch(document, selector), do: MDEx.Document.Access.fetch(document, selector)

  @doc """
  Callback implementation for `Access.get_and_update/3`.

  See the [Access](#module-access) section for more info.
  """
  def get_and_update(%MDEx.Document{} = document, selector, fun), do: MDEx.Document.Access.get_and_update(document, selector, fun)

  @doc """
  Callback implementation for `Access.fetch/2`.

  See the [Access](#module-access) section for more info.
  """
  def pop(%MDEx.Document{} = document, key, default \\ nil), do: MDEx.Document.Access.pop(document, key, default)

  defimpl Collectable do
    def into(%MDEx.Document{} = document) do
      append_block = fn doc, chunk ->
        markdown =
          chunk
          |> MDEx.Document.wrap()
          |> MDEx.to_markdown!()

        payload = if MDEx.Tree.is_block_node?(chunk), do: ["\n", markdown], else: markdown
        MDEx.Document.put_markdown(doc, payload)
      end

      collector = fn
        {doc, mode}, {:cont, %MDEx.Document{}} ->
          {doc, mode}

        {doc, _mode}, {:cont, chunk} when is_binary(chunk) or is_list(chunk) ->
          {MDEx.Document.put_markdown(doc, chunk), :default}

        {doc, :skip_inline}, {:cont, chunk} ->
          cond do
            MDEx.Tree.is_block_node?(chunk) ->
              {append_block.(doc, chunk), :skip_inline}

            true ->
              {doc, :skip_inline}
          end

        {doc, _mode}, {:cont, chunk} when is_struct(chunk, MDEx.Text) ->
          {MDEx.Document.put_markdown(doc, chunk.literal), :default}

        {doc, _mode}, {:cont, chunk} when is_struct(chunk) ->
          mode = if MDEx.Tree.is_block_node?(chunk), do: :skip_inline, else: :default
          {append_block.(doc, chunk), mode}

        {doc, _mode}, :done ->
          doc

        _acc, :halt ->
          :ok
      end

      {{document, :default},
       fn
         {doc, mode}, {:cont, chunk} -> collector.({doc, mode}, {:cont, chunk})
         {doc, mode}, other -> collector.({doc, mode}, other)
       end}
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
          literal: String.t(),
          closed: boolean()
        }
  defstruct nodes: [], fenced: true, fence_char: "`", fence_length: 3, fence_offset: 0, info: "", literal: "", closed: true
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

  @type t :: %__MODULE__{nodes: [MDEx.Document.md_node()], level: pos_integer(), setext: boolean(), closed: boolean()}
  defstruct nodes: [], level: 1, setext: false, closed: false
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

  @type t :: %__MODULE__{name: String.t(), ref_num: non_neg_integer(), ix: non_neg_integer(), texts: [{String.t(), non_neg_integer()}]}
  defstruct name: "", ref_num: nil, ix: nil, texts: []
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

defmodule MDEx.Highlight do
  @moduledoc """
  Highlight (mark) text.

  Uses double equals syntax: `==highlighted text==`
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
    MDEx.to_markdown!(%MDEx.Document{nodes: [node]})
  end
end

defimpl Jason.Encoder, for: MDEx.Document do
  def encode(%MDEx.Document{} = document, opts) do
    map = %{"nodes" => document.nodes, "node_type" => inspect(MDEx.Document)}
    Jason.Encode.map(map, opts)
  end
end

defimpl Jason.Encoder,
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
  def encode(%type{} = node, opts) do
    map =
      node
      |> Map.from_struct()
      |> Map.put("node_type", inspect(type))

    Jason.Encode.map(map, opts)
  end
end

defimpl Inspect, for: MDEx.Document do
  import Inspect.Algebra

  def inspect(%MDEx.Document{} = document, opts) do
    case Application.get_env(:mdex, :inspect_format, :tree) do
      :struct ->
        infos =
          for %{field: field} = map <- MDEx.Document.__info__(:struct),
              field != :__exception__,
              do: map

        if function_exported?(Inspect.Map, :inspect, 4) do
          apply(Inspect.Map, :inspect, [document, inspect(document.__struct__), infos, opts])
        else
          apply(Inspect.Map, :inspect_as_struct, [
            document,
            inspect(document.__struct__),
            infos,
            opts
          ])
        end

      _ ->
        inspect_tree(document, opts)
    end
  end

  defp inspect_tree(%MDEx.Document{nodes: nodes}, _opts) do
    node_count = Enum.count(%MDEx.Document{nodes: nodes}) - 1
    header = concat(["#MDEx.Document(", to_string(node_count), " nodes)<"])

    if Enum.empty?(nodes) do
      concat([header, ">"])
    else
      {tree_lines, _} = build_tree_lines(nodes, [], 1)

      tree_content =
        tree_lines
        |> Enum.map(&string/1)
        |> Enum.intersperse(line())
        |> concat()

      force_unfit(
        concat([
          header,
          line(),
          tree_content,
          line(),
          ">"
        ])
      )
    end
  end

  defp build_tree_lines([], _prefixes, start_index), do: {[], start_index}

  defp build_tree_lines([node | rest], prefixes, start_index) do
    is_last = Enum.empty?(rest)
    {current_lines, next_index} = format_node(node, prefixes, is_last, start_index)
    {remaining_lines, final_index} = build_tree_lines(rest, prefixes, next_index)
    {current_lines ++ remaining_lines, final_index}
  end

  defp format_node(node, prefixes, is_last, index) do
    connector = if is_last, do: "└── ", else: "├── "
    prefix = Enum.join(prefixes, "")
    node_info = get_node_info(node)
    line_content = "#{prefix}#{connector}#{index} #{node_info}"
    child_prefix = if is_last, do: "    ", else: "│   "
    new_prefixes = prefixes ++ [child_prefix]

    case Map.get(node, :nodes, []) do
      [] ->
        {[line_content], index + 1}

      children ->
        {child_lines, final_index} = build_tree_lines(children, new_prefixes, index + 1)
        {[line_content | child_lines], final_index}
    end
  end

  defp get_node_info(node) do
    module_name = node.__struct__ |> Module.split() |> List.last() |> Macro.underscore()

    attrs =
      node
      |> Map.from_struct()
      |> Map.delete(:nodes)
      |> Enum.map(fn {k, v} -> "#{k}: #{inspect(v)}" end)

    case attrs do
      [] -> "[#{module_name}]"
      attrs -> "[#{module_name}] #{Enum.join(attrs, ", ")}"
    end
  end
end
