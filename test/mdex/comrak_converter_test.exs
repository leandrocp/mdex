defmodule MDEx.ComrakConverterTest do
  use ExUnit.Case

  @nodes [
    Sourcepos,
    FrontMatter,
    BlockQuote,
    List,
    ListItem,
    DescriptionList,
    DescriptionItem,
    DescriptionTerm,
    DescriptionDetails,
    CodeBlock,
    HtmlBlock,
    Paragraph,
    Heading,
    ThematicBreak,
    FootnoteDefinition,
    FootnoteReference,
    Table,
    TableRow,
    TableCell,
    Text,
    TaskItem,
    SoftBreak,
    LineBreak,
    Code,
    HtmlInline,
    Raw,
    Emph,
    Strong,
    Strikethrough,
    Highlight,
    Insert,
    Superscript,
    Link,
    Image,
    ShortCode,
    Math,
    MultilineBlockQuote,
    Escaped,
    WikiLink,
    Underline,
    Subscript,
    SpoileredText,
    Subtext,
    EscapedTag,
    Alert,
    Callout,
    CalloutTitle,
    CommentInline,
    MultilineComment,
    BlockDirective,
    HeexBlock,
    HeexInline
  ]

  test "native nodes have the same fields as mdex nodes" do
    for suffix <- @nodes do
      mdex_fields = fields(Module.concat(MDEx, suffix))
      native_fields = fields(Module.concat(MDExNative.Comrak, suffix))

      assert native_fields == mdex_fields, "field mismatch for #{inspect(suffix)}"
    end
  end

  test "native document keeps only Comrak AST fields" do
    assert fields(MDExNative.Comrak.Document) == [:nodes, :sourcepos]
    assert fields(MDExNative.Comrak.Document) -- fields(MDEx.Document) == []
  end

  test "Obsidian nodes survive parsing, JSON, native conversion, traversal, and rendering" do
    markdown = "> [!Custom|meta]- **Title**\n> A %%hidden%% ![[page|label]]\n\n%%\nblock comment\n%%\n"
    options = [extension: [ofm_callouts: true, ofm_comments: true, wikilinks_title_after_pipe: true]]
    document = MDEx.parse_document!(markdown, options)

    assert [%MDEx.Callout{callout_type: "custom", metadata: "meta", fold: :collapsed} = callout, %MDEx.MultilineComment{closed: true}] =
             document.nodes

    assert [%MDEx.CalloutTitle{} = title, %MDEx.Paragraph{}] = callout.nodes
    assert [%MDEx.CommentInline{literal: "hidden"}] = document[MDEx.CommentInline]
    assert [%MDEx.WikiLink{embed: true, url: "page"}] = document[MDEx.WikiLink]
    assert Enum.any?(callout, &match?(%MDEx.Text{literal: "Title"}, &1))
    assert Enum.any?(title, &match?(%MDEx.Strong{}, &1))
    assert MDEx.Document.fragment?(callout)
    assert MDEx.Document.fragment?(%MDEx.CommentInline{})
    assert Enum.to_list(%MDEx.CommentInline{literal: "hidden"}) == [%MDEx.CommentInline{literal: "hidden"}]

    native = MDEx.ComrakConverter.from_mdex(document)
    assert MDEx.ComrakConverter.to_mdex(native).nodes == document.nodes

    json = MDEx.to_json!(document)
    decoded = MDEx.parse_document!({:json, json}, options)
    assert decoded.nodes == document.nodes
    assert MDEx.to_xml!(decoded) =~ ~s(fold="collapsed")
    assert MDEx.to_xml!(decoded) =~ ~s(embed="true")
    assert MDEx.to_markdown!(decoded) =~ "![[page|label]]"
    assert to_string(callout) =~ "> [!custom|meta]- **Title**"

    html = MDEx.to_html!(markdown, options)
    assert html =~ ~s(data-callout-fold="collapsed")
    assert html =~ "<strong>Title</strong>"
    refute html =~ "hidden"
    refute html =~ "block comment"
    assert MDEx.to_html!(document) == html
    assert MDEx.to_html!(decoded) == html

    assert MDEx.to_html!("![[page]] [[page]]", extension: [wikilinks_title_after_pipe: true, wikilinks_ignore_embeds: true]) ==
             ~s(<p>![[page]] <a href="page" data-wikilink="true">page</a></p>)
  end

  # Takes well over a millisecond to parse even in a release build.
  @slow_markdown String.duplicate("a *b* [c](d) ", 50_000)

  test "limits reach every native parse; non-bang functions return the error" do
    limits = [limits: [parse_time: 1]]
    document = MDEx.new([markdown: @slow_markdown] ++ limits)

    for function <- [:parse_document, :to_html, :to_xml, :to_json, :to_delta, :to_slack] do
      assert {:error, %MDExNative.ParseTimeExceededError{parse_time: 1}} =
               apply(MDEx, function, [@slow_markdown, limits])

      assert_raise MDExNative.ParseTimeExceededError, fn ->
        apply(MDEx, :"#{function}!", [@slow_markdown, limits])
      end
    end

    for function <- [:to_html, :to_xml, :to_json, :to_delta, :to_slack, :to_markdown] do
      assert {:error, %MDExNative.ParseTimeExceededError{}} = apply(MDEx, function, [document])
    end

    assert {%MDEx.Document{halted: true}, %MDExNative.ParseTimeExceededError{}} = MDEx.Document.run(document)

    assert_raise MDExNative.ParseTimeExceededError, fn ->
      [@slow_markdown] |> MDEx.stream(limits) |> Enum.to_list()
    end
  end

  test "a parse time of zero, nil, or a generous limit leaves the output unchanged" do
    html = MDEx.to_html!(@slow_markdown)

    for parse_time <- [0, 60_000, nil] do
      assert MDEx.to_html!(@slow_markdown, limits: [parse_time: parse_time]) == html
    end
  end

  test "converts native document structs to mdex structs" do
    document = %MDExNative.Comrak.Document{
      nodes: [
        %MDExNative.Comrak.Heading{
          nodes: [%MDExNative.Comrak.Text{literal: "Hello"}],
          level: 1
        }
      ]
    }

    assert %MDEx.Document{nodes: [%MDEx.Heading{nodes: [%MDEx.Text{literal: "Hello"}]}]} =
             MDEx.ComrakConverter.to_mdex(document)
  end

  test "preserves escaped character children through MDEx conversion" do
    options = [parse: [escaped_char_spans: true], render: [escaped_char_spans: true]]

    native_document = MDExNative.Comrak.parse_document!(~S(\*escaped\*), options)
    mdex_document = MDEx.ComrakConverter.to_mdex(native_document)

    assert %MDEx.Document{
             nodes: [
               %MDEx.Paragraph{
                 nodes: [
                   %MDEx.Escaped{nodes: [%MDEx.Text{literal: "*"}]},
                   %MDEx.Text{literal: "escaped"},
                   %MDEx.Escaped{nodes: [%MDEx.Text{literal: "*"}]}
                 ]
               }
             ]
           } = mdex_document

    rebuilt = MDEx.ComrakConverter.from_mdex(mdex_document)

    assert MDExNative.Comrak.document_to_commonmark!(rebuilt, options) == "\\*escaped\\*\n"

    assert MDExNative.Comrak.document_to_html!(rebuilt, options) ==
             "<p><span data-escaped-char>*</span>escaped<span data-escaped-char>*</span></p>\n"
  end

  test "defaults missing attrs to nil" do
    native_code =
      %MDExNative.Comrak.Code{literal: "elixir"}
      |> Map.delete(:attrs)

    assert %MDEx.Code{literal: "elixir", attrs: nil} =
             MDEx.ComrakConverter.to_mdex(native_code)
  end

  test "rebuilds structs when source and target fields differ" do
    native_code =
      %MDExNative.Comrak.Code{literal: "elixir"}
      |> Map.delete(:attrs)
      |> Map.put(:future_field, true)

    assert %MDEx.Code{literal: "elixir", attrs: nil} =
             MDEx.ComrakConverter.to_mdex(native_code)
  end

  test "converts mdex document structs to native structs" do
    document = %MDEx.Document{
      nodes: [
        %MDEx.Paragraph{
          nodes: [%MDEx.Code{literal: "elixir"}]
        }
      ]
    }

    native_document = MDEx.ComrakConverter.from_mdex(document)

    assert %MDExNative.Comrak.Document{
             nodes: [
               %MDExNative.Comrak.Paragraph{nodes: [%MDExNative.Comrak.Code{literal: "elixir"}]}
             ]
           } = native_document

    assert native_document |> Map.from_struct() |> Map.keys() |> Enum.sort() == [
             :nodes,
             :sourcepos
           ]
  end

  test "raises on non-convertible structs" do
    assert_raise ArgumentError, "cannot convert URI", fn ->
      MDEx.ComrakConverter.to_mdex(%URI{path: "/"})
    end
  end

  test "round-trips every struct MDExNative.Comrak defines" do
    natives = native_structs()
    refute Enum.empty?(natives)

    for module <- natives do
      ["MDExNative", "Comrak", suffix] = Module.split(module)
      native = module.__struct__()
      mdex = MDEx.ComrakConverter.to_mdex(native)

      assert mdex.__struct__ == Module.concat(MDEx, suffix)
      assert MDEx.ComrakConverter.from_mdex(mdex) == native
    end
  end

  defp native_structs do
    for module <- Application.spec(:mdex_native, :modules),
        match?(["MDExNative", "Comrak", _suffix], Module.split(module)),
        Code.ensure_loaded?(module) and function_exported?(module, :__struct__, 0),
        do: module
  end

  defp fields(module) do
    module.__struct__()
    |> Map.from_struct()
    |> Map.keys()
    |> Enum.sort()
  end
end
