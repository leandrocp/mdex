defmodule MDEx.JsonFormatTest do
  use ExUnit.Case

  @extension [
    strikethrough: true,
    tagfilter: true,
    table: true,
    autolink: true,
    tasklist: true,
    superscript: true,
    footnotes: true,
    description_lists: true,
    front_matter_delimiter: "---",
    multiline_block_quotes: true,
    math_dollars: true,
    math_code: true,
    shortcodes: true,
    underline: true,
    spoiler: true,
    greentext: true,
    insert: true
  ]

  def to_json(document, extension \\ []) do
    opts = [
      extension: Keyword.merge(@extension, extension),
      render: [unsafe: true]
    ]

    assert {:ok, json} = MDEx.to_json(document, opts)
    Jason.decode!(json, keys: :atoms!)
  end

  test "empty doc" do
    assert %{node_type: "MDEx.Document", nodes: []} = to_json("")
  end

  test "heading" do
    assert %{
             node_type: "MDEx.Document",
             nodes: [%{node_type: "MDEx.Heading", nodes: [%{node_type: "MDEx.Text", literal: "Title"}], level: 1, setext: false}]
           } = to_json("# Title")
  end

  test "insert" do
    assert %{
             node_type: "MDEx.Document",
             nodes: [
               %{
                 node_type: "MDEx.Paragraph",
                 nodes: [
                   %{node_type: "MDEx.Text", literal: "this is "},
                   %{node_type: "MDEx.Insert", nodes: [%{node_type: "MDEx.Text", literal: "inserted"}]},
                   %{node_type: "MDEx.Text", literal: " text"}
                 ]
               }
             ]
           } = to_json("this is ++inserted++ text")
  end

  test "highlight" do
    assert %{
             node_type: "MDEx.Document",
             nodes: [
               %{
                 node_type: "MDEx.Paragraph",
                 nodes: [
                   %{node_type: "MDEx.Text", literal: "this is "},
                   %{node_type: "MDEx.Highlight", nodes: [%{node_type: "MDEx.Text", literal: "marked"}]},
                   %{node_type: "MDEx.Text", literal: " text"}
                 ]
               }
             ]
           } = to_json("this is ==marked== text", highlight: true)
  end

  test "subtext" do
    assert %{
             node_type: "MDEx.Document",
             nodes: [
               %{node_type: "MDEx.Subtext", nodes: [%{node_type: "MDEx.Text", literal: "Some Subtext"}]}
             ]
           } = to_json("-# Some Subtext\n", subtext: true)
  end
end
