defmodule MDEx do
  @external_resource "README.md"

  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC -->")
             |> Enum.fetch!(1)

  alias MDEx.Native
  alias MDEx.Document
  alias MDEx.DecodeError
  alias MDEx.InvalidInputError

  @typedoc """
  Data that can be processed as Markdown, ie: the initial input.
  """
  @type input :: String.t() | MDEx.Document.t() | MDEx.Pipe.t()

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
    unsafe_: [
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
    experimental_inline_sourcepos: [
      type: :boolean,
      default: false,
      doc: "Include inline sourcepos in HTML output, which is known to have issues."
    ],
    escaped_char_spans: [
      type: :boolean,
      default: false,
      doc: "Wrap escaped characters in a `<span>` to allow any post-processing to recognize them."
    ],
    ignore_setext: [
      type: :boolean,
      default: false,
      doc: "Ignore setext headings in input."
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

  @features_options_schema [
    sanitize: [
      type: :boolean,
      default: false,
      doc: "sanitize output using [ammonia](https://crates.io/crates/ammonia). See the [Safety](#module-safety) section for more info."
    ],
    syntax_highlight_theme: [
      type: {:or, [:string, nil]},
      default: "onedark",
      doc:
        "syntax highlight code fences using [autumn themes](https://github.com/leandrocp/autumn/tree/main/priv/themes), you should pass the filename without special chars and without extension, for example you should pass `syntax_highlight_theme: \"adwaita_dark\"` to use the [Adwaita Dark](https://github.com/leandrocp/autumn/blob/main/priv/themes/adwaita-dark.toml) theme."
    ],
    syntax_highlight_inline_style: [
      type: :boolean,
      default: true,
      doc:
        "embed styles in the output for each generated token. You'll need to [serve CSS themes](https://github.com/leandrocp/autumn?tab=readme-ov-file#linked) if inline styles are disabled to properly highlight code."
    ]
  ]

  @options_schema [
    document: [
      type: {:or, [:string, {:struct, MDEx.Document}, nil]},
      default: "",
      doc: "Markdown document, either a string or a `MDEx.Document` struct."
    ],
    extension: [
      type: :keyword_list,
      default: [],
      doc:
        "Enable extensions. See comrak's [ExtensionOptions](https://docs.rs/comrak/latest/comrak/struct.ExtensionOptions.html) for more info and examples.",
      keys: @extension_options_schema
    ],
    parse: [
      type: :keyword_list,
      default: [],
      doc:
        "Configure parsing behavior. See comrak's [ParseOptions](https://docs.rs/comrak/latest/comrak/struct.ParseOptions.html) for more info and examples.",
      keys: @parse_options_schema
    ],
    render: [
      type: :keyword_list,
      default: [],
      doc:
        "Configure rendering behavior. See comrak's [RenderOptions](https://docs.rs/comrak/latest/comrak/struct.RenderOptions.html) for more info and examples.",
      keys: @render_options_schema
    ],
    features: [
      type: :keyword_list,
      default: [],
      doc: "Enable extra features. ",
      keys: @features_options_schema
    ]
  ]

  @doc false
  def extension_options_schema, do: @extension_options_schema

  @doc false
  def render_options_schema, do: @render_options_schema

  @doc false
  def parse_options_schema, do: @parse_options_schema

  @doc false
  def features_options_schema, do: @features_options_schema

  @doc false
  def options_schema, do: @options_schema

  @doc """
  Returns `true` if node is a fragment of a document.

  ## Examples

      iex> MDEx.is_fragment(%MDEx.Heading{})
      true

      iex> MDEx.is_fragment(%MDEx.Document{})
      false

  """
  @spec is_fragment(Document.md_node()) :: boolean()
  def is_fragment(node), do: Document.is_fragment(node)

  @typedoc """
  Options to customize the parsing and rendering of Markdown documents.

  See `new/1` for a full list.
  """
  @type options() :: [unquote(NimbleOptions.option_typespec(@options_schema))]

  @doc """
  Parse a `markdown` string and returns a `MDEx.Document`.

  ## Options

  See `new/1` for the available options.

  ## Examples

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
  """
  @spec parse_document(String.t(), options()) :: {:ok, Document.t()} | {:error, term()}
  def parse_document(markdown, options \\ [])

  def parse_document(markdown, options) when is_binary(markdown) do
    Native.parse_document(markdown, comrak_options(options))
  end

  def parse_document(%MDEx.Document{} = document, _options), do: {:ok, document}

  def parse_document(document, options) when is_struct(document) do
    document
    |> MDEx.Document.wrap()
    |> parse_document(options)
  end

  def parse_document(_pipe, _options), do: {:error, :invalid}

  @doc """
  Same as `parse_document/2` but raises if the parsing fails.
  """
  @spec parse_document!(String.t(), options()) :: Document.t()
  def parse_document!(markdown, options \\ []) when is_binary(markdown) do
    case parse_document(markdown, options) do
      {:ok, doc} -> doc
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
  @spec parse_fragment(String.t(), options()) :: {:ok, Document.md_node()} | nil
  def parse_fragment(markdown, options \\ []) when is_binary(markdown) do
    case parse_document(markdown, options) do
      {:ok, %Document{nodes: [%MDEx.Paragraph{nodes: [node]}]}} -> {:ok, node}
      {:ok, %Document{nodes: [node]}} -> {:ok, node}
      _ -> nil
    end
  end

  @doc """
  Same as `parse_fragment/2` but raises if the parsing fails.

  > #### Experimental {: .warning}
  >
  > Consider this function experimental and subject to change.

  """
  @spec parse_fragment!(String.t(), options()) :: Document.md_node()
  def parse_fragment!(markdown, options \\ []) when is_binary(markdown) do
    case parse_fragment(markdown, options) do
      {:ok, fragment} -> fragment
      _ -> raise %InvalidInputError{found: markdown}
    end
  end

  @doc """
  Convert Markdown or `MDEx.Document` to HTML using default options.

  Use `to_html/2` to pass options and customize the generated HTML.

  ## Examples

      iex> MDEx.to_html("# MDEx")
      {:ok, "<h1>MDEx</h1>"}

      iex> MDEx.to_html("Implemented with:\\n1. Elixir\\n2. Rust")
      {:ok, "<p>Implemented with:</p>\\n<ol>\\n<li>Elixir</li>\\n<li>Rust</li>\\n</ol>"}

      iex> MDEx.to_html(%MDEx.Document{nodes: [%MDEx.Heading{nodes: [%MDEx.Text{literal: "MDEx"}], level: 3, setext: false}]})
      {:ok, "<h3>MDEx</h3>"}

  Fragments of a document are also supported:

      iex> MDEx.to_html(%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "MDEx"}]})
      {:ok, "<p>MDEx</p>"}

  """
  @spec to_html(input()) ::
          {:ok, String.t()}
          | {:error, MDEx.DecodeError.t()}
          | {:error, MDEx.InvalidInputError.t()}
  def to_html(input)

  def to_html(%MDEx.Pipe{} = pipe) do
    pipe
    |> MDEx.Pipe.run()
    |> then(&to_html(&1.document, &1.options))
  end

  def to_html(input) when is_binary(input) do
    input
    |> Native.markdown_to_html()
    |> maybe_trim()
  end

  def to_html(%Document{} = doc) do
    doc
    |> Native.document_to_html()
    |> maybe_trim()
  rescue
    ErlangError ->
      {:error, %DecodeError{document: doc}}
  end

  def to_html(input) do
    if is_fragment(input) do
      input
      |> Document.wrap()
      |> to_html()
    else
      {:error, %InvalidInputError{found: input}}
    end
  end

  @doc """
  Same as `to_html/1` but raises an error if the conversion fails.
  """
  @spec to_html!(input()) :: String.t()
  def to_html!(input) do
    case to_html(input) do
      {:ok, html} -> html
      {:error, error} -> raise error
    end
  end

  @doc """
  Convert Markdown or `MDEx.Document` to HTML using custom options.

  ## Options

  See `new/1` for the available options.

  ## Examples

      iex> MDEx.to_html("Hello ~world~ there", extension: [strikethrough: true])
      {:ok, "<p>Hello <del>world</del> there</p>"}

      iex> MDEx.to_html("<marquee>visit https://beaconcms.org</marquee>", extension: [autolink: true], render: [unsafe_: true])
      {:ok, "<p><marquee>visit <a href=\\"https://beaconcms.org\\">https://beaconcms.org</a></marquee></p>"}

  """
  @spec to_html(input(), options()) ::
          {:ok, String.t()}
          | {:error, MDEx.DecodeError.t()}
          | {:error, MDEx.InvalidInputError.t()}
  def to_html(input, options)

  def to_html(%MDEx.Pipe{} = pipe, options) when is_list(options) do
    pipe
    |> MDEx.Steps.put_options(options)
    |> MDEx.Pipe.run()
    |> then(&to_html(&1.document, &1.options))
  end

  def to_html(input, options) when is_binary(input) and is_list(options) do
    input
    |> Native.markdown_to_html_with_options(comrak_options(options))
    # |> maybe_wrap_error()
    |> maybe_trim()
  end

  def to_html(%Document{} = doc, options) when is_list(options) do
    doc
    |> Native.document_to_html_with_options(comrak_options(options))
    |> maybe_trim()
  rescue
    ErlangError ->
      {:error, %DecodeError{document: doc}}
  end

  def to_html(input, options) do
    if is_fragment(input) do
      input
      |> Document.wrap()
      |> to_html(options)
    else
      {:error, %InvalidInputError{found: input}}
    end
  end

  @doc """
  Same as `to_html/2` but raises error if the conversion fails.
  """
  @spec to_html!(input(), options()) :: String.t()
  def to_html!(input, options) do
    case to_html(input, options) do
      {:ok, html} -> html
      {:error, error} -> raise error
    end
  end

  @doc """
  Convert Markdown or `MDEx.Document` to XML using default options.

  Use `to_xml/2` to pass options and customize the generated XML.

  ## Examples

      iex> {:ok, xml} =  MDEx.to_xml("# MDEx")
      iex> xml
      \"""
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE document SYSTEM "CommonMark.dtd">
      <document xmlns="http://commonmark.org/xml/1.0">
        <heading level="1">
          <text xml:space="preserve">MDEx</text>
        </heading>
      </document>
      \"""

      iex> {:ok, xml} = MDEx.to_xml("Implemented with:\\n1. Elixir\\n2. Rust")
      iex> xml
      \"""
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE document SYSTEM "CommonMark.dtd">
      <document xmlns="http://commonmark.org/xml/1.0">
        <paragraph>
          <text xml:space="preserve">Implemented with:</text>
        </paragraph>
        <list type="ordered" start="1" delim="period" tight="true">
          <item>
            <paragraph>
              <text xml:space="preserve">Elixir</text>
            </paragraph>
          </item>
          <item>
            <paragraph>
              <text xml:space="preserve">Rust</text>
            </paragraph>
          </item>
        </list>
      </document>
      \"""

      iex> {:ok, xml} = MDEx.to_xml(%MDEx.Document{nodes: [%MDEx.Heading{nodes: [%MDEx.Text{literal: "MDEx"}], level: 3, setext: false}]})
      iex> xml
      \"""
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE document SYSTEM "CommonMark.dtd">
      <document xmlns="http://commonmark.org/xml/1.0">
        <heading level="3">
          <text xml:space="preserve">MDEx</text>
        </heading>
      </document>
      \"""

  Fragments of a document are also supported:

      iex> {:ok, xml} = MDEx.to_xml(%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "MDEx"}]})
      iex> xml
      \"""
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE document SYSTEM "CommonMark.dtd">
      <document xmlns="http://commonmark.org/xml/1.0">
        <paragraph>
          <text xml:space="preserve">MDEx</text>
        </paragraph>
      </document>
      \"""

  """
  @spec to_xml(input()) ::
          {:ok, String.t()}
          | {:error, MDEx.DecodeError.t()}
          | {:error, MDEx.InvalidInputError.t()}
  def to_xml(input)

  def to_xml(input) when is_binary(input) do
    input
    |> Native.markdown_to_xml()

    # |> maybe_trim()
  end

  def to_xml(%Document{} = doc) do
    doc
    |> Native.document_to_xml()

    # |> maybe_trim()
  rescue
    ErlangError ->
      {:error, %DecodeError{document: doc}}
  end

  def to_xml(input) do
    if is_fragment(input) do
      input
      |> Document.wrap()
      |> to_xml()
    else
      {:error, %InvalidInputError{found: input}}
    end
  end

  @doc """
  Same as `to_xml/1` but raises an error if the conversion fails.
  """
  @spec to_xml!(input()) :: String.t()
  def to_xml!(input) do
    case to_xml(input) do
      {:ok, xml} -> xml
      {:error, error} -> raise error
    end
  end

  @doc """
  Convert Markdown or `MDEx.Document` to XML using custom options.

  ## Options

  See `new/1` for the available options.

  ## Examples

      iex> {:ok, xml} = MDEx.to_xml("Hello ~world~ there", extension: [strikethrough: true])
      iex> xml
      \"""
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE document SYSTEM "CommonMark.dtd">
      <document xmlns="http://commonmark.org/xml/1.0">
        <paragraph>
          <text xml:space="preserve">Hello </text>
          <strikethrough>
            <text xml:space="preserve">world</text>
          </strikethrough>
          <text xml:space="preserve"> there</text>
        </paragraph>
      </document>
      \"""

      iex> {:ok, xml} = MDEx.to_xml("<marquee>visit https://beaconcms.org</marquee>", extension: [autolink: true], render: [unsafe_: true])
      iex> xml
      \"""
      <?xml version="1.0" encoding="UTF-8"?>
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
      </document>
      \"""

  """
  @spec to_xml(input(), options()) ::
          {:ok, String.t()}
          | {:error, MDEx.DecodeError.t()}
          | {:error, MDEx.InvalidInputError.t()}
  def to_xml(input, options)

  def to_xml(input, options) when is_binary(input) and is_list(options) do
    input
    |> Native.markdown_to_xml_with_options(comrak_options(options))

    # |> maybe_wrap_error()
    # |> maybe_trim()
  end

  def to_xml(%Document{} = doc, options) when is_list(options) do
    doc
    |> Native.document_to_xml_with_options(comrak_options(options))
    |> maybe_trim()
  rescue
    ErlangError ->
      {:error, %DecodeError{document: doc}}
  end

  def to_xml(input, options) do
    if is_fragment(input) do
      input
      |> Document.wrap()
      |> to_xml(options)
    else
      {:error, %InvalidInputError{found: input}}
    end
  end

  @doc """
  Same as `to_xml/2` but raises error if the conversion fails.
  """
  @spec to_xml!(input(), options()) :: String.t()
  def to_xml!(input, options) do
    case to_xml(input, options) do
      {:ok, xml} -> xml
      {:error, error} -> raise error
    end
  end

  @doc """
  Convert an AST to CommonMark using default options.

  To customize the output, use `to_commonmark/2`.

  ## Example

      iex> MDEx.to_commonmark(%MDEx.Document{nodes: [%MDEx.Heading{nodes: [%MDEx.Text{literal: "Hello"}], level: 3, setext: false}]})
      {:ok, "### Hello"}

  """
  @spec to_commonmark(Document.t()) :: {:ok, String.t()} | {:error, MDEx.DecodeError.t()}
  def to_commonmark(%Document{} = doc) do
    doc
    |> Native.document_to_commonmark()
    # |> maybe_wrap_error()
    |> maybe_trim()
  end

  @doc """
  Same as `to_commonmark/1` but raises `MDEx.DecodeError` if the conversion fails.
  """
  @spec to_commonmark!(Document.t()) :: String.t()
  def to_commonmark!(%Document{} = doc) do
    case to_commonmark(doc) do
      {:ok, md} -> md
      {:error, error} -> raise error
    end
  end

  @doc """
  Convert an AST to CommonMark with custom options.

  ## Options

  See `new/1` for the available options.
  """
  @spec to_commonmark(Document.t(), keyword()) :: {:ok, String.t()} | {:error, MDEx.DecodeError.t()}
  def to_commonmark(%Document{} = doc, options) when is_list(options) do
    doc
    |> Native.document_to_commonmark_with_options(comrak_options(options))
    # |> maybe_wrap_error()
    |> maybe_trim()
  end

  @doc """
  Same as `to_commonmark/2` but raises `MDEx.DecodeError` if the conversion fails.
  """
  @spec to_commonmark!(Document.t(), options()) :: String.t()
  def to_commonmark!(%Document{} = doc, options) when is_list(options) do
    case to_commonmark(doc, options) do
      {:ok, md} -> md
      {:error, error} -> raise error
    end
  end

  @doc """
  Traverse and update the Markdown document preserving the tree structure format.

  ## Examples

  Traverse an entire Markdown document:


      iex> import MDEx.Sigil
      iex> doc = ~M\"""
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
  @spec traverse_and_update(MDEx.Document.t(), (MDEx.Document.md_node() -> MDEx.Document.md_node())) :: MDEx.Document.t()
  def traverse_and_update(ast, fun), do: MDEx.Document.Traversal.traverse_and_update(ast, fun)

  @doc """
  Traverse and update the Markdown document preserving the tree structure format and keeping an accumulator.

  ## Example

      iex> import MDEx.Sigil
      iex> doc = ~M\"""
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
  @spec traverse_and_update(MDEx.Document.t(), term(), (MDEx.Document.md_node() -> MDEx.Document.md_node())) :: MDEx.Document.t()
  def traverse_and_update(ast, acc, fun), do: MDEx.Document.Traversal.traverse_and_update(ast, acc, fun)

  defp comrak_options(options) do
    comrak_options =
      NimbleOptions.validate!(
        [
          extension: options[:extension] || [],
          parse: options[:parse] || [],
          render: options[:render] || [],
          features: options[:features] || []
        ],
        @options_schema
      )

    %{
      extension: Map.new(comrak_options[:extension]),
      parse: Map.new(comrak_options[:parse]),
      render: Map.new(comrak_options[:render]),
      features: Map.new(comrak_options[:features])
    }
  end

  defp maybe_trim({:ok, result}), do: {:ok, String.trim(result)}
  defp maybe_trim(error), do: error

  @doc """
  Utility function to sanitize and escape HTML.

  ## Examples

      iex> MDEx.safe_html("<script>console.log('attack')</script>")
      ""

      iex> MDEx.safe_html("<h1>{'Example:'}</h1><code>{:ok, 'MDEx'}</code>")
      "&lt;h1&gt;{&#x27;Example:&#x27;}&lt;&#x2f;h1&gt;&lt;code&gt;&lbrace;:ok, &#x27;MDEx&#x27;&rbrace;&lt;&#x2f;code&gt;"

      iex> MDEx.safe_html("<h1>{'Example:'}</h1><code>{:ok, 'MDEx'}</code>", escape: [content: false])
      "<h1>{'Example:'}</h1><code>&lbrace;:ok, 'MDEx'&rbrace;</code>"

  ## Options

    - `:sanitize` - clean HTML using these rules https://docs.rs/ammonia/latest/ammonia/fn.clean.html. Defaults to `true`.
    - `:escape` - which entities should be escaped. Defaults to `[:content, :curly_braces_in_code]`.
        - `:content` - escape common chars like `<`, `>`, `&`, and others in the HTML content;
        - `:curly_braces_in_code` - escape `{` and `}` only inside `<code>` tags, particularly useful for compiling HTML in LiveView;
  """
  def safe_html(unsafe_html, options \\ []) when is_binary(unsafe_html) and is_list(options) do
    sanitize = opt(options, [:sanitize], true)
    escape_content = opt(options, [:escape, :content], true)
    escape_curly_braces_in_code = opt(options, [:escape, :curly_braces_in_code], true)
    Native.safe_html(unsafe_html, sanitize, escape_content, escape_curly_braces_in_code)
  end

  defp opt(options, keys, default) do
    case get_in(options, keys) do
      nil -> default
      val -> val
    end
  end

  @doc """
  Returns a new `MDEx.Pipe` instance.

  Once the pipe has all transformations you want, call either one of the following functions to format it:

  - `MDEx.to_html/1`
  - `MDEx.to_xml/1`
  - `MDEx.to_commonmark/1`

  ## Options

  Options are separated into 4 main groups:

  - `:document` - the Markdown document to be parsed and transformed in the pipeline.
  - `:extension` - [comrak extensions](https://docs.rs/comrak/latest/comrak/struct.ExtensionOptions.html)
  - `:parse` - [comrak parse options](https://docs.rs/comrak/latest/comrak/struct.ParseOptions.html)
  - `:render` - [comrak render options](https://docs.rs/comrak/latest/comrak/struct.RenderOptions.html)
  - `:features` - extra features like sanitization and syntax highlighting.

  See the full list below:

  #{NimbleOptions.docs(@options_schema)}

  ## Examples

      iex> mdex = MDEx.new(document: "# Hello")
      iex> mdex |> MDEx.to_html()
      {:ok, "<h1>Hello</h1>"}

      iex> mdex = MDEx.new(document: "Hello ~world~", extension: [strikethrough: true])
      iex> mdex |> MDEx.to_html()
      {:ok, "<p>Hello <del>world</del></p>"}

  ## Notes

  1. String documents are automatically [parsed](https://hexdocs.pm/mdex/MDEx.html#parse_document!/2)
  into `MDEx.Document` before the pipeline runs so every step receives the same data type.

  2. You can pass the document when creating the pipe:

  ```elixir
  MDEx.new(document: "# Hello") |> MDEx.to_html()
  ```

  Or pass it only when formatting the document:

  ```elixir
  mdex = MDEx.new()

  MDEx.to_html(mdex, document: "# Hello to HTML")
  MDEx.to_xml(mdex, document: "# Hello to XML")
  ```

  Useful to reuse the same pipe with different documents and formats.

  """
  @spec new(options()) :: MDEx.Pipe.t()
  def new(options \\ []) do
    %MDEx.Pipe{}
    |> MDEx.Steps.put_options(options)
    |> MDEx.Steps.attach()
  end
end
