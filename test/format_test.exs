defmodule MDEx.FormatTest do
  use ExUnit.Case
  doctest MDEx

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
      extension: Keyword.merge(@extension, extension)
    ]

    assert {:ok, ast} = MDEx.parse_document(document, opts)
    assert MDEx.to_html(ast, opts) == {:ok, expected}
  end

  describe "error handling" do
    test "invalid ast" do
      assert {:error, %MDEx.DecodeError{reason: :invalid_ast, found: "{<<\"document\">>}"}} = MDEx.to_html([{"document"}], [])
      assert {:error, %MDEx.DecodeError{reason: :invalid_ast, found: "{<<\"code\">>,[invalid],[]}"}} = MDEx.to_html([{"code", [:invalid], []}], [])
      assert {:error, %MDEx.DecodeError{reason: :invalid_ast, found: "{<<\"code\">>,[{}],[]}"}} = MDEx.to_html([{"code", [{}], []}], [])
      assert {:error, %MDEx.DecodeError{reason: :invalid_ast_node_attr_key, found: "offset"}} = MDEx.to_html([{"code", [{:offset, 1}], []}], [])

      assert {:error, %MDEx.DecodeError{reason: :invalid_ast, found: "{<<\"code\">>,[{<<\"offset\">>}],[]}"}} =
               MDEx.to_html([{"code", [{"offset"}], []}], [])
    end
  end

  test "text" do
    assert_format("mdex", "<p>mdex</p>\n")
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

  test "block quote" do
    assert_format(
      """
      > MDEx
      """,
      "<blockquote>\n<p>MDEx</p>\n</blockquote>\n"
    )
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
      <dl><dt>MDEx</dt>
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
      "<pre><code class=\"language-elixir\">String.trim(&quot; MDEx &quot;)\n</code></pre>\n"
    )
  end

  test "headings" do
    assert_format(
      """
      # one
      ## two
      ### three
      """,
      "<h1>one</h1>\n<h2>two</h2>\n<h3>three</h3>\n"
    )
  end

  test "table" do
    assert_format(
      """
      | foo | bar |
      | --- | --- |
      | baz | bim |
      """,
      "<table>\n<thead>\n<tr>\n<th>foo</th>\n<th>bar</th>\n</tr>\n</thead>\n<tbody>\n<tr>\n<td>baz</td>\n<td>bim</td>\n</tr>\n</tbody>\n</table>\n"
    )
  end
end
