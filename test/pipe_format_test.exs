defmodule MDEx.PipeFormatTest do
  use ExUnit.Case

  def assert_html(document, expected, extension \\ []) do
    opts = [
      document: document,
      extension: extension,
      render: [unsafe_: true]
    ]

    mdex = MDEx.new()
    assert {:ok, html} = MDEx.to_html(mdex, opts)
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
      assert_html("~mdex~", "<p>mdex</p>", strikethrough: true)
    end
  end
end
