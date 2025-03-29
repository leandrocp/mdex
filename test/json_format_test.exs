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
    greentext: true
  ]

  def to_json(document, extension \\ []) do
    opts = [
      extension: Keyword.merge(@extension, extension),
      render: [unsafe_: true]
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
end
