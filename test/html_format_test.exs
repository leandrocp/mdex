defmodule MDEx.HTMLFormatTest do
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

  def assert_commonmark(document, extension \\ []) do
    opts = [
      extension: Keyword.merge(@extension, extension),
      render: [unsafe_: true]
    ]

    assert {:ok, ast} = MDEx.parse_document(document, opts)
    assert {:ok, markdown} = MDEx.to_commonmark(ast, opts)

    assert markdown == String.trim(document)
  end

  def assert_format(document, expected, extension \\ []) do
    opts = [
      extension: Keyword.merge(@extension, extension),
      render: [unsafe_: true]
    ]

    assert {:ok, doc} = MDEx.parse_document(document, opts)
    assert {:ok, html} = MDEx.to_html(doc, opts)

    # IO.puts(html)
    assert html == String.trim(expected)
  end

  test "text" do
    assert_format("mdex", "<p>mdex</p>\n")

    assert_commonmark("""
    mdex
    """)

    assert_commonmark("""
    Hello ~~world~~ there
    """)
  end

  test "front matter" do
    assert_format(
      """
      ---
      title: MDEx
      ---
      """,
      ""
    )
  end

  test "thematic break" do
    assert_format(
      """
      ---
      # Heading

      """,
      "<hr />\n<h1>Heading</h1>\n"
    )
  end

  test "block quote" do
    assert_format(
      """
      > MDEx
      """,
      "<blockquote>\n<p>MDEx</p>\n</blockquote>\n"
    )

    assert_commonmark("""
    > MDEx
    """)
  end

  describe "list" do
    test "unordered" do
      assert_format(
        """
        - foo
          - bar
            - baz
              - boo
        """,
        """
        <ul>
        <li>foo
        <ul>
        <li>bar
        <ul>
        <li>baz
        <ul>
        <li>boo</li>
        </ul>
        </li>
        </ul>
        </li>
        </ul>
        </li>
        </ul>
        """
      )
    end

    test "ordered" do
      assert_format(
        """
        1. foo
        2.
        3. bar
        """,
        """
        <ol>
        <li>foo</li>
        <li></li>
        <li>bar</li>
        </ol>
        """
      )
    end
  end

  test "description list" do
    assert_format(
      """
      MDEx

      : Built with Elixir and Rust
      """,
      """
      <dl>
      <dt>MDEx</dt>
      <dd>
      <p>Built with Elixir and Rust</p>
      </dd>
      </dl>
      """
    )
  end

  test "code block" do
    assert_format(
      """
      ```elixir
      String.trim(" MDEx ")
      ```
      """,
      """
      <pre class="autumn-hl" style="background-color: #282C34; color: #ABB2BF;"><code class="language-elixir" translate="no"><span class="ahl-namespace" style="color: #61AFEF;">String</span><span class="ahl-operator" style="color: #C678DD;">.</span><span class="ahl-function" style="color: #61AFEF;">trim</span><span class="ahl-punctuation ahl-bracket" style="color: #ABB2BF;">(</span><span class="ahl-string" style="color: #98C379;">&quot; MDEx &quot;</span><span class="ahl-punctuation ahl-bracket" style="color: #ABB2BF;">)</span>
      </code></pre>
      """
    )
  end

  test "html block" do
    assert_format(
      """
      <h1>MDEx</h1>
      """,
      "<h1>MDEx</h1>\n"
    )
  end

  test "header" do
    assert_format(
      """
      # level_1
      ###### level_6
      """,
      """
      <h1>level_1</h1>
      <h6>level_6</h6>
      """
    )
  end

  test "footnote" do
    assert_format(
      """
      footnote[^1]

      [^1]: ref
      """,
      """
      <p>footnote<sup class="footnote-ref"><a href="#fn-1" id="fnref-1" data-footnote-ref>1</a></sup></p>
      <section class="footnotes" data-footnotes>
      <ol>
      <li id="fn-1">
      <p>ref <a href="#fnref-1" class="footnote-backref" data-footnote-backref data-footnote-backref-idx="1" aria-label="Back to reference 1">↩</a></p>
      </li>
      </ol>
      </section>
      """
    )
  end

  test "table" do
    assert_format(
      """
      | foo | bar |
      | --- | --- |
      | baz | bim |
      """,
      """
      <table>
      <thead>
      <tr>
      <th>foo</th>
      <th>bar</th>
      </tr>
      </thead>
      <tbody>
      <tr>
      <td>baz</td>
      <td>bim</td>
      </tr>
      </tbody>
      </table>
      """
    )

    assert_format(
      """
      | abc | defghi |
      :-: | -----------:
      bar | baz
      """,
      """
      <table>
      <thead>
      <tr>
      <th align="center">abc</th>
      <th align="right">defghi</th>
      </tr>
      </thead>
      <tbody>
      <tr>
      <td align="center">bar</td>
      <td align="right">baz</td>
      </tr>
      </tbody>
      </table>
      """
    )
  end

  test "task item" do
    assert_format(
      """
      * [x] Done
      * [ ] Not done
      """,
      """
      <ul>
      <li><input type="checkbox" checked="" disabled="" /> Done</li>
      <li><input type="checkbox" disabled="" /> Not done</li>
      </ul>
      """
    )
  end

  test "link" do
    assert_format(
      """
      [foo]: /url "title"

      [foo]
      """,
      """
      <p><a href="/url" title="title">foo</a></p>
      """
    )
  end

  test "image" do
    assert_format(
      """
      ![foo](/url "title")
      """,
      """
      <p><img src="/url" alt="foo" title="title" /></p>
      """
    )
  end

  test "code" do
    assert_format(
      """
      `String.trim(" MDEx ")`
      """,
      "<p><code>String.trim(&quot; MDEx &quot;)</code></p>\n"
    )
  end

  test "shortcode" do
    assert_format(
      """
      :smile:
      """,
      "<p>😄</p>\n"
    )
  end

  test "math" do
    assert_format(
      """
      $1 + 2$ and $$x = y$$

      $`1 + 2`$
      """,
      """
      <p><span data-math-style="inline">1 + 2</span> and <span data-math-style="display">x = y</span></p>
      <p><code data-math-style="inline">1 + 2</code></p>
      """
    )
  end

  describe "wiki links" do
    test "title before pipe" do
      assert_format(
        """
        [[repo|https://github.com/leandrocp/mdex]]
        """,
        "<p><a href=\"https://github.com/leandrocp/mdex\" data-wikilink=\"true\">repo</a></p>\n",
        wikilinks_title_before_pipe: true
      )
    end

    test "title after pipe" do
      assert_format(
        """
        [[https://github.com/leandrocp/mdex|repo]]
        """,
        "<p><a href=\"https://github.com/leandrocp/mdex\" data-wikilink=\"true\">repo</a></p>",
        wikilinks_title_after_pipe: true
      )
    end
  end

  test "spoiler" do
    assert_format(
      """
      Darth Vader is ||Luke's father||
      """,
      "<p>Darth Vader is <span class=\"spoiler\">Luke's father</span></p>"
    )
  end

  test "greentext" do
    assert_format(
      """
      > one
      > > two
      > three
      """,
      "<blockquote>\n<p>one</p>\n<blockquote>\n<p>two</p>\n</blockquote>\n<p>three</p>\n</blockquote>\n"
    )
  end

  test "subscript" do
    assert_format("H~2~O", "<p>H<sub>2</sub>O</p>", subscript: true)
  end

  test "raw" do
    ast = %MDEx.Document{
      nodes: [
        %MDEx.Raw{
          literal: "&lbrace; <!-- literal --> &rbrace;"
        }
      ]
    }

    assert MDEx.to_html(ast) == {:ok, "&lbrace; <!-- literal --> &rbrace;"}
  end
end
