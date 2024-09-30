defmodule MDEx.SigilTest do
  use ExUnit.Case
  import MDEx.Sigil

  test "defaults to HTML" do
    assert ~M|# Hello| == "<h1>Hello</h1>\n"
  end

  test "AST modifier" do
    assert ~M|# Hello|a == [{"document", [], [{"heading", [{"level", 1}, {"setext", false}], ["Hello"]}]}]
  end
end
