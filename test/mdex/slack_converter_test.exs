defmodule MDEx.SlackConverterTest do
  use ExUnit.Case

  alias MDEx.SlackConverter
  alias MDEx.Document

  describe "convert/2" do
    test "converts empty document" do
      input = %Document{nodes: []}

      {:ok, result} = SlackConverter.convert(input, [])

      assert result == ""
    end

    test "converts plain text paragraph" do
      input = %Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Hello World"}]}]}

      {:ok, result} = SlackConverter.convert(input, [])

      assert result == "Hello World\n"
    end

    test "bold becomes *text*" do
      input = %Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [%MDEx.Strong{nodes: [%MDEx.Text{literal: "bold"}]}]
          }
        ]
      }

      {:ok, result} = SlackConverter.convert(input, [])

      assert result == "*bold*\n"
    end

    test "italic becomes _text_" do
      input = %Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [%MDEx.Emph{nodes: [%MDEx.Text{literal: "italic"}]}]
          }
        ]
      }

      {:ok, result} = SlackConverter.convert(input, [])

      assert result == "_italic_\n"
    end

    test "inline code becomes `code`" do
      input = %Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [%MDEx.Code{literal: "myFunc()", num_backticks: 1}]
          }
        ]
      }

      {:ok, result} = SlackConverter.convert(input, [])

      assert result == "`myFunc()`\n"
    end

    test "code block becomes triple-backtick block without language tag" do
      input = %Document{
        nodes: [
          %MDEx.CodeBlock{literal: "def hello do\n  :world\nend\n", info: "elixir", fenced: true, fence_char: "`", fence_length: 3, fence_offset: 0}
        ]
      }

      {:ok, result} = SlackConverter.convert(input, [])

      assert result == "```\ndef hello do\n  :world\nend\n```\n"
    end

    test "link becomes <url|label>" do
      input = %Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [%MDEx.Link{url: "https://example.com", title: "", nodes: [%MDEx.Text{literal: "Example"}]}]
          }
        ]
      }

      {:ok, result} = SlackConverter.convert(input, [])

      assert result == "<https://example.com|Example>\n"
    end

    test "strikethrough becomes ~text~" do
      input = %Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [%MDEx.Strikethrough{nodes: [%MDEx.Text{literal: "deleted"}]}]
          }
        ]
      }

      {:ok, result} = SlackConverter.convert(input, [])

      assert result == "~deleted~\n"
    end

    test "unordered list items get - prefix" do
      input = %Document{
        nodes: [
          %MDEx.List{
            list_type: :bullet,
            tight: true,
            nodes: [
              %MDEx.ListItem{list_type: :bullet, nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "first"}]}]},
              %MDEx.ListItem{list_type: :bullet, nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "second"}]}]}
            ]
          }
        ]
      }

      {:ok, result} = SlackConverter.convert(input, [])

      assert result == "- first\n- second\n"
    end

    test "ordered list items get numbered prefix" do
      input = %Document{
        nodes: [
          %MDEx.List{
            list_type: :ordered,
            tight: true,
            nodes: [
              %MDEx.ListItem{list_type: :ordered, nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "alpha"}]}]},
              %MDEx.ListItem{list_type: :ordered, nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "beta"}]}]}
            ]
          }
        ]
      }

      {:ok, result} = SlackConverter.convert(input, [])

      assert result == "1. alpha\n2. beta\n"
    end

    test "heading levels 1-6 render as *bold text*" do
      for level <- 1..6 do
        input = %Document{
          nodes: [%MDEx.Heading{level: level, setext: false, nodes: [%MDEx.Text{literal: "Title"}]}]
        }

        {:ok, result} = SlackConverter.convert(input, [])

        assert result == "*Title*\n", "Heading level #{level} failed"
      end
    end

    test "blockquote renders as > text" do
      input = %Document{
        nodes: [
          %MDEx.BlockQuote{
            nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "quoted text"}]}]
          }
        ]
      }

      {:ok, result} = SlackConverter.convert(input, [])

      assert result =~ "> quoted text"
    end

    test "nested inline formatting bold+italic produces *_text_*" do
      input = %Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [
              %MDEx.Strong{
                nodes: [%MDEx.Emph{nodes: [%MDEx.Text{literal: "nested"}]}]
              }
            ]
          }
        ]
      }

      {:ok, result} = SlackConverter.convert(input, [])

      assert result == "*_nested_*\n"
    end

    test "custom converter override via :custom_converters option" do
      custom = %{
        MDEx.Strong => fn _node, _opts -> "CUSTOM_BOLD" end
      }

      input = %Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [%MDEx.Strong{nodes: [%MDEx.Text{literal: "text"}]}]
          }
        ]
      }

      {:ok, result} = SlackConverter.convert(input, custom_converters: custom)

      assert result == "CUSTOM_BOLD\n"
    end

    test "custom converter can skip a node with :skip" do
      custom = %{
        MDEx.Strikethrough => fn _node, _opts -> :skip end
      }

      input = %Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [
              %MDEx.Text{literal: "before"},
              %MDEx.Strikethrough{nodes: [%MDEx.Text{literal: "skipped"}]},
              %MDEx.Text{literal: "after"}
            ]
          }
        ]
      }

      {:ok, result} = SlackConverter.convert(input, custom_converters: custom)

      assert result == "beforeafter\n"
    end
  end

  describe "to_slack/2 integration" do
    test "converts markdown string end-to-end" do
      {:ok, result} = MDEx.to_slack("**bold** and _italic_")

      assert result == "*bold* and _italic_\n"
    end

    test "to_slack!/2 returns string on success" do
      result = MDEx.to_slack!("Hello")

      assert is_binary(result)
      assert result == "Hello\n"
    end

    test "converts heading from markdown" do
      {:ok, result} = MDEx.to_slack("# My Heading")

      assert result == "*My Heading*\n"
    end

    test "converts link from markdown" do
      {:ok, result} = MDEx.to_slack("[click here](https://example.com)")

      assert result == "<https://example.com|click here>\n"
    end

    test "converts fenced code block without language tag" do
      {:ok, result} = MDEx.to_slack("```elixir\nIO.puts(\"hello\")\n```")

      assert result == "```\nIO.puts(\"hello\")\n```\n"
    end

    test "converts strikethrough from markdown" do
      {:ok, result} = MDEx.to_slack("~~strikethrough~~")

      assert result == "~strikethrough~\n"
    end
  end
end
