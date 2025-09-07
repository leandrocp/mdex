defmodule MDEx.DeltaConverterTest do
  use ExUnit.Case

  alias MDEx.DeltaConverter
  alias MDEx.Document

  describe "convert/2" do
    test "converts empty document" do
      input = %Document{nodes: []}

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == []
    end

    test "converts simple text" do
      input = %Document{nodes: [%MDEx.Text{literal: "Hello World"}]}

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [%{"insert" => "Hello World"}]
    end

    test "converts text with bold formatting" do
      input = %Document{
        nodes: [
          %MDEx.Strong{
            nodes: [%MDEx.Text{literal: "Bold text"}]
          }
        ]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [%{"insert" => "Bold text", "attributes" => %{"bold" => true}}]
    end

    test "converts text with italic formatting" do
      input = %Document{
        nodes: [
          %MDEx.Emph{
            nodes: [%MDEx.Text{literal: "Italic text"}]
          }
        ]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [%{"insert" => "Italic text", "attributes" => %{"italic" => true}}]
    end

    test "converts inline code" do
      input = %Document{
        nodes: [%MDEx.Code{literal: "console.log()", num_backticks: 1}]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [%{"insert" => "console.log()", "attributes" => %{"code" => true}}]
    end

    test "converts nested formatting (bold + italic)" do
      input = %Document{
        nodes: [
          %MDEx.Strong{
            nodes: [
              %MDEx.Emph{
                nodes: [%MDEx.Text{literal: "Bold italic"}]
              }
            ]
          }
        ]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [
               %{"insert" => "Bold italic", "attributes" => %{"bold" => true, "italic" => true}}
             ]
    end

    test "converts paragraph" do
      input = %Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [%MDEx.Text{literal: "Paragraph text"}]
          }
        ]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [
               %{"insert" => "Paragraph text"},
               %{"insert" => "\n"}
             ]
    end

    test "converts multiple paragraphs" do
      input = %Document{
        nodes: [
          %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "First paragraph"}]},
          %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Second paragraph"}]}
        ]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [
               %{"insert" => "First paragraph"},
               %{"insert" => "\n"},
               %{"insert" => "Second paragraph"},
               %{"insert" => "\n"}
             ]
    end

    test "converts heading level 1" do
      input = %Document{
        nodes: [
          %MDEx.Heading{
            level: 1,
            nodes: [%MDEx.Text{literal: "Main Title"}],
            setext: false
          }
        ]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [
               %{"insert" => "Main Title"},
               %{"insert" => "\n", "attributes" => %{"header" => 1}}
             ]
    end

    test "converts heading level 2" do
      input = %Document{
        nodes: [
          %MDEx.Heading{
            level: 2,
            nodes: [%MDEx.Text{literal: "Subtitle"}],
            setext: false
          }
        ]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [
               %{"insert" => "Subtitle"},
               %{"insert" => "\n", "attributes" => %{"header" => 2}}
             ]
    end

    test "converts all heading levels" do
      for level <- 1..6 do
        input = %Document{
          nodes: [
            %MDEx.Heading{
              level: level,
              nodes: [%MDEx.Text{literal: "Header #{level}"}],
              setext: false
            }
          ]
        }

        {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

        assert result == [
                 %{"insert" => "Header #{level}"},
                 %{"insert" => "\n", "attributes" => %{"header" => level}}
               ]
      end
    end

    test "converts heading with formatting" do
      input = %Document{
        nodes: [
          %MDEx.Heading{
            level: 1,
            nodes: [
              %MDEx.Strong{
                nodes: [%MDEx.Text{literal: "Bold Title"}]
              }
            ],
            setext: false
          }
        ]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [
               %{"insert" => "Bold Title", "attributes" => %{"bold" => true}},
               %{"insert" => "\n", "attributes" => %{"header" => 1}}
             ]
    end

    test "converts soft break as space" do
      input = %Document{
        nodes: [
          %MDEx.Text{literal: "Line one"},
          %MDEx.SoftBreak{},
          %MDEx.Text{literal: "line two"}
        ]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [
               %{"insert" => "Line one"},
               %{"insert" => " "},
               %{"insert" => "line two"}
             ]
    end

    test "converts line break" do
      input = %Document{
        nodes: [
          %MDEx.Text{literal: "Line one"},
          %MDEx.LineBreak{},
          %MDEx.Text{literal: "Line two"}
        ]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [
               %{"insert" => "Line one"},
               %{"insert" => "\n"},
               %{"insert" => "Line two"}
             ]
    end

    test "converts complex mixed content" do
      input = %Document{
        nodes: [
          %MDEx.Heading{
            level: 1,
            nodes: [%MDEx.Text{literal: "Title"}],
            setext: false
          },
          %MDEx.Paragraph{
            nodes: [
              %MDEx.Text{literal: "This is "},
              %MDEx.Strong{nodes: [%MDEx.Text{literal: "bold"}]},
              %MDEx.Text{literal: " and "},
              %MDEx.Emph{nodes: [%MDEx.Text{literal: "italic"}]},
              %MDEx.Text{literal: " with "},
              %MDEx.Code{literal: "code", num_backticks: 1},
              %MDEx.Text{literal: "."}
            ]
          }
        ]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [
               %{"insert" => "Title"},
               %{"insert" => "\n", "attributes" => %{"header" => 1}},
               %{"insert" => "This is "},
               %{"insert" => "bold", "attributes" => %{"bold" => true}},
               %{"insert" => " and "},
               %{"insert" => "italic", "attributes" => %{"italic" => true}},
               %{"insert" => " with "},
               %{"insert" => "code", "attributes" => %{"code" => true}},
               %{"insert" => "."},
               %{"insert" => "\n"}
             ]
    end

    test "handles unknown nodes gracefully" do
      # Create a mock unknown node type
      unknown_node = %{__struct__: UnknownNode, literal: "unknown content"}
      input = %Document{nodes: [unknown_node]}

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [%{"insert" => "unknown content"}]
    end

    test "uses custom converter when provided" do
      # Create a custom converter for a mock node type
      custom_node = %{__struct__: CustomNode, content: "custom"}

      custom_converter = fn node, _options ->
        [%{"insert" => "CUSTOM: #{node.content}"}]
      end

      converters = %{CustomNode => custom_converter}
      input = %Document{nodes: [custom_node]}

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: converters})

      assert result == [%{"insert" => "CUSTOM: custom"}]
    end

    test "handles empty text nodes" do
      input = %Document{nodes: [%MDEx.Text{literal: ""}]}

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [%{"insert" => ""}]
    end

    test "handles nested container nodes" do
      # Test a container node we don't explicitly handle
      unknown_container = %{__struct__: UnknownContainer, nodes: [%MDEx.Text{literal: "nested"}]}
      input = %Document{nodes: [unknown_container]}

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [%{"insert" => "nested"}]
    end
  end

  describe "Phase 2: Exotic Node Support" do
    test "converts strikethrough text" do
      input = %Document{
        nodes: [%MDEx.Strikethrough{nodes: [%MDEx.Text{literal: "struck text"}]}]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [%{"insert" => "struck text", "attributes" => %{"strike" => true}}]
    end

    test "converts underline text" do
      input = %Document{
        nodes: [%MDEx.Underline{nodes: [%MDEx.Text{literal: "underlined text"}]}]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [%{"insert" => "underlined text", "attributes" => %{"underline" => true}}]
    end

    test "converts links" do
      input = %Document{
        nodes: [%MDEx.Link{url: "https://example.com", nodes: [%MDEx.Text{literal: "link text"}]}]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [%{"insert" => "link text", "attributes" => %{"link" => "https://example.com"}}]
    end

    test "converts images with title" do
      input = %Document{
        nodes: [%MDEx.Image{url: "https://example.com/image.png", title: "Alt text"}]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [%{"insert" => %{"image" => "https://example.com/image.png", "alt" => "Alt text"}}]
    end

    test "converts images without title" do
      input = %Document{
        nodes: [%MDEx.Image{url: "https://example.com/image.png", title: nil}]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [%{"insert" => %{"image" => "https://example.com/image.png"}}]
    end

    test "converts blockquotes" do
      input = %Document{
        nodes: [
          %MDEx.BlockQuote{
            nodes: [
              %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Quote text"}]}
            ]
          }
        ]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [
               %{"insert" => "Quote text"},
               %{"insert" => "\n", "attributes" => %{"blockquote" => true}}
             ]
    end

    test "converts code blocks with language" do
      input = %Document{
        nodes: [%MDEx.CodeBlock{literal: "console.log('hello');", info: "javascript"}]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [
               %{"insert" => "console.log('hello');"},
               %{"insert" => "\n", "attributes" => %{"code-block" => true, "code-block-lang" => "javascript"}}
             ]
    end

    test "converts code blocks without language" do
      input = %Document{
        nodes: [%MDEx.CodeBlock{literal: "echo hello", info: nil}]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [
               %{"insert" => "echo hello"},
               %{"insert" => "\n", "attributes" => %{"code-block" => true}}
             ]
    end


    test "converts thematic breaks" do
      input = %Document{
        nodes: [%MDEx.ThematicBreak{}]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [%{"insert" => "***\n"}]
    end

    test "converts bullet lists" do
      input = %Document{
        nodes: [
          %MDEx.List{
            nodes: [
              %MDEx.ListItem{
                list_type: :bullet,
                nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "First item"}]}]
              },
              %MDEx.ListItem{
                list_type: :bullet,
                nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Second item"}]}]
              }
            ]
          }
        ]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [
               %{"insert" => "First item"},
               %{"insert" => "\n", "attributes" => %{"list" => "bullet"}},
               %{"insert" => "Second item"},
               %{"insert" => "\n", "attributes" => %{"list" => "bullet"}}
             ]
    end

    test "converts ordered lists" do
      input = %Document{
        nodes: [
          %MDEx.List{
            nodes: [
              %MDEx.ListItem{
                list_type: :ordered,
                nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "First item"}]}]
              },
              %MDEx.ListItem{
                list_type: :ordered,
                nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Second item"}]}]
              }
            ]
          }
        ]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [
               %{"insert" => "First item"},
               %{"insert" => "\n", "attributes" => %{"list" => "ordered"}},
               %{"insert" => "Second item"},
               %{"insert" => "\n", "attributes" => %{"list" => "ordered"}}
             ]
    end

    test "converts task items checked" do
      input = %Document{
        nodes: [
          %MDEx.TaskItem{
            checked: true,
            nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Completed task"}]}]
          }
        ]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [
               %{"insert" => "Completed task"},
               %{"insert" => "\n", "attributes" => %{"list" => "bullet", "task" => true}}
             ]
    end

    test "converts task items unchecked" do
      input = %Document{
        nodes: [
          %MDEx.TaskItem{
            checked: false,
            nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Pending task"}]}]
          }
        ]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [
               %{"insert" => "Pending task"},
               %{"insert" => "\n", "attributes" => %{"list" => "bullet", "task" => false}}
             ]
    end

    test "converts footnote references" do
      input = %Document{
        nodes: [%MDEx.FootnoteReference{name: "note1"}]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [%{"insert" => "[^note1]", "attributes" => %{"footnote_ref" => "note1"}}]
    end

    test "converts footnote definitions" do
      input = %Document{
        nodes: [
          %MDEx.FootnoteDefinition{
            name: "note1",
            nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Footnote content"}]}]
          }
        ]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [
               %{"insert" => "Footnote content"},
               %{"insert" => "\n", "attributes" => %{"footnote_definition" => "note1"}}
             ]
    end

    test "converts subscript" do
      input = %Document{
        nodes: [%MDEx.Subscript{nodes: [%MDEx.Text{literal: "H2O"}]}]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [%{"insert" => "H2O", "attributes" => %{"subscript" => true}}]
    end

    test "converts superscript" do
      input = %Document{
        nodes: [%MDEx.Superscript{nodes: [%MDEx.Text{literal: "E=mc2"}]}]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [%{"insert" => "E=mc2", "attributes" => %{"superscript" => true}}]
    end

    test "converts inline math" do
      input = %Document{
        nodes: [%MDEx.Math{literal: "x^2 + y^2 = z^2", display_math: false}]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [%{"insert" => "x^2 + y^2 = z^2", "attributes" => %{"math" => "inline"}}]
    end

    test "converts display math" do
      input = %Document{
        nodes: [%MDEx.Math{literal: "\\sum_{i=1}^n x_i", display_math: true}]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [%{"insert" => "\\sum_{i=1}^n x_i", "attributes" => %{"math" => "display"}}]
    end

    test "converts alerts with title" do
      input = %Document{
        nodes: [
          %MDEx.Alert{
            alert_type: :warning,
            title: "Important",
            nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "This is a warning"}]}]
          }
        ]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [
               %{"insert" => "This is a warning"},
               %{"insert" => "\n", "attributes" => %{"alert" => "warning", "alert_title" => "Important"}}
             ]
    end

    test "converts alerts without title" do
      input = %Document{
        nodes: [
          %MDEx.Alert{
            alert_type: :note,
            title: nil,
            nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "This is a note"}]}]
          }
        ]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [
               %{"insert" => "This is a note"},
               %{"insert" => "\n", "attributes" => %{"alert" => "note"}}
             ]
    end

    test "converts spoilered text" do
      input = %Document{
        nodes: [%MDEx.SpoileredText{nodes: [%MDEx.Text{literal: "Hidden content"}]}]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [%{"insert" => "Hidden content", "attributes" => %{"spoiler" => true}}]
    end

    test "converts wiki links" do
      input = %Document{
        nodes: [%MDEx.WikiLink{url: "WikiPage", nodes: [%MDEx.Text{literal: "Wiki Page"}]}]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [%{"insert" => "Wiki Page", "attributes" => %{"link" => "WikiPage", "wikilink" => true}}]
    end

    test "converts simple table" do
      input = %Document{
        nodes: [
          %MDEx.Table{
            nodes: [
              %MDEx.TableRow{
                header: true,
                nodes: [
                  %MDEx.TableCell{nodes: [%MDEx.Text{literal: "Name"}]},
                  %MDEx.TableCell{nodes: [%MDEx.Text{literal: "Age"}]}
                ]
              },
              %MDEx.TableRow{
                header: false,
                nodes: [
                  %MDEx.TableCell{nodes: [%MDEx.Text{literal: "John"}]},
                  %MDEx.TableCell{nodes: [%MDEx.Text{literal: "30"}]}
                ]
              }
            ]
          }
        ]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [
               %{"insert" => "Name"},
               %{"insert" => "\t"},
               %{"insert" => "Age"},
               %{"insert" => "\n", "attributes" => %{"table" => "header"}},
               %{"insert" => "John"},
               %{"insert" => "\t"},
               %{"insert" => "30"},
               %{"insert" => "\n", "attributes" => %{"table" => "row"}}
             ]
    end

    test "converts HTML block" do
      input = %Document{
        nodes: [%MDEx.HtmlBlock{literal: "<div>HTML content</div>"}]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [
               %{"insert" => "<div>HTML content</div>"},
               %{"insert" => "\n", "attributes" => %{"html" => "block"}}
             ]
    end

    test "converts HTML inline" do
      input = %Document{
        nodes: [%MDEx.HtmlInline{literal: "<span>inline HTML</span>"}]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [%{"insert" => "<span>inline HTML</span>", "attributes" => %{"html" => "inline"}}]
    end

    test "converts short codes" do
      input = %Document{
        nodes: [%MDEx.ShortCode{emoji: "😀", code: ":smile:"}]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [%{"insert" => "😀"}]
    end

    test "converts raw content" do
      input = %Document{
        nodes: [%MDEx.Raw{literal: "raw content"}]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [%{"insert" => "raw content"}]
    end

    test "converts front matter" do
      input = %Document{
        nodes: [%MDEx.FrontMatter{literal: "---\ntitle: Test\n---"}]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [
               %{"insert" => "---\ntitle: Test\n---"},
               %{"insert" => "\n", "attributes" => %{"front_matter" => true}}
             ]
    end

    test "converts complex nested formatting" do
      input = %Document{
        nodes: [
          %MDEx.Strong{
            nodes: [
              %MDEx.Emph{
                nodes: [
                  %MDEx.Strikethrough{
                    nodes: [%MDEx.Text{literal: "Bold italic strike"}]
                  }
                ]
              }
            ]
          }
        ]
      }

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{}})

      assert result == [
               %{
                 "insert" => "Bold italic strike",
                 "attributes" => %{
                   "bold" => true,
                   "italic" => true,
                   "strike" => true
                 }
               }
             ]
    end
  end

  describe "custom converters" do
    test "custom table converter creates structured Delta objects" do
      input = %Document{
        nodes: [
          %MDEx.Table{
            nodes: [
              %MDEx.TableRow{
                header: true,
                nodes: [
                  %MDEx.TableCell{nodes: [%MDEx.Text{literal: "Name"}]},
                  %MDEx.TableCell{nodes: [%MDEx.Text{literal: "Age"}]}
                ]
              },
              %MDEx.TableRow{
                header: false,
                nodes: [
                  %MDEx.TableCell{nodes: [%MDEx.Text{literal: "John"}]},
                  %MDEx.TableCell{nodes: [%MDEx.Text{literal: "30"}]}
                ]
              }
            ]
          }
        ]
      }

      table_converter = fn %MDEx.Table{nodes: rows}, _options ->
        [
          %{
            "insert" => %{
              "table" => %{
                "rows" => length(rows),
                "data" => "custom_table_data"
              }
            }
          }
        ]
      end

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{MDEx.Table => table_converter}})

      assert result == [
               %{
                 "insert" => %{
                   "table" => %{
                     "rows" => 2,
                     "data" => "custom_table_data"
                   }
                 }
               }
             ]
    end

    test "skip converter skips nodes entirely" do
      input = %Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [
              %MDEx.Text{literal: "Before math "},
              %MDEx.Math{literal: "x^2", display_math: false},
              %MDEx.Text{literal: " after math"}
            ]
          }
        ]
      }

      math_skipper = fn %MDEx.Math{}, _options -> :skip end

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{MDEx.Math => math_skipper}})

      assert result == [
               %{"insert" => "Before math "},
               %{"insert" => " after math"},
               %{"insert" => "\n"}
             ]
    end

    test "custom image converter with custom format" do
      input = %Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [
              %MDEx.Image{url: "https://example.com/image.png", title: "Example Image"}
            ]
          }
        ]
      }

      image_converter = fn %MDEx.Image{url: url, title: title}, _options ->
        [
          %{
            "insert" => %{"custom_image" => %{"src" => url, "alt" => title || ""}},
            "attributes" => %{"display" => "block"}
          }
        ]
      end

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{MDEx.Image => image_converter}})

      assert result == [
               %{
                 "insert" => %{"custom_image" => %{"src" => "https://example.com/image.png", "alt" => "Example Image"}},
                 "attributes" => %{"display" => "block"}
               },
               %{"insert" => "\n"}
             ]
    end

    test "custom converter returning empty list skips the node" do
      input = %Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [
              %MDEx.Text{literal: "Before "},
              %MDEx.Code{literal: "test"},
              %MDEx.Text{literal: " after"}
            ]
          }
        ]
      }

      skip_converter = fn %MDEx.Code{}, _options -> [] end

      {:ok, result} = DeltaConverter.convert(input, %{custom_converters: %{MDEx.Code => skip_converter}})

      assert result == [
               %{"insert" => "Before "},
               %{"insert" => " after"},
               %{"insert" => "\n"}
             ]
    end

    test "custom converter returning error propagates error" do
      input = %Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [%MDEx.Code{literal: "test"}]
          }
        ]
      }

      error_converter = fn %MDEx.Code{}, _options -> {:error, "Custom error"} end

      assert {:error, {:custom_converter_error, "Custom error"}} =
               DeltaConverter.convert(input, %{custom_converters: %{MDEx.Code => error_converter}})
    end

    test "multiple custom converters work together" do
      input = %Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [
              %MDEx.Strong{nodes: [%MDEx.Text{literal: "Bold"}]},
              %MDEx.Text{literal: " and "},
              %MDEx.Math{literal: "x^2", display_math: false}
            ]
          }
        ]
      }

      math_to_text = fn %MDEx.Math{literal: math}, _options ->
        [%{"insert" => "[MATH: #{math}]", "attributes" => %{"math_placeholder" => true}}]
      end

      strong_to_caps = fn %MDEx.Strong{nodes: children}, _options ->
        child_text =
          Enum.map_join(children, "", fn
            %MDEx.Text{literal: text} -> String.upcase(text)
            _ -> ""
          end)

        [%{"insert" => child_text, "attributes" => %{"uppercase" => true}}]
      end

      {:ok, result} =
        DeltaConverter.convert(input, %{
          custom_converters: %{
            MDEx.Math => math_to_text,
            MDEx.Strong => strong_to_caps
          }
        })

      assert result == [
               %{"insert" => "BOLD", "attributes" => %{"uppercase" => true}},
               %{"insert" => " and "},
               %{"insert" => "[MATH: x^2]", "attributes" => %{"math_placeholder" => true}},
               %{"insert" => "\n"}
             ]
    end
  end
end
