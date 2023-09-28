defmodule MDExTest do
  use ExUnit.Case
  doctest MDEx

  describe "syntax highlighting" do
    test "enabled by default" do
      assert MDEx.to_html(~S"""
             ```elixir
             {:mdex, "~> 0.1"}
             ```
             """) ==
               "<pre class=\"autumn highlight\" style=\"background-color: #282C34; color: #ABB2BF;\">\n<code class=\"language-elixir\"><span class=\"\" style=\"color: #ABB2BF;\">{</span><span class=\"string\" style=\"color: #98C379;\">:mdex</span><span class=\"\" style=\"color: #ABB2BF;\">,</span> <span class=\"string\" style=\"color: #98C379;\">&quot;~&gt; 0.1&quot;</span><span class=\"\" style=\"color: #ABB2BF;\">}</span>\n</code></pre>\n"
    end

    test "change theme name" do
      assert MDEx.to_html(
               ~S"""
               ```elixir
               {:mdex, "~> 0.1"}
               ```
               """,
               features: [syntax_highlight_theme: "nord"]
             ) ==
               "<pre class=\"autumn highlight\" style=\"background-color: #2e3440; color: #D8DEE9;\">\n<code class=\"language-elixir\"><span class=\"punctuation bracket\" style=\"color: #ECEFF4;\">{</span><span class=\"string special\" style=\"color: #EBCB8B;\">:mdex</span><span class=\"punctuation delimiter\" style=\"color: #ECEFF4;\">,</span> <span class=\"string\" style=\"color: #A3BE8C;\">&quot;~&gt; 0.1&quot;</span><span class=\"punctuation bracket\" style=\"color: #ECEFF4;\">}</span>\n</code></pre>\n"
    end

    test "can be disabled" do
      assert MDEx.to_html(
               ~S"""
               ```elixir
               {:mdex, "~> 0.1"}
               ```
               """,
               features: [syntax_highlight_theme: nil]
             ) ==
               "<pre><code class=\"language-elixir\">{:mdex, &quot;~&gt; 0.1&quot;}\n</code></pre>\n"
    end

    test "with invalid lang" do
      assert MDEx.to_html(~S"""
             ```invalid
             {:mdex, "~> 0.1"}
             ```
             """) == ~s"""
             <pre class="autumn highlight" style="background-color: #282C34; color: #ABB2BF;">
             <code class="language-invalid">{:mdex, &quot;~&gt; 0.1&quot;}
             </code></pre>
             """
    end

    test "without lang" do
      assert MDEx.to_html(~S"""
             ```
             {:mdex, "~> 0.1"}
             ```
             """) == ~s"""
             <pre class="autumn highlight" style="background-color: #282C34; color: #ABB2BF;">
             <code>{:mdex, &quot;~&gt; 0.1&quot;}
             </code></pre>
             """
    end
  end
end
