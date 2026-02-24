defmodule MDEx.FragmentParserTest do
  use ExUnit.Case, async: true

  import MDEx.FragmentParser

  test "**text" do
    assert complete("**text") == "**text**"
  end

  test "**text*" do
    assert complete("**text*") == "**text**"
  end

  test " text** - prefix: **" do
    assert complete(" text**", prefix: "**") == "**text**"
  end

  test "*it" do
    assert complete("*it") == "*it*"
  end

  test "_it" do
    assert complete("_it") == "_it_"
  end

  test "This is *it" do
    assert complete("This is *it") == "This is *it*"
  end

  test "This is _it" do
    assert complete("This is _it") == "This is _it_"
  end

  test "_x" do
    assert complete("_x") == "_x_"
  end

  test "__x_" do
    assert complete("__x_") == "__x__"
  end

  test "x__ - prefix: __" do
    assert complete("x__", prefix: "__") == "__x__"
  end

  test "~~x" do
    assert complete("~~x") == "~~x~~"
  end

  test "This is *italic **bold" do
    assert complete("This is *italic **bold") == "This is *italic **bold***"
  end

  test "This is *italic **bold** text" do
    assert complete("This is *italic **bold** text") == "This is *italic **bold** text*"
  end

  test "This is _italic __bold" do
    assert complete("This is _italic __bold") == "This is _italic __bold___"
  end

  test "~~strike~" do
    assert complete("~~strike~") == "~~strike~~"
  end

  test "This is ~~strike" do
    assert complete("This is ~~strike") == "This is ~~strike~~"
  end

  test "~~x~" do
    assert complete("~~x~") == "~~x~~"
  end

  test "x~~ - prefix: ~~" do
    assert complete("x~~", prefix: "~~") == "~~x~~"
  end

  test "mixed emphasis with strikethrough ~~strike *bold" do
    assert complete("~~strike *bold") == "~~strike *bold~~"
  end

  test "incomplete emphasis in list items" do
    assert complete("- **bold") == "- **bold**"
  end

  test "incomplete italic in list items" do
    assert complete("- *italic") == "- *italic*"
  end

  test "incomplete strikethrough in list items" do
    assert complete("- ~~strike") == "- ~~strike~~"
  end

  test "incomplete link in list items" do
    assert complete("- [foo") == "- [foo](mdex:incomplete-link)"
  end

  test "incomplete emphasis in nested list items" do
    assert complete("  - **bold") == "  - **bold**"
  end

  test "incomplete emphasis in task list items" do
    assert complete("- [x] **completed") == "- [x] **completed**"
  end

  test "incomplete emphasis in ordered list items" do
    assert complete("1. **first") == "1. **first**"
  end

  test "# text" do
    assert complete("# text") == "# text"
  end

  test "# text " do
    assert complete("# text ") == "# text "
  end

  test "`code" do
    assert complete("`code") == "`code`"
  end

  test "`code " do
    assert complete("`code ") == "`code` "
  end

  test "bar` - prefix: `foo " do
    assert complete("bar`", prefix: "`foo ") == "`foo bar`"
  end

  test "```" do
    assert complete("```") == "```"
  end

  test "```rust\nfn foo" do
    assert complete("```rust\nfn foo") == "```rust\nfn foo\n```"
  end

  test "```rust\nfn foo\n" do
    assert complete("```rust\nfn foo\n") == "```rust\nfn foo\n```"
  end

  test "```rust\nfn foo\n`" do
    assert complete("```rust\nfn foo\n`") == "```rust\nfn foo\n```"
  end

  test "code block with multiple lines" do
    assert complete("""
           ```elixir
           defmodule Foo do

             def code(bar) do
               

               bar

             end

           """) == "```elixir\ndefmodule Foo do\n\n  def code(bar) do\n    \n\n    bar\n\n  end\n```\n"
  end

  test "mixed spaces" do
    assert complete("  foo bar  baz   ") == "foo bar  baz   "
  end

  test "[foo] (bar)" do
    assert complete("[foo] (bar)") == "[foo] (bar)"
  end

  test "[foo](bar)" do
    assert complete("[foo](bar)") == "[foo](bar)"
  end

  test "[foo" do
    assert complete("[foo") == "[foo](mdex:incomplete-link)"
  end

  test "[foo]" do
    assert complete("[foo]") == "[foo](mdex:incomplete-link)"
  end

  test "![foo" do
    assert complete("![foo") == "![foo](mdex:incomplete-link)"
  end

  test "![foo]" do
    assert complete("![foo]") == "![foo](mdex:incomplete-link)"
  end

  test "does not close emphasis inside shortcode" do
    assert complete("Streaming with :keyboard_shortcuts:") == "Streaming with :keyboard_shortcuts:"
  end

  test "| foo | bar |" do
    assert complete("| foo | bar |") == "| foo | bar |"
  end

  test "| foo |\n" do
    assert complete("| foo |\n") == "| foo |\n| - |"
  end

  test "| foo | bar |\n" do
    assert complete("| foo | bar |\n") == "| foo | bar |\n| - | - |"
  end

  test "- [x] Collect *n" do
    assert complete("- [x] Collect *n") == "- [x] Collect *n*"
  end

  test "inline math $x =" do
    assert complete("$x =") == "$x =$"
  end

  test "display math $$\\n" do
    assert complete("$$\n") == "$$\n$$"
  end

  test "display math $$E = mc^2" do
    assert complete("$$E = mc^2") == "$$E = mc^2$$"
  end

  test "inline math inside text The formula $a^2 + b^2" do
    assert complete("The formula $a^2 + b^2") == "The formula $a^2 + b^2$"
  end

  test "complete math doesn't add delimiter" do
    assert complete("$x = 1$") == "$x = 1$"
  end

  test "complete display math doesn't add delimiter" do
    assert complete("$$x = 1$$") == "$$x = 1$$"
  end

  test "++ins" do
    assert complete("++ins") == "++ins++"
  end

  test "==mark" do
    assert complete("==mark") == "==mark=="
  end

  test "This is ++inserted" do
    assert complete("This is ++inserted") == "This is ++inserted++"
  end

  test "This is ==highlighted" do
    assert complete("This is ==highlighted") == "This is ==highlighted=="
  end

  test "[foo](https://example" do
    assert complete("[foo](https://example") == "[foo](https://example)"
  end

  test "![img](https://cdn.example.com/pic" do
    assert complete("![img](https://cdn.example.com/pic") == "![img](https://cdn.example.com/pic)"
  end

  test "complete link is not modified" do
    assert complete("[foo](https://example.com)") == "[foo](https://example.com)"
  end

  test "dollar followed by digit is not math" do
    assert complete("Price is $5.00") == "Price is $5.00"
  end

  test "escaped dollar is not math" do
    assert complete("Price is \\$5") == "Price is \\$5"
  end

  test "real inline math still works" do
    assert complete("$x + y") == "$x + y$"
  end

  test "C++17 is not treated as insert delimiter" do
    assert complete("C++17") == "C++17"
  end

  test "x==1 is not treated as highlight delimiter" do
    assert complete("x==1") == "x==1"
  end

  test "stray ]( is not treated as link" do
    assert complete("text ]( stray") == "text ]( stray"
  end

  test "a]( without [ is not treated as link" do
    assert complete("no bracket]( url") == "no bracket]( url"
  end

  test "link with nested parens is incomplete" do
    assert complete("[wiki](https://en.wikipedia.org/wiki/Foo_(bar)") ==
             "[wiki](https://en.wikipedia.org/wiki/Foo_(bar))"
  end

  test "mixed currency and math $5 + $x" do
    assert complete("$5 + $x") == "$5 + $x$"
  end

  test "multiple currency amounts $5.00 and $10" do
    assert complete("$5.00 and $10") == "$5.00 and $10"
  end

  test "display math $$x$$ is complete" do
    assert complete("$$x$$") == "$$x$$"
  end
end
