defmodule MDExTest do
  use ExUnit.Case
  doctest MDEx

  defp assert_output(input, expected, opts \\ []) do
    html = MDEx.to_html(input, opts)
    # IO.puts(html) # debug
    assert html == expected
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
        <pre class="autumn highlight" style="background-color: #282C34; color: #ABB2BF;"><code class="language-elixir" translate="no"><span class="" style="color: #ABB2BF;">{</span><span class="string" style="color: #98C379;">:mdex</span><span class="" style="color: #ABB2BF;">,</span> <span class="string" style="color: #98C379;">&quot;~&gt; 0.1&quot;</span><span class="" style="color: #ABB2BF;">}</span>
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
        <pre class="autumn highlight" style="background-color: #2e3440; color: #D8DEE9;"><code class="language-elixir" translate="no"><span class="punctuation bracket" style="color: #ECEFF4;">{</span><span class="string special" style="color: #EBCB8B;">:mdex</span><span class="punctuation delimiter" style="color: #ECEFF4;">,</span> <span class="string" style="color: #A3BE8C;">&quot;~&gt; 0.1&quot;</span><span class="punctuation bracket" style="color: #ECEFF4;">}</span>
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
        <pre class="autumn highlight" style="background-color: #282C34; color: #ABB2BF;"><code class="language-invalid" translate="no">{:mdex, &quot;~&gt; 0.1&quot;}
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
        <pre class="autumn highlight" style="background-color: #282C34; color: #ABB2BF;"><code class="language-plain-text" translate="no">{:mdex, &quot;~&gt; 0.1&quot;}
        </code></pre>
        """
      )
    end
  end
end
