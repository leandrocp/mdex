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

  def assert_format(document, expected, extension \\ []) do
    opts = [
      extension: Keyword.merge(@extension, extension),
      render: [unsafe_: true]
    ]

    assert {:ok, json} = MDEx.to_json(document, opts)
    # IO.puts(json)
    assert String.trim(json) == String.trim(expected)
  end

  test "empty doc" do
    assert_format("", """
    {"nodes":[],"node_type":"MDEx.Document"}
    """)
  end

  test "heading" do
    assert_format("# Title", """
    {"nodes":[{"nodes":[{"literal":"Title","node_type":"MDEx.Text"}],"level":1,"setext":false,"node_type":"MDEx.Heading"}],"node_type":"MDEx.Document"}
    """)
  end
end
