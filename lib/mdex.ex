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

  import MDEx.Document, only: [is_fragment: 1]

  require Logger

  @type input :: String.t() | Document.t()

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
        "col" => ~w(align char charoff span),
        "colgroup" => ~w(align char charoff span),
        "del" => ~w(cite datetime),
        "hr" => ~w(align size width),
        "img" => ~w(align alt height src width),
        "ins" => ~w(cite datetime),
        "ol" => ~w(start),
        "q" => ~w(cite),
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

  @features_options_schema [
    sanitize: [
      type: {:or, [{:keyword_list, @sanitize_options_schema}, nil]},
      type_spec: quote(do: sanitize_options() | nil),
      default: nil,
      doc: """
      Cleans HTML using [ammonia](https://crates.io/crates/ammonia) after rendering.

      Use a [conservative set of options by default](https://docs.rs/ammonia/latest/ammonia/fn.clean.html),
      but you can overwrite the default options `MDEx.default_sanitize_options/0`. For example to
      build an [empty](https://docs.rs/ammonia/latest/ammonia/struct.Builder.html#method.empty) base with no allowed tags:

          empty_base = Keyword.put(MDEx.default_sanitize_options(), :tags, [])
          features: [sanitize: empty_base]

      See the [Safety](#module-safety) section for more info.
      """
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
    features: [
      type: :keyword_list,
      type_spec: quote(do: features_options()),
      default: [],
      doc: "Enable extra features.",
      keys: @features_options_schema
    ]
  ]

  @typedoc """
  Options to customize the parsing and rendering of Markdown documents.

  ## Examples

  - Enable the `table` extension:

      ```elixir
      iex> MDEx.to_html!(\"""
      ...> | lang |
      ...> |------|
      ...> | elixir |
      ...> \""",
      ...> extension: [table: true])
      "<table>\\n<thead>\\n<tr>\\n<th>lang</th>\\n</tr>\\n</thead>\\n<tbody>\\n<tr>\\n<td>elixir</td>\\n</tr>\\n</tbody>\\n</table>"
      ```

  ## Options

  #{NimbleOptions.docs(@options_schema)}
  """
  @type options() :: [unquote(NimbleOptions.option_typespec(@options_schema))]

  @typedoc "List of [comrak extension options](https://docs.rs/comrak/latest/comrak/struct.ExtensionOptions.html)."
  @type extension_options() :: [unquote(NimbleOptions.option_typespec(@extension_options_schema))]

  @typedoc "List of [comrak parse options](https://docs.rs/comrak/latest/comrak/struct.ParseOptions.html)."
  @type parse_options() :: [unquote(NimbleOptions.option_typespec(@parse_options_schema))]

  @typedoc "List of [comrak render options](https://docs.rs/comrak/latest/comrak/struct.RenderOptions.html)."
  @type render_options() :: [unquote(NimbleOptions.option_typespec(@render_options_schema))]

  @typedoc "List of extra features."
  @type features_options() :: [unquote(NimbleOptions.option_typespec(@features_options_schema))]

  @typedoc "List of [ammonia options](https://docs.rs/ammonia/latest/ammonia/struct.Builder.html)."
  @type sanitize_options() :: [unquote(NimbleOptions.option_typespec(@sanitize_options_schema))]

  @doc """
  Returns the default options for the `:extension` group.

  #{NimbleOptions.docs(@extension_options_schema)}
  """
  @spec default_extension_options() :: extension_options()
  def default_extension_options, do: NimbleOptions.validate!([], @extension_options_schema)

  @doc """
  Returns the default options for the `:parse` group.

  #{NimbleOptions.docs(@parse_options_schema)}
  """
  @spec default_parse_options() :: parse_options()
  def default_parse_options, do: NimbleOptions.validate!([], @parse_options_schema)

  @doc """
  Returns the default options for the `:render` group.

  #{NimbleOptions.docs(@render_options_schema)}
  """
  @spec default_render_options() :: render_options()
  def default_render_options, do: NimbleOptions.validate!([], @render_options_schema)

  @doc """
  Returns the default options for the `:features` group.

  #{NimbleOptions.docs(@features_options_schema)}
  """
  @spec default_features_options() :: features_options()
  def default_features_options, do: NimbleOptions.validate!([], @features_options_schema)

  @doc """
  Returns the default options for the `:sanitize` group.

  #{NimbleOptions.docs(@sanitize_options_schema)}
  """
  @spec default_sanitize_options() :: sanitize_options()
  def default_sanitize_options, do: NimbleOptions.validate!([], @sanitize_options_schema)

  @doc """
  Parse a `markdown` string and returns a `MDEx.Document`.

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
  @spec parse_document(String.t(), options()) :: {:ok, Document.t()} | {:error, any()}
  def parse_document(markdown, options \\ []) when is_binary(markdown) do
    Native.parse_document(markdown, validate_options!(options))
  end

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
  Same as `parse_fragment/2` but raises if the parsing fails or returns `nil`.

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
      to_html(%Document{nodes: List.wrap(input)})
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

  See the [Options](#module-options) section for the available options.

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

  def to_html(input, options) when is_binary(input) and is_list(options) do
    input
    |> Native.markdown_to_html_with_options(validate_options!(options))
    # |> maybe_wrap_error()
    |> maybe_trim()
  end

  def to_html(%Document{} = doc, options) when is_list(options) do
    doc
    |> Native.document_to_html_with_options(validate_options!(options))
    |> maybe_trim()
  rescue
    ErlangError ->
      {:error, %DecodeError{document: doc}}
  end

  def to_html(input, options) do
    if is_fragment(input) do
      to_html(%Document{nodes: List.wrap(input)}, options)
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
      to_xml(%Document{nodes: List.wrap(input)})
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

  See the [Options](#module-options) section for the available options.

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
    |> Native.markdown_to_xml_with_options(validate_options!(options))

    # |> maybe_wrap_error()
    # |> maybe_trim()
  end

  def to_xml(%Document{} = doc, options) when is_list(options) do
    doc
    |> Native.document_to_xml_with_options(validate_options!(options))
    |> maybe_trim()
  rescue
    ErlangError ->
      {:error, %DecodeError{document: doc}}
  end

  def to_xml(input, options) do
    if is_fragment(input) do
      to_xml(%Document{nodes: List.wrap(input)}, options)
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

  See the [Options](#module-options) section for the available options.
  """
  @spec to_commonmark(Document.t(), options()) :: {:ok, String.t()} | {:error, MDEx.DecodeError.t()}
  def to_commonmark(%Document{} = doc, options) when is_list(options) do
    doc
    |> Native.document_to_commonmark_with_options(validate_options!(options))
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
  @spec traverse_and_update(MDEx.Document.t(), any(), (MDEx.Document.md_node() -> MDEx.Document.md_node())) :: MDEx.Document.t()
  def traverse_and_update(ast, acc, fun), do: MDEx.Document.Traversal.traverse_and_update(ast, acc, fun)

  def validate_options!(options) do
    sanitize =
      options
      |> get_in([:features, :sanitize])
      |> update_deprecated_sanitize_options()

    options =
      NimbleOptions.validate!(
        [
          extension: options[:extension] || [],
          parse: options[:parse] || [],
          render: options[:render] || [],
          features: Keyword.put(options[:features] || [], :sanitize, sanitize)
        ],
        @options_schema
      )
      |> update_in([:features, :sanitize], &adapt_sanitize_options/1)

    %{
      extension: Map.new(options[:extension]),
      parse: Map.new(options[:parse]),
      render: Map.new(options[:render]),
      features: Map.new(options[:features])
    }
  end

  defp update_deprecated_sanitize_options(true = _options) do
    Logger.warning("""
    sanitize: true is deprecated. Pass :sanitize options instead, for example:

      sanitize: MDEx.default_sanitize_options()

    MDEx.default_sanitize_options() is the same behavior as the now deprecated sanitize: true

    """)

    MDEx.default_sanitize_options()
  end

  defp update_deprecated_sanitize_options(false = _options) do
    Logger.warning("""
    sanitize: false is deprecated. Use nil instead:

      sanitize: nil

    """)

    nil
  end

  defp update_deprecated_sanitize_options(options), do: options

  defp adapt_sanitize_options(nil = _options), do: nil

  defp adapt_sanitize_options(options) do
    # dbg(options)

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

    - `:sanitize` - cleans HTML after rendering. Defaults to `MDEx.default_sanitize_options/0`.
        - `keyword` - `t:sanitize_options/0`
        - `nil` - do not sanitize output.

    - `:escape` - which entities should be escaped. Defaults to `[:content, :curly_braces_in_code]`.
        - `:content` - escape common chars like `<`, `>`, `&`, and others in the HTML content;
        - `:curly_braces_in_code` - escape `{` and `}` only inside `<code>` tags, particularly useful for compiling HTML in LiveView;
  """
  @spec safe_html(
          String.t(),
          options :: [
            sanitize: sanitize_options() | nil,
            escape: [atom()]
          ]
        ) :: String.t()
  def safe_html(unsafe_html, options \\ []) when is_binary(unsafe_html) and is_list(options) do
    sanitize =
      options
      |> opt([:sanitize], MDEx.default_sanitize_options())
      |> update_deprecated_sanitize_options()
      |> case do
        nil ->
          nil

        options ->
          options
          |> NimbleOptions.validate!(@sanitize_options_schema)
          |> adapt_sanitize_options()
      end

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
end
