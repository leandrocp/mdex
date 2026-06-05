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

  test "converts mdex document structs to native structs" do
    document = %MDEx.Document{
      nodes: [
        %MDEx.Paragraph{
          nodes: [%MDEx.Code{literal: "elixir"}]
        }
      ]
    }

    assert %MDExNative.Comrak.Document{
             nodes: [%MDExNative.Comrak.Paragraph{nodes: [%MDExNative.Comrak.Code{literal: "elixir"}]}]
           } = MDEx.ComrakConverter.from_mdex(document)
  end

  test "raises on non-convertible structs" do
    assert_raise ArgumentError, "cannot convert URI", fn ->
      MDEx.ComrakConverter.to_mdex(%URI{path: "/"})
    end
  end

  defp fields(module) do
    module.__struct__()
    |> Map.from_struct()
    |> Map.keys()
    |> Enum.sort()
  end
end
