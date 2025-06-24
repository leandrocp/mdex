defmodule MDEx do
  @external_resource "README.md"

  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC -->")
             |> Enum.fetch!(1)

  alias MDEx.Native
  alias MDEx.Document
  alias MDEx.Pipe
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
  @type source :: markdown :: String.t() | Document.t() | Pipe.t()

  @built_in_options [
    :document,
    :extension,
    :parse,
    :render,
    :syntax_highlight,
    :sanitize
  ]

  @doc false
  def built_in_options, do: @built_in_options

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

  @features_options_schema [
    sanitize: [
      type: {:or, [:keyword_list, nil]},
      deprecated: "Use :sanitize (in :options) instead."
    ],
    syntax_highlight_theme: [
      type: {:or, [:string, nil]},
      deprecated: "Use :syntax_highlight (in :options) instead."
    ],
    syntax_highlight_inline_style: [
      type: :boolean,
      deprecated: "Use :syntax_highlight (in :options) instead."
    ]
  ]

  @options_schema [
    document: [
      type: {:or, [:string, {:struct, MDEx.Document}, nil]},
      type_spec: quote(do: markdown :: String.t() | Document.t()),
      default: "",
      doc: "Markdown document, either a string or a `MDEx.Document` struct."
    ],
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
      type_spec: quote(do: syntax_highlight_options()),
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

          [sanitize: MDEx.default_sanitize_options()]

      Or customize one of the options. For example, to disallow `<a>` tags:

          [sanitize: [rm_tags: ["a"]]]

      In the example above it will append `rm_tags: ["a"]` into the default set of options, essentially the same as:

          sanitize = Keyword.put(MDEx.default_sanitize_options(), :rm_tags, ["a"])
          [sanitize: sanitize]

      See the [Safety](#module-safety) section for more info.
      """
    ],
    features: [
      type: :keyword_list,
      deprecated: "Use :syntax_highlight or :sanitize instead.",
      keys: @features_options_schema
    ]
  ]

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

  @typedoc "List of [comrak extension options](https://docs.rs/comrak/latest/comrak/struct.ExtensionOptions.html)."
  @type extension_options() :: [unquote(NimbleOptions.option_typespec(@extension_options_schema))]

  @typedoc "List of [comrak parse options](https://docs.rs/comrak/latest/comrak/struct.ParseOptions.html)."
  @type parse_options() :: [unquote(NimbleOptions.option_typespec(@parse_options_schema))]

  @typedoc "List of [comrak render options](https://docs.rs/comrak/latest/comrak/struct.RenderOptions.html)."
  @type render_options() :: [unquote(NimbleOptions.option_typespec(@render_options_schema))]

  @typedoc "Syntax Highlight code blocks using [autumn](https://hexdocs.pm/autumn)."
  @type syntax_highlight_options() :: [unquote(NimbleOptions.option_typespec(@syntax_highlight_options_schema))]

  @typedoc "List of [ammonia options](https://docs.rs/ammonia/latest/ammonia/struct.Builder.html)."
  @type sanitize_options() :: [unquote(NimbleOptions.option_typespec(@sanitize_options_schema))]

  @doc """
  Returns the default options for the `:extension` group.
  """
  @spec default_extension_options() :: extension_options()
  def default_extension_options, do: NimbleOptions.validate!([], @extension_options_schema)

  @doc """
  Returns the default options for the `:parse` group.
  """
  @spec default_parse_options() :: parse_options()
  def default_parse_options, do: NimbleOptions.validate!([], @parse_options_schema)

  @doc """
  Returns the default options for the `:render` group.
  """
  @spec default_render_options() :: render_options()
  def default_render_options, do: NimbleOptions.validate!([], @render_options_schema)

  @doc """
  Returns the default options for the `:syntax_highlight` group.
  """
  @spec default_syntax_highlight_options() :: syntax_highlight_options()
  def default_syntax_highlight_options, do: NimbleOptions.validate!([], @syntax_highlight_options_schema)

  @doc """
  Returns the default options for the `:sanitize` group.
  """
  @spec default_sanitize_options() :: sanitize_options()
  def default_sanitize_options, do: NimbleOptions.validate!([], @sanitize_options_schema)

  @doc false
  def extension_options_schema, do: @extension_options_schema

  @doc false
  def render_options_schema, do: @render_options_schema

  @doc false
  def parse_options_schema, do: @parse_options_schema

  @doc false
  def syntax_highlight_options_schema, do: @syntax_highlight_options_schema

  @doc false
  def sanitize_options_schema, do: @sanitize_options_schema

  @doc false
  def options_schema, do: @options_schema

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
  @spec parse_document(markdown :: String.t() | {:json, String.t()}, options()) :: {:ok, Document.t()} | {:error, any()}
  # TODO: support :xml
  def parse_document(source, options \\ [])

  def parse_document(markdown, options) when is_binary(markdown) do
    Native.parse_document(markdown, validate_options!(options))
  end

  def parse_document({:json, json}, _options) when is_binary(json) do
    case Jason.decode(json, keys: :atoms!) do
      {:ok, decoded} ->
        {:ok, json_to_node(decoded)}

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
  @spec parse_document!(markdown :: String.t() | {:json, String.t()}, options()) :: Document.t()
  def parse_document!(source, options \\ [])

  def parse_document!(markdown, options) when is_binary(markdown) do
    case parse_document(markdown, options) do
      {:ok, document} -> document
      {:error, error} -> raise error
    end
  end

  def parse_document!({format, source}, options) when format in [:json, :xml] and is_binary(source) do
    case parse_document({format, source}, options) do
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
  Convert Markdown, `MDEx.Document`, or `MDEx.Pipe` to HTML.

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
  @spec to_html(source(), options()) ::
          {:ok, String.t()}
          | {:error, MDEx.DecodeError.t()}
          | {:error, MDEx.InvalidInputError.t()}
  def to_html(source, options \\ [])

  def to_html(source, options) when is_binary(source) and is_list(options) do
    source
    |> Native.markdown_to_html_with_options(validate_options!(options))
    |> maybe_trim()
  end

  def to_html(%Pipe{} = pipe, options) when is_list(options) do
    pipe
    |> Pipe.put_options(options)
    |> Pipe.run()
    |> then(&to_html(&1.document, &1.options))
  end

  def to_html(%Document{} = document, options) when is_list(options) do
    document
    |> Native.document_to_html_with_options(validate_options!(options))
    |> maybe_trim()
  rescue
    ErlangError ->
      {:error, %DecodeError{document: document}}
  end

  def to_html(source, options) do
    if is_fragment(source) do
      to_html(%Document{nodes: List.wrap(source)}, options)
    else
      {:error, %InvalidInputError{found: source}}
    end
  end

  @doc """
  Same as `to_html/2` but raises error if the conversion fails.
  """
  @spec to_html!(source(), options()) :: String.t()
  def to_html!(source, options \\ []) do
    case to_html(source, options) do
      {:ok, html} -> html
      {:error, error} -> raise error
    end
  end

  @doc """
  Convert Markdown, `MDEx.Document`, or `MDEx.Pipe` to XML.

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
  @spec to_xml(source(), options()) ::
          {:ok, String.t()}
          | {:error, MDEx.DecodeError.t()}
          | {:error, MDEx.InvalidInputError.t()}
  def to_xml(source, options \\ [])

  def to_xml(source, options) when is_binary(source) and is_list(options) do
    source
    |> Native.markdown_to_xml_with_options(validate_options!(options))
    |> maybe_trim()
  end

  def to_xml(%Pipe{} = pipe, options) when is_list(options) do
    pipe
    |> Pipe.put_options(options)
    |> Pipe.run()
    |> then(&to_xml(&1.document, &1.options))
  end

  def to_xml(%Document{} = document, options) when is_list(options) do
    document
    |> Native.document_to_xml_with_options(validate_options!(options))
    |> maybe_trim()
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
  @spec to_xml!(source(), options()) :: String.t()
  def to_xml!(source, options \\ []) do
    case to_xml(source, options) do
      {:ok, xml} -> xml
      {:error, error} -> raise error
    end
  end

  @doc """
  Convert Markdown, `MDEx.Document`, or `MDEx.Pipe` to JSON using default options.

  Use `to_json/2` to pass custom options.

  ## Examples

      iex> MDEx.to_json("# Hello")
      {:ok, ~s|{"nodes":[{"nodes":[{"literal":"Hello","node_type":"MDEx.Text"}],"level":1,"setext":false,"node_type":"MDEx.Heading"}],"node_type":"MDEx.Document"}|}

      iex> MDEx.to_json("1. First\\n2. Second")
      {:ok, ~s|{"nodes":[{"start":1,"nodes":[{"start":1,"nodes":[{"nodes":[{"literal":"First","node_type":"MDEx.Text"}],"node_type":"MDEx.Paragraph"}],"delimiter":"period","padding":3,"list_type":"ordered","marker_offset":0,"bullet_char":"","tight":false,"is_task_list":false,"node_type":"MDEx.ListItem"},{"start":2,"nodes":[{"nodes":[{"literal":"Second","node_type":"MDEx.Text"}],"node_type":"MDEx.Paragraph"}],"delimiter":"period","padding":3,"list_type":"ordered","marker_offset":0,"bullet_char":"","tight":false,"is_task_list":false,"node_type":"MDEx.ListItem"}],"delimiter":"period","padding":3,"list_type":"ordered","marker_offset":0,"bullet_char":"","tight":true,"is_task_list":false,"node_type":"MDEx.List"}],"node_type":"MDEx.Document"}|}

      iex> MDEx.to_json(%MDEx.Document{nodes: [%MDEx.Heading{nodes: [%MDEx.Text{literal: "Hello"}], level: 3, setext: false}]})
      {:ok, ~s|{"nodes":[{"nodes":[{"literal":"Hello","node_type":"MDEx.Text"}],"level":3,"setext":false,"node_type":"MDEx.Heading"}],"node_type":"MDEx.Document"}|}

  Fragments of a document are also supported:

      iex> MDEx.to_json(%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Hello"}]})
      {:ok, ~s|{"nodes":[{"nodes":[{"literal":"Hello","node_type":"MDEx.Text"}],"node_type":"MDEx.Paragraph"}],"node_type":"MDEx.Document"}|}

  """
  @spec to_json(source()) ::
          {:ok, String.t()}
          | {:error, MDEx.DecodeError.t()}
          | {:error, MDEx.InvalidInputError.t()}
  def to_json(source)

  def to_json(source) when is_binary(source) do
    with {:ok, document} <- parse_document(source),
         {:ok, json} <- to_json(document) do
      {:ok, json}
    end
  end

  def to_json(%Pipe{} = pipe) do
    pipe
    |> Pipe.run()
    |> then(&to_json(&1.document, &1.options))
  end

  def to_json(%Document{} = document) do
    case Jason.encode(document) do
      {:ok, json} -> {:ok, json}
      {:error, error} -> {:error, %DecodeError{document: document, error: error}}
    end
  end

  def to_json(source) do
    if is_fragment(source) do
      to_json(%Document{nodes: List.wrap(source)})
    else
      {:error, %InvalidInputError{found: source}}
    end
  end

  @doc """
  Same as `to_json/1` but raises an error if the conversion fails.
  """
  @spec to_json!(source()) :: String.t()
  def to_json!(source) do
    case to_json(source) do
      {:ok, json} -> json
      {:error, error} -> raise error
    end
  end

  @doc """
  Convert Markdown, `MDEx.Document`, or `MDEx.Pipe` to JSON using custom options.

  ## Examples

      iex> MDEx.to_json("Hello ~world~", extension: [strikethrough: true])
      {:ok, ~s|{"nodes":[{"nodes":[{"literal":"Hello ","node_type":"MDEx.Text"},{"nodes":[{"literal":"world","node_type":"MDEx.Text"}],"node_type":"MDEx.Strikethrough"}],"node_type":"MDEx.Paragraph"}],"node_type":"MDEx.Document"}|}

  """
  @spec to_json(source(), options()) ::
          {:ok, String.t()}
          | {:error, MDEx.DecodeError.t()}
          | {:error, MDEx.InvalidInputError.t()}
  def to_json(source, options)

  def to_json(source, options) when is_binary(source) and is_list(options) do
    with {:ok, document} <- parse_document(source, options),
         {:ok, json} <- to_json(document, options) do
      {:ok, json}
    end
  end

  def to_json(%Pipe{} = pipe, options) when is_list(options) do
    pipe
    |> Pipe.put_options(options)
    |> Pipe.run()
    |> then(&to_json(&1.document, &1.options))
  end

  def to_json(%Document{} = document, options) when is_list(options) do
    case Jason.encode(document) do
      {:ok, json} -> {:ok, json}
      {:error, error} -> {:error, %DecodeError{document: document, error: error}}
    end
  end

  def to_json(source, options) do
    if is_fragment(source) do
      to_json(%Document{nodes: List.wrap(source)}, options)
    else
      {:error, %InvalidInputError{found: source}}
    end
  end

  @doc """
  Same as `to_json/2` but raises error if the conversion fails.
  """
  @spec to_json!(source(), options()) :: String.t()
  def to_json!(source, options) do
    case to_json(source, options) do
      {:ok, json} -> json
      {:error, error} -> raise error
    end
  end

  @doc """
  Convert `MDEx.Document` or `MDEx.Pipe` to Markdown using default options.

  Use `to_markdown/2` to pass custom options.

  ## Example

      iex> MDEx.to_markdown(%MDEx.Document{nodes: [%MDEx.Heading{nodes: [%MDEx.Text{literal: "Hello"}], level: 3, setext: false}]})
      {:ok, "### Hello"}

  """
  @spec to_markdown(Document.t() | Pipe.t()) :: {:ok, String.t()} | {:error, MDEx.DecodeError.t()}
  def to_markdown(source)

  def to_markdown(%Pipe{} = pipe) do
    pipe
    |> Pipe.run()
    |> then(&to_markdown(&1.document, &1.options))
  end

  def to_markdown(%Document{} = document) do
    document
    |> Native.document_to_commonmark()
    # |> maybe_wrap_error()
    |> maybe_trim()
  end

  @doc """
  Same as `to_markdown/1` but raises `MDEx.DecodeError` if the conversion fails.
  """
  @spec to_markdown!(Document.t()) :: String.t()
  def to_markdown!(%Document{} = document) do
    case to_markdown(document) do
      {:ok, md} -> md
      {:error, error} -> raise error
    end
  end

  @doc """
  Convert `MDEx.Document` or `MDEx.Pipe` to Markdown using custom options.
  """
  @spec to_markdown(Document.t() | Pipe.t(), options()) :: {:ok, String.t()} | {:error, MDEx.DecodeError.t()}
  def to_markdown(source, options)

  def to_markdown(%Pipe{} = pipe, options) when is_list(options) do
    pipe
    |> Pipe.put_options(options)
    |> Pipe.run()
    |> then(&to_markdown(&1.document, &1.options))
  end

  def to_markdown(%Document{} = document, options) when is_list(options) do
    document
    |> Native.document_to_commonmark_with_options(validate_options!(options))
    # |> maybe_wrap_error()
    |> maybe_trim()
  end

  @doc """
  Same as `to_markdown/2` but raises `MDEx.DecodeError` if the conversion fails.
  """
  @spec to_markdown!(Document.t(), options()) :: String.t()
  def to_markdown!(%Document{} = document, options) when is_list(options) do
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
  @spec traverse_and_update(MDEx.Document.t(), (MDEx.Document.md_node() -> MDEx.Document.md_node())) :: MDEx.Document.t()
  def traverse_and_update(ast, fun), do: MDEx.Document.Traversal.traverse_and_update(ast, fun)

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
  @spec traverse_and_update(MDEx.Document.t(), any(), (MDEx.Document.md_node() -> MDEx.Document.md_node())) :: MDEx.Document.t()
  def traverse_and_update(ast, acc, fun), do: MDEx.Document.Traversal.traverse_and_update(ast, acc, fun)

  @doc false
  def validate_options!(options) do
    sanitize_opts = update_deprecated_sanitize_options(get_in(options, [:features, :sanitize]) || get_in(options, [:sanitize]))
    deprecated_theme_opt = options[:features][:syntax_highlight_theme]
    deprecated_inline_style_opt = options[:features][:syntax_highlight_inline_style]

    options =
      options
      |> Keyword.put(:sanitize, sanitize_opts)
      |> Keyword.take(@built_in_options)
      |> NimbleOptions.validate!(@options_schema)
      |> update_in([:sanitize], &adapt_sanitize_options/1)
      |> update_in([:render], fn render ->
        {unsafe, render} = Keyword.pop(render, :unsafe, false)
        Keyword.put(render, :unsafe_, unsafe)
      end)

    syntax_highlight =
      case options[:syntax_highlight] do
        nil ->
          nil

        opts ->
          {formatter, formatter_opts} = options[:syntax_highlight][:formatter]
          theme = Autumn.build_theme(deprecated_theme_opt || formatter_opts[:theme])

          formatter =
            case deprecated_inline_style_opt do
              true -> :html_inline
              false -> :html_linked
              nil -> formatter
            end

          opts
          |> Map.new()
          |> Map.put(:formatter, {formatter, Map.put(formatter_opts, :theme, theme)})
      end

    %{
      extension: Map.new(options[:extension]),
      parse: Map.new(options[:parse]),
      render: Map.new(options[:render]),
      syntax_highlight: syntax_highlight,
      sanitize: options[:sanitize]
    }
  end

  defp update_deprecated_sanitize_options(true = _options) do
    Logger.warning("""
    sanitize: true is deprecated. Pass :sanitize options instead, for example:

      sanitize: MDEx.default_sanitize_options()

    MDEx.default_sanitize_options() is the same behavior as the deprecated sanitize: true

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

      iex> MDEx.safe_html("<custom_tag>Hello</custom_tag>")
      "Hello"

      iex> MDEx.safe_html("<custom_tag>Hello</custom_tag>", sanitize: [add_tags: ["custom_tag"]], escape: [content: false])
      "<custom_tag>Hello</custom_tag>"

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

  @doc """
  Builds a new `MDEx.Pipe` instance.

  Once the pipe is complete, call either one of the following functions to format the document:

  - `MDEx.to_html/2`
  - `MDEx.to_json/1`
  - `MDEx.to_xml/2`
  - `MDEx.to_markdown/1`

  ## Examples

  * Build a pipe with `:document`:

        iex> mdex = MDEx.new(document: "# Hello")
        iex> MDEx.to_html(mdex)
        {:ok, "<h1>Hello</h1>"}

        iex> mdex = MDEx.new(document: "Hello ~world~", extension: [strikethrough: true])
        iex> MDEx.to_json(mdex)
        {:ok, ~s|{"nodes":[{"nodes":[{"literal":"Hello ","node_type":"MDEx.Text"},{"nodes":[{"literal":"world","node_type":"MDEx.Text"}],"node_type":"MDEx.Strikethrough"}],"node_type":"MDEx.Paragraph"}],"node_type":"MDEx.Document"}|}

  * Pass a `:document` when formatting:

        iex> mdex = MDEx.new(extension: [strikethrough: true])
        iex> MDEx.to_xml(mdex, document: "Hello ~world~")
        {:ok, ~s|<?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE document SYSTEM "CommonMark.dtd">
        <document xmlns="http://commonmark.org/xml/1.0">
          <paragraph>
            <text xml:space="preserve">Hello </text>
            <strikethrough>
              <text xml:space="preserve">world</text>
            </strikethrough>
          </paragraph>
        </document>|}

  ## Notes

  1. Source `:document` is automatically [parsed](https://hexdocs.pm/mdex/MDEx.html#parse_document!/2)
  into `MDEx.Document` before the pipeline runs so every step receives the same data type.

  2. You can pass the document when creating the pipe:

  ```elixir
  MDEx.new(document: "# Hello") |> MDEx.to_html()
  ```

  Or pass it only when formatting the document,
  useful to reuse the same pipe with different documents and formats.

  ```elixir
  mdex = MDEx.new()
  # ... attach plugins and steps

  MDEx.to_html(mdex, document: "# Hello HTML")
  MDEx.to_json(mdex, document: "# Hello JSON")
  ```
  """
  @spec new(options()) :: MDEx.Pipe.t()
  def new(options \\ []) do
    %Pipe{}
    |> Pipe.register_options([
      :document,
      :extension,
      :parse,
      :render,
      :syntax_highlight,
      :sanitize
    ])
    |> Pipe.put_options(options)
  end

  @doc """
  Converts a given `text` string to a format that can be used as an "anchor", such as in a Table of Contents.

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
end
