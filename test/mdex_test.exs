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
               features: [syntax_highlight_theme: "Nord"]
             ) ==
               "<pre style=\"background-color:#2e3440;\"><code class=\"language-elixir\"><span style=\"color:#d8dee9;\">{:mdex</span><span style=\"color:#eceff4;\">, </span><span style=\"color:#a3be8c;\">&quot;~&gt; 0.1&quot;</span><span style=\"color:#d8dee9;\">}\n</span></code></pre>\n"
    end

    test "respect space and new lines" do
      template = ~S"""
      ```elixir
      {images_binary, images_type, _} = train_images

      images =
        images_binary
        |> Nx.from_binary(images_type)
      ```
      """

      expected = ~S"""
      <pre style="background-color:#282a36;"><code class="language-elixir"><span style="color:#f8f8f2;">{images_binary, images_type, _} </span><span style="color:#ff79c6;">=</span><span style="color:#f8f8f2;"> train_images
      </span><span style="color:#f8f8f2;">
      </span><span style="color:#f8f8f2;">images </span><span style="color:#ff79c6;">=
      </span><span style="color:#f8f8f2;">  images_binary
      </span><span style="color:#f8f8f2;">  </span><span style="color:#ff79c6;">|&gt; </span><span style="text-decoration:underline;color:#8be9fd;">Nx</span><span style="color:#f8f8f2;">.from_binary(images_type)
      </span></code></pre>
      """

      assert MDEx.to_html(template, features: [syntax_highlight_theme: "Dracula"]) == expected
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
