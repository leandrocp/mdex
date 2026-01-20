defmodule MDEx.SigilTest do
  use ExUnit.Case, async: true
  import MDEx.Sigil
  alias MDEx.Code

  defp assert_json(json, expected) do
    assert Jason.decode!(json) == expected
  end

  describe "sigil_MD with assigns" do
    test "to html" do
      assigns = %{lang: "Elixir"}
      assert ~MD|# <%= @lang %>|HTML == "<h1>Elixir</h1>"
    end

    test "to md" do
      assigns = %{lang: "Elixir"}
      assert ~MD|# <%= @lang %>|MD == "# Elixir"
    end

    # test "markdown to heex" do
    #   assigns = %{lang: ":elixir"}
    #   assert %Phoenix.LiveView.Rendered{} = ~MD|`lang = <%= @lang %>`|HEEX
    # end
  end

  describe "sigil_MD without assigns" do
    test "markdown to document" do
      assert %MDEx.Document{
               nodes: [%MDEx.Heading{nodes: [%MDEx.HeexInline{literal: "<%= @lang %>"}], level: 1, setext: false}]
             } = ~MD|# <%= @lang %>|
    end

    test "to markdown" do
      assert ~MD|# <%= @lang %>|MD == "# <%= @lang %>"
    end

    test "markdown to html" do
      assert ~MD|# <%= @lang %>|HTML == "<h1><%= @lang %></h1>"
    end

    test "markdown to json" do
      assert_json(
        ~MD|`lang = :elixir`|JSON,
        %{
          "node_type" => "MDEx.Document",
          "nodes" => [
            %{
              "node_type" => "MDEx.Paragraph",
              "nodes" => [
                %{
                  "node_type" => "MDEx.Code",
                  "num_backticks" => 1,
                  "literal" => "lang = :elixir"
                }
              ]
            }
          ]
        }
      )
    end

    test "markdown to xml" do
      assert ~MD|`lang = :elixir`|XML ==
               "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE document SYSTEM \"CommonMark.dtd\">\n<document xmlns=\"http://commonmark.org/xml/1.0\">\n  <paragraph>\n    <code xml:space=\"preserve\">lang = :elixir</code>\n  </paragraph>\n</document>"
    end

    test "markdown to delta" do
      assert ~MD|`lang = :elixir`|DELTA ==
               [%{"insert" => "lang = :elixir", "attributes" => %{"code" => true}}, %{"insert" => "\n"}]
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
      assert_json(
        ~MD|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = :elixir"}]}]}|JSON,
        %{
          "node_type" => "MDEx.Document",
          "nodes" => [
            %{
              "node_type" => "MDEx.Paragraph",
              "nodes" => [
                %{
                  "node_type" => "MDEx.Code",
                  "num_backticks" => 1,
                  "literal" => "lang = :elixir"
                }
              ]
            }
          ]
        }
      )
    end

    test "document to xml" do
      assert ~MD|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = :elixir"}]}]}|XML ==
               "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE document SYSTEM \"CommonMark.dtd\">\n<document xmlns=\"http://commonmark.org/xml/1.0\">\n  <paragraph>\n    <code xml:space=\"preserve\">lang = :elixir</code>\n  </paragraph>\n</document>"
    end

    test "document to delta" do
      assert ~MD|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = :elixir"}]}]}|DELTA ==
               [%{"insert" => "lang = :elixir", "attributes" => %{"code" => true}}, %{"insert" => "\n"}]
    end
  end

  describe "sigil_MD with code block decorators" do
    test "highlight_lines" do
      html = ~MD|```elixir highlight_lines=2
      defmodule Test do
        @langs [:elixir, :rust]
      end
      ```|HTML

      assert html =~ "<div class=\"line\" data-line=\"1\">"
      assert html =~ "<div class=\"line\" style=\"background-color: #3b4252;\" data-line=\"2\">"
    end
  end

  describe "sigil_M" do
    test "markdown to document" do
      assert %MDEx.Document{
               nodes: [%MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "lang = :elixir"}]}]
             } = ~M|`lang = :elixir`|
    end

    test "markdown to html" do
      assert ~M|`lang = :elixir`|HTML ==
               "<p><code>lang = :elixir</code></p>"
    end

    test "markdown to json" do
      assert_json(
        ~M|`lang = :elixir`|JSON,
        %{
          "node_type" => "MDEx.Document",
          "nodes" => [
            %{
              "node_type" => "MDEx.Paragraph",
              "nodes" => [
                %{
                  "node_type" => "MDEx.Code",
                  "num_backticks" => 1,
                  "literal" => "lang = :elixir"
                }
              ]
            }
          ]
        }
      )
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
      assert_json(
        ~M|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = :elixir"}]}]}|JSON,
        %{
          "node_type" => "MDEx.Document",
          "nodes" => [
            %{
              "node_type" => "MDEx.Paragraph",
              "nodes" => [
                %{
                  "node_type" => "MDEx.Code",
                  "num_backticks" => 1,
                  "literal" => "lang = :elixir"
                }
              ]
            }
          ]
        }
      )
    end

    test "document to xml" do
      assert ~M|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = :elixir"}]}]}|XML ==
               "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE document SYSTEM \"CommonMark.dtd\">\n<document xmlns=\"http://commonmark.org/xml/1.0\">\n  <paragraph>\n    <code xml:space=\"preserve\">lang = :elixir</code>\n  </paragraph>\n</document>"
    end
  end

  describe "sigil_m without interpolation" do
    test "markdown to document" do
      assert %MDEx.Document{
               nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = :elixir"}]}]
             } = ~m|`lang = :elixir`|
    end

    test "markdown to html" do
      assert ~m|`lang = :elixir`|HTML ==
               "<p><code>lang = :elixir</code></p>"
    end

    test "markdown to json" do
      assert_json(
        ~m|`lang = :elixir`|JSON,
        %{
          "node_type" => "MDEx.Document",
          "nodes" => [
            %{
              "node_type" => "MDEx.Paragraph",
              "nodes" => [
                %{
                  "node_type" => "MDEx.Code",
                  "num_backticks" => 1,
                  "literal" => "lang = :elixir"
                }
              ]
            }
          ]
        }
      )
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
      assert_json(
        ~m|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = :elixir"}]}]}|JSON,
        %{
          "node_type" => "MDEx.Document",
          "nodes" => [
            %{
              "node_type" => "MDEx.Paragraph",
              "nodes" => [
                %{
                  "node_type" => "MDEx.Code",
                  "num_backticks" => 1,
                  "literal" => "lang = :elixir"
                }
              ]
            }
          ]
        }
      )
    end

    test "document to xml" do
      assert ~m|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = :elixir"}]}]}|XML ==
               "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE document SYSTEM \"CommonMark.dtd\">\n<document xmlns=\"http://commonmark.org/xml/1.0\">\n  <paragraph>\n    <code xml:space=\"preserve\">lang = :elixir</code>\n  </paragraph>\n</document>"
    end
  end

  describe "sigil_m with interpolation" do
    @lang :elixir

    test "markdown to document" do
      assert %MDEx.Document{
               nodes: [%MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "lang = :elixir"}]}]
             } = ~m|`lang = #{inspect(@lang)}`|
    end

    test "markdown to html" do
      assert ~m|`lang = #{inspect(@lang)}`|HTML ==
               "<p><code>lang = :elixir</code></p>"
    end

    test "markdown to json" do
      assert_json(
        ~m|`lang = #{inspect(@lang)}`|JSON,
        %{
          "node_type" => "MDEx.Document",
          "nodes" => [
            %{
              "node_type" => "MDEx.Paragraph",
              "nodes" => [
                %{
                  "node_type" => "MDEx.Code",
                  "num_backticks" => 1,
                  "literal" => "lang = :elixir"
                }
              ]
            }
          ]
        }
      )
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
      assert_json(
        ~m|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = #{inspect(@lang)}"}]}]}|JSON,
        %{
          "node_type" => "MDEx.Document",
          "nodes" => [
            %{
              "node_type" => "MDEx.Paragraph",
              "nodes" => [
                %{
                  "node_type" => "MDEx.Code",
                  "num_backticks" => 1,
                  "literal" => "lang = :elixir"
                }
              ]
            }
          ]
        }
      )
    end

    test "document to xml" do
      assert ~m|%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%Code{num_backticks: 1, literal: "lang = #{inspect(@lang)}"}]}]}|XML ==
               "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE document SYSTEM \"CommonMark.dtd\">\n<document xmlns=\"http://commonmark.org/xml/1.0\">\n  <paragraph>\n    <code xml:space=\"preserve\">lang = :elixir</code>\n  </paragraph>\n</document>"
    end
  end

  describe "html" do
    test "code with assigns" do
      assigns = %{lang: ":elixir"}
      assert ~MD|`lang = <%= @lang %>`|HTML == "<p><code>lang = &lt;%= @lang %&gt;</code></p>"
    end

    test "code block with assigns" do
      assigns = %{lang: ":elixir"}

      assert ~MD|
      ```elixir
      lang = <%= @lang %>
      ```|HTML =~ "lang = &lt;%= @lang %&gt;"
    end
  end

  # describe "heex" do
  #   test "code with assigns" do
  #     assigns = %{lang: ":elixir"}
  #     assert ~MD|`lang = <%= @lang %>`|HEEX |> MDEx.rendered_to_html() == "<p><code>lang = &lt;%= @lang %&gt;</code></p>"
  #     assert ~MD|`lang = {@lang}`|HEEX |> MDEx.rendered_to_html() == "<p><code>lang = &lbrace;@lang&rbrace;</code></p>"
  #   end
  #
  #   test "code block with assigns" do
  #     assigns = %{lang: ":elixir"}
  #
  #     assert ~MD|
  #     ```elixir
  #     lang = <%= @lang %>
  #     ```|HEEX |> MDEx.rendered_to_html() =~ "lang = &lt;%= @lang %&gt;"
  #
  #     assert ~MD|
  #     ```elixir
  #     lang = {@lang}
  #     ```|HEEX |> MDEx.rendered_to_html() =~ "lang = &lbrace;@lang&rbrace;"
  #   end
  # end

  describe "use MDEx with options" do
    defmodule UnderlineDisabled do
      use MDEx, extension: [underline: false]

      def html do
        ~MD|Hello __world__|HTML
      end
    end

    defmodule DefaultOptions do
      use MDEx

      def html do
        ~MD|Hello __world__|HTML
      end
    end

    test "underline disabled" do
      assert UnderlineDisabled.html() == "<p>Hello <strong>world</strong></p>"
    end

    test "default options" do
      assert DefaultOptions.html() == "<p>Hello <u>world</u></p>"
    end
  end

  describe "use MDEx merge options" do
    defmodule OverwriteOptions do
      use MDEx, extension: [superscript: false]

      def test_underline do
        ~MD|Hello ~world~|HTML
      end

      def test_superscript do
        ~MD|Hello ^world^|HTML
      end
    end

    test "default underline still enabled" do
      assert OverwriteOptions.test_underline() == "<p>Hello <del>world</del></p>"
    end

    test "disable default option" do
      assert OverwriteOptions.test_superscript() == "<p>Hello ^world^</p>"
    end
  end

  describe "import MDEx.Sigil without use MDEx" do
    defmodule ImportOnly do
      import MDEx.Sigil

      def html do
        ~MD|Hello ~world~|HTML
      end
    end

    test "default options" do
      assert ImportOnly.html() == "<p>Hello <del>world</del></p>"
    end
  end
end
