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
               features: [syntax_highlight_theme: "Dracula"]
             ) ==
               "<pre style=\"background-color:#282a36;\"><code class=\"language-elixir\"><span style=\"color:#f8f8f2;\">{</span><span style=\"color:#bd93f9;\">:mdex</span><span style=\"color:#f8f8f2;\">, </span><span style=\"color:#f1fa8c;\">&quot;~&gt; 0.1&quot;</span><span style=\"color:#f8f8f2;\">}\n</span></code></pre>\n"
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
