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

  test "preserves escaped character children through MDEx conversion" do
    options = [parse: [escaped_char_spans: true], render: [escaped_char_spans: true]]

    native_document = MDExNative.Comrak.parse_document(~S(\*escaped\*), options)
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

    assert MDExNative.Comrak.document_to_commonmark(rebuilt, options) == "\\*escaped\\*\n"

    assert MDExNative.Comrak.document_to_html(rebuilt, options) ==
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

  # MDEx.DecodeError relies on this to name the field holding a value of the wrong type
  test "every mdex node renders with its default values" do
    for suffix <- @nodes -- [Sourcepos] do
      document = %MDEx.Document{nodes: [in_parent(struct(Module.concat(MDEx, suffix)))]}

      assert {:ok, _} = MDEx.to_html(document), "#{inspect(suffix)} does not render with its default values"
    end
  end

  # comrak panics rendering a table cell outside a table row
  defp in_parent(%MDEx.TableCell{} = cell), do: %MDEx.Table{nodes: [%MDEx.TableRow{nodes: [cell]}], alignments: [:none]}
  defp in_parent(node), do: node

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
