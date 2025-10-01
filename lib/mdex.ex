defmodule MDEx do
  @external_resource "README.md"

  @inner_moduledoc """
  ## Parsing

  Converts Markdown to an AST data structure that can be inspected and manipulated to change the content of the document programmatically.

  The data structure format is inspired on [Floki](https://github.com/philss/floki) (with `:attributes_as_maps = true`) so we can keep similar APIs and keep the same mental model when
  working with these documents, either Markdown or HTML, where each node is represented as a struct holding the node name as the struct name and its attributes and children, for eg:

      %MDEx.Heading{
        level: 1
        nodes: [...],
      }

  The parent node that represents the root of the document is the `MDEx.Document` struct,
  where you can find more more information about the AST and what operations are available.

  The complete list of nodes is listed in the the section `Document Nodes`.

  ## Formatting

  Formatting is the process of converting from one format to another, for example from AST or Markdown to HTML.
  Formatting to XML and to Markdown is also supported.

  You can use `MDEx.parse_document/2` to generate an AST or any of the `to_*` functions to convert to Markdown (CommonMark), HTML, JSON, or XML.
  """

  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC -->")
             |> Enum.fetch!(1)
             |> Kernel.<>(@inner_moduledoc)

  alias MDEx.Native
  alias MDEx.Document
  alias MDEx.DecodeError
  alias MDEx.InvalidInputError

  import MDEx.Document, only: [is_fragment: 1]

  require Logger

  @typedoc """
  Input source document.

  ## Examples

  * From Markdown to HTML

        iex> MDEx.to_html!("# Hello")
        "<h1>Hello</h1>"

  * From Markdown to `MDEx.Document`

        iex> MDEx.parse_document!("Hello")
        %MDEx.Document{
          nodes: [
            %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Hello"}]}
          ]
        }

  * From `MDEx.Document` to HTML

        iex> MDEx.to_html!(%MDEx.Document{
        ...>   nodes: [
        ...>     %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Hello"}]}
        ...>   ]
        ...> })
        "<p>Hello</p>"

  You can also leverage `MDEx.Document` as an intermediate data type to convert between formats:

  * From JSON to HTML:

        iex> json = ~s|{"nodes":[{"nodes":[{"literal":"Hello","node_type":"MDEx.Text"}],"level":1,"setext":false,"node_type":"MDEx.Heading"}],"node_type":"MDEx.Document"}|
        iex> {:json, json} |> MDEx.parse_document!() |> MDEx.to_html!()
        "<h1>Hello</h1>"

  """
  @type source :: markdown :: String.t() | Document.t()

  @deprecated "Use `MDEx.Document.default_extension_options/0` instead"
  def default_extension_options, do: Document.default_extension_options()

  @deprecated "Use `MDEx.Document.default_parse_options/0` instead"
  def default_parse_options, do: Document.default_parse_options()

  @deprecated "Use `MDEx.Document.default_render_options/0` instead"
  def default_render_options, do: Document.default_render_options()

  @deprecated "Use `MDEx.Document.default_syntax_highlight_options/0` instead"
  def default_syntax_highlight_options, do: Document.default_syntax_highlight_options()

  @deprecated "Use `MDEx.Document.default_sanitize_options/0` instead"
  def default_sanitize_options, do: Document.default_sanitize_options()

  @doc """
  Parse `source` and returns `MDEx.Document`.

  Source can be either a Markdown string or a tagged JSON string.

  ## Examples

  * Parse Markdown with default options:

        iex> MDEx.parse_document!(\"""
        ...> # Languages
        ...>
        ...> - Elixir
        ...> - Rust
        ...> \""")
        %MDEx.Document{
          nodes: [
            %MDEx.Heading{nodes: [%MDEx.Text{literal: "Languages"}], level: 1, setext: false},
            %MDEx.List{
              nodes: [
                %MDEx.ListItem{
                  nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Elixir"}]}],
                  list_type: :bullet,
                  marker_offset: 0,
                  padding: 2,
                  start: 1,
                  delimiter: :period,
                  bullet_char: "-",
                  tight: false
                },
                %MDEx.ListItem{
                  nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Rust"}]}],
                  list_type: :bullet,
                  marker_offset: 0,
                  padding: 2,
                  start: 1,
                  delimiter: :period,
                  bullet_char: "-",
                  tight: false
                }
              ],
              list_type: :bullet,
              marker_offset: 0,
              padding: 2,
              start: 1,
              delimiter: :period,
              bullet_char: "-",
              tight: true
            }
          ]
        }

  * Parse Markdown with custom options:

        iex> MDEx.parse_document!("Darth Vader is ||Luke's father||", extension: [spoiler: true])
        %MDEx.Document{
          nodes: [
            %MDEx.Paragraph{
              nodes: [
                %MDEx.Text{literal: "Darth Vader is "},
                %MDEx.SpoileredText{nodes: [%MDEx.Text{literal: "Luke's father"}]}
              ]
            }
          ]
        }

  * Parse JSON:

        iex> json = ~s|{"nodes":[{"nodes":[{"literal":"Title","node_type":"MDEx.Text"}],"level":1,"setext":false,"node_type":"MDEx.Heading"}],"node_type":"MDEx.Document"}|
        iex> MDEx.parse_document!({:json, json})
        %MDEx.Document{
          nodes: [
            %MDEx.Heading{
              nodes: [%MDEx.Text{literal: "Title"} ],
              level: 1,
              setext: false
            }
          ]
        }

  """
  @spec parse_document(markdown :: String.t() | {:json, String.t()}, MDEx.Document.options()) :: {:ok, Document.t()} | {:error, any()}
  # TODO: support :xml
  def parse_document(source, options \\ [])

  def parse_document(markdown, options) when is_binary(markdown) do
    options
    |> MDEx.new()
    |> MDEx.Document.parse_markdown(markdown)
  end

  def parse_document({:json, json}, options) when is_binary(json) do
    case Jason.decode(json, keys: :atoms!) do
      {:ok, decoded} ->
        document = %{MDEx.new(options) | nodes: json_to_node(decoded).nodes}
        {:ok, document}

      {:error, error} ->
        {:error, %DecodeError{error: error}}
    end
  end

  defp json_to_node(json) do
    {node_type, node} = Map.pop!(json, :node_type)
    node_type = Module.concat([node_type])
    node = map_nodes(node)
    struct(node_type, node)
  end

  defp map_nodes(%{nodes: nodes} = node) do
    %{node | nodes: Enum.map(nodes, &json_to_node/1)}
  end

  defp map_nodes(node), do: node

  @doc """
  Same as `parse_document/2` but raises if the parsing fails.
  """
  @spec parse_document!(markdown :: String.t() | {:json, String.t()}, MDEx.Document.options()) :: Document.t()
  def parse_document!(source, options \\ []) do
    case parse_document(source, options) do
      {:ok, document} -> document
      {:error, error} -> raise error
    end
  end

  @doc """
  Parse a `markdown` string and returns only the node that represents the fragment.

  Usually that means filtering out the parent document and paragraphs.

  That's useful to generate fragment nodes and inject them into the document
  when you're manipulating it.

  Use `parse_document/2` to generate a complete document.

  > #### Experimental {: .warning}
  >
  > Consider this function experimental and subject to change.

  ## Examples

      iex> MDEx.parse_fragment("# Elixir")
      {:ok, %MDEx.Heading{nodes: [%MDEx.Text{literal: "Elixir"}], level: 1, setext: false}}

      iex> MDEx.parse_fragment("<h1>Elixir</h1>")
      {:ok, %MDEx.HtmlBlock{nodes: [], block_type: 6, literal: "<h1>Elixir</h1>\\n"}}

  """
  @spec parse_fragment(String.t(), MDEx.Document.options()) :: {:ok, Document.md_node()} | nil
  def parse_fragment(markdown, options \\ []) when is_binary(markdown) do
    case parse_document(markdown, options) do
      {:ok, %Document{nodes: [%MDEx.Paragraph{nodes: [node]}]}} -> {:ok, node}
      {:ok, %Document{nodes: [node]}} -> {:ok, node}
      _ -> nil
    end
  end

  @doc """
  Same as `parse_fragment/2` but raises if the parsing fails or returns `nil`.

  > #### Experimental {: .warning}
  >
  > Consider this function experimental and subject to change.

  """
  @spec parse_fragment!(String.t(), MDEx.Document.options()) :: Document.md_node()
  def parse_fragment!(markdown, options \\ []) when is_binary(markdown) do
    case parse_fragment(markdown, options) do
      {:ok, fragment} -> fragment
      _ -> raise %InvalidInputError{found: markdown}
    end
  end

  @doc """
  Convert Markdown or `MDEx.Document` to HTML.

  ## Examples

      iex> MDEx.to_html("# MDEx")
      {:ok, "<h1>MDEx</h1>"}

      iex> MDEx.to_html("Implemented with:\\n1. Elixir\\n2. Rust")
      {:ok, "<p>Implemented with:</p>\\n<ol>\\n<li>Elixir</li>\\n<li>Rust</li>\\n</ol>"}

      iex> MDEx.to_html(%MDEx.Document{nodes: [%MDEx.Heading{nodes: [%MDEx.Text{literal: "MDEx"}], level: 3, setext: false}]})
      {:ok, "<h3>MDEx</h3>"}

      iex> MDEx.to_html("Hello ~world~ there", extension: [strikethrough: true])
      {:ok, "<p>Hello <del>world</del> there</p>"}

      iex> MDEx.to_html("<marquee>visit https://beaconcms.org</marquee>", extension: [autolink: true], render: [unsafe: true])
      {:ok, "<p><marquee>visit <a href=\\"https://beaconcms.org\\">https://beaconcms.org</a></marquee></p>"}

   Fragments of a document are also supported:

      iex> MDEx.to_html(%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "MDEx"}]})
      {:ok, "<p>MDEx</p>"}

  """
  @spec to_html(source(), Document.options()) ::
          {:ok, String.t()}
          | {:error, MDEx.DecodeError.t()}
          | {:error, MDEx.InvalidInputError.t()}
  def to_html(source, options \\ [])

  def to_html(markdown, options) when is_binary(markdown) and is_list(options) do
    {document, options} = Keyword.pop(options, :document, nil)
    markdown = document || markdown || ""
    options = Document.put_options(MDEx.new(), options).options

    markdown
    |> Native.markdown_to_html_with_options(Document.rust_options!(options))
    |> maybe_trim()
  end

  def to_html(%Document{} = document, options) when is_list(options) do
    run_pipeline(document, options, &Native.document_to_html_with_options/2)
  rescue
    ErlangError ->
      {:error, %DecodeError{document: document}}
  end

  def to_html(source, options) do
    if is_fragment(source) do
      source
      |> Document.wrap()
      |> to_html(options)
    else
      {:error, %InvalidInputError{found: source}}
    end
  end

  @doc """
  Same as `to_html/2` but raises error if the conversion fails.
  """
  @spec to_html!(source(), MDEx.Document.options()) :: String.t()
  def to_html!(source, options \\ []) do
    case to_html(source, options) do
      {:ok, html} -> html
      {:error, error} -> raise error
    end
  end

  @doc """
  Convert Markdown or `MDEx.Document` to XML.

  ## Examples

      iex> {:ok, xml} = MDEx.to_xml("Hello ~world~ there", extension: [strikethrough: true])
      iex> xml
      ~s|<?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE document SYSTEM "CommonMark.dtd">
      <document xmlns="http://commonmark.org/xml/1.0">
        <paragraph>
          <text xml:space="preserve">Hello </text>
          <strikethrough>
            <text xml:space="preserve">world</text>
          </strikethrough>
          <text xml:space="preserve"> there</text>
        </paragraph>
      </document>|

      iex> {:ok, xml} = MDEx.to_xml("<marquee>visit https://beaconcms.org</marquee>", extension: [autolink: true], render: [unsafe: true])
      iex> xml
      ~s|<?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE document SYSTEM "CommonMark.dtd">
      <document xmlns="http://commonmark.org/xml/1.0">
        <paragraph>
          <html_inline xml:space="preserve">&lt;marquee&gt;</html_inline>
          <text xml:space="preserve">visit </text>
          <link destination="https://beaconcms.org" title="">
            <text xml:space="preserve">https://beaconcms.org</text>
          </link>
          <html_inline xml:space="preserve">&lt;/marquee&gt;</html_inline>
        </paragraph>
      </document>|

  Fragments of a document are also supported:

      iex> {:ok, xml} = MDEx.to_xml(%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "MDEx"}]})
      iex> xml
      ~s|<?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE document SYSTEM "CommonMark.dtd">
      <document xmlns="http://commonmark.org/xml/1.0">
        <paragraph>
          <text xml:space="preserve">MDEx</text>
        </paragraph>
      </document>|

  """
  @spec to_xml(source(), MDEx.Document.options()) ::
          {:ok, String.t()}
          | {:error, MDEx.DecodeError.t()}
          | {:error, MDEx.InvalidInputError.t()}
  def to_xml(source, options \\ [])

  def to_xml(markdown, options) when is_binary(markdown) and is_list(options) do
    {document, options} = Keyword.pop(options, :document, nil)
    markdown = document || markdown || ""
    options = Document.put_options(MDEx.new(), options).options

    markdown
    |> Native.markdown_to_xml_with_options(Document.rust_options!(options))
    |> maybe_trim()
  end

  def to_xml(%Document{} = document, options) when is_list(options) do
    run_pipeline(document, options, &Native.document_to_xml_with_options/2)
  rescue
    ErlangError ->
      {:error, %DecodeError{document: document}}
  end

  def to_xml(source, options) do
    if is_fragment(source) do
      to_xml(%Document{nodes: List.wrap(source)}, options)
    else
      {:error, %InvalidInputError{found: source}}
    end
  end

  @doc """
  Same as `to_xml/2` but raises error if the conversion fails.
  """
  @spec to_xml!(source(), MDEx.Document.options()) :: String.t()
  def to_xml!(source, options \\ []) do
    case to_xml(source, options) do
      {:ok, xml} -> xml
      {:error, error} -> raise error
    end
  end

  @doc """
  Convert Markdown or `MDEx.Document` to JSON.

  ## Examples

      iex> MDEx.to_json("# Hello")
      {:ok, ~s|{"nodes":[{"nodes":[{"literal":"Hello","node_type":"MDEx.Text"}],"level":1,"setext":false,"node_type":"MDEx.Heading"}],"node_type":"MDEx.Document"}|}

      iex> MDEx.to_json("1. First\\n2. Second")
      {:ok, ~s|{"nodes":[{"start":1,"nodes":[{"start":1,"nodes":[{"nodes":[{"literal":"First","node_type":"MDEx.Text"}],"node_type":"MDEx.Paragraph"}],"delimiter":"period","padding":3,"list_type":"ordered","marker_offset":0,"bullet_char":"","tight":false,"is_task_list":false,"node_type":"MDEx.ListItem"},{"start":2,"nodes":[{"nodes":[{"literal":"Second","node_type":"MDEx.Text"}],"node_type":"MDEx.Paragraph"}],"delimiter":"period","padding":3,"list_type":"ordered","marker_offset":0,"bullet_char":"","tight":false,"is_task_list":false,"node_type":"MDEx.ListItem"}],"delimiter":"period","padding":3,"list_type":"ordered","marker_offset":0,"bullet_char":"","tight":true,"is_task_list":false,"node_type":"MDEx.List"}],"node_type":"MDEx.Document"}|}

      iex> MDEx.to_json(%MDEx.Document{nodes: [%MDEx.Heading{nodes: [%MDEx.Text{literal: "Hello"}], level: 3, setext: false}]})
      {:ok, ~s|{"nodes":[{"nodes":[{"literal":"Hello","node_type":"MDEx.Text"}],"level":3,"setext":false,"node_type":"MDEx.Heading"}],"node_type":"MDEx.Document"}|}

      iex> MDEx.to_json("Hello ~world~", extension: [strikethrough: true])
      {:ok, ~s|{"nodes":[{"nodes":[{"literal":"Hello ","node_type":"MDEx.Text"},{"nodes":[{"literal":"world","node_type":"MDEx.Text"}],"node_type":"MDEx.Strikethrough"}],"node_type":"MDEx.Paragraph"}],"node_type":"MDEx.Document"}|}

  Fragments of a document are also supported:

      iex> MDEx.to_json(%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Hello"}]})
      {:ok, ~s|{"nodes":[{"nodes":[{"literal":"Hello","node_type":"MDEx.Text"}],"node_type":"MDEx.Paragraph"}],"node_type":"MDEx.Document"}|}

  """
  @spec to_json(source(), MDEx.Document.options()) ::
          {:ok, String.t()}
          | {:error, MDEx.DecodeError.t()}
          | {:error, MDEx.InvalidInputError.t()}
          | {:error, Jason.EncodeError.t()}
          | {:error, Exception.t()}
  def to_json(source, options \\ [])

  def to_json(source, options) when is_binary(source) do
    {_document_opt, options} = pop_deprecated_document_option(options)

    with {:ok, document} <- parse_document(source, options),
         {:ok, json} <- Jason.encode(document) do
      {:ok, json}
    end
  end

  def to_json(%Document{} = document, options) do
    {document_opt, options} = pop_deprecated_document_option(options)

    document
    |> Document.put_options(options)
    |> maybe_apply_document_option(document_opt)
    |> Document.run()
    |> then(fn document ->
      document
      |> Jason.encode()
      |> case do
        {:ok, json} -> {:ok, json}
        {:error, error} -> {:error, %DecodeError{document: document, error: error}}
      end
    end)
  end

  def to_json(source, options) do
    if is_fragment(source) do
      source
      |> Document.wrap()
      |> to_json(options)
    else
      {:error, %InvalidInputError{found: source}}
    end
  end

  @doc """
  Same as `to_json/2` but raises an error if the conversion fails.
  """
  @spec to_json!(source(), MDEx.Document.options()) :: String.t()
  def to_json!(source, options \\ []) do
    case to_json(source, options) do
      {:ok, json} -> json
      {:error, error} -> raise error
    end
  end

  @doc """
  Convert Markdown or `MDEx.Document` to Quill Delta format.

  Quill Delta is a JSON-based format that represents documents as a sequence
  of insert, retain, and delete operations. This format is commonly used by
  the Quill rich text editor.

  ## Examples

      iex> MDEx.to_delta("# Hello\\n**World**")
      {:ok, [
        %{"insert" => "Hello"},
        %{"insert" => "\\n", "attributes" => %{"header" => 1}},
        %{"insert" => "World", "attributes" => %{"bold" => true}},
        %{"insert" => "\\n"}
      ]}

      iex> doc = MDEx.parse_document!("*italic* text")
      iex> MDEx.to_delta(doc)
      {:ok, [
        %{"insert" => "italic", "attributes" => %{"italic" => true}},
        %{"insert" => " text"},
        %{"insert" => "\\n"}
      ]}

  ## Node Type Mappings

  The following table shows how MDEx node types are converted to Delta attributes:

  | MDEx Node Type | Delta Attribute | Example |
  |---|---|---|
  | `MDEx.Strong` | `{"bold": true}` | `**text**` → `{"insert": "text", "attributes": {"bold": true}}` |
  | `MDEx.Emph` | `{"italic": true}` | `*text*` → `{"insert": "text", "attributes": {"italic": true}}` |
  | `MDEx.Code` | `{"code": true}` | `` `code` `` → `{"insert": "code", "attributes": {"code": true}}` |
  | `MDEx.Strikethrough` | `{"strike": true}` | `~~text~~` → `{"insert": "text", "attributes": {"strike": true}}` |
  | `MDEx.Underline` | `{"underline": true}` | `__text__` → `{"insert": "text", "attributes": {"underline": true}}` |
  | `MDEx.Subscript` | `{"subscript": true}` | `H~2~O` → `{"insert": "2", "attributes": {"subscript": true}}` |
  | `MDEx.Superscript` | `{"superscript": true}` | `E=mc^2^` → `{"insert": "2", "attributes": {"superscript": true}}` |
  | `MDEx.SpoileredText` | `{"spoiler": true}` | `\\|\\|spoiler\\|\\|` → `{"insert": "spoiler", "attributes": {"spoiler": true}}` |
  | `MDEx.Link` | `{"link": "url"}` | `[text](url)` → `{"insert": "text", "attributes": {"link": "url"}}` |
  | `MDEx.WikiLink` | `{"link": "url", "wikilink": true}` | `[[WikiPage]]` → `{"insert": "WikiPage", "attributes": {"link": "WikiPage", "wikilink": true}}` |
  | `MDEx.Math` | `{"math": "inline"\\|"display"}` | `$x^2$` → `{"insert": "x^2", "attributes": {"math": "inline"}}` |
  | `MDEx.FootnoteReference` | `{"footnote_ref": "id"}` | `[^1]` → `{"insert": "[^1]", "attributes": {"footnote_ref": "1"}}` |
  | `MDEx.HtmlInline` | `{"html": "inline"}` | `<span>text</span>` → `{"insert": "<span>text</span>", "attributes": {"html": "inline"}}` |
  | `MDEx.Heading` | `{"header": level}` | `# Title` → `{"insert": "Title"}`, `{"insert": "\\n", "attributes": {"header": 1}}` |
  | `MDEx.BlockQuote` | `{"blockquote": true}` | `> quote` → `{"insert": "\\n", "attributes": {"blockquote": true}}` |
  | `MDEx.CodeBlock` | `{"code-block": true, "code-block-lang": "lang"}` | ` ```js\\ncode``` ` → `{"insert": "\\n", "attributes": {"code-block": true, "code-block-lang": "js"}}` |
  | `MDEx.ThematicBreak` | Text insertion | `---` → `{"insert": "***\\n"}` |
  | `MDEx.List` (bullet) | `{"list": "bullet"}` | `- item` → `{"insert": "\\n", "attributes": {"list": "bullet"}}` |
  | `MDEx.List` (ordered) | `{"list": "ordered"}` | `1. item` → `{"insert": "\\n", "attributes": {"list": "ordered"}}` |
  | `MDEx.TaskItem` | `{"list": "bullet", "task": true/false}` | `- [x] done` → `{"insert": "\\n", "attributes": {"list": "bullet", "task": true}}` |
  | `MDEx.Table` | `{"table": "header/row"}` | Table rows → `{"insert": "\\n", "attributes": {"table": "header"}}` |
  | `MDEx.Alert` | `{"alert": "type", "alert_title": "title"}` | `> [!NOTE]\\n> text` → `{"insert": "\\n", "attributes": {"alert": "note"}}` |
  | `MDEx.FootnoteDefinition` | `{"footnote_definition": "id"}` | `[^1]: def` → `{"insert": "\\n", "attributes": {"footnote_definition": "1"}}` |
  | `MDEx.HtmlBlock` | `{"html": "block"}` | `<div>block</div>` → `{"insert": "\\n", "attributes": {"html": "block"}}` |
  | `MDEx.FrontMatter` | `{"front_matter": true}` | `---\\ntitle: x\\n---` → `{"insert": "\\n", "attributes": {"front_matter": true}}` |

  **Note**: Block-level attributes are applied to newline characters (`\\n`) following Quill Delta conventions.
  Inline attributes are applied directly to text content. Multiple attributes can be combined (e.g., bold + italic).

  ## Options

    * `t:MDEx.Document.options/0` - options passed to the parser and document processing
    * `:custom_converters` - map of node types to converter functions for custom behavior

  ## Custom Converters

  Custom converters allow you to override the default behavior for any node type:

      # Example: Custom table converter that creates structured Delta objects
      table_converter = fn %MDEx.Table{nodes: rows}, _options ->
        [%{
          "insert" => %{
            "table" => %{
              "rows" => length(rows),
              "data" => "custom_table_data"
            }
          }
        }]
      end

      # Example: Skip math nodes entirely
      math_skipper = fn %MDEx.Math{}, _options -> :skip end

      # Example: Convert images to custom format
      image_converter = fn %MDEx.Image{url: url, title: title}, _options ->
        [%{
          "insert" => %{"custom_image" => %{"src" => url, "alt" => title || ""}},
          "attributes" => %{"display" => "block"}
        }]
      end

      # Usage
      MDEx.to_delta(document, [
        custom_converters: %{
          MDEx.Table => table_converter,
          MDEx.Math => math_skipper,
          MDEx.Image => image_converter
        }
      ])

  ### Custom Converter Contract

  Input: `(node :: MDEx.Document.md_node(), options :: keyword())`

  Output:
    - `[delta_op()]` - List of Delta operations to insert
    - `:skip` - Skip this node entirely
    - `{:error, reason}` - Return an error

  **Note**: If you need default conversion behavior for child nodes, call `MDEx.to_delta/2` on them.

  """
  @spec to_delta(source(), keyword()) ::
          {:ok, [map()]} | {:error, MDEx.DecodeError.t()} | {:error, MDEx.InvalidInputError.t()}
  def to_delta(source, options \\ [])

  def to_delta(source, options) when is_binary(source) and is_list(options) do
    {_deprecated_document, options} = pop_deprecated_document_option(options)

    parse_options = Keyword.drop(options, [:custom_converters])

    with {:ok, document} <- parse_document(source, parse_options) do
      to_delta(document, options)
    end
  end

  def to_delta(%Document{} = document, options) when is_list(options) do
    {document_opt, options} = pop_deprecated_document_option(options)

    validated_options =
      options
      |> Keyword.take([:custom_converters])
      |> NimbleOptions.validate!(custom_converters: [type: :map, default: %{}])

    document_options = Keyword.drop(options, [:custom_converters])

    document
    |> Document.put_options(document_options)
    |> maybe_apply_document_option(document_opt)
    |> Document.run()
    |> then(fn document ->
      document
      |> MDEx.DeltaConverter.convert(validated_options)
      |> case do
        {:ok, ops} ->
          {:ok, ops}

        {:error, reason} ->
          {:error, %DecodeError{document: document, error: reason}}
      end
    end)
  end

  def to_delta(source, options) do
    if is_fragment(source) do
      source
      |> Document.wrap()
      |> to_delta(options)
    else
      {:error, %InvalidInputError{found: source}}
    end
  end

  @doc """
  Same as `to_delta/2` but raises on error.
  """
  @spec to_delta!(source(), keyword()) :: [map()]
  def to_delta!(source, options \\ []) do
    case to_delta(source, options) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @doc """
  Convert `MDEx.Document` to Markdown using default options.

  Use `to_markdown/2` to pass custom options.

  ## Example

      iex> MDEx.to_markdown(%MDEx.Document{nodes: [%MDEx.Heading{nodes: [%MDEx.Text{literal: "Hello"}], level: 3, setext: false}]})
      {:ok, "### Hello"}

  """
  @spec to_markdown(Document.t(), MDEx.Document.options()) :: {:ok, String.t()} | {:error, MDEx.DecodeError.t()}
  def to_markdown(%Document{} = document, options \\ []) do
    run_pipeline(document, options, fn doc, _opts -> Native.document_to_commonmark(doc) end)
  end

  @doc """
  Same as `to_markdown/1` but raises `MDEx.DecodeError` if the conversion fails.
  """
  @spec to_markdown!(Document.t(), MDEx.Document.options()) :: String.t()
  def to_markdown!(%Document{} = document, options \\ []) do
    case to_markdown(document, options) do
      {:ok, md} -> md
      {:error, error} -> raise error
    end
  end

  @deprecated "Use `to_markdown/1` instead"
  def to_commonmark(document), do: to_markdown(document)

  @deprecated "Use `to_markdown!/1` instead"
  def to_commonmark!(document), do: to_markdown!(document)

  @deprecated "Use `to_markdown/2` instead"
  def to_commonmark(document, options), do: to_markdown(document, options)

  @deprecated "Use `to_markdown!/2` instead"
  def to_commonmark!(document, options), do: to_markdown!(document, options)

  @doc """
  Low-level function to traverse and update the Markdown document preserving the tree structure format.

  See `MDEx.Document` for more information about the tree structure and for higher-level functions
  using the Access and Enumerable protocols.

  ## Examples

  Traverse an entire Markdown document:

      iex> import MDEx.Sigil
      iex> doc = ~MD\"""
      ...> # Languages
      ...>
      ...> `elixir`
      ...>
      ...> `rust`
      ...> \"""
      iex> MDEx.traverse_and_update(doc, fn
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

    Or fragments of a document:

      iex> fragment = MDEx.parse_fragment!("Lang: `elixir`")
      iex> MDEx.traverse_and_update(fragment, fn
      ...>   %MDEx.Code{literal: "elixir"} = node -> %{node | literal: "ex"}
      ...>   node -> node
      ...> end)
      %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Lang: "}, %MDEx.Code{num_backticks: 1, literal: "ex"}]}

  """
  # TODO: move to Document
  @spec traverse_and_update(MDEx.Document.t(), (MDEx.Document.md_node() -> MDEx.Document.md_node())) :: MDEx.Document.t()
  def traverse_and_update(ast, fun), do: Document.Traversal.traverse_and_update(ast, fun)

  @doc """
  Low-level function to traverse and update the Markdown document preserving the tree structure format and keeping an accumulator.

  See `MDEx.Document` for more information about the tree structure and for higher-level functions
  using the Access and Enumerable protocols.

  ## Example

      iex> import MDEx.Sigil
      iex> doc = ~MD\"""
      ...> # Languages
      ...>
      ...> `elixir`
      ...>
      ...> `rust`
      ...> \"""
      iex> MDEx.traverse_and_update(doc, 0, fn
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

  Also works with fragments.

  """
  # TODO: move to Document
  @spec traverse_and_update(MDEx.Document.t(), any(), (MDEx.Document.md_node() -> MDEx.Document.md_node())) :: MDEx.Document.t()
  def traverse_and_update(ast, acc, fun), do: Document.Traversal.traverse_and_update(ast, acc, fun)

  defp maybe_trim({:ok, result}), do: {:ok, String.trim(result)}
  defp maybe_trim(error), do: error

  defp run_pipeline(document, options, converter) do
    {document_opt, options} = pop_deprecated_document_option(options)

    document
    |> Document.put_options(options)
    |> maybe_apply_document_option(document_opt)
    |> Document.run()
    |> then(fn document ->
      document
      |> converter.(Document.rust_options!(document.options))
      |> maybe_trim()
    end)
  end

  @doc """
  Utility function to sanitize and escape HTML.

  ## Examples

      iex> MDEx.safe_html("<script>console.log('attack')</script>")
      ""

      iex> MDEx.safe_html("<custom_tag>Hello</custom_tag>")
      "Hello"

      iex> MDEx.safe_html("<custom_tag>Hello</custom_tag>", sanitize: [add_tags: ["custom_tag"]], escape: [content: false])
      "<custom_tag>Hello</custom_tag>"

      iex> MDEx.safe_html("<h1>{'Example:'}</h1><code>{:ok, 'MDEx'}</code>")
      "&lt;h1&gt;{&#x27;Example:&#x27;}&lt;&#x2f;h1&gt;&lt;code&gt;&lbrace;:ok, &#x27;MDEx&#x27;&rbrace;&lt;&#x2f;code&gt;"

      iex> MDEx.safe_html("<h1>{'Example:'}</h1><code>{:ok, 'MDEx'}</code>", escape: [content: false])
      "<h1>{'Example:'}</h1><code>&lbrace;:ok, 'MDEx'&rbrace;</code>"

  ## Options

    - `:sanitize` - cleans HTML after rendering. Defaults to `MDEx.Document.default_sanitize_options()/0`.
        - `keyword` - `t:sanitize_options/0`
        - `nil` - do not sanitize output.

    - `:escape` - which entities should be escaped. Defaults to `[:content, :curly_braces_in_code]`.
        - `:content` - escape common chars like `<`, `>`, `&`, and others in the HTML content;
        - `:curly_braces_in_code` - escape `{` and `}` only inside `<code>` tags, particularly useful for compiling HTML in LiveView;
  """
  @spec safe_html(
          String.t(),
          options :: [
            sanitize: MDEx.Document.sanitize_options() | nil,
            escape: [atom()]
          ]
        ) :: String.t()
  def safe_html(unsafe_html, options \\ []) when is_binary(unsafe_html) and is_list(options) do
    sanitize =
      options
      |> opt([:sanitize], Document.default_sanitize_options())
      |> case do
        nil ->
          nil

        options ->
          options
          |> NimbleOptions.validate!(MDEx.Document.sanitize_options_schema())
          |> MDEx.Document.adapt_sanitize_options()
      end

    escape_content = opt(options, [:escape, :content], true)
    escape_curly_braces_in_code = opt(options, [:escape, :curly_braces_in_code], true)
    Native.safe_html(unsafe_html, sanitize, escape_content, escape_curly_braces_in_code)
  end

  # if Code.ensure_loaded?(Phoenix.LiveView.Rendered) do
  #   @doc """
  #   Utility function to convert a `Phoenix.LiveView.Rendered` struct to HTML (string).
  #
  #   ## Example
  #
  #       iex> assigns = %{url: "https://elixir-lang.org", title: "Elixir Lang"}
  #       iex> ~MD|<.link href={URI.parse(@url)}>{@title}</.link>|HEEX |> MDEx.rendered_to_html()
  #       "<a href=\\"https://elixir-lang.org\\">Elixir</a>"
  #   """
  #   @spec rendered_to_html(Phoenix.LiveView.Rendered.t()) :: String.t()
  #   def rendered_to_html(%Phoenix.LiveView.Rendered{} = rendered) do
  #     rendered
  #     |> Phoenix.HTML.html_escape()
  #     |> Phoenix.HTML.safe_to_string()
  #   end
  # else
  #   def rendered_to_html(_rendered) do
  #     raise "MDEx.rendered_to_html/1 requires Phoenix.LiveView to be available"
  #   end
  # end

  defp opt(options, keys, default) do
    case get_in(options, keys) do
      nil -> default
      val -> val
    end
  end

  @document Document.put_options(%MDEx.Document{}, MDEx.Document.default_options())

  @doc """
  Builds a new `MDEx.Document` instance.

  `MDEx.Document` is the core data structure used across MDEx. It holds the full CommonMark AST and
  exposes rich `Access`, `Enumerable`, and pipeline APIs so you can traverse, manipulate, and enrich
  Markdown before turning it into HTML/JSON/XML/Markdown/Delta.

  * Pass `:markdown` to include Markdown into the buffer or call `MDEx.Document.put_markdown/2` to add more later.
  * Pass any built-in options (`:extension`, `:parse`, `:render`, `:syntax_highlight`, `:sanitize`) to
    shape how the document will be parsed and rendered.
  * Chain pipeline helpers such as `MDEx.Document.append_steps/2`, `MDEx.Document.update_nodes/3`, or your own plugin
    modules to programmatically modify the AST.

  Once you finish manipulating the document, call one of the `MDEx.to_*` functions to output the final result to a format
  or `MDEx.Document.run/1` to finalize the document and get the updated AST.

  ## Options

    - `:markdown` (`t:String.t/0`)  Raw Markdown to parse into the document. Defaults to `""`
    - `:extension` (`t:MDEx.Document.extension_options/0`) Enable extensions. Defaults to `MDEx.Document.default_extension_options/0`
    - `:parse` - (`t:parse_options/0`) Modify parsing behavior. Defaults to `MDEx.Document.default_parse_options/0`
    - `:render` - (`t:render_options/0`) Modify rendering behavior. Defaults to `MDEx.Document.default_render_options/0`
    - `:syntax_highlight` - (`t:syntax_highlight_options/0` | `nil`) Modify syntax highlighting behavior or `nil` to disable. Defaults to `MDEx.Document.default_syntax_highlight_options/0`
    - `:sanitize` - (`t:sanitize_options/0` | `nil`) Modify sanitization behavior  or `nil` to disable sanitization. Use `MDEx.Document.default_sanitize_options/0` to enable a default set of sanitization options. Defaults to `nil`.

  Note that `:sanitize` and `:unsafe` are disabled by default. See [Safety](https://hexdocs.pm/mdex/safety.html) for more info.

  ## Examples

      iex> MDEx.new(markdown: "# Hello") |> MDEx.to_html!()
      "<h1>Hello</h1>"

      iex> MDEx.new(markdown: "Hello ~world~", extension: [strikethrough: true]) |> MDEx.to_html!()
      "<p>Hello <del>world</del></p>"

      iex> MDEx.new(markdown: "# Intro")
      ...> |> MDEx.Document.append_steps(inject_html: fn doc ->
      ...>   snippet = %MDEx.HtmlBlock{literal: "<section>Injected</section>"}
      ...>   MDEx.Document.put_node_in_document_root(doc, snippet, :bottom)
      ...> end)
      ...> |> MDEx.to_html!(render: [unsafe: true])
      "<h1>Intro</h1>\\n<section>Injected</section>"

  Using `MDEx.Document.run/1` to process buffered markdown and get the AST:

      iex> doc = MDEx.new(markdown: "# First\\n")
      ...> |> MDEx.Document.put_markdown("# Second")
      ...> |> MDEx.Document.run()
      iex> doc.nodes
      [
        %MDEx.Heading{nodes: [%MDEx.Text{literal: "First"}], level: 1, setext: false},
        %MDEx.Heading{nodes: [%MDEx.Text{literal: "Second"}], level: 1, setext: false}
      ]

  """
  @spec new(keyword()) :: Document.t()
  def new(options \\ []) do
    # TODO: remove :document in v1.0
    {document, options} = Keyword.pop(options, :document, nil)
    {markdown, options} = Keyword.pop(options, :markdown, nil)
    markdown = document || markdown || ""

    unless is_binary(markdown) do
      raise ArgumentError, ":markdown option must be a binary, got: #{inspect(markdown)}"
    end

    @document
    |> Document.put_options(options)
    |> Document.put_markdown(markdown)
  end

  @doc """
  Convert a given `text` string to a format that can be used as an "anchor", such as in a Table of Contents.

  This uses the same algorithm GFM uses for anchor ids, so it can be used reliably.

  > #### Repeated anchors
  > GFM will dedupe multiple repeated anchors with the same value by appending
  > an incrementing number to the end of the anchor. That is beyond the scope of
  > this function, so you will have to handle it yourself.

  ## Examples

      iex> MDEx.anchorize("Hello World")
      "hello-world"

      iex> MDEx.anchorize("Hello, World!")
      "hello-world"

      iex> MDEx.anchorize("Hello -- World")
      "hello----world"

      iex> MDEx.anchorize("Hello World 123")
      "hello-world-123"

      iex> MDEx.anchorize("你好世界")
      "你好世界"
  """
  @spec anchorize(String.t()) :: String.t()
  def anchorize(text), do: Native.text_to_anchor(text)

  # TODO: remove in v1.0
  defp pop_deprecated_document_option(options) do
    {document, options} = Keyword.pop(options, :document)

    if !is_nil(document) do
      IO.warn("option :document is deprecated, use :markdown instead")
    end

    {document, options}
  end

  # TODO: remove in v1.0
  defp maybe_apply_document_option(document, nil), do: document

  defp maybe_apply_document_option(document, markdown) when is_binary(markdown) do
    Document.parse_markdown!(document, markdown)
  end

  defp maybe_apply_document_option(document, %Document{} = replacement) do
    %{document | nodes: replacement.nodes}
  end

  defp maybe_apply_document_option(_document, other) do
    raise ArgumentError, "option :document must be a binary or %MDEx.Document{}, got: #{inspect(other)}"
  end
end
