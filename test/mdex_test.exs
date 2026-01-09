defmodule MDExTest do
  use ExUnit.Case, async: true
  alias MDEx.Document
  alias MDEx.Heading
  alias MDEx.Text
  import ExUnit.CaptureIO

  doctest MDEx,
    import: true,
    except: [
      :moduledoc,
      to_json: 1,
      to_json: 2,
      to_json!: 1,
      to_json!: 2,
      parse_document: 1,
      parse_document: 2,
      parse_document!: 1,
      parse_document!: 2,
      traverse_and_update: 2,
      traverse_and_update: 3,
      source: 0
    ]

  defp assert_output(input, expected, opts \\ []) do
    assert {:ok, html} = MDEx.to_html(input, opts)
    # IO.puts(html)
    assert html == String.trim(expected)
  end

  describe "option handling" do
    test "inline syntax highlighting" do
      assert_output(
        ~S"""
        ```elixir
        {:mdex, "~> 0.1"}
        ```
        """,
        ~S"""
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-elixir" translate="no" tabindex="0"><div class="line" data-line="1"><span style="color: #c678dd;">&lbrace;</span><span style="color: #e06c75;">:mdex</span><span style="color: #abb2bf;">,</span> <span style="color: #98c379;">&quot;~&gt; 0.1&quot;</span><span style="color: #c678dd;">&rbrace;</span>
        </div></code></pre>
        """,
        syntax_highlight: [formatter: {:html_inline, theme: "onedark"}]
      )
    end

    test "linked syntax highlighting" do
      assert_output(
        ~S"""
        ```elixir
        {:mdex, "~> 0.1"}
        ```
        """,
        ~S"""
        <pre class="athl"><code class="language-elixir" translate="no" tabindex="0"><div class="line" data-line="1"><span class="punctuation-bracket">&lbrace;</span><span class="string-special-symbol">:mdex</span><span class="punctuation-delimiter">,</span> <span class="string">&quot;~&gt; 0.1&quot;</span><span class="punctuation-bracket">&rbrace;</span>
        </div></code></pre>
        """,
        syntax_highlight: [formatter: {:html_linked, []}]
      )
    end

    test "custom syntax highlight theme" do
      assert_output(
        ~S"""
        ```elixir
        {:mdex, "~> 0.1"}
        ```
        """,
        ~S"""
        <pre class="athl" style="color: #f8f8f2; background-color: #282a36;"><code class="language-elixir" translate="no" tabindex="0"><div class="line" data-line="1"><span style="color: #f8f8f2;">&lbrace;</span><span style="color: #bd93f9;">:mdex</span><span style="color: #f8f8f2;">,</span> <span style="color: #f1fa8c;">&quot;~&gt; 0.1&quot;</span><span style="color: #f8f8f2;">&rbrace;</span>
        </div></code></pre>
        """,
        syntax_highlight: [formatter: {:html_inline, theme: "Dracula"}]
      )
    end

    test "sanitize nil (disabled)" do
      assert MDEx.to_html!("<script>hello</script>", render: [unsafe: true], sanitize: nil) == "<script>hello</script>"
    end

    test "sanitize with default options" do
      default_options = MDEx.Document.default_sanitize_options()
      assert MDEx.to_html!("<h1>test</h1>", render: [unsafe: true], sanitize: default_options) == "<h1>test</h1>"
    end

    test "unsafe_" do
      assert MDEx.to_html!("<script>hello</script>", render: [unsafe_: true]) == "<script>hello</script>"
    end
  end

  describe "to_html" do
    test "wrap fragment in root document" do
      assert MDEx.to_html(%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "mdex"}]}) == {:ok, "<p>mdex</p>"}
    end

    test "incomplete document struct" do
      assert MDEx.to_html!(%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "lang = :elixir"}]}]}) ==
               "<p><code>lang = :elixir</code></p>"
    end

    test "deprecated :document option still works" do
      warning =
        capture_io(:stderr, fn ->
          assert {:ok, "<h1>Hello</h1>"} = MDEx.to_html(MDEx.new(), document: "# Hello")
        end)

      assert warning =~ "option :document is deprecated"
    end
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
    test "with options" do
      assert %MDEx.Document{
               nodes: [
                 %MDEx.Heading{
                   nodes: [
                     %MDEx.Text{literal: "new"}
                   ],
                   level: 1,
                   setext: false
                 }
               ],
               options: options
             } =
               MDEx.new(markdown: "# new", render: [escape: true])
               |> MDEx.Document.run()

      assert get_in(options, [:render, :escape])
    end
  end

  describe "syntax highlighting" do
    test "enabled by default" do
      expected =
        String.trim(~S"""
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-elixir" translate="no" tabindex="0"><div class="line" data-line="1"><span style="color: #c678dd;">&lbrace;</span><span style="color: #e06c75;">:mdex</span><span style="color: #abb2bf;">,</span> <span style="color: #98c379;">&quot;~&gt; 0.1&quot;</span><span style="color: #c678dd;">&rbrace;</span>
        </div></code></pre>
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
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-plaintext" translate="no" tabindex="0"><div class="line" data-line="1">&lbrace;:mdex, &quot;~&gt; 0.1&quot;&rbrace;
        </div></code></pre>
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
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-plaintext" translate="no" tabindex="0"><div class="line" data-line="1">&lbrace;:mdex, &quot;~&gt; 0.1&quot;&rbrace;
        </div></code></pre>
        """
      )
    end
  end

  describe "syntax highlighting - html_inline" do
    test "default options" do
      assert_output(
        ~S"""
        ```elixir
        {:mdex, "~> 0.1"}
        ```
        """,
        ~S"""
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-elixir" translate="no" tabindex="0"><div class="line" data-line="1"><span style="color: #c678dd;">&lbrace;</span><span style="color: #e06c75;">:mdex</span><span style="color: #abb2bf;">,</span> <span style="color: #98c379;">&quot;~&gt; 0.1&quot;</span><span style="color: #c678dd;">&rbrace;</span>
        </div></code></pre>
        """,
        syntax_highlight: [formatter: :html_inline]
      )
    end

    test "built-in theme" do
      assert_output(
        ~S"""
        ```elixir
        {:mdex, "~> 0.1"}
        ```
        """,
        ~S"""
        <pre class="athl" style="color: #d8dee9; background-color: #2e3440;"><code class="language-elixir" translate="no" tabindex="0"><div class="line" data-line="1"><span style="color: #88c0d0;">&lbrace;</span><span style="color: #ebcb8b;">:mdex</span><span style="color: #88c0d0;">,</span> <span style="color: #a3be8c;">&quot;~&gt; 0.1&quot;</span><span style="color: #88c0d0;">&rbrace;</span>
        </div></code></pre>
        """,
        syntax_highlight: [formatter: {:html_inline, theme: "nord"}]
      )
    end

    test "custom theme" do
      theme = Autumn.Theme.get("github_light")

      function_call_style =
        %Autumn.Theme.Style{
          fg: "#d1242f",
          bg: "#e4b7be",
          bold: true
        }

      custom_theme =
        put_in(
          theme,
          [Access.key!(:highlights), Access.key!("function.call")],
          function_call_style
        )

      assert_output(
        ~S"""
        ```elixir
        {:mdex, "~> 0.1"}
        ```
        """,
        ~S"""
        <pre class="athl" style="color: #1f2328; background-color: #ffffff;"><code class="language-elixir" translate="no" tabindex="0"><div class="line" data-line="1"><span style="color: #1f2328;">&lbrace;</span><span style="color: #0550ae;">:mdex</span><span style="color: #1f2328;">,</span> <span style="color: #0a3069;">&quot;~&gt; 0.1&quot;</span><span style="color: #1f2328;">&rbrace;</span>
        </div></code></pre>
        """,
        syntax_highlight: [formatter: {:html_inline, theme: custom_theme}]
      )
    end
  end

  describe "syntax highlighting - html_linked" do
    test "default options" do
      assert_output(
        ~S"""
        ```elixir
        {:mdex, "~> 0.1"}
        ```
        """,
        ~S"""
        <pre class="athl"><code class="language-elixir" translate="no" tabindex="0"><div class="line" data-line="1"><span class="punctuation-bracket">&lbrace;</span><span class="string-special-symbol">:mdex</span><span class="punctuation-delimiter">,</span> <span class="string">&quot;~&gt; 0.1&quot;</span><span class="punctuation-bracket">&rbrace;</span>
        </div></code></pre>
        """,
        syntax_highlight: [formatter: :html_linked]
      )
    end
  end

  describe "syntax highlighting - html_multi_themes" do
    test "with themes" do
      {:ok, html} =
        MDEx.to_html(
          ~S"""
          ```elixir
          {:mdex, "~> 0.1"}
          ```
          """,
          syntax_highlight: [formatter: {:html_multi_themes, themes: [light: "github_light", dark: "github_dark"]}]
        )

      assert html =~ ~s(--athl-light: #1f2328)
      assert html =~ ~s(--athl-dark: #e6edf3)
    end
  end

  test "render emoji shortcodes" do
    assert_output(":rocket:", "<p>🚀</p>\n", extension: [shortcodes: true])
  end

  describe "parse_document" do
    test "markdown" do
      assert %MDEx.Document{
               nodes: [%MDEx.Heading{level: 1, setext: false, nodes: [%MDEx.Text{literal: "Test"}]}]
             } = MDEx.parse_document!("# Test")

      assert %MDEx.Document{
               nodes: [
                 %MDEx.HtmlBlock{
                   nodes: [],
                   block_type: 1,
                   literal: "<script type=\"module\">\n  mermaid.initialize({ startOnLoad: true })\n</script>\n"
                 }
               ]
             } =
               MDEx.parse_document!("""
               <script type="module">
                 mermaid.initialize({ startOnLoad: true })
               </script>
               """)
    end

    test "json" do
      json = MDEx.to_json!("# Test")

      assert %MDEx.Document{
               nodes: [%MDEx.Heading{level: 1, setext: false, nodes: [%MDEx.Text{literal: "Test"}]}]
             } = MDEx.parse_document!({:json, json})
    end
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

    # https://github.com/leandrocp/mdex/issues/263
    test "preserve html entities with unsafe render" do
      assert MDEx.to_html!("<b>test</b> &lt;b&gt;test2&lt;/b&gt;", render: [unsafe: true]) ==
               "<p><b>test</b> &lt;b&gt;test2&lt;/b&gt;</p>"
    end

    test "sanitize unsafe raw html" do
      sanitize_options = MDEx.Document.default_sanitize_options()

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

      assert MDEx.to_html!(input, render: [unsafe: true], sanitize: MDEx.Document.default_sanitize_options()) <> "\n" == ~s"""
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
        """,
        ~S"""
        <pre>example</pre>
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
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-elixir" translate="no" tabindex="0"><div><span style="color: #c678dd;">&lbrace;</span><span style="color: #e06c75;">:mdex</span><span style="color: #abb2bf;">,</span> <span style="color: #98c379;">"~&gt; 0.1"</span><span style="color: #c678dd;">&rbrace;</span>
        </div></code></pre>
        """,
        sanitize: MDEx.Document.default_sanitize_options()
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
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-elixir" translate="no" tabindex="0"><div class="line" data-line="1"><span style="color: #c678dd;">&lbrace;</span><span style="color: #e06c75;">:ok</span><span style="color: #abb2bf;">,</span> <span style="color: #98c379;">&quot;code&quot;</span><span style="color: #c678dd;">&rbrace;</span>
        </div></code></pre>
        """
      )
    end
  end

  describe "safe html" do
    test "sanitize" do
      assert MDEx.safe_html("<span>tag</span><script>console.log('hello')</script>",
               sanitize: MDEx.Document.default_sanitize_options(),
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

  describe "html_inline: code block decorators" do
    test "pre_class" do
      assert_output(
        ~S"""
        ```elixir pre_class="custom-class another-class"
        @lang :elixir
        ```
        """,
        ~S"""
        <pre class="athl custom-class another-class" style="color: #abb2bf; background-color: #282c34;"><code class="language-elixir" translate="no" tabindex="0"><div class="line" data-line="1"><span style="color: #d19a66;">@</span><span style="color: #d19a66;">lang </span><span style="color: #e06c75;">:elixir</span>
        </div></code></pre>
        """,
        render: [github_pre_lang: true, full_info_string: true]
      )
    end

    test "theme" do
      assert_output(
        ~S"""
        ```elixir theme=dracula
        :hello
        ```
        """,
        ~S"""
        <pre class="athl" style="color: #f8f8f2; background-color: #282a36;"><code class="language-elixir" translate="no" tabindex="0"><div class="line" data-line="1"><span style="color: #bd93f9;">:hello</span>
        </div></code></pre>
        """,
        render: [github_pre_lang: true, full_info_string: true]
      )
    end

    test "include_highlights" do
      assert_output(
        ~S"""
        ```elixir include_highlights
        defmodule Example do
        end
        ```
        """,
        ~S"""
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-elixir" translate="no" tabindex="0"><div class="line" data-line="1"><span data-highlight="keyword" style="color: #c678dd;">defmodule</span> <span data-highlight="module" style="color: #e5c07b;">Example</span> <span data-highlight="keyword" style="color: #c678dd;">do</span>
        </div><div class="line" data-line="2"><span data-highlight="keyword" style="color: #c678dd;">end</span>
        </div></code></pre>
        """,
        render: [github_pre_lang: true, full_info_string: true]
      )
    end

    test "highlight_lines single line" do
      assert_output(
        ~S"""
        ```elixir highlight_lines="2"
        defmodule Example do
          def hello, do: :world
        end
        ```
        """,
        ~S"""
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-elixir" translate="no" tabindex="0"><div class="line" data-line="1"><span style="color: #c678dd;">defmodule</span> <span style="color: #e5c07b;">Example</span> <span style="color: #c678dd;">do</span>
        </div><div class="line" style="background-color: #3b4252;" data-line="2">  <span style="color: #c678dd;">def</span> <span style="color: #e06c75;">hello</span><span style="color: #abb2bf;">,</span> <span style="color: #e06c75;">do: </span><span style="color: #e06c75;">:world</span>
        </div><div class="line" data-line="3"><span style="color: #c678dd;">end</span>
        </div></code></pre>
        """,
        render: [github_pre_lang: true, full_info_string: true]
      )
    end

    test "highlight_lines range" do
      assert_output(
        ~S"""
        ```elixir highlight_lines="2-3"
        defmodule Example do
          def hello do
            :world
          end
        end
        ```
        """,
        ~S"""
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-elixir" translate="no" tabindex="0"><div class="line" data-line="1"><span style="color: #c678dd;">defmodule</span> <span style="color: #e5c07b;">Example</span> <span style="color: #c678dd;">do</span>
        </div><div class="line" style="background-color: #3b4252;" data-line="2">  <span style="color: #c678dd;">def</span> <span style="color: #e06c75;">hello</span> <span style="color: #c678dd;">do</span>
        </div><div class="line" style="background-color: #3b4252;" data-line="3">    <span style="color: #e06c75;">:world</span>
        </div><div class="line" data-line="4">  <span style="color: #c678dd;">end</span>
        </div><div class="line" data-line="5"><span style="color: #c678dd;">end</span>
        </div></code></pre>
        """,
        render: [github_pre_lang: true, full_info_string: true]
      )
    end

    test "highlight_lines_style custom" do
      assert_output(
        ~S"""
        ```elixir highlight_lines="2" highlight_lines_style="background-color: yellow; font-weight: bold;"
        def hello do
          :world
        end
        ```
        """,
        ~S"""
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-elixir" translate="no" tabindex="0"><div class="line" data-line="1"><span style="color: #c678dd;">def</span> <span style="color: #e06c75;">hello</span> <span style="color: #c678dd;">do</span>
        </div><div class="line" style="background-color: yellow; font-weight: bold;" data-line="2">  <span style="color: #e06c75;">:world</span>
        </div><div class="line" data-line="3"><span style="color: #c678dd;">end</span>
        </div></code></pre>
        """,
        render: [github_pre_lang: true, full_info_string: true]
      )
    end

    test "highlight_lines_style theme" do
      assert_output(
        ~S"""
        ```elixir highlight_lines="1" highlight_lines_style=theme
        :hello
        ```
        """,
        ~S"""
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-elixir" translate="no" tabindex="0"><div class="line" style="background-color: #282c34;" data-line="1"><span style="color: #e06c75;">:hello</span>
        </div></code></pre>
        """,
        render: [github_pre_lang: true, full_info_string: true]
      )
    end

    test "highlight_lines_class" do
      assert_output(
        ~S"""
        ```elixir highlight_lines="2" highlight_lines_class="focus-line"
        def hello do
          :world
        end
        ```
        """,
        ~S"""
        <pre class="athl" style="color: #abb2bf; background-color: #282c34;"><code class="language-elixir" translate="no" tabindex="0"><div class="line" data-line="1"><span style="color: #c678dd;">def</span> <span style="color: #e06c75;">hello</span> <span style="color: #c678dd;">do</span>
        </div><div class="line focus-line" style="background-color: #3b4252;" data-line="2">  <span style="color: #e06c75;">:world</span>
        </div><div class="line" data-line="3"><span style="color: #c678dd;">end</span>
        </div></code></pre>
        """,
        render: [github_pre_lang: true, full_info_string: true]
      )
    end

    test "all combined" do
      assert_output(
        ~S"""
        ```elixir pre_class="my-code" theme=dracula include_highlights highlight_lines="2-3" highlight_lines_style="background-color: #44475a;" highlight_lines_class="hl"
        defmodule Example do
          def hello do
            :world
          end
        end
        ```
        """,
        ~S"""
        <pre class="athl my-code" style="color: #f8f8f2; background-color: #282a36;"><code class="language-elixir" translate="no" tabindex="0"><div class="line" data-line="1"><span data-highlight="keyword" style="color: #ff79c6;">defmodule</span> <span data-highlight="module" style="color: #ffb86c;">Example</span> <span data-highlight="keyword" style="color: #ff79c6;">do</span>
        </div><div class="line hl" style="background-color: #44475a;" data-line="2">  <span data-highlight="keyword" style="color: #ff79c6;">def</span> <span data-highlight="variable" style="color: #f8f8f2;">hello</span> <span data-highlight="keyword" style="color: #ff79c6;">do</span>
        </div><div class="line hl" style="background-color: #44475a;" data-line="3">    <span data-highlight="string.special.symbol" style="color: #bd93f9;">:world</span>
        </div><div class="line" data-line="4">  <span data-highlight="keyword" style="color: #ff79c6;">end</span>
        </div><div class="line" data-line="5"><span data-highlight="keyword" style="color: #ff79c6;">end</span>
        </div></code></pre>
        """,
        render: [github_pre_lang: true, full_info_string: true]
      )
    end
  end

  describe "html_linked: code block decorators" do
    test "pre_class" do
      assert_output(
        ~S"""
        ```elixir pre_class="custom-class another-class"
        @lang :elixir
        ```
        """,
        ~S"""
        <pre class="athl custom-class another-class"><code class="language-elixir" translate="no" tabindex="0"><div class="line" data-line="1"><span class="constant">@</span><span class="constant">lang </span><span class="string-special-symbol">:elixir</span>
        </div></code></pre>
        """,
        render: [github_pre_lang: true, full_info_string: true],
        syntax_highlight: [formatter: :html_linked]
      )
    end

    test "highlight_lines single line" do
      assert_output(
        ~S"""
        ```elixir highlight_lines="2"
        defmodule Example do
          def hello, do: :world
        end
        ```
        """,
        ~S"""
        <pre class="athl"><code class="language-elixir" translate="no" tabindex="0"><div class="line" data-line="1"><span class="keyword">defmodule</span> <span class="module">Example</span> <span class="keyword">do</span>
        </div><div class="line highlighted" data-line="2">  <span class="keyword">def</span> <span class="variable">hello</span><span class="punctuation-delimiter">,</span> <span class="string-special-symbol">do: </span><span class="string-special-symbol">:world</span>
        </div><div class="line" data-line="3"><span class="keyword">end</span>
        </div></code></pre>
        """,
        render: [github_pre_lang: true, full_info_string: true],
        syntax_highlight: [formatter: :html_linked]
      )
    end

    test "highlight_lines range" do
      assert_output(
        ~S"""
        ```elixir highlight_lines="2-3"
        defmodule Example do
          def hello do
            :world
          end
        end
        ```
        """,
        ~S"""
        <pre class="athl"><code class="language-elixir" translate="no" tabindex="0"><div class="line" data-line="1"><span class="keyword">defmodule</span> <span class="module">Example</span> <span class="keyword">do</span>
        </div><div class="line highlighted" data-line="2">  <span class="keyword">def</span> <span class="variable">hello</span> <span class="keyword">do</span>
        </div><div class="line highlighted" data-line="3">    <span class="string-special-symbol">:world</span>
        </div><div class="line" data-line="4">  <span class="keyword">end</span>
        </div><div class="line" data-line="5"><span class="keyword">end</span>
        </div></code></pre>
        """,
        render: [github_pre_lang: true, full_info_string: true],
        syntax_highlight: [formatter: :html_linked]
      )
    end

    test "highlight_lines_class" do
      assert_output(
        ~S"""
        ```elixir highlight_lines="2" highlight_lines_class="focus-line"
        def hello do
          :world
        end
        ```
        """,
        ~S"""
        <pre class="athl"><code class="language-elixir" translate="no" tabindex="0"><div class="line" data-line="1"><span class="keyword">def</span> <span class="variable">hello</span> <span class="keyword">do</span>
        </div><div class="line focus-line" data-line="2">  <span class="string-special-symbol">:world</span>
        </div><div class="line" data-line="3"><span class="keyword">end</span>
        </div></code></pre>
        """,
        render: [github_pre_lang: true, full_info_string: true],
        syntax_highlight: [formatter: :html_linked]
      )
    end

    test "all combined" do
      assert_output(
        ~S"""
        ```elixir pre_class="my-code" highlight_lines="2-3" highlight_lines_class="focus"
        defmodule Example do
          def hello do
            :world
          end
        end
        ```
        """,
        ~S"""
        <pre class="athl my-code"><code class="language-elixir" translate="no" tabindex="0"><div class="line" data-line="1"><span class="keyword">defmodule</span> <span class="module">Example</span> <span class="keyword">do</span>
        </div><div class="line focus" data-line="2">  <span class="keyword">def</span> <span class="variable">hello</span> <span class="keyword">do</span>
        </div><div class="line focus" data-line="3">    <span class="string-special-symbol">:world</span>
        </div><div class="line" data-line="4">  <span class="keyword">end</span>
        </div><div class="line" data-line="5"><span class="keyword">end</span>
        </div></code></pre>
        """,
        render: [github_pre_lang: true, full_info_string: true],
        syntax_highlight: [formatter: :html_linked]
      )
    end
  end

  describe "to_xml" do
    test "converts document to xml" do
      assert {:ok, xml} = MDEx.to_xml("# Hello")

      assert xml =~ ~s(<document xmlns="http://commonmark.org/xml/1.0">)
      assert xml =~ ~s(<heading level="1">)
      assert xml =~ ~s(<text xml:space="preserve">Hello</text>)
    end

    test "converts document to xml!" do
      assert xml = MDEx.to_xml!("# Hello")

      assert xml =~ ~s(<document xmlns="http://commonmark.org/xml/1.0">)
    end

    test "converts fragment to xml" do
      frag = %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "test"}]}

      assert {:ok, xml} = MDEx.to_xml(frag)

      assert xml =~ ~s(<paragraph>)
    end

    test "raises on invalid document" do
      assert_raise MDEx.DecodeError, fn ->
        MDEx.to_xml!(%MDEx.Document{nodes: nil})
      end
    end

    test "returns error on erlang error" do
      assert {:error, %MDEx.DecodeError{}} = MDEx.to_xml(%MDEx.Document{nodes: nil})
    end
  end

  describe "to_json" do
    test "converts fragment to json" do
      frag = %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "test"}]}

      assert {:ok, json} = MDEx.to_json(frag)

      assert %{
               "node_type" => "MDEx.Document",
               "nodes" => [
                 %{
                   "node_type" => "MDEx.Paragraph",
                   "nodes" => [%{"literal" => "test", "node_type" => "MDEx.Text"}]
                 }
               ]
             } = Jason.decode!(json)
    end
  end

  describe "anchorize" do
    test "converts text to anchor" do
      assert MDEx.anchorize("Hello World") == "hello-world"
    end
  end

  describe "parse_document error handling" do
    test "returns error on invalid json" do
      assert {:error, %MDEx.DecodeError{}} = MDEx.parse_document({:json, "invalid"})
    end

    test "raises on invalid json with bang version" do
      assert_raise MDEx.DecodeError, fn ->
        MDEx.parse_document!({:json, "invalid"})
      end
    end
  end

  describe "new with invalid markdown option" do
    test "raises on non-binary markdown" do
      assert_raise ArgumentError, fn ->
        MDEx.new(markdown: :invalid)
      end
    end
  end
end
