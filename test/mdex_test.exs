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
               "<pre style=\"background-color:#ffffff;\"><code class=\"language-elixir\"><span style=\"color:#323232;\">{:mdex, &quot;~&gt; 0.1&quot;}\n</span></code></pre>\n"
    end

    test "change theme name" do
      assert MDEx.to_html(
               ~S"""
               ```elixir
               {:mdex, "~> 0.1"}
               ```
               """,
               features: [syntax_highlighting: "base16-mocha.dark"]
             ) ==
               "<pre style=\"background-color:#3b3228;\"><code class=\"language-elixir\"><span style=\"color:#d0c8c6;\">{:mdex, &quot;~&gt; 0.1&quot;}\n</span></code></pre>\n"
    end

    test "can be disabled" do
      assert MDEx.to_html(
               ~S"""
               ```elixir
               {:mdex, "~> 0.1"}
               ```
               """,
               features: [syntax_highlighting: nil]
             ) ==
               "<pre><code class=\"language-elixir\">{:mdex, &quot;~&gt; 0.1&quot;}\n</code></pre>\n"
    end
  end
end
