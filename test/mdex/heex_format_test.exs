defmodule MDEx.HEExFormatTest do
  use ExUnit.Case
  import MDEx.Sigil

  def assert_format(rendered, expected) do
    html = MDEx.rendered_to_html(rendered)
    assert html == String.trim(expected)
  end

  test "curly braces expression" do
    assigns = %{}
    assert_format(~MD[{1 + 2}]HEEX, "<p>3</p>")
  end

  test "function call" do
    assigns = %{}
    assert_format(~MD[{URI.parse("https://elixir-lang.org")}]HEEX, "<p>https://elixir-lang.org</p>")
  end

  test "assigns" do
    assigns = %{url: "https://elixir-lang.org"}
    assert_format(~MD[{URI.parse(@url)}]HEEX, "<p>https://elixir-lang.org</p>")
  end

  test "expression inside inline code is escaped" do
    assigns = %{title: "Hello"}
    assert_format(~MD[text: {@title} | code: `{@title}`]HEEX, "<p>text: Hello | code: <code>&lbrace;@title&rbrace;</code></p>")
  end

  test "expression inside code block is escaped" do
    assigns = %{}

    assert ~MD"""
           ```elixir
           1 < 2
           ```
           """HEEX
           |> MDEx.rendered_to_html() =~
             "<span style=\"color: #d19a66;\">1</span> <span style=\"color: #56b6c2;\">&lt;</span> <span style=\"color: #d19a66;\">2</span>"
  end

  test "components" do
    assigns = %{url: "https://elixir-lang.org"}

    assert ~MD"""
           <Phoenix.Component.link href={URI.parse(@url)} class="p-4">elixir lang</Phoenix.Component.link>
           """HEEX
           |> MDEx.rendered_to_html() == "<p><a href=\"https://elixir-lang.org\" class=\"p-4\">elixir lang</a></p>"
  end
end
