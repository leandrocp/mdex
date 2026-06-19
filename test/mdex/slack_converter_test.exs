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

    test "flattens duplicate bold inside heading" do
      {:ok, result} = MDEx.to_slack("# Yay **Slack**")

      assert result == "*Yay Slack*\n"
    end

    test "preserves distinct nested styles inside heading" do
      {:ok, result} = MDEx.to_slack("# Yay _Slack_ and ~~mrkdwn~~")

      assert result == "*Yay _Slack_ and ~mrkdwn~*\n"
    end

    test "converts link from markdown" do
      {:ok, result} = MDEx.to_slack("[click here](https://example.com)")

      assert result == "<https://example.com|click here>\n"
    end

    test "flattens formatting inside link labels" do
      {:ok, result} = MDEx.to_slack("[**bold** and _italic_](https://example.com)")

      assert result == "<https://example.com|bold and italic>\n"
    end

    test "converts fenced code block without language tag" do
      {:ok, result} = MDEx.to_slack("```elixir\nIO.puts(\"hello\")\n```")

      assert result == "```\nIO.puts(\"hello\")\n```\n"
    end

    test "converts strikethrough from markdown" do
      {:ok, result} = MDEx.to_slack("~~strikethrough~~")

      assert result == "~strikethrough~\n"
    end

    test "escapes Slack control characters in text" do
      {:ok, result} = MDEx.to_slack("Tom & Jerry < Bugs > Daffy")

      assert result == "Tom &amp; Jerry &lt; Bugs &gt; Daffy\n"
    end

    test "does not escape generated link delimiters" do
      {:ok, result} = MDEx.to_slack("[Slack & docs](https://docs.slack.dev/?a=1&b=2)")

      assert result == "<https://docs.slack.dev/?a=1&amp;b=2|Slack &amp; docs>\n"
    end

    test "omits dangerous link URLs by default" do
      {:ok, result} = MDEx.to_slack("[click me](javascript:alert(document.cookie))")

      assert result == "click me\n"
    end

    test "detects dangerous URL schemes case-insensitively" do
      input =
        "[a](javascript:a) [b](Javascript:b) [c](jaVascript:c) [d](data:xyz) [e](Data:xyz) [f](vbscripT:f) [g](FILE:g) [h](data:image/png;base64,AAAA)"

      {:ok, result} = MDEx.to_slack(input)

      assert result == "a b c d e f g <data:image/png;base64,AAAA|h>\n"
    end

    test "preserves dangerous link URLs when unsafe rendering is enabled" do
      {:ok, result} = MDEx.to_slack("[click me](javascript:alert(document.cookie))", render: [unsafe: true])

      assert result == "<javascript:alert(document.cookie)|click me>\n"
    end

    test "omits dangerous image URLs by default" do
      input = %Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [
              %MDEx.Image{url: "data:text/html,<script>alert(1)</script>", title: "Alt text"}
            ]
          }
        ]
      }

      {:ok, result} = SlackConverter.convert(input, [])

      assert result == "Alt text\n"
    end

    test "preserves dangerous image URLs when unsafe rendering is enabled" do
      input = %Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [
              %MDEx.Image{url: "javascript:alert(1)", title: "Alt text"}
            ]
          }
        ]
      }

      {:ok, result} = SlackConverter.convert(input, unsafe: true)

      assert result == "<javascript:alert(1)|Alt text>\n"
    end

    test "renders nested lists with indentation" do
      input = %Document{
        nodes: [
          %MDEx.List{
            nodes: [
              %MDEx.ListItem{
                list_type: :bullet,
                nodes: [
                  %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "top"}]},
                  %MDEx.List{
                    nodes: [
                      %MDEx.ListItem{list_type: :bullet, nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "nested"}]}]}
                    ]
                  }
                ]
              }
            ]
          }
        ]
      }

      {:ok, result} = SlackConverter.convert(input, [])

      assert result == "- top\n  - nested\n"
    end

    test "renders literal HTML as escaped text" do
      input = %Document{nodes: [%MDEx.HtmlInline{literal: "<span>text & more</span>"}]}

      {:ok, result} = SlackConverter.convert(input, [])

      assert result == "&lt;span&gt;text &amp; more&lt;/span&gt;"
    end
  end

  describe "Slack mrkdwn docs matrix" do
    test "renders Slack-supported inline styles" do
      {:ok, result} = MDEx.to_slack("**bold** _italic_ ~~strike~~ `code`")

      assert result == "*bold* _italic_ ~strike~ `code`\n"
    end

    test "renders supported nested inline styles without duplicate delimiters" do
      {:ok, result} = MDEx.to_slack("**bold _italic_** and _italic **bold**_")

      assert result == "*bold _italic_* and _italic *bold*_\n"
    end

    test "escapes Slack control characters in literal text and code" do
      {:ok, result} = MDEx.to_slack("Tom & Jerry < Bugs > `a < b && c > d`")

      assert result == "Tom &amp; Jerry &lt; Bugs &gt; `a &lt; b &amp;&amp; c &gt; d`\n"
    end

    test "renders line breaks and block quotes using Slack mrkdwn syntax" do
      {:ok, result} = MDEx.to_slack("line one\nline two\n\n> quoted\n> still quoted")

      assert result == "line one line two\n> quoted still quoted\n"
    end

    test "renders Markdown lists as Slack plain-text list approximations" do
      {:ok, result} = MDEx.to_slack("- first\n- second\n\n1. alpha\n2. beta")

      assert result == "- first\n- second\n1. alpha\n2. beta\n"
    end

    test "renders task lists as plain-text checkbox approximations" do
      {:ok, result} = MDEx.to_slack("- [ ] todo\n- [x] done", extension: [tasklist: true])

      assert result == "- [ ] todo\n- [x] done\n"
    end

    test "renders thematic breaks as Slack divider text" do
      {:ok, result} = MDEx.to_slack("---")

      assert result == "---\n"
    end

    test "renders Markdown links and images as Slack links" do
      input = "[Slack](https://docs.slack.dev/?a=1&b=2) ![Logo](https://example.com/logo.png)"

      {:ok, result} = MDEx.to_slack(input)

      assert result == "<https://docs.slack.dev/?a=1&amp;b=2|Slack> <https://example.com/logo.png|Logo>\n"
    end

    test "escapes Slack link separators inside generated URLs" do
      {:ok, result} = MDEx.to_slack("[pipe](https://example.com/a|b)")

      assert result == "<https://example.com/a%7Cb|pipe>\n"
    end

    test "flattens Markdown tables to pipe-separated text rows" do
      input = "| Name | Age |\n| --- | --- |\n| Ana | 42 |"

      {:ok, result} = MDEx.to_slack(input, extension: [table: true])

      assert result == "Name | Age\nAna | 42\n"
    end

    test "preserves fenced code content while dropping unsupported language tags" do
      {:ok, result} = MDEx.to_slack("```python\nprint(\"hello\")\n```")

      assert result == "```\nprint(\"hello\")\n```\n"
    end
  end
end
