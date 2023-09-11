defmodule MDExTest do
  use ExUnit.Case
  doctest MDEx

  describe "options" do
    test "render" do
      assert MDEx.to_html("Hello.\nWorld.\n", render: [hardbreaks: true]) ==
               "<p>Hello.<br />\nWorld.</p>\n"

      # assert MDEx.to_html("- one\n- two\n- three", render: %{list_style: :plus}) ==
      #          "<p>Hello.<br />\nWorld.</p>\n"
    end
  end
end
