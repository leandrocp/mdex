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
    assert complete("~~strike *bold") == "~~strike *bold*~~"
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

  describe "space-flanked asterisk (not emphasis)" do
    test "5 * 0 = ? stays unchanged" do
      assert complete("5 * 0 = ?") == "5 * 0 = ?"
    end

    test "2 * 3 * 4 stays unchanged" do
      assert complete("2 * 3 * 4") == "2 * 3 * 4"
    end

    test "*italic text gets closed" do
      assert complete("*italic text") == "*italic text*"
    end

    test "a *word gets closed" do
      assert complete("a *word") == "a *word*"
    end
  end

  describe "half-complete $$ math close" do
    test "$$x^2 + y^2$ gets single $ appended" do
      assert complete("$$x^2 + y^2$") == "$$x^2 + y^2$$"
    end

    test "$$formula gets full $$ appended" do
      assert complete("$$formula") == "$$formula$$"
    end

    test "$$formula$$ stays unchanged" do
      assert complete("$$formula$$") == "$$formula$$"
    end
  end

  describe "incomplete HTML tag stripping" do
    test "Hello <div is stripped" do
      assert complete("Hello <div") == "Hello"
    end

    test "text <custom class=\"foo is stripped" do
      assert complete("text <custom class=\"foo") == "text"
    end

    test "<br> hello is unchanged (complete tag)" do
      assert complete("<br> hello") == "<br> hello"
    end

    test "inline code with < is not stripped" do
      assert complete("`<div`") == "`<div`"
    end
  end

  describe "nested bracket depth in links" do
    test "[outer [inner] text has one unclosed bracket" do
      result = complete("[outer [inner] text")
      assert String.contains?(result, "](")
    end

    test "[a] [b] trailing label gets destination placeholder" do
      assert complete("[a] [b]") == "[a] [b](mdex:incomplete-link)"
    end
  end

  describe "edge cases for coverage" do
    test "empty string" do
      assert complete("") == ""
    end

    test "whitespace only" do
      assert complete("   ") == ""
    end

    test "less-than not a tag start" do
      assert complete("5 < 10") == "5 < 10"
    end

    test "less-than followed by digit" do
      assert complete("value <3") == "value <3"
    end

    test "only incomplete tag" do
      assert complete("<span") == ""
    end

    test "list marker with no content" do
      assert complete("- ") == "- "
    end

    test "fenced code with partial closing and content" do
      assert complete("````\ncode\n``x") == "````\ncode\n``x\n````"
    end

    test "single pipe table does not generate separator" do
      assert complete("| only\n") == "| only\n"
    end

    test "incomplete link destination with trailing label" do
      assert complete("text [label]") == "text [label](mdex:incomplete-link)"
    end

    test "tilde fence" do
      assert complete("~~~\ncode") == "~~~\ncode\n~~~"
    end

    test "display math with trailing newline and half close" do
      assert complete("$$formula$\n") == "$$formula$\n$"
    end
  end

  describe "proper nesting order for multiple unclosed markers" do
    test "**bold _under closes inner first" do
      assert complete("**bold _under") == "**bold _under_**"
    end

    test "*em **strong closes inner first" do
      assert complete("*em **strong") == "*em **strong***"
    end
  end
end
