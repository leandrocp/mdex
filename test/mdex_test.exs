defmodule MDExTest do
  use ExUnit.Case
  doctest MDEx

  defp assert_output(input, expected, opts \\ []) do
    assert {:ok, html} = MDEx.to_html(input, opts)
    assert html == expected
  end

  test "wrap fragment in root document" do
    assert MDEx.to_html([]) == {:ok, ""}
    assert MDEx.to_html([{"paragraph", %{}, ["mdex"]}]) == {:ok, "<p>mdex</p>\n"}
    assert MDEx.to_html(["mdex", "test"]) == {:ok, "mdextest"}
  end

  describe "to_html error handling" do
    test "invalid ast" do
      assert {:error, %MDEx.DecodeError{reason: :missing_node_field, found: "{<<\"document\">>}"}} = MDEx.to_html([{"document"}], [])

      assert {:error, %MDEx.DecodeError{reason: :node_name_not_string, found: "invalid", kind: "Atom", node: "(invalid, [], [])"}} =
               MDEx.to_html([{:invalid, [], []}], [])

      assert {:error, %MDEx.DecodeError{reason: :unknown_node_name, found: "unknown", node: "(<<\"unknown\">>, [], [])"}} =
               MDEx.to_html([{"unknown", [], []}], [])

      assert {:error,
              %MDEx.DecodeError{
                reason: :missing_attr_field,
                found: "[{<<\"literal\">>}]",
                node: "(<<\"code\">>, [{<<\"literal\">>}], [])"
              }} = MDEx.to_html([{"code", [{"literal"}], []}], [])

      assert {:error, %MDEx.DecodeError{reason: :attr_key_not_string, found: "1", kind: "Integer", node: "(<<\"code\">>, \#{1=><<\"foo\">>}, [])"}} =
               MDEx.to_html([{"code", %{1 => "foo"}, []}], [])

      assert {:error,
              %MDEx.DecodeError{
                reason: :unknown_attr_value,
                attr: "(\"literal\", nil)",
                found: "nil",
                kind: "Atom",
                node: "(<<\"code\">>, \#{<<\"literal\">>=>nil}, [])"
              }} =
               MDEx.to_html([{"code", %{"literal" => nil}, []}], [])
    end
  end

  describe "to_commonmark error handling" do
    test "invalid ast" do
      assert {:error, %MDEx.DecodeError{found: "[]", reason: :empty}} = MDEx.to_commonmark([])
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
        <pre class="autumn-hl" style="background-color: #282C34; color: #ABB2BF;"><code class="language-elixir" translate="no"><span class="ahl-punctuation ahl-bracket" style="color: #ABB2BF;">{</span><span class="ahl-string ahl-special ahl-symbol" style="color: #98C379;">:mdex</span><span class="ahl-punctuation ahl-delimiter" style="color: #ABB2BF;">,</span> <span class="ahl-string" style="color: #98C379;">&quot;~&gt; 0.1&quot;</span><span class="ahl-punctuation ahl-bracket" style="color: #ABB2BF;">}</span>
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
        <pre class="autumn-hl" style="background-color: #2e3440; color: #D8DEE9;"><code class="language-elixir" translate="no"><span class="ahl-punctuation ahl-bracket" style="color: #ECEFF4;">{</span><span class="ahl-string ahl-special ahl-symbol" style="color: #EBCB8B;">:mdex</span><span class="ahl-punctuation ahl-delimiter" style="color: #ECEFF4;">,</span> <span class="ahl-string" style="color: #A3BE8C;">&quot;~&gt; 0.1&quot;</span><span class="ahl-punctuation ahl-bracket" style="color: #ECEFF4;">}</span>
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
        <pre><code class="language-elixir">{:mdex, &quot;~&gt; 0.1&quot;}
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
        <pre class="autumn-hl" style="background-color: #282C34; color: #ABB2BF;"><code class="language-plaintext" translate="no">{:mdex, &quot;~&gt; 0.1&quot;}
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
        <pre class="autumn-hl" style="background-color: #282C34; color: #ABB2BF;"><code class="language-plaintext" translate="no">{:mdex, &quot;~&gt; 0.1&quot;}
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
        <pre class="autumn-hl"><code class="language-elixir" translate="no"><span class="ahl-punctuation ahl-bracket">{</span><span class="ahl-string ahl-special ahl-symbol">:mdex</span><span class="ahl-punctuation ahl-delimiter">,</span> <span class="ahl-string">&quot;~&gt; 0.1&quot;</span><span class="ahl-punctuation ahl-bracket">}</span>
        </code></pre>
        """,
        features: [syntax_highlight_inline_style: false]
      )
    end
  end

  test "render emoji shortcodes" do
    assert_output(":rocket:", "<p>🚀</p>\n", extension: [shortcodes: true])
  end

  describe "parse_document" do
    assert MDEx.parse_document!("# Level 1") == [{"document", %{}, [{"heading", %{"level" => 1, "setext" => false}, ["Level 1"]}]}]

    assert MDEx.parse_document!("""
           <script type="module">
             mermaid.initialize({ startOnLoad: true })
           </script>
           """) ==
             [
               {"document", %{},
                [
                  {"html_block",
                   %{"block_type" => 1, "literal" => "<script type=\"module\">\n  mermaid.initialize({ startOnLoad: true })\n</script>\n"}, []}
                ]}
             ]
  end

  describe "traverse_and_update" do
    test "append child" do
      ast =
        "# Test"
        |> MDEx.parse_document!()
        |> MDEx.traverse_and_update(fn
          {"document", attrs, children} ->
            # FIXME: add parse_fragment that returns only the child without document + paragraph
            child = MDEx.parse_document!("`foo = 1`")
            {"document", attrs, children ++ child}

          other ->
            other
        end)

      assert MDEx.to_html!(ast) == """
             <h1>Test</h1>
             <p><code>foo = 1</code></p>
             """
    end
  end

  describe "security" do
    test "omit raw html by default" do
      assert MDEx.to_html!("<h1>test</h1>") == "<!-- raw HTML omitted -->\n"
    end

    test "escape raw html" do
      assert MDEx.to_html!("<h1>test</h1>", render: [escape: true]) == "&lt;h1&gt;test&lt;/h1&gt;\n"
    end

    test "render raw html" do
      assert MDEx.to_html!("<h1>test</h1>", render: [unsafe_: true]) == "<h1>test</h1>\n"
    end

    test "sanitize unsafe raw html" do
      assert MDEx.to_html!("<h1>test</h1>", render: [unsafe_: true], features: [sanitize: true]) == "<h1>test</h1>\n"

      assert MDEx.to_html!("<a href=https://elixir-lang.org/>Elixir</a>", render: [unsafe_: true], features: [sanitize: true]) ==
               "<p><a href=\"https://elixir-lang.org/\" rel=\"noopener noreferrer\">Elixir</a></p>\n"

      assert MDEx.to_html!("<a href=https://elixir-lang.org/><script>attack</script></a>", render: [unsafe_: true], features: [sanitize: true]) ==
               "<p><a href=\"https://elixir-lang.org/\" rel=\"noopener noreferrer\"></a></p>\n"
    end
  end
end
