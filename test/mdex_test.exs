defmodule MDExTest do
  use ExUnit.Case, async: true
  alias MDEx.Document
  alias MDEx.Heading
  alias MDEx.Text
  doctest MDEx, except: [to_json: 1, to_json: 2]

  defp assert_output(input, expected, opts \\ []) do
    assert {:ok, html} = MDEx.to_html(input, opts)
    # IO.puts(html)
    assert html == String.trim(expected)
  end

  test "wrap fragment in root document" do
    assert MDEx.to_html(%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "mdex"}]}) == {:ok, "<p>mdex</p>"}
  end

  describe "to_html error handling" do
    test "invalid document" do
      assert {:error, %MDEx.DecodeError{}} = MDEx.to_html(%Document{nodes: nil})
      assert {:error, %MDEx.DecodeError{}} = MDEx.to_html(%Document{nodes: [nil]})
      assert {:error, %MDEx.DecodeError{}} = MDEx.to_html(%Document{nodes: [%MDEx.Text{literal: nil}]})
    end

    test "invalid input" do
      assert {:error, %MDEx.InvalidInputError{}} = MDEx.to_html(nil)
      assert {:error, %MDEx.InvalidInputError{}} = MDEx.to_html([])
    end
  end

  describe "syntax highlighting" do
    test "enabled by default" do
      assert_output(
        ~S"""
        ```elixir
        {:mdex, "~> 0.1"}
        ```
        """,
        ~S"""
        <pre class="autumn-hl" style="background-color: #282C34; color: #ABB2BF;"><code class="language-elixir" translate="no"><span class="ahl-punctuation ahl-bracket" style="color: #ABB2BF;">&lbrace;</span><span class="ahl-string ahl-special ahl-symbol" style="color: #98C379;">:mdex</span><span class="ahl-punctuation ahl-delimiter" style="color: #ABB2BF;">,</span> <span class="ahl-string" style="color: #98C379;">&quot;~&gt; 0.1&quot;</span><span class="ahl-punctuation ahl-bracket" style="color: #ABB2BF;">&rbrace;</span>
        </code></pre>
        """
      )
    end

    test "change theme name" do
      assert_output(
        ~S"""
        ```elixir
        {:mdex, "~> 0.1"}
        ```
        """,
        ~S"""
        <pre class="autumn-hl" style="background-color: #2e3440; color: #D8DEE9;"><code class="language-elixir" translate="no"><span class="ahl-punctuation ahl-bracket" style="color: #ECEFF4;">&lbrace;</span><span class="ahl-string ahl-special ahl-symbol" style="color: #EBCB8B;">:mdex</span><span class="ahl-punctuation ahl-delimiter" style="color: #ECEFF4;">,</span> <span class="ahl-string" style="color: #A3BE8C;">&quot;~&gt; 0.1&quot;</span><span class="ahl-punctuation ahl-bracket" style="color: #ECEFF4;">&rbrace;</span>
        </code></pre>
        """,
        features: [syntax_highlight_theme: "nord"]
      )
    end

    test "can be disabled" do
      assert_output(
        ~S"""
        ```elixir
        {:mdex, "~> 0.1"}
        ```
        """,
        ~S"""
        <pre><code class="language-elixir">&lbrace;:mdex, &quot;~&gt; 0.1&quot;&rbrace;
        </code></pre>
        """,
        features: [syntax_highlight_theme: nil]
      )
    end

    test "with invalid lang" do
      assert_output(
        ~S"""
        ```invalid
        {:mdex, "~> 0.1"}
        ```
        """,
        ~s"""
        <pre class="autumn-hl" style="background-color: #282C34; color: #ABB2BF;"><code class="language-plaintext" translate="no">&lbrace;:mdex, &quot;~&gt; 0.1&quot;&rbrace;
        </code></pre>
        """
      )
    end

    test "without lang" do
      assert_output(
        ~S"""
        ```
        {:mdex, "~> 0.1"}
        ```
        """,
        ~s"""
        <pre class="autumn-hl" style="background-color: #282C34; color: #ABB2BF;"><code class="language-plaintext" translate="no">&lbrace;:mdex, &quot;~&gt; 0.1&quot;&rbrace;
        </code></pre>
        """
      )
    end

    test "without inline styles" do
      assert_output(
        ~S"""
        ```elixir
        {:mdex, "~> 0.1"}
        ```
        """,
        ~S"""
        <pre class="autumn-hl"><code class="language-elixir" translate="no"><span class="ahl-punctuation ahl-bracket">&lbrace;</span><span class="ahl-string ahl-special ahl-symbol">:mdex</span><span class="ahl-punctuation ahl-delimiter">,</span> <span class="ahl-string">&quot;~&gt; 0.1&quot;</span><span class="ahl-punctuation ahl-bracket">&rbrace;</span>
        </code></pre>
        """,
        features: [syntax_highlight_inline_style: false]
      )
    end
  end

  test "render emoji shortcodes" do
    assert_output(":rocket:", "<p>🚀</p>\n", extension: [shortcodes: true])
  end

  test "parse_document" do
    assert MDEx.parse_document!("# Test") == %MDEx.Document{
             nodes: [%MDEx.Heading{level: 1, setext: false, nodes: [%MDEx.Text{literal: "Test"}]}]
           }

    assert MDEx.parse_document!("""
           <script type="module">
             mermaid.initialize({ startOnLoad: true })
           </script>
           """) ==
             %MDEx.Document{
               nodes: [
                 %MDEx.HtmlBlock{
                   nodes: [],
                   block_type: 1,
                   literal: "<script type=\"module\">\n  mermaid.initialize({ startOnLoad: true })\n</script>\n"
                 }
               ]
             }
  end

  test "parse_fragment" do
    assert MDEx.parse_fragment!("test") == %MDEx.Text{literal: "test"}
    assert MDEx.parse_fragment!("`elixir`") == %MDEx.Code{literal: "elixir", num_backticks: 1}
    assert MDEx.parse_fragment!("# Test") == %MDEx.Heading{level: 1, nodes: [%MDEx.Text{literal: "Test"}], setext: false}

    assert MDEx.parse_fragment!("- Test") == %MDEx.List{
             bullet_char: "-",
             delimiter: :period,
             list_type: :bullet,
             marker_offset: 0,
             nodes: [
               %MDEx.ListItem{
                 nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Test"}]}],
                 bullet_char: "-",
                 delimiter: :period,
                 list_type: :bullet,
                 marker_offset: 0,
                 padding: 2,
                 start: 1,
                 tight: false
               }
             ],
             padding: 2,
             start: 1,
             tight: true
           }
  end

  describe "security" do
    test "omit raw html by default" do
      assert MDEx.to_html!("<h1>test</h1>") == "<!-- raw HTML omitted -->"
    end

    test "escape raw html" do
      assert MDEx.to_html!("<h1>test</h1>", render: [escape: true]) == "&lt;h1&gt;test&lt;/h1&gt;"
    end

    test "render raw html" do
      assert MDEx.to_html!("<h1>test</h1>", render: [unsafe_: true]) == "<h1>test</h1>"
    end

    test "sanitize unsafe raw html" do
      sanitize_options = MDEx.default_sanitize_options()

      assert MDEx.to_html!("<h1>test</h1>", render: [unsafe_: true], features: [sanitize: sanitize_options]) == "<h1>test</h1>"

      assert MDEx.to_html!("<a href=https://elixir-lang.org/>Elixir</a>", render: [unsafe_: true], features: [sanitize: sanitize_options]) ==
               "<p><a href=\"https://elixir-lang.org/\" rel=\"noopener noreferrer\">Elixir</a></p>"

      assert MDEx.to_html!("<a href=https://elixir-lang.org/><script>attack</script></a>",
               render: [unsafe_: true],
               features: [sanitize: sanitize_options]
             ) ==
               "<p><a href=\"https://elixir-lang.org/\" rel=\"noopener noreferrer\"></a></p>"
    end

    test "range of sanitize specifications" do
      input = ~s"""
      <h1 class="abc xyz" e="f" f="g" data-val="1" x-val="2" data-x="3">
      <strong>te<!-- :) -->st</strong> <a id="elixir" href="https://elixir-lang.org/"></a>
      </h1>
      """

      assert MDEx.to_html!(input, render: [unsafe_: true], features: [sanitize: MDEx.default_sanitize_options()]) <> "\n" == ~s"""
             <h1>
             <strong>test</strong> <a href="https://elixir-lang.org/" rel="noopener noreferrer"></a>
             </h1>
             """

      assert MDEx.to_html!(input,
               render: [unsafe_: true],
               features: [
                 sanitize: [
                   tags: ["h1"],
                   add_tags: ["a", "strong"],
                   rm_tags: ["strong"],
                   add_clean_content_tags: ["script"],
                   add_tag_attributes: %{"h1" => ["data-val"]},
                   add_tag_attribute_values: %{"h1" => %{"data-x" => ["3"]}},
                   generic_attribute_prefixes: ["x-"],
                   generic_attributes: ["id"],
                   allowed_classes: %{"h1" => ["xyz"]},
                   set_tag_attribute_values: %{"h1" => %{"hello" => "world"}},
                   set_tag_attribute_value: %{"h1" => %{"ola" => "mundo"}},
                   rm_set_tag_attribute_value: %{"h1" => "hello"},
                   strip_comments: false,
                   link_rel: "no",
                   id_prefix: "user-content-"
                 ]
               ]
             ) <> "\n" == ~s"""
             <h1 class="xyz" data-val="1" x-val="2" data-x="3" ola="mundo">
             te<!-- :) -->st <a id="user-content-elixir" href="https://elixir-lang.org/" rel="no"></a>
             </h1>
             """

      assert MDEx.to_html!(
               ~s"""
               <p>
               <a href="">empty</a>
               <a href="/">root</a>
               <a href="https://host/">elsewhere</a>
               </p>
               """,
               render: [unsafe_: true],
               features: [
                 sanitize: [
                   link_rel: nil,
                   url_relative: {:rewrite_with_root, {"https://example/root/", "index.html"}}
                 ]
               ]
             ) <> "\n" == ~s"""
             <p>
             <a href="https://example/root/index.html">empty</a>
             <a href="https://example/root/">root</a>
             <a href="https://host/">elsewhere</a>
             </p>
             """
    end

    test "encode curly braces in inline code" do
      assert_output(
        ~S"""
        `{:mdex, "~> 0.1"}`
        """,
        ~S"""
        <p><code>&lbrace;:mdex, &quot;~&gt; 0.1&quot;&rbrace;</code></p>
        """
      )
    end

    test "preserve curly braces outside inline code" do
      assert_output(
        ~S"""
        # {Title} `{:code}`

        - Elixir {:ex}

        ```elixir
        {:ok, "code"}
        ```
        """,
        ~S"""
        <h1>{Title} <code>&lbrace;:code&rbrace;</code></h1>
        <ul>
        <li>Elixir {:ex}</li>
        </ul>
        <pre class="autumn-hl" style="background-color: #282C34; color: #ABB2BF;"><code class="language-elixir" translate="no"><span class="ahl-punctuation ahl-bracket" style="color: #ABB2BF;">&lbrace;</span><span class="ahl-string ahl-special ahl-symbol" style="color: #98C379;">:ok</span><span class="ahl-punctuation ahl-delimiter" style="color: #ABB2BF;">,</span> <span class="ahl-string" style="color: #98C379;">&quot;code&quot;</span><span class="ahl-punctuation ahl-bracket" style="color: #ABB2BF;">&rbrace;</span>
        </code></pre>
        """
      )
    end
  end

  describe "safe html" do
    test "sanitize" do
      assert MDEx.safe_html("<span>tag</span><script>console.log('hello')</script>",
               sanitize: MDEx.default_sanitize_options(),
               escape: [content: false, curly_braces_in_code: false]
             ) == "<span>tag</span>"
    end

    test "escape tags" do
      assert MDEx.safe_html("<span>content</span>",
               sanitize: nil,
               escape: [content: true, curly_braces_in_code: false]
             ) == "&lt;span&gt;content&lt;&#x2f;span&gt;"
    end

    test "escape curly braces in code tags" do
      assert MDEx.safe_html("<h1>{test}</h1><code>{:foo}</code>",
               sanitize: nil,
               escape: [content: false, curly_braces_in_code: true]
             ) == "<h1>{test}</h1><code>&lbrace;:foo&rbrace;</code>"
    end

    test "enable all by default" do
      assert MDEx.safe_html(
               "<span>{:example} <code class=\"lang-ex\" data-foo=\"{:val}\">{:ok, 'foo'}</code></span><script>console.log('hello')</script>"
             ) ==
               "&lt;span&gt;{:example} &lt;code&gt;&lbrace;:ok, &#x27;foo&#x27;&rbrace;&lt;&#x2f;code&gt;&lt;&#x2f;span&gt;"
    end
  end

  describe "to_markdown" do
    test "document to markdown with default options" do
      assert MDEx.to_markdown!(%Document{nodes: [%Heading{nodes: [%Text{literal: "Test"}]}]}) == "# Test"
    end
  end
end
