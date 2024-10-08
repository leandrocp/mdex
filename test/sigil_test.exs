defmodule MDEx.SigilTest do
  use ExUnit.Case
  import MDEx.Sigil

  describe "sigil_M" do
    test "markdown to html" do
      assert ~M|`lang = :elixir`| == "<p><code>lang = :elixir</code></p>"
    end

    test "markdown to ast" do
      assert ~M|`lang = :elixir`|AST == [{"document", [], [{"paragraph", [], [{"code", [{"num_backticks", 1}, {"literal", "lang = :elixir"}], []}]}]}]
    end

    test "ast to html" do
      assert ~M|[{"document", [], [{"paragraph", [], [{"code", [{"num_backticks", 1}, {"literal", "lang = :elixir"}], []}]}]}]| ==
               "<p><code>lang = :elixir</code></p>"
    end

    test "ast to markdown" do
      assert ~M|[{"document", [], [{"paragraph", [], [{"code", [{"num_backticks", 1}, {"literal", "lang = :elixir"}], []}]}]}]|MD ==
               "`lang = :elixir`"
    end
  end

  describe "sigil_m without interpolation" do
    test "markdown to html" do
      assert ~m|`lang = :elixir`| == "<p><code>lang = :elixir</code></p>"
    end

    test "markdown to ast" do
      assert ~m|`lang = :elixir`|AST == [{"document", [], [{"paragraph", [], [{"code", [{"num_backticks", 1}, {"literal", "lang = :elixir"}], []}]}]}]
    end

    test "ast to html" do
      assert ~m|[{"document", [], [{"paragraph", [], [{"code", [{"num_backticks", 1}, {"literal", "lang = :elixir"}], []}]}]}]| ==
               "<p><code>lang = :elixir</code></p>"
    end

    test "ast to markdown" do
      assert ~m|[{"document", [], [{"paragraph", [], [{"code", [{"num_backticks", 1}, {"literal", "lang = :elixir"}], []}]}]}]|MD ==
               "`lang = :elixir`"
    end
  end

  describe "sigil_m with interpolation" do
    @lang :elixir

    test "markdown to html" do
      assert ~m|`lang = #{inspect(@lang)}`| == "<p><code>lang = :elixir</code></p>"
    end

    test "markdown to ast" do
      assert ~m|`lang = #{inspect(@lang)}`|AST == [
               {"document", [], [{"paragraph", [], [{"code", [{"num_backticks", 1}, {"literal", "lang = :elixir"}], []}]}]}
             ]
    end

    test "ast to html" do
      assert ~m|[{"document", [], [{"paragraph", [], [{"code", [{"num_backticks", 1}, {"literal", "lang = #{inspect(@lang)}"}], []}]}]}]| ==
               "<p><code>lang = :elixir</code></p>"
    end

    test "ast to markdown" do
      assert ~m|[{"document", [], [{"paragraph", [], [{"code", [{"num_backticks", 1}, {"literal", "lang = #{inspect(@lang)}"}], []}]}]}]|MD ==
               "`lang = :elixir`"
    end
  end
end
