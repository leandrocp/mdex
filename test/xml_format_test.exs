defmodule MDEx.XmlFormatTest do
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

    assert {:ok, xml} = MDEx.to_xml(document, opts)
    assert xml == expected
  end

  test "empty doc" do
    assert_format("", """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE document SYSTEM "CommonMark.dtd">
    <document xmlns="http://commonmark.org/xml/1.0" />
    """)
  end

  test "text" do
    assert_format("mdex", """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE document SYSTEM "CommonMark.dtd">
    <document xmlns="http://commonmark.org/xml/1.0">
      <paragraph>
        <text xml:space="preserve">mdex</text>
      </paragraph>
    </document>
    """)
  end

  test "heading" do
    assert_format("# mdex", """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE document SYSTEM "CommonMark.dtd">
    <document xmlns="http://commonmark.org/xml/1.0">
      <heading level="1">
        <text xml:space="preserve">mdex</text>
      </heading>
    </document>
    """)
  end
end
