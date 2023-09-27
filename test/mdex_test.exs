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
               "<pre class=\"autumn highlight\" style=\"background-color: #282C34;\">\n<code class=\"language-elixir\"><span class=\"\" style=\"color: #ABB2BF;\">{</span><span class=\"string\" style=\"color: #98C379;\">:mdex</span><span class=\"\" style=\"color: #ABB2BF;\">,</span> <span class=\"string\" style=\"color: #98C379;\">&quot;~&gt; 0.1&quot;</span><span class=\"\" style=\"color: #ABB2BF;\">}</span>\n</code></pre>\n"
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
               "<pre class=\"autumn highlight\" style=\"background-color: #2e3440;\">\n<code class=\"language-elixir\"><span class=\"punctuation bracket\" style=\"color: #ECEFF4;\">{</span><span class=\"string special\" style=\"color: #EBCB8B;\">:mdex</span><span class=\"punctuation delimiter\" style=\"color: #ECEFF4;\">,</span> <span class=\"string\" style=\"color: #A3BE8C;\">&quot;~&gt; 0.1&quot;</span><span class=\"punctuation bracket\" style=\"color: #ECEFF4;\">}</span>\n</code></pre>\n"
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
  end
end
