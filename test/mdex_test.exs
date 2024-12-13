defmodule MDExTest do
  use ExUnit.Case, async: true
  alias MDEx.Document
  alias MDEx.Heading
  alias MDEx.Text
  doctest MDEx

  defp assert_output(input, expected, opts \\ []) do
    assert {:ok, html} = MDEx.to_html(input, opts)
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
      assert MDEx.to_html!("<h1>test</h1>", render: [unsafe_: true], features: [sanitize: true]) == "<h1>test</h1>"

      assert MDEx.to_html!("<a href=https://elixir-lang.org/>Elixir</a>", render: [unsafe_: true], features: [sanitize: true]) ==
               "<p><a href=\"https://elixir-lang.org/\" rel=\"noopener noreferrer\">Elixir</a></p>"

      assert MDEx.to_html!("<a href=https://elixir-lang.org/><script>attack</script></a>", render: [unsafe_: true], features: [sanitize: true]) ==
               "<p><a href=\"https://elixir-lang.org/\" rel=\"noopener noreferrer\"></a></p>"
    end
  end

  describe "to_commonmark" do
    test "document to commonmark with default options" do
      assert MDEx.to_commonmark!(%Document{nodes: [%Heading{nodes: [%Text{literal: "Test"}]}]}) == "# Test"
    end
  end
end
