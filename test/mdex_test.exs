defmodule MDExTest do
  use ExUnit.Case, async: true
  alias MDEx.Document
  alias MDEx.Heading
  alias MDEx.Text
  doctest MDEx, except: [to_json: 1, to_json: 2, rendered_to_html: 1]

  defp assert_output(input, expected, opts \\ []) do
    assert {:ok, html} = MDEx.to_html(input, opts)
    # IO.puts(html)
    assert html == String.trim(expected)
  end

  describe "deprecated still works" do
    test "inline_style: true" do
      assert_output(
        ~S"""
        ```elixir
        {:mdex, "~> 0.1"}
        ```
        """,
        ~S"""
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-elixir" translate="no" tabindex="0"><span class="line" data-line="1"><span style="color: #c678dd;">&lbrace;</span><span style="color: #e06c75;">:mdex</span><span style="color: #abb2bf;">,</span> <span style="color: #98c379;">&quot;~&gt; 0.1&quot;</span><span style="color: #c678dd;">&rbrace;</span>
        </span></code></pre>
        """,
        features: [syntax_highlight_inline_style: true]
      )
    end

    test "inline_style: false" do
      assert_output(
        ~S"""
        ```elixir
        {:mdex, "~> 0.1"}
        ```
        """,
        ~S"""
        <pre class="athl"><code class="language-elixir" translate="no" tabindex="0"><span class="line" data-line="1"><span class="punctuation-bracket">&lbrace;</span><span class="string-special-symbol">:mdex</span><span class="punctuation-delimiter">,</span> <span class="string">&quot;~&gt; 0.1&quot;</span><span class="punctuation-bracket">&rbrace;</span>
        </span></code></pre>
        """,
        features: [syntax_highlight_inline_style: false]
      )
    end

    test "theme" do
      assert_output(
        ~S"""
        ```elixir
        {:mdex, "~> 0.1"}
        ```
        """,
        ~S"""
        <pre class="athl" style="color: #f8f8f2; background-color: #282a36;"><code class="language-elixir" translate="no" tabindex="0"><span class="line" data-line="1"><span style="color: #f8f8f2;">&lbrace;</span><span style="color: #bd93f9;">:mdex</span><span style="color: #f8f8f2;">,</span> <span style="color: #f1fa8c;">&quot;~&gt; 0.1&quot;</span><span style="color: #f8f8f2;">&rbrace;</span>
        </span></code></pre>
        """,
        features: [syntax_highlight_theme: "Dracula"]
      )
    end

    test "sanitize nil (disabled)" do
      assert MDEx.to_html!("<script>hello</script>", render: [unsafe: true], features: [sanitize: nil]) == "<script>hello</script>"
    end

    test "sanitize false (disabled)" do
      assert MDEx.to_html!("<script>hello</script>", render: [unsafe: true], features: [sanitize: false]) == "<script>hello</script>"
    end

    test "sanitize true (enabled)" do
      assert MDEx.to_html!("<script>hello</script>", render: [unsafe: true], features: [sanitize: true]) == ""
    end

    test "sanitize with default options" do
      default_options = MDEx.default_sanitize_options()
      assert MDEx.to_html!("<h1>test</h1>", render: [unsafe: true], features: [sanitize: default_options]) == "<h1>test</h1>"
    end

    test "unsafe_" do
      assert MDEx.to_html!("<script>hello</script>", render: [unsafe_: true]) == "<script>hello</script>"
    end
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

  describe "new" do
    test "default" do
      assert %MDEx.Pipe{
               document: nil,
               options: [
                 document: "",
                 extension: [],
                 parse: [],
                 render: [],
                 syntax_highlight: [],
                 sanitize: nil
               ],
               halted: false
             } = MDEx.new()
    end

    test "with options" do
      assert %MDEx.Pipe{
               options: [
                 document: "new",
                 extension: [],
                 parse: [],
                 render: [escape: true],
                 syntax_highlight: [],
                 sanitize: nil
               ]
             } = MDEx.new(document: "new", render: [escape: true])
    end
  end

  describe "syntax highlighting" do
    test "enabled by default" do
      expected =
        String.trim(~S"""
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-elixir" translate="no" tabindex="0"><span class="line" data-line="1"><span style="color: #c678dd;">&lbrace;</span><span style="color: #e06c75;">:mdex</span><span style="color: #abb2bf;">,</span> <span style="color: #98c379;">&quot;~&gt; 0.1&quot;</span><span style="color: #c678dd;">&rbrace;</span>
        </span></code></pre>
        """)

      assert {:ok, expected} ==
               MDEx.to_html(~S"""
               ```elixir
               {:mdex, "~> 0.1"}
               ```
               """)

      assert {:ok, expected} ==
               MDEx.to_html(
                 ~S"""
                 ```elixir
                 {:mdex, "~> 0.1"}
                 ```
                 """,
                 []
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
        <pre class="athl" style="color: #d8dee9; background-color: #2e3440;"><code class="language-elixir" translate="no" tabindex="0"><span class="line" data-line="1"><span style="color: #88c0d0;">&lbrace;</span><span style="color: #ebcb8b;">:mdex</span><span style="color: #88c0d0;">,</span> <span style="color: #a3be8c;">&quot;~&gt; 0.1&quot;</span><span style="color: #88c0d0;">&rbrace;</span>
        </span></code></pre>
        """,
        syntax_highlight: [formatter: {:html_inline, theme: "nord"}]
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
        syntax_highlight: nil
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
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-plaintext" translate="no" tabindex="0"><span class="line" data-line="1">&lbrace;:mdex, &quot;~&gt; 0.1&quot;&rbrace;
        </span></code></pre>
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
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-plaintext" translate="no" tabindex="0"><span class="line" data-line="1">&lbrace;:mdex, &quot;~&gt; 0.1&quot;&rbrace;
        </span></code></pre>
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
        <pre class="athl"><code class="language-elixir" translate="no" tabindex="0"><span class="line" data-line="1"><span class="punctuation-bracket">&lbrace;</span><span class="string-special-symbol">:mdex</span><span class="punctuation-delimiter">,</span> <span class="string">&quot;~&gt; 0.1&quot;</span><span class="punctuation-bracket">&rbrace;</span>
        </span></code></pre>
        """,
        syntax_highlight: [formatter: :html_linked]
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
      assert MDEx.to_html!("<h1>test</h1>", render: [unsafe: true]) == "<h1>test</h1>"
    end

    test "sanitize unsafe raw html" do
      sanitize_options = MDEx.default_sanitize_options()

      assert MDEx.to_html!("<h1>test</h1>", render: [unsafe: true], sanitize: sanitize_options) == "<h1>test</h1>"

      assert MDEx.to_html!("<a href=https://elixir-lang.org/>Elixir</a>", render: [unsafe: true], sanitize: sanitize_options) ==
               "<p><a href=\"https://elixir-lang.org/\" rel=\"noopener noreferrer\">Elixir</a></p>"

      assert MDEx.to_html!("<a href=https://elixir-lang.org/><script>attack</script></a>",
               render: [unsafe: true],
               sanitize: sanitize_options
             ) ==
               "<p><a href=\"https://elixir-lang.org/\" rel=\"noopener noreferrer\"></a></p>"
    end

    test "range of sanitize specifications" do
      input = ~s"""
      <h1 class="abc xyz" e="f" f="g" data-val="1" x-val="2" data-x="3">
      <strong>te<!-- :) -->st</strong> <a id="elixir" href="https://elixir-lang.org/"></a>
      </h1>
      """

      assert MDEx.to_html!(input, render: [unsafe: true], sanitize: MDEx.default_sanitize_options()) <> "\n" == ~s"""
             <h1>
             <strong>test</strong> <a href="https://elixir-lang.org/" rel="noopener noreferrer"></a>
             </h1>
             """

      assert MDEx.to_html!(input,
               render: [unsafe: true],
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
               render: [unsafe: true],
               sanitize: [
                 link_rel: nil,
                 url_relative: {:rewrite_with_root, {"https://example/root/", "index.html"}}
               ]
             ) <> "\n" == ~s"""
             <p>
             <a href="https://example/root/index.html">empty</a>
             <a href="https://example/root/">root</a>
             <a href="https://host/">elsewhere</a>
             </p>
             """
    end

    test "conflicting sanitization rules" do
      assert_output(
        ~S"""
        <pre><code>example</code></pre>

        ```elixir
        {:mdex, "~> 0.1"}
        ```
        """,
        ~S"""
        <pre>example</pre>
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><span class="line" data-line="1"><span style="color: #c678dd;">{</span><span style="color: #e06c75;">:mdex</span><span style="color: #abb2bf;">,</span> <span style="color: #98c379;">"~&gt; 0.1"</span><span style="color: #c678dd;">}</span>
        </span></pre>
        """,
        render: [unsafe: true],
        sanitize: [
          add_tags: ["code"],
          rm_tags: ["code"]
        ]
      )
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

    test "encode curly braces in inline code with sanitize enabled" do
      assert_output(
        ~S"""
        `{:mdex, "~> 0.1"}`

        ```elixir
        {:mdex, "~> 0.1"}
        ```
        """,
        ~S"""
        <p><code>&lbrace;:mdex, "~&gt; 0.1"&rbrace;</code></p>
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-elixir" translate="no" tabindex="0"><span class="line" data-line="1"><span style="color: #c678dd;">&lbrace;</span><span style="color: #e06c75;">:mdex</span><span style="color: #abb2bf;">,</span> <span style="color: #98c379;">"~&gt; 0.1"</span><span style="color: #c678dd;">&rbrace;</span>
        </span></code></pre>
        """,
        sanitize: MDEx.default_sanitize_options()
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
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-elixir" translate="no" tabindex="0"><span class="line" data-line="1"><span style="color: #c678dd;">&lbrace;</span><span style="color: #e06c75;">:ok</span><span style="color: #abb2bf;">,</span> <span style="color: #98c379;">&quot;code&quot;</span><span style="color: #c678dd;">&rbrace;</span>
        </span></code></pre>
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
               "&lt;span&gt;{:example} &lt;code class=&quot;lang-ex&quot;&gt;&lbrace;:ok, &#x27;foo&#x27;&rbrace;&lt;&#x2f;code&gt;&lt;&#x2f;span&gt;"
    end
  end

  describe "to_markdown" do
    test "document to markdown with default options" do
      assert MDEx.to_markdown!(%Document{nodes: [%Heading{nodes: [%Text{literal: "Test"}]}]}) == "# Test"
    end
  end

  describe "url rewriter" do
    test "image_url_rewrite with {@url}" do
      assert_output(
        ~S"""
        ![alt text](http://unsafe.com/image.png)
        """,
        ~S"""
        <p><img src="https://safe.example.com?url=http://unsafe.com/image.png" alt="alt text" /></p>
        """,
        extension: [image_url_rewriter: "https://safe.example.com?url={@url}"]
      )
    end

    test "image_url_rewrite without {@url}" do
      assert_output(
        ~S"""
        ![alt text](http://unsafe.com/image.png)
        """,
        ~S"""
        <p><img src="https://other.example.com/other.png" alt="alt text" /></p>
        """,
        extension: [image_url_rewriter: "https://other.example.com/other.png"]
      )
    end

    test "link_url_rewrite with {@url}" do
      assert_output(
        ~S"""
        [my link](http://unsafe.example.com/bad)
        """,
        ~S"""
        <p><a href="https://safe.example.com/norefer?url=http://unsafe.example.com/bad">my link</a></p>
        """,
        extension: [link_url_rewriter: "https://safe.example.com/norefer?url={@url}"]
      )
    end

    test "link_url_rewrite without {@url}" do
      assert_output(
        ~S"""
        [my link](http://unsafe.example.com/bad)
        """,
        ~S"""
        <p><a href="https://other.example.com">my link</a></p>
        """,
        extension: [link_url_rewriter: "https://other.example.com"]
      )
    end
  end

  describe "code block decorators" do
    test "theme" do
      assert_output(
        ~S"""
        ```elixir theme=github_light
        @lang :elixir
        ```
        """,
        ~S"""
        <pre class="athl" style="color: #1f2328; background-color: #ffffff;"><code class="language-elixir" translate="no" tabindex="0"><span class="line" data-line="1"><span style="color: #0550ae;"><span style="color: #0550ae;">@<span style="color: #6639ba;"><span style="color: #0550ae;">lang <span style="color: #0550ae;">:elixir</span></span></span></span></span>
        </span></code></pre>
        """,
        render: [github_pre_lang: true, full_info_string: true]
      )
    end

    test "pre_class" do
      assert_output(
        ~S"""
        ```elixir pre_class="custom-class another-class"
        @lang :elixir
        ```
        """,
        ~S"""
        <pre class="athl custom-class another-class" style="color: #abb2bf; background-color: #282c34;"><code class="language-elixir" translate="no" tabindex="0"><span class="line" data-line="1"><span style="color: #56b6c2;"><span style="color: #d19a66;">@<span style="color: #61afef;"><span style="color: #d19a66;">lang <span style="color: #e06c75;">:elixir</span></span></span></span></span>
        </span></code></pre>
        """,
        render: [github_pre_lang: true, full_info_string: true]
      )
    end

    test "highlight_lines with single line" do
      assert_output(
        ~S"""
        ```elixir highlight_lines="1"
        @lang :elixir
        def hello, do: "world"
        ```
        """,
        ~S"""
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-elixir" translate="no" tabindex="0"><span class="line" style="background-color: #414858;" data-line="1"><span style="color: #56b6c2;"><span style="color: #d19a66;">@<span style="color: #61afef;"><span style="color: #d19a66;">lang <span style="color: #e06c75;">:elixir</span></span></span></span></span>
        </span><span class="line" data-line="2"><span style="color: #c678dd;">def</span> <span style="color: #e06c75;">hello</span><span style="color: #abb2bf;">,</span> <span style="color: #e06c75;">do: </span><span style="color: #98c379;">&quot;world&quot;</span>
        </span></code></pre>
        """,
        render: [github_pre_lang: true, full_info_string: true]
      )
    end

    test "highlight_lines with range" do
      assert_output(
        ~S"""
        ```elixir highlight_lines="1-2"
        @lang :elixir
        def hello, do: "world"
        ```
        """,
        ~S"""
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-elixir" translate="no" tabindex="0"><span class="line" style="background-color: #414858;" data-line="1"><span style="color: #56b6c2;"><span style="color: #d19a66;">@<span style="color: #61afef;"><span style="color: #d19a66;">lang <span style="color: #e06c75;">:elixir</span></span></span></span></span>
        </span><span class="line" style="background-color: #414858;" data-line="2"><span style="color: #c678dd;">def</span> <span style="color: #e06c75;">hello</span><span style="color: #abb2bf;">,</span> <span style="color: #e06c75;">do: </span><span style="color: #98c379;">&quot;world&quot;</span>
        </span></code></pre>
        """,
        render: [github_pre_lang: true, full_info_string: true]
      )
    end

    test "highlight_lines with mixed single and range" do
      assert_output(
        ~S"""
        ```elixir highlight_lines="1,3-4"
        @lang :elixir
        def hello, do: "world"
        def greet(name), do: "Hello, #{name}!"
        IO.puts(greet("Elixir"))
        ```
        """,
        ~S"""
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-elixir" translate="no" tabindex="0"><span class="line" style="background-color: #414858;" data-line="1"><span style="color: #56b6c2;"><span style="color: #d19a66;">@<span style="color: #61afef;"><span style="color: #d19a66;">lang <span style="color: #e06c75;">:elixir</span></span></span></span></span>
        </span><span class="line" data-line="2"><span style="color: #c678dd;">def</span> <span style="color: #e06c75;">hello</span><span style="color: #abb2bf;">,</span> <span style="color: #e06c75;">do: </span><span style="color: #98c379;">&quot;world&quot;</span>
        </span><span class="line" style="background-color: #414858;" data-line="3"><span style="color: #c678dd;">def</span> <span style="color: #61afef;">greet</span><span style="color: #c678dd;">(</span><span style="color: #e06c75;">name</span><span style="color: #c678dd;">)</span><span style="color: #abb2bf;">,</span> <span style="color: #e06c75;">do: </span><span style="color: #98c379;">&quot;Hello, <span style="color: #61afef;">#&lbrace;</span><span style="color: #e06c75;">name</span><span style="color: #61afef;">&rbrace;</span>!&quot;</span>
        </span><span class="line" style="background-color: #414858;" data-line="4"><span style="color: #e5c07b;">IO</span><span style="color: #56b6c2;">.</span><span style="color: #61afef;">puts</span><span style="color: #c678dd;">(</span><span style="color: #61afef;">greet</span><span style="color: #c678dd;">(</span><span style="color: #98c379;">&quot;Elixir&quot;</span><span style="color: #c678dd;">)</span><span style="color: #c678dd;">)</span>
        </span></code></pre>
        """,
        render: [github_pre_lang: true, full_info_string: true]
      )
    end

    test "highlight_lines_style with custom style" do
      assert_output(
        ~S"""
        ```elixir highlight_lines="1" highlight_lines_style="background-color: yellow; font-weight: bold;"
        @lang :elixir
        def hello, do: "world"
        ```
        """,
        ~S"""
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-elixir" translate="no" tabindex="0"><span class="line" style="background-color: yellow; font-weight: bold;" data-line="1"><span style="color: #56b6c2;"><span style="color: #d19a66;">@<span style="color: #61afef;"><span style="color: #d19a66;">lang <span style="color: #e06c75;">:elixir</span></span></span></span></span>
        </span><span class="line" data-line="2"><span style="color: #c678dd;">def</span> <span style="color: #e06c75;">hello</span><span style="color: #abb2bf;">,</span> <span style="color: #e06c75;">do: </span><span style="color: #98c379;">&quot;world&quot;</span>
        </span></code></pre>
        """,
        render: [github_pre_lang: true, full_info_string: true]
      )
    end

    test "include_highlights" do
      assert_output(
        ~S"""
        ```elixir include_highlights
        @lang :elixir
        ```
        """,
        ~S"""
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-elixir" translate="no" tabindex="0"><span class="line" data-line="1"><span data-highlight="operator" style="color: #56b6c2;"><span data-highlight="constant" style="color: #d19a66;">@<span data-highlight="function.call" style="color: #61afef;"><span data-highlight="constant" style="color: #d19a66;">lang <span data-highlight="string.special.symbol" style="color: #e06c75;">:elixir</span></span></span></span></span>
        </span></code></pre>
        """,
        render: [github_pre_lang: true, full_info_string: true]
      )
    end

    test "multiple decorators combined" do
      assert_output(
        ~S"""
        ```elixir theme=github_light pre_class="custom-pre" highlight_lines="1" include_highlights
        @lang :elixir
        def hello, do: "world"
        ```
        """,
        ~S"""
        <pre class="athl custom-pre" style="color: #1f2328; background-color: #ffffff;"><code class="language-elixir" translate="no" tabindex="0"><span class="line" style="background-color: #dae9f9;" data-line="1"><span data-highlight="operator" style="color: #0550ae;"><span data-highlight="constant" style="color: #0550ae;">@<span data-highlight="function.call" style="color: #6639ba;"><span data-highlight="constant" style="color: #0550ae;">lang <span data-highlight="string.special.symbol" style="color: #0550ae;">:elixir</span></span></span></span></span>
        </span><span class="line" data-line="2"><span data-highlight="keyword" style="color: #cf222e;">def</span> <span data-highlight="variable" style="color: #1f2328;">hello</span><span data-highlight="punctuation.delimiter" style="color: #1f2328;">,</span> <span data-highlight="string.special.symbol" style="color: #0550ae;">do: </span><span data-highlight="string" style="color: #0a3069;">&quot;world&quot;</span>
        </span></code></pre>
        """,
        render: [github_pre_lang: true, full_info_string: true]
      )
    end
  end
end
