defmodule MDEx.SigilTest do
  use ExUnit.Case
  import MDEx.Sigil

  describe "sigil_m without modifiers" do
    @expected "<p><code>lang = :elixir</code></p>\n"

    test "without interpolation" do
      assert ~m|`lang = :elixir`| == @expected
    end

    test "with interpolation" do
      lang = ":elixir"
      assert ~m|`lang = #{lang}`| == @expected
    end
  end

  describe "sigil_m with AST modifier" do
    @expected [{"document", [], [{"paragraph", [], [{"code", [{"num_backticks", 1}, {"literal", "lang = :elixir"}], []}]}]}]

    test "without interpolation" do
      assert ~m|`lang = :elixir`|a == @expected
    end

    test "with interpolation" do
      lang = ":elixir"
      assert ~m|`lang = #{lang}`|a == @expected
    end
  end

  describe "sigil_m with CommonMark modifier" do
    @expected "`lang = :elixir`\n"

    test "without interpolation" do
      assert ~m|[{"document", [], [{"paragraph", [], [{"code", [{"num_backticks", 1}, {"literal", "lang = :elixir"}], []}]}]}]|c == @expected
    end

    test "with interpolation" do
      lang = ":elixir"
      assert ~m|[{"document", [], [{"paragraph", [], [{"code", [{"num_backticks", 1}, {"literal", "lang = #{lang}"}], []}]}]}]|c == @expected
    end
  end
end
