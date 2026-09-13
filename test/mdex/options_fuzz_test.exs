defmodule MDEx.OptionsFuzzTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import ExUnit.CaptureIO

  alias MDEx.ComrakConverter
  alias MDEx.Document
  alias MDExNative.Comrak, as: NativeComrak

  require MDEx

  @max_runs if System.get_env("CI"), do: 500, else: 100

  @extension_option_kinds %{
    alerts: :boolean,
    autolink: :boolean,
    block_directive: :boolean,
    cjk_friendly_emphasis: :boolean,
    description_lists: :boolean,
    fenced_code_attributes: :boolean,
    footnotes: :boolean,
    front_matter_delimiter: :front_matter_delimiter,
    greentext: :boolean,
    header_attributes: :boolean,
    header_id_prefix: :optional_string,
    header_id_prefix_in_href: :boolean,
    header_ids: :deprecated_header_ids,
    highlight: :boolean,
    image_url_rewriter: :url_rewriter,
    inline_code_attributes: :boolean,
    inline_footnotes: :boolean,
    insert: :boolean,
    link_attributes: :boolean,
    link_url_rewriter: :url_rewriter,
    math_code: :boolean,
    math_dollars: :boolean,
    math_latex: :boolean,
    multiline_block_quotes: :boolean,
    phoenix_heex: :boolean,
    shortcodes: :boolean,
    spoiler: :boolean,
    strikethrough: :boolean,
    subscript: :boolean,
    subtext: :boolean,
    superscript: :boolean,
    table: :boolean,
    tagfilter: :boolean,
    tasklist: :boolean,
    underline: :boolean,
    wikilinks_title_after_pipe: :boolean,
    wikilinks_title_before_pipe: :boolean
  }

  @parse_option_kinds %{
    default_info_string: :optional_string,
    escaped_char_spans: :boolean,
    ignore_setext: :boolean,
    leave_footnote_definitions: :boolean,
    relaxed_autolinks: :boolean,
    relaxed_tasklist_matching: :boolean,
    smart: :boolean,
    sourcepos_chars: :boolean,
    tasklist_in_table: :boolean
  }

  @render_option_kinds %{
    alert_style: {:member_of, [:specific, :semantic]},
    compact_html: :boolean,
    escape: :boolean,
    escaped_char_spans: :boolean,
    experimental_minimize_commonmark: :boolean,
    figure_with_caption: :boolean,
    full_info_string: :boolean,
    gfm_quirks: :boolean,
    github_pre_lang: :boolean,
    hardbreaks: :boolean,
    ignore_empty_links: :boolean,
    list_style: {:member_of, [:dash, :plus, :star]},
    ol_width: :non_negative_integer,
    prefer_fenced: :boolean,
    sourcepos: :boolean,
    tasklist_classes: :boolean,
    unsafe: :boolean,
    width: :non_negative_integer
  }

  @feature_rich_markdown ~S"""
  # Heading {#custom .wide data-kind=fuzz}

  Setext heading
  ==============

  [link](https://example.com/a?b=1&c=2 "title"){target=_blank} and
  ![image](https://example.com/image.png "alt"){width=10}

  https://example.com and <user@example.com>

  **strong** *emphasis* ~~strike~~ __underline__ ~subscript~ ^superscript^
  ==highlight== ++insert++ ||spoiler|| {-subtext-} :rocket:

  Inline math $x + y$ and `code`{.language-elixir key=value}.

  - [x] task
  - [ ] pending

  1. ordered
  2. list

  | column | value |
  | :----- | ----: |
  | row    | data  |

  An inline footnote ^[inline note] and a reference.[^note]

  [^note]: footnote definition

  Term
  : Description

  > [!NOTE]
  > alert

  >>>
  multiline block quote
  >>>

  > greentext or block quote

  ::: details
  block directive
  :::

  [[Page|Title]] and [[Title|Page]]

  <span data-kind="raw">raw HTML</span>

  ```elixir {.example key=value}
  IO.puts("hello")
  ```

  ```
  code without an info string
  ```
  """

  @heex_markdown ~S"""
  # Heading

  **strong** *emphasis* ~~strike~~ ~subscript~ ^superscript^

  [link](https://example.com) ![image](https://example.com/image.png)

  - [x] task

  | a | b |
  | - | - |
  | c | d |

  <span data-kind="raw">raw HTML</span>

      IO.puts("hello")
  """

  test "fuzz option definitions stay in parity with MDEx defaults" do
    assert MapSet.new(Map.keys(@extension_option_kinds)) ==
             MapSet.new(Keyword.keys(Document.default_extension_options()))

    assert MapSet.new(Map.keys(@parse_option_kinds)) ==
             MapSet.new(Keyword.keys(Document.default_parse_options()))

    assert MapSet.new(Map.keys(@render_option_kinds)) ==
             MapSet.new(Keyword.keys(Document.default_render_options()))
  end

  property "parsing stays in parity with mdex_native" do
    check all({markdown, options} <- fuzz_case(), property_options()) do
      native_nodes = NativeComrak.parse_document(markdown, native_options(options)).nodes

      mdex_nodes =
        markdown
        |> MDEx.parse_document!(options)
        |> ComrakConverter.from_mdex()
        |> Map.fetch!(:nodes)

      assert mdex_nodes == native_nodes
    end
  end

  property "HTML rendering has Markdown and Document input parity" do
    check all({markdown, options} <- fuzz_case(), property_options()) do
      expected = MDEx.to_html!(markdown, options)
      document = MDEx.parse_document!(markdown, options)

      assert html_tree(MDEx.to_html!(document)) == html_tree(expected)
    end
  end

  property "XML rendering has Markdown and Document input parity" do
    check all({markdown, options} <- fuzz_case(), property_options()) do
      expected = MDEx.to_xml!(markdown, options)
      document = MDEx.parse_document!(markdown, options)
      actual = MDEx.to_xml!(document)

      assert normalize_document_sourcepos(actual) == normalize_document_sourcepos(expected)
      assert actual =~ "<document"
      assert String.ends_with?(actual, "</document>") or String.ends_with?(actual, "/>")
    end
  end

  property "CommonMark rendering stays in parity with mdex_native" do
    check all({markdown, options} <- commonmark_fuzz_case(), property_options()) do
      native_options = native_options(options)

      expected =
        markdown
        |> NativeComrak.parse_document(native_options)
        |> NativeComrak.document_to_commonmark(native_options)
        |> String.trim()

      document = MDEx.parse_document!(markdown, options)

      assert MDEx.to_markdown!(document) == expected
    end
  end

  property "JSON rendering round-trips the parsed document" do
    check all({markdown, options} <- fuzz_case(), property_options()) do
      document = MDEx.parse_document!(markdown, options)
      json = MDEx.to_json!(markdown, options)

      assert MDEx.to_json!(document) == json
      assert %{"node_type" => "MDEx.Document", "nodes" => nodes} = Jason.decode!(json)
      assert is_list(nodes)

      assert MDEx.parse_document!({:json, json}, options).nodes == document.nodes
    end
  end

  property "Delta rendering has Markdown and Document input parity" do
    check all({markdown, options} <- fuzz_case(), property_options()) do
      document = MDEx.parse_document!(markdown, options)
      delta = MDEx.to_delta!(markdown, options)

      assert MDEx.to_delta!(document) == delta
      assert_valid_delta(delta)
    end
  end

  property "Slack rendering has Markdown and Document input parity" do
    check all({markdown, options} <- fuzz_case(), property_options()) do
      document = MDEx.parse_document!(markdown, options)
      slack = MDEx.to_slack!(markdown, options)

      assert MDEx.to_slack!(document) == slack
      assert String.valid?(slack)
    end
  end

  property "HEEx rendering has Markdown and Document input parity" do
    check all({markdown, options} <- heex_fuzz_case(), property_options()) do
      document = MDEx.parse_document!(markdown, heex_options(options))

      from_markdown = markdown |> MDEx.to_heex!(options) |> MDEx.to_html!()
      from_document = document |> MDEx.to_heex!() |> MDEx.to_html!()

      assert html_tree(from_document) == html_tree(from_markdown)
    end
  end

  property "deprecated header_ids matches header_id_prefix" do
    check all({markdown, options} <- fuzz_case(), prefix <- option_string(), property_options()) do
      extension = Keyword.fetch!(options, :extension)

      legacy_options =
        Keyword.put(
          options,
          :extension,
          extension
          |> Keyword.delete(:header_id_prefix)
          |> Keyword.put(:header_ids, prefix)
        )

      current_options =
        Keyword.put(
          options,
          :extension,
          extension
          |> Keyword.put(:header_ids, nil)
          |> Keyword.put(:header_id_prefix, prefix)
        )

      warning =
        capture_io(:stderr, fn ->
          assert html_tree(MDEx.to_html!(markdown, legacy_options)) ==
                   html_tree(MDEx.to_html!(markdown, current_options))
        end)

      assert warning =~ "extension :header_ids is deprecated"
    end
  end

  defp fuzz_case do
    gen all(options <- options(), suffix <- string(:utf8, max_length: 128), rich? <- boolean()) do
      markdown = if rich?, do: feature_rich_markdown(options, suffix), else: suffix
      {markdown, options}
    end
  end

  defp heex_fuzz_case do
    gen all(options <- options(), suffix <- string(:alphanumeric, max_length: 128)) do
      {heex_markdown(options, suffix), options}
    end
  end

  defp commonmark_fuzz_case do
    gen all(options <- options(), suffix <- string(:alphanumeric, max_length: 128)) do
      {feature_rich_markdown(options, suffix), options}
    end
  end

  defp feature_rich_markdown(options, suffix) do
    delimiter = get_in(options, [:extension, :front_matter_delimiter])
    front_matter = if delimiter, do: "#{delimiter}\ntitle: Fuzz\n#{delimiter}\n\n", else: ""

    front_matter <> @feature_rich_markdown <> "\n" <> suffix
  end

  defp heex_markdown(options, suffix) do
    delimiter = get_in(options, [:extension, :front_matter_delimiter])
    front_matter = if delimiter, do: "#{delimiter}\ntitle: Fuzz\n#{delimiter}\n\n", else: ""

    front_matter <> @heex_markdown <> "\n" <> suffix
  end

  defp options do
    fixed_map(%{
      extension: option_group(@extension_option_kinds),
      parse: option_group(@parse_option_kinds),
      render: option_group(@render_option_kinds)
    })
    |> map(&Map.to_list/1)
  end

  defp option_group(kinds) do
    kinds
    |> Map.new(fn {name, kind} -> {name, option_value(kind)} end)
    |> fixed_map()
    |> map(&Map.to_list/1)
  end

  defp option_value(:boolean), do: boolean()
  defp option_value(:deprecated_header_ids), do: constant(nil)
  defp option_value(:optional_string), do: one_of([constant(nil), option_string()])
  defp option_value(:front_matter_delimiter), do: member_of([nil, "---", "+++", ";;;"])

  defp option_value(:url_rewriter) do
    member_of([nil, "https://proxy.test/?url={@url}", "/proxy/{@url}"])
  end

  defp option_value(:non_negative_integer) do
    frequency([{8, integer(0..100)}, {1, member_of([255, 1_024])}])
  end

  defp option_value({:member_of, values}), do: member_of(values)

  defp option_string, do: string(:alphanumeric, max_length: 24)

  defp property_options do
    [max_runs: @max_runs, max_generation_size: 30]
  end

  defp native_options(options), do: Document.rust_options!(options)

  defp heex_options(options) do
    options
    |> Keyword.update!(:extension, &Keyword.put(&1, :phoenix_heex, true))
    |> Keyword.update!(:render, &Keyword.put(&1, :unsafe, true))
  end

  defp normalize_document_sourcepos(xml) do
    String.replace(xml, ~r/<document sourcepos="[^"]*"/, "<document")
  end

  defp html_tree(html) do
    html
    |> Floki.parse_fragment!()
    |> normalize_html_tree()
  end

  defp normalize_html_tree(nodes) when is_list(nodes), do: Enum.map(nodes, &normalize_html_tree/1)

  defp normalize_html_tree({tag, attributes, children}) do
    {tag, Enum.sort(attributes), normalize_html_tree(children)}
  end

  defp normalize_html_tree(node), do: node

  defp assert_valid_delta(delta) do
    assert is_list(delta)

    Enum.each(delta, fn operation ->
      assert %{"insert" => insert} = operation
      assert is_binary(insert) or is_map(insert)

      if attributes = operation["attributes"] do
        assert is_map(attributes)
      end
    end)
  end
end
