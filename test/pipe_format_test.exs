defmodule MDEx.PipeFormatTest do
  use ExUnit.Case

  def assert_html(document, expected, options \\ []) do
    options = Keyword.merge([document: document], options)

    mdex = MDEx.new()
    assert {:ok, html} = MDEx.to_html(mdex, options)
    assert html == expected
  end

  describe "html" do
    test "empty doc" do
      assert_html("", """
      """)
    end

    test "text" do
      assert_html("mdex", "<p>mdex</p>")
    end

    test "options" do
      assert_html("~mdex~", "<p><del>mdex</del></p>", extension: [strikethrough: true])
    end
  end
end
