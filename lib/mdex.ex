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

  @doc """
  Parse a `markdown` string and returns a `MDEx.Document`.

  ## Options

  See the [Options](#module-options) section for the available `opts`.

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
  @spec parse_document(String.t(), keyword()) :: {:ok, Document.t()} | {:error, term()}
  def parse_document(markdown, opts \\ []) when is_binary(markdown) do
    Native.parse_document(markdown, comrak_options(opts))
  end

  @doc """
  Same as `parse_document/2` but raises if the parsing fails.
  """
  @spec parse_document!(String.t(), keyword()) :: Document.t()
  def parse_document!(markdown, opts \\ []) when is_binary(markdown) do
    case parse_document(markdown, opts) do
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

  Consider this function experimental and subject to change.

  ## Examples

      iex> MDEx.parse_fragment("# MDEx")
      {:ok, %MDEx.Heading{nodes: [%MDEx.Text{literal: "MDEx"}], level: 1, setext: false}}

  """
  @spec parse_fragment(String.t(), keyword()) :: {:ok, Document.md_node()} | nil
  def parse_fragment(markdown, opts \\ []) when is_binary(markdown) do
    case parse_document(markdown, opts) do
      {:ok, %Document{nodes: [%MDEx.Paragraph{nodes: [node]}]}} -> {:ok, node}
      {:ok, %Document{nodes: [node]}} -> {:ok, node}
      _ -> nil
    end
  end

  @doc """
  Same as `parse_fragment/2` but raises if the parsing fails.
  """
  def parse_fragment!(markdown, opts \\ []) when is_binary(markdown) do
    case parse_fragment(markdown, opts) do
      {:ok, fragment} -> fragment
      {:error, error} -> raise error
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
  @spec to_html(md_or_doc :: String.t() | Document.t()) ::
          {:ok, String.t()}
          | {:error, MDEx.DecodeError.t()}
          | {:error, MDEx.InvalidInputError.t()}
  def to_html(md_or_doc)

  def to_html(md_or_doc) when is_binary(md_or_doc) do
    md_or_doc
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

  def to_html(fragment) when is_fragment(fragment) do
    to_html(%Document{nodes: [fragment]})
  end

  def to_html(md_or_doc) do
    {:error, %InvalidInputError{found: md_or_doc}}
  end

  @doc """
  Same as `to_html/1` but raises an error if the conversion fails.
  """
  @spec to_html!(md_or_doc :: String.t() | Document.t()) :: String.t()
  def to_html!(md_or_doc) do
    case to_html(md_or_doc) do
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
  @spec to_html(md_or_doc :: String.t() | Document.t(), opts :: keyword()) ::
          {:ok, String.t()}
          | {:error, MDEx.DecodeError.t()}
          | {:error, MDEx.InvalidInputError.t()}
  def to_html(md_or_doc, opts)

  def to_html(md_or_doc, opts) when is_binary(md_or_doc) and is_list(opts) do
    md_or_doc
    |> Native.markdown_to_html_with_options(comrak_options(opts))
    # |> maybe_wrap_error()
    |> maybe_trim()
  end

  def to_html(%Document{} = doc, opts) when is_list(opts) do
    doc
    |> Native.document_to_html_with_options(comrak_options(opts))
    |> maybe_trim()
  rescue
    ErlangError ->
      {:error, %DecodeError{document: doc}}
  end

  def to_html(fragment, opts) when is_fragment(fragment) and is_list(opts) do
    to_html(%Document{nodes: [fragment]}, opts)
  end

  def to_html(md_or_doc, _opts) do
    {:error, %InvalidInputError{found: md_or_doc}}
  end

  @doc """
  Same as `to_html/2` but raises error if the conversion fails.
  """
  @spec to_html!(md_or_doc :: String.t() | Document.t(), opts :: keyword()) :: String.t()
  def to_html!(md_or_doc, opts) do
    case to_html(md_or_doc, opts) do
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
  @spec to_xml(md_or_doc :: String.t() | Document.t()) ::
          {:ok, String.t()}
          | {:error, MDEx.DecodeError.t()}
          | {:error, MDEx.InvalidInputError.t()}
  def to_xml(md_or_doc)

  def to_xml(md_or_doc) when is_binary(md_or_doc) do
    md_or_doc
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

  def to_xml(fragment) when is_fragment(fragment) do
    to_xml(%Document{nodes: [fragment]})
  end

  def to_xml(md_or_doc) do
    {:error, %InvalidInputError{found: md_or_doc}}
  end

  @doc """
  Same as `to_xml/1` but raises an error if the conversion fails.
  """
  @spec to_xml!(md_or_doc :: String.t() | Document.t()) :: String.t()
  def to_xml!(md_or_doc) do
    case to_xml(md_or_doc) do
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
  @spec to_xml(md_or_doc :: String.t() | Document.t(), opts :: keyword()) ::
          {:ok, String.t()}
          | {:error, MDEx.DecodeError.t()}
          | {:error, MDEx.InvalidInputError.t()}
  def to_xml(md_or_doc, opts)

  def to_xml(md_or_doc, opts) when is_binary(md_or_doc) and is_list(opts) do
    md_or_doc
    |> Native.markdown_to_xml_with_options(comrak_options(opts))

    # |> maybe_wrap_error()
    # |> maybe_trim()
  end

  def to_xml(%Document{} = doc, opts) when is_list(opts) do
    doc
    |> Native.document_to_xml_with_options(comrak_options(opts))
    |> maybe_trim()
  rescue
    ErlangError ->
      {:error, %DecodeError{document: doc}}
  end

  def to_xml(fragment, opts) when is_fragment(fragment) and is_list(opts) do
    to_xml(%Document{nodes: [fragment]}, opts)
  end

  def to_xml(md_or_doc, _opts) do
    {:error, %InvalidInputError{found: md_or_doc}}
  end

  @doc """
  Same as `to_xml/2` but raises error if the conversion fails.
  """
  @spec to_xml!(md_or_doc :: String.t() | Document.t(), opts :: keyword()) :: String.t()
  def to_xml!(md_or_doc, opts) do
    case to_xml(md_or_doc, opts) do
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
  @spec to_commonmark(Document.t(), keyword()) :: {:ok, String.t()} | {:error, MDEx.DecodeError.t()}
  def to_commonmark(%Document{} = doc, opts) when is_list(opts) do
    doc
    |> Native.document_to_commonmark_with_options(comrak_options(opts))
    # |> maybe_wrap_error()
    |> maybe_trim()
  end

  @doc """
  Same as `to_commonmark/2` but raises `MDEx.DecodeError` if the conversion fails.
  """
  @spec to_commonmark!(Document.t(), keyword()) :: String.t()
  def to_commonmark!(%Document{} = doc, opts) when is_list(opts) do
    case to_commonmark(doc, opts) do
      {:ok, md} -> md
      {:error, error} -> raise error
    end
  end

  defp comrak_options(opts) do
    extension = Keyword.get(opts, :extension, %{})
    parse = Keyword.get(opts, :parse, %{})
    render = Keyword.get(opts, :render, %{})
    features = Keyword.get(opts, :features, %{})

    %MDEx.Types.Options{
      extension: struct(MDEx.Types.ExtensionOptions, extension),
      parse: struct(MDEx.Types.ParseOptions, parse),
      render: struct(MDEx.Types.RenderOptions, render),
      features: struct(MDEx.Types.FeaturesOptions, features)
    }
  end

  # def maybe_wrap_document([{"document", _, _} | _] = tree), do: tree

  # def maybe_wrap_document(fragment) do
  #   [{"document", %{}, List.wrap(fragment)}]
  # end

  # defp maybe_wrap_error({:ok, result}), do: {:ok, result}

  # defp maybe_wrap_error({:error, {reason, found}}),
  #   do: {:error, %MDEx.DecodeError{reason: reason, found: found}}

  # defp maybe_wrap_error({:error, {reason, found, node}}),
  #   do: {:error, %MDEx.DecodeError{reason: reason, found: found, node: node}}

  # defp maybe_wrap_error({:error, {reason, found, node, kind}}),
  #   do: {:error, %MDEx.DecodeError{reason: reason, found: found, node: node, kind: kind}}

  # defp maybe_wrap_error({:error, {reason, found, node, attr, kind}}),
  #   do: {:error, %MDEx.DecodeError{reason: reason, found: found, node: node, attr: attr, kind: kind}}

  defp maybe_trim({:ok, result}), do: {:ok, String.trim(result)}
  defp maybe_trim(error), do: error
end
