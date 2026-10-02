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

  test "delimiters inside inline code remain literal" do
    markdown = ~s|`{:mdex, "~> 0.12"}`|

    assert complete(markdown) == markdown
    assert complete("`~>` and **bold") == "`~>` and **bold**"
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

  test "incomplete link label crossing newline is not completed" do
    assert complete("[foo\nbar") == "[foo\nbar"
  end

  test "trailing link label on previous line is not completed" do
    assert complete("[foo]\n") == "[foo]\n"
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

  test "table closed by blank line" do
    assert complete("| a |\n|---|\n| 1 |\n\n") == "| a |\n|---|\n| 1 |\n\n"
  end

  test "multi column table closed by blank line" do
    assert complete("| a | b |\n|---|---|\n| 1 | 2 |\n\n") == "| a | b |\n|---|---|\n| 1 | 2 |\n\n"
  end

  test "table closed by blank line after other blocks" do
    assert complete("# h\n\n| a |\n|---|\n| 1 |\n\n") == "# h\n\n| a |\n|---|\n| 1 |\n\n"
  end

  test "open table that already has a delimiter row is left alone" do
    assert complete("| a |\n|---|\n") == "| a |\n|---|\n"
    assert complete("| a |\n|---|\n| 1 |\n") == "| a |\n|---|\n| 1 |\n"

    assert complete("| a | b |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |\n") ==
             "| a | b |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |\n"
  end

  test "alignment markers count as a delimiter row" do
    assert complete("| a | b |\n|:--|--:|\n| 1 | 2 |\n") == "| a | b |\n|:--|--:|\n| 1 | 2 |\n"
    assert complete("| a | b |\n|:-:|:-:|\n| 1 | 2 |\n") == "| a | b |\n|:-:|:-:|\n| 1 | 2 |\n"
  end

  test "header after another block still gets a delimiter row" do
    assert complete("text\n\n| a | b |\n") == "text\n\n| a | b |\n| - | - |"
  end

  test "outer pipes are optional when looking for the delimiter row" do
    assert complete("| a | b |\n---|---\n| 1 | 2 |\n") == "| a | b |\n---|---\n| 1 | 2 |\n"
    assert complete("| a | b |\n:--|--:\n| 1 | 2 |\n") == "| a | b |\n:--|--:\n| 1 | 2 |\n"
    assert complete("a | b\n--|--\n| 1 | 2 |\n") == "a | b\n--|--\n| 1 | 2 |\n"

    assert complete("| a | b |\n| --- | --- |\n1 | 2\n| 3 | 4 |\n") ==
             "| a | b |\n| --- | --- |\n1 | 2\n| 3 | 4 |\n"
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
    assert complete("[foo](https://example") == "[foo](mdex:incomplete-link)"
  end

  test "![img](https://cdn.example.com/pic" do
    assert complete("![img](https://cdn.example.com/pic") == "![img](mdex:incomplete-link)"
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
    assert complete("[wiki](https://en.wikipedia.org/wiki/Foo_(bar)") == "[wiki](mdex:incomplete-link)"
  end

  describe "links still arriving never render a partial URL" do
    test "URL starting on the next line" do
      assert complete("[a](\nhttps://exa") == "[a](mdex:incomplete-link)"
    end

    test "URL ending in an escape" do
      assert complete("[a](https://example.com/a\\") == "[a](mdex:incomplete-link)"
    end

    test "URL ended by whitespace is kept while the title arrives" do
      assert complete(~s{[a](https://example.com "Tit}) == "[a](https://example.com)"
      assert complete("[a](https://example.com\n'Tit") == "[a](https://example.com)"
      assert complete("[a](<https://example.com/a b> (Tit") == "[a](<https://example.com/a b>)"
      assert complete("[a](https://example.com ") == "[a](https://example.com) "
    end

    test "link with a closed title waits only for the paren" do
      assert complete(~s{[a](https://example.com "Title"}) == ~s{[a](https://example.com "Title")}
    end

    test "link inside emphasis" do
      assert complete("**[a](https://exa") == "**[a](mdex:incomplete-link)**"
      assert complete("*see [a](https://example.com/Foo_") == "*see [a](mdex:incomplete-link)*"
    end

    test "emphasis markers inside a URL are not emphasis" do
      assert complete("[a](https://example.com/*b) and text") == "[a](https://example.com/*b) and text"
      assert complete("[a](https://example.com/Foo_(bar)) done") == "[a](https://example.com/Foo_(bar)) done"
      assert complete("*see [a](https://example.com/*b) and text") == "*see [a](https://example.com/*b) and text*"
    end

    test "emphasis inside the label closes before the link" do
      assert complete("[**bo") == "[**bo**](mdex:incomplete-link)"
    end

    test "image inside a link" do
      assert complete("[![badge](https://img") == "[![badge](mdex:incomplete-link)](mdex:incomplete-link)"
      assert complete("[![badge](https://img.test/b.svg)](https://exa") == "[![badge](https://img.test/b.svg)](mdex:incomplete-link)"
    end

    test "closed brackets inside a label" do
      assert complete("[a [b]") == "[a [b]](mdex:incomplete-link)"
      assert complete("[a [b] c](https://exa") == "[a [b] c](mdex:incomplete-link)"
    end

    test "full and collapsed references" do
      assert complete("[a][re") == "[a](mdex:incomplete-link)"
      assert complete("[a][ref]") == "[a](mdex:incomplete-link)"
      assert complete("[a][]") == "[a](mdex:incomplete-link)"
    end

    test "escaped brackets and code spans are not links" do
      assert complete("\\[a](https://exa") == "\\[a](https://exa"
      assert complete("`[a](b` text") == "`[a](b` text"
    end

    test "a blank line after the URL leaves the text alone" do
      assert complete("[a](https://example.com\n\nNext") == "[a](https://example.com\n\nNext"
    end

    test "link reference definition" do
      assert complete("[a]\n\n[a]: https://exa") == "[a]\n\n[a]: mdex:incomplete-link"
      assert complete("[a]\n\n[a]:\nhttps://exa") == "[a]\n\n[a]: mdex:incomplete-link"
      assert complete(~s{[a]\n\n[a]: https://example.com "Tit}) == "[a]\n\n[a]: https://example.com"
      assert complete("text\n[a]: https://exa") == "text\n[a]: https://exa"
    end

    test "link reference definition after multi-line definitions" do
      assert complete(~s{[a]: https://a.test\n  "Title A"\n[b]: https://exa}) ==
               ~s{[a]: https://a.test\n  "Title A"\n[b]: mdex:incomplete-link}

      assert complete(~s{[a]: https://a.test\n"Title\nA"\n[b]: https://exa}) ==
               ~s{[a]: https://a.test\n"Title\nA"\n[b]: mdex:incomplete-link}

      assert complete("[a]:\nhttps://a.test\n[b]: https://exa") == "[a]:\nhttps://a.test\n[b]: mdex:incomplete-link"
      assert complete("[foo\nbar]: https://exa") == "[foo\nbar]: mdex:incomplete-link"
      assert complete(~s{[a]: https://example.com\n"Tit}) == "[a]: https://example.com"
    end

    test "link reference definitions in block quotes" do
      for prefix <- ["> ", ">", "> > ", ">>", ">   > ", ">\t", "> \t "] do
        assert complete("[a]\n\n#{prefix}[a]: https://exa") == "[a]\n\n#{prefix}[a]: mdex:incomplete-link"
        assert complete("#{prefix}[a]: <https://exa") == "#{prefix}[a]: mdex:incomplete-link"
        assert complete("#{prefix}[a]: https://example.com ") == "#{prefix}[a]: https://example.com "
        assert complete("#{prefix}[a]: https://example.com\n") == "#{prefix}[a]: https://example.com\n"
        assert complete("#{prefix}[a]: <https://example.com>") == "#{prefix}[a]: <https://example.com>"
        assert complete(~s{#{prefix}[a]: https://example.com "Tit}) == "#{prefix}[a]: https://example.com"
      end

      assert complete("[a]\n\n  > [a]: https://exa") == "[a]\n\n  > [a]: mdex:incomplete-link"
    end

    test "quoted multiline definitions preserve source offsets" do
      for newline <- ["\n", "\r\n", "\r"] do
        assert complete("> [café]:#{newline}> https://exa") == "> [café]: mdex:incomplete-link"

        assert complete("> [café#{newline}> noir]: https://exa") ==
                 "> [café#{newline}> noir]: mdex:incomplete-link"

        assert complete(~s{> [a]: https://a.test#{newline}> "Café#{newline}> noir"#{newline}> [b]: https://exa}) ==
                 ~s{> [a]: https://a.test#{newline}> "Café#{newline}> noir"#{newline}> [b]: mdex:incomplete-link}

        assert complete(~s{> [a]:#{newline}> https://a.test#{newline}> "Tit}) ==
                 "> [a]:#{newline}> https://a.test"
      end
    end

    test "quoted reference definitions cannot interrupt a paragraph or code" do
      for source <- [
            "> text\n> [a]: https://exa",
            ">     [a]: https://exa",
            ">\t  [a]: https://exa",
            "> ~~~\n>\n> [a]: https://exa",
            "> > text\n> > [a]: https://exa"
          ] do
        assert complete(source) == source
      end
    end

    test "reference definitions at the start of a quote or after a quoted blank line" do
      assert complete("text\n> [a]: https://exa") == "text\n> [a]: mdex:incomplete-link"
      assert complete("> text\n> > [a]: https://exa") == "> text\n> > [a]: mdex:incomplete-link"
      assert complete("> text\n>\n> [a]: https://exa") == "> text\n>\n> [a]: mdex:incomplete-link"
    end

    test "quoted blank lines do not turn raw HTML into reference definitions" do
      for {opening, closing} <- [{"<script>", "</script>"}, {"<pre>", "</pre>"}, {"<!--", "-->"}, {"<?", "?>"}, {"<![CDATA[", "]]>"}] do
        source = "> #{opening}\n>\n> [a]: https://exa"
        assert complete(source) == source

        source = "> #{opening}\n> #{closing}\n>\n> [a]: https://exa"
        assert complete(source) == "> #{opening}\n> #{closing}\n>\n> [a]: mdex:incomplete-link"
      end
    end

    test "CRLF and CR line endings" do
      assert complete("[a]: https://a.test\r\n[b]: https://exa") == "[a]: https://a.test\r\n[b]: mdex:incomplete-link"
      assert complete(~s{[a]: https://a.test\r\n"T"\r\n[b]: https://exa}) == ~s{[a]: https://a.test\r\n"T"\r\n[b]: mdex:incomplete-link}
      assert complete("[a]: https://a.test\r[b]: https://exa") == "[a]: https://a.test\r[b]: mdex:incomplete-link"
      assert complete("text\r\n[a]: https://exa") == "text\r\n[a]: https://exa"
      assert complete("[a](\r\nhttps://exa") == "[a](mdex:incomplete-link)"
    end

    test "task list markers are not links" do
      assert complete("- [ ]") == "- [ ]"
      assert complete("- [x]") == "- [x]"
    end

    test "autolinks" do
      options = [extension: [autolink: true]]

      assert complete("see https://exa", options) == "see [https\\:\\/\\/exa](mdex:incomplete-link)"
      assert complete("see www.exa", options) == "see [www\\.exa](mdex:incomplete-link)"
      assert complete("mail me@example.c", options) == "mail [me\\@example\\.c](mdex:incomplete-link)"
      assert complete("**see https://example.com*", options) == "**see [https\\:\\/\\/example\\.com](mdex:incomplete-link)**"
      assert complete("see https://example.com ", options) == "see https://example.com "
      assert complete("[a](https://example.com)", options) == "[a](https://example.com)"
      assert complete(~s{<a href="https://example.com">}, options) == ~s{<a href="https://example.com">}
      assert complete("see https://exa") == "see https://exa"
    end

    test "wikilinks" do
      assert complete("[[Wiki Pa", extension: [wikilinks_title_after_pipe: true]) ==
               "[[mdex:incomplete-link|Wiki Pa]]"

      assert complete("[[Title|https://exa", extension: [wikilinks_title_before_pipe: true]) ==
               "[[Title|mdex:incomplete-link]]"
    end

    test "footnote references are not links" do
      assert complete("Note[^1]", extension: [footnotes: true]) == "Note[^1]"
      assert complete("Note[^1", extension: [footnotes: true]) == "Note[^1"
    end
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

    test "incomplete tag is preserved in state" do
      assert {"Hello", %MDEx.FragmentParser.State{pending_html: "<div"}} =
               complete_with_state("Hello <div", nil)
    end

    test "pending incomplete tag is prepended on next completion" do
      {_completed, state} = complete_with_state("<div", nil)

      assert {"<div>hello", %MDEx.FragmentParser.State{pending_html: nil}} =
               complete_with_state(">hello", state)
    end

    test "trailing bare less-than is preserved only in stateful completion" do
      assert complete("hello <") == "hello <"

      assert {"hello", %MDEx.FragmentParser.State{pending_html: "<"}} =
               complete_with_state("hello <", nil)
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

    test "trailing label on previous line is left as text" do
      assert complete("text [label]\nnext") == "text [label]\nnext"
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
