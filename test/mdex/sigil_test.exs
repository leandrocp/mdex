defmodule MDEx.SigilTest do
  use ExUnit.Case, async: true
  import MDEx.Sigil
  alias MDEx.Code

  test "respect render.escape option on text nodes " do
    assert ~MD"""
           # Test

           <.link navigate={~p"/"} class="underline">home</.link>
           """HTML == "<h1>Test</h1>\n<p><.link navigate={~p\"/\"} class=\"underline\">home</.link></p>"
  end

  describe "sigil_MD with assigns" do
    test "markdown to document" do
      assigns = %{lang: ":elixir"}
      assert ~MD|`lang = <%= @lang %>`| == %MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "lang = :elixir"}]}]}
    end

    test "markdown to html" do
      assigns = %{lang: ":elixir"}
      assert ~MD|`lang = <%= @lang %>`|HTML == "<p><code>lang = :elixir</code></p>"
    end

    test "markdown to json" do
      assigns = %{lang: ":elixir"}

      assert ~MD|`lang = <%= @lang %>`|JSON ==
               "{\"nodes\":[{\"nodes\":[{\"literal\":\"lang = :elixir\",\"num_backticks\":1,\"node_type\":\"MDEx.Code\"}],\"node_type\":\"MDEx.Paragraph\"}],\"node_type\":\"MDEx.Document\"}"
    end

    test "markdown to xml" do
      assigns = %{lang: ":elixir"}

      assert ~MD|`lang = <%= @lang %>`|XML ==
               "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE document SYSTEM \"CommonMark.dtd\">\n<document xmlns=\"http://commonmark.org/xml/1.0\">\n  <paragraph>\n    <code xml:space=\"preserve\">lang = :elixir</code>\n  </paragraph>\n</document>"
    end
  end

  describe "sigil_MD without assigns" do
    test "markdown to document" do
      assert ~MD|`lang = :elixir`| == %MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "lang = :elixir"}]}]}
    end

    test "markdown to html" do
      assert ~MD|`lang = :elixir`|HTML == "<p><code>lang = :elixir</code></p>"
    end

    test "markdown to json" do
      assert ~MD|`lang = :elixir`|JSON ==
               "{\"nodes\":[{\"nodes\":[{\"literal\":\"lang = :elixir\",\"num_backticks\":1,\"node_type\":\"MDEx.Code\"}],\"node_type\":\"MDEx.Paragraph\"}],\"node_type\":\"MDEx.Document\"}"
    end

    test "markdown to xml" do
      assert ~MD|`lang = :elixir`|XML ==
               "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE document SYSTEM \"CommonMark.dtd\">\n<document xmlns=\"http://commonmark.org/xml/1.0\">\n  <paragraph>\n    <code xml:space=\"preserve\">lang = :elixir</code>\n  </paragraph>\n</document>"
    end

    test "document to markdown" do
      assert ~MD|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = :elixir"}]}]}|MD ==
               "`lang = :elixir`"
    end

    test "document to html" do
      assert ~MD|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = :elixir"}]}]}|HTML ==
               "<p><code>lang = :elixir</code></p>"
    end

    test "document to json" do
      assert ~MD|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = :elixir"}]}]}|JSON ==
               "{\"nodes\":[{\"nodes\":[{\"literal\":\"lang = :elixir\",\"num_backticks\":1,\"node_type\":\"MDEx.Code\"}],\"node_type\":\"MDEx.Paragraph\"}],\"node_type\":\"MDEx.Document\"}"
    end

    test "document to xml" do
      assert ~MD|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = :elixir"}]}]}|XML ==
               "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE document SYSTEM \"CommonMark.dtd\">\n<document xmlns=\"http://commonmark.org/xml/1.0\">\n  <paragraph>\n    <code xml:space=\"preserve\">lang = :elixir</code>\n  </paragraph>\n</document>"
    end
  end

  describe "sigil_M" do
    test "markdown to document" do
      assert ~M|`lang = :elixir`| ==
               %MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "lang = :elixir"}]}]}
    end

    test "markdown to html" do
      assert ~M|`lang = :elixir`|HTML ==
               "<p><code>lang = :elixir</code></p>"
    end

    test "markdown to json" do
      assert ~M|`lang = :elixir`|JSON ==
               "{\"nodes\":[{\"nodes\":[{\"literal\":\"lang = :elixir\",\"num_backticks\":1,\"node_type\":\"MDEx.Code\"}],\"node_type\":\"MDEx.Paragraph\"}],\"node_type\":\"MDEx.Document\"}"
    end

    test "markdown to xml" do
      assert ~M|`lang = :elixir`|XML ==
               "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE document SYSTEM \"CommonMark.dtd\">\n<document xmlns=\"http://commonmark.org/xml/1.0\">\n  <paragraph>\n    <code xml:space=\"preserve\">lang = :elixir</code>\n  </paragraph>\n</document>"
    end

    test "document to markdown" do
      assert ~M|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = :elixir"}]}]}|MD ==
               "`lang = :elixir`"
    end

    test "document to html" do
      assert ~M|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = :elixir"}]}]}|HTML ==
               "<p><code>lang = :elixir</code></p>"
    end

    test "document to json" do
      assert ~M|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = :elixir"}]}]}|JSON ==
               "{\"nodes\":[{\"nodes\":[{\"literal\":\"lang = :elixir\",\"num_backticks\":1,\"node_type\":\"MDEx.Code\"}],\"node_type\":\"MDEx.Paragraph\"}],\"node_type\":\"MDEx.Document\"}"
    end

    test "document to xml" do
      assert ~M|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = :elixir"}]}]}|XML ==
               "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE document SYSTEM \"CommonMark.dtd\">\n<document xmlns=\"http://commonmark.org/xml/1.0\">\n  <paragraph>\n    <code xml:space=\"preserve\">lang = :elixir</code>\n  </paragraph>\n</document>"
    end
  end

  describe "sigil_m without interpolation" do
    test "markdown to document" do
      assert ~m|`lang = :elixir`| ==
               %MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = :elixir"}]}]}
    end

    test "markdown to html" do
      assert ~m|`lang = :elixir`|HTML ==
               "<p><code>lang = :elixir</code></p>"
    end

    test "markdown to json" do
      assert ~m|`lang = :elixir`|JSON ==
               "{\"nodes\":[{\"nodes\":[{\"literal\":\"lang = :elixir\",\"num_backticks\":1,\"node_type\":\"MDEx.Code\"}],\"node_type\":\"MDEx.Paragraph\"}],\"node_type\":\"MDEx.Document\"}"
    end

    test "markdown to xml" do
      assert ~m|`lang = :elixir`|XML ==
               "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE document SYSTEM \"CommonMark.dtd\">\n<document xmlns=\"http://commonmark.org/xml/1.0\">\n  <paragraph>\n    <code xml:space=\"preserve\">lang = :elixir</code>\n  </paragraph>\n</document>"
    end

    test "document to markdown" do
      assert ~m|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = :elixir"}]}]}|MD ==
               "`lang = :elixir`"
    end

    test "document to html" do
      assert ~m|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = :elixir"}]}]}|HTML ==
               "<p><code>lang = :elixir</code></p>"
    end

    test "document to json" do
      assert ~m|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = :elixir"}]}]}|JSON ==
               "{\"nodes\":[{\"nodes\":[{\"literal\":\"lang = :elixir\",\"num_backticks\":1,\"node_type\":\"MDEx.Code\"}],\"node_type\":\"MDEx.Paragraph\"}],\"node_type\":\"MDEx.Document\"}"
    end

    test "document to xml" do
      assert ~m|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = :elixir"}]}]}|XML ==
               "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE document SYSTEM \"CommonMark.dtd\">\n<document xmlns=\"http://commonmark.org/xml/1.0\">\n  <paragraph>\n    <code xml:space=\"preserve\">lang = :elixir</code>\n  </paragraph>\n</document>"
    end
  end

  describe "sigil_m with interpolation" do
    @lang :elixir

    test "markdown to document" do
      assert ~m|`lang = #{inspect(@lang)}`| ==
               %MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "lang = :elixir"}]}]}
    end

    test "markdown to html" do
      assert ~m|`lang = #{inspect(@lang)}`|HTML ==
               "<p><code>lang = :elixir</code></p>"
    end

    test "markdown to json" do
      assert ~m|`lang = #{inspect(@lang)}`|JSON ==
               "{\"nodes\":[{\"nodes\":[{\"literal\":\"lang = :elixir\",\"num_backticks\":1,\"node_type\":\"MDEx.Code\"}],\"node_type\":\"MDEx.Paragraph\"}],\"node_type\":\"MDEx.Document\"}"
    end

    test "markdown to xml" do
      assert ~m|`lang = #{inspect(@lang)}`|XML ==
               "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE document SYSTEM \"CommonMark.dtd\">\n<document xmlns=\"http://commonmark.org/xml/1.0\">\n  <paragraph>\n    <code xml:space=\"preserve\">lang = :elixir</code>\n  </paragraph>\n</document>"
    end

    test "document to markdown" do
      assert ~m|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = #{inspect(@lang)}"}]}]}|MD ==
               "`lang = :elixir`"
    end

    test "document to html" do
      assert ~m|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = #{inspect(@lang)}"}]}]}|HTML ==
               "<p><code>lang = :elixir</code></p>"
    end

    test "document to json" do
      assert ~m|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = #{inspect(@lang)}"}]}]}|JSON ==
               "{\"nodes\":[{\"nodes\":[{\"literal\":\"lang = :elixir\",\"num_backticks\":1,\"node_type\":\"MDEx.Code\"}],\"node_type\":\"MDEx.Paragraph\"}],\"node_type\":\"MDEx.Document\"}"
    end

    test "document to xml" do
      assert ~m|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = #{inspect(@lang)}"}]}]}|XML ==
               "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE document SYSTEM \"CommonMark.dtd\">\n<document xmlns=\"http://commonmark.org/xml/1.0\">\n  <paragraph>\n    <code xml:space=\"preserve\">lang = :elixir</code>\n  </paragraph>\n</document>"
    end
  end
end
