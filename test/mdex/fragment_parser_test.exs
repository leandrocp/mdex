defmodule MDEx.FragmentParserTest do
  use ExUnit.Case, async: true

  import MDEx.FragmentParser

  test "**text" do
    assert complete("**text") == {"**text**", "**", "", ""}
  end

  test "**text*" do
    assert complete("**text*") == {"**text**", "*", "", ""}
  end

  test " text** prefix: **" do
    assert complete(" text**", prefix: "**") == {"**text**", "", " ", ""}
  end

  test "*it" do
    assert complete("*it") == {"*it*", "*", "", ""}
  end

  test "_it" do
    assert complete("_it") == {"_it_", "_", "", ""}
  end

  test "This is *it" do
    assert complete("This is *it") == {"This is *it*", "*", "", ""}
  end

  test "This is _it" do
    assert complete("This is _it") == {"This is _it_", "_", "", ""}
  end

  test "_x" do
    assert complete("_x") == {"_x_", "_", "", ""}
  end

  test "__x_" do
    assert complete("__x_") == {"__x__", "_", "", ""}
  end

  test "x__ prefix: __" do
    assert complete("x__", prefix: "__") == {"__x__", "", "", ""}
  end

  test "~~x" do
    assert complete("~~x") == {"~~x~~", "~~", "", ""}
  end

  test "This is *italic **bold" do
    assert complete("This is *italic **bold") == {"This is *italic **bold***", "***", "", ""}
  end

  test "This is *italic **bold** text" do
    assert complete("This is *italic **bold** text") == {"This is *italic **bold** text*", "*", "", ""}
  end

  test "This is _italic __bold" do
    assert complete("This is _italic __bold") == {"This is _italic __bold___", "___", "", ""}
  end

  test "~~strike~" do
    assert complete("~~strike~") == {"~~strike~~", "~", "", ""}
  end

  test "This is ~~strike" do
    assert complete("This is ~~strike") == {"This is ~~strike~~", "~~", "", ""}
  end

  test "~~x~" do
    assert complete("~~x~") == {"~~x~~", "~", "", ""}
  end

  test "x~~ prefix: ~~" do
    assert complete("x~~", prefix: "~~") == {"~~x~~", "", "", ""}
  end

  test "mixed emphasis with strikethrough ~~strike *bold" do
    # Strikethrough takes precedence over incomplete emphasis
    assert complete("~~strike *bold") == {"~~strike *bold~~", "~~", "", ""}
  end

  test "incomplete emphasis in list items" do
    assert complete("- **bold") == {"- **bold**", "**", "", ""}
  end

  test "incomplete italic in list items" do
    assert complete("- *italic") == {"- *italic*", "*", "", ""}
  end

  test "incomplete strikethrough in list items" do
    assert complete("- ~~strike") == {"- ~~strike~~", "~~", "", ""}
  end

  test "incomplete emphasis in nested list items" do
    assert complete("  - **bold") == {"  - **bold**", "**", "", ""}
  end

  test "incomplete emphasis in task list items" do
    assert complete("- [x] **completed") == {"- [x] **completed**", "**", "", ""}
  end

  test "incomplete emphasis in ordered list items" do
    assert complete("1. **first") == {"1. **first**", "**", "", ""}
  end
end
