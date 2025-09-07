defmodule MDEx.DeltaConverterTest do
  use ExUnit.Case

  alias MDEx.DeltaConverter
  alias MDEx.Document

  describe "convert/2" do
    test "converts empty document" do
      doc = %Document{nodes: []}
      assert {:ok, %{"ops" => []}} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts simple text" do
      doc = %Document{nodes: [%MDEx.Text{literal: "Hello World"}]}
      
      assert {:ok, %{"ops" => [%{"insert" => "Hello World"}]}} = 
        DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts text with bold formatting" do
      doc = %Document{
        nodes: [
          %MDEx.Strong{
            nodes: [%MDEx.Text{literal: "Bold text"}]
          }
        ]
      }
      
      expected = %{"ops" => [%{"insert" => "Bold text", "attributes" => %{"bold" => true}}]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts text with italic formatting" do
      doc = %Document{
        nodes: [
          %MDEx.Emph{
            nodes: [%MDEx.Text{literal: "Italic text"}]
          }
        ]
      }
      
      expected = %{"ops" => [%{"insert" => "Italic text", "attributes" => %{"italic" => true}}]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts inline code" do
      doc = %Document{
        nodes: [%MDEx.Code{literal: "console.log()", num_backticks: 1}]
      }
      
      expected = %{"ops" => [%{"insert" => "console.log()", "attributes" => %{"code" => true}}]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts nested formatting (bold + italic)" do
      doc = %Document{
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
      
      expected = %{"ops" => [
        %{"insert" => "Bold italic", "attributes" => %{"bold" => true, "italic" => true}}
      ]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts paragraph" do
      doc = %Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [%MDEx.Text{literal: "Paragraph text"}]
          }
        ]
      }
      
      expected = %{"ops" => [
        %{"insert" => "Paragraph text"},
        %{"insert" => "\n"}
      ]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts multiple paragraphs" do
      doc = %Document{
        nodes: [
          %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "First paragraph"}]},
          %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Second paragraph"}]}
        ]
      }
      
      expected = %{"ops" => [
        %{"insert" => "First paragraph"},
        %{"insert" => "\n"},
        %{"insert" => "Second paragraph"},
        %{"insert" => "\n"}
      ]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts heading level 1" do
      doc = %Document{
        nodes: [
          %MDEx.Heading{
            level: 1,
            nodes: [%MDEx.Text{literal: "Main Title"}],
            setext: false
          }
        ]
      }
      
      expected = %{"ops" => [
        %{"insert" => "Main Title"},
        %{"insert" => "\n", "attributes" => %{"header" => 1}}
      ]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts heading level 2" do
      doc = %Document{
        nodes: [
          %MDEx.Heading{
            level: 2,
            nodes: [%MDEx.Text{literal: "Subtitle"}],
            setext: false
          }
        ]
      }
      
      expected = %{"ops" => [
        %{"insert" => "Subtitle"},
        %{"insert" => "\n", "attributes" => %{"header" => 2}}
      ]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts all heading levels" do
      for level <- 1..6 do
        doc = %Document{
          nodes: [
            %MDEx.Heading{
              level: level,
              nodes: [%MDEx.Text{literal: "Header #{level}"}],
              setext: false
            }
          ]
        }
        
        expected = %{"ops" => [
          %{"insert" => "Header #{level}"},
          %{"insert" => "\n", "attributes" => %{"header" => level}}
        ]}
        assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
      end
    end

    test "converts heading with formatting" do
      doc = %Document{
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
      
      expected = %{"ops" => [
        %{"insert" => "Bold Title", "attributes" => %{"bold" => true}},
        %{"insert" => "\n", "attributes" => %{"header" => 1}}
      ]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts soft break as space" do
      doc = %Document{
        nodes: [
          %MDEx.Text{literal: "Line one"},
          %MDEx.SoftBreak{},
          %MDEx.Text{literal: "line two"}
        ]
      }
      
      expected = %{"ops" => [
        %{"insert" => "Line one"},
        %{"insert" => " "},
        %{"insert" => "line two"}
      ]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts line break" do
      doc = %Document{
        nodes: [
          %MDEx.Text{literal: "Line one"},
          %MDEx.LineBreak{},
          %MDEx.Text{literal: "Line two"}
        ]
      }
      
      expected = %{"ops" => [
        %{"insert" => "Line one"},
        %{"insert" => "\n"},
        %{"insert" => "Line two"}
      ]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts complex mixed content" do
      doc = %Document{
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
      
      expected = %{"ops" => [
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
      ]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "handles unknown nodes gracefully" do
      # Create a mock unknown node type
      unknown_node = %{__struct__: UnknownNode, literal: "unknown content"}
      doc = %Document{nodes: [unknown_node]}
      
      expected = %{"ops" => [%{"insert" => "unknown content"}]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "uses custom converter when provided" do
      # Create a custom converter for a mock node type
      custom_node = %{__struct__: CustomNode, content: "custom"}
      
      custom_converter = fn node, _attrs, _opts ->
        [%{"insert" => "CUSTOM: #{node.content}"}]
      end
      
      converters = %{CustomNode => custom_converter}
      doc = %Document{nodes: [custom_node]}
      
      expected = %{"ops" => [%{"insert" => "CUSTOM: custom"}]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: converters})
    end

    test "handles empty text nodes" do
      doc = %Document{nodes: [%MDEx.Text{literal: ""}]}
      
      expected = %{"ops" => [%{"insert" => ""}]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "handles nested container nodes" do
      # Test a container node we don't explicitly handle
      unknown_container = %{__struct__: UnknownContainer, nodes: [%MDEx.Text{literal: "nested"}]}
      doc = %Document{nodes: [unknown_container]}
      
      expected = %{"ops" => [%{"insert" => "nested"}]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end
  end

  describe "Phase 2: Exotic Node Support" do
    test "converts strikethrough text" do
      doc = %Document{
        nodes: [%MDEx.Strikethrough{nodes: [%MDEx.Text{literal: "struck text"}]}]
      }
      
      expected = %{"ops" => [%{"insert" => "struck text", "attributes" => %{"strike" => true}}]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts underline text" do
      doc = %Document{
        nodes: [%MDEx.Underline{nodes: [%MDEx.Text{literal: "underlined text"}]}]
      }
      
      expected = %{"ops" => [%{"insert" => "underlined text", "attributes" => %{"underline" => true}}]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts links" do
      doc = %Document{
        nodes: [%MDEx.Link{url: "https://example.com", nodes: [%MDEx.Text{literal: "link text"}]}]
      }
      
      expected = %{"ops" => [%{"insert" => "link text", "attributes" => %{"link" => "https://example.com"}}]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts images with title" do
      doc = %Document{
        nodes: [%MDEx.Image{url: "https://example.com/image.png", title: "Alt text"}]
      }
      
      expected = %{"ops" => [%{"insert" => %{"image" => "https://example.com/image.png", "alt" => "Alt text"}}]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts images without title" do
      doc = %Document{
        nodes: [%MDEx.Image{url: "https://example.com/image.png", title: nil}]
      }
      
      expected = %{"ops" => [%{"insert" => %{"image" => "https://example.com/image.png"}}]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts blockquotes" do
      doc = %Document{
        nodes: [
          %MDEx.BlockQuote{
            nodes: [
              %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Quote text"}]}
            ]
          }
        ]
      }
      
      expected = %{"ops" => [
        %{"insert" => "Quote text"},
        %{"insert" => "\n", "attributes" => %{"blockquote" => true}}
      ]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts code blocks with language" do
      doc = %Document{
        nodes: [%MDEx.CodeBlock{literal: "console.log('hello');", info: "javascript"}]
      }
      
      expected = %{"ops" => [
        %{"insert" => "console.log('hello');"},
        %{"insert" => "\n", "attributes" => %{"code-block" => true, "code-block-lang" => "javascript"}}
      ]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts code blocks without language" do
      doc = %Document{
        nodes: [%MDEx.CodeBlock{literal: "echo hello", info: nil}]
      }
      
      expected = %{"ops" => [
        %{"insert" => "echo hello"},
        %{"insert" => "\n", "attributes" => %{"code-block" => true}}
      ]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts thematic breaks" do
      doc = %Document{
        nodes: [%MDEx.ThematicBreak{}]
      }
      
      expected = %{"ops" => [%{"insert" => "---\n"}]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts bullet lists" do
      doc = %Document{
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
      
      expected = %{"ops" => [
        %{"insert" => "First item"},
        %{"insert" => "\n", "attributes" => %{"list" => "bullet"}},
        %{"insert" => "Second item"},
        %{"insert" => "\n", "attributes" => %{"list" => "bullet"}}
      ]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts ordered lists" do
      doc = %Document{
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
      
      expected = %{"ops" => [
        %{"insert" => "First item"},
        %{"insert" => "\n", "attributes" => %{"list" => "ordered"}},
        %{"insert" => "Second item"},
        %{"insert" => "\n", "attributes" => %{"list" => "ordered"}}
      ]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts task items checked" do
      doc = %Document{
        nodes: [
          %MDEx.TaskItem{
            checked: true,
            nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Completed task"}]}]
          }
        ]
      }
      
      expected = %{"ops" => [
        %{"insert" => "Completed task"},
        %{"insert" => "\n", "attributes" => %{"list" => "bullet", "task" => true}}
      ]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts task items unchecked" do
      doc = %Document{
        nodes: [
          %MDEx.TaskItem{
            checked: false,
            nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Pending task"}]}]
          }
        ]
      }
      
      expected = %{"ops" => [
        %{"insert" => "Pending task"},
        %{"insert" => "\n", "attributes" => %{"list" => "bullet", "task" => false}}
      ]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts footnote references" do
      doc = %Document{
        nodes: [%MDEx.FootnoteReference{name: "note1"}]
      }
      
      expected = %{"ops" => [%{"insert" => "[^note1]", "attributes" => %{"footnote_ref" => "note1"}}]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts footnote definitions" do
      doc = %Document{
        nodes: [
          %MDEx.FootnoteDefinition{
            name: "note1",
            nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Footnote content"}]}]
          }
        ]
      }
      
      expected = %{"ops" => [
        %{"insert" => "Footnote content"},
        %{"insert" => "\n", "attributes" => %{"footnote_definition" => "note1"}}
      ]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts subscript" do
      doc = %Document{
        nodes: [%MDEx.Subscript{nodes: [%MDEx.Text{literal: "H2O"}]}]
      }
      
      expected = %{"ops" => [%{"insert" => "H2O", "attributes" => %{"subscript" => true}}]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts superscript" do
      doc = %Document{
        nodes: [%MDEx.Superscript{nodes: [%MDEx.Text{literal: "E=mc2"}]}]
      }
      
      expected = %{"ops" => [%{"insert" => "E=mc2", "attributes" => %{"superscript" => true}}]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts inline math" do
      doc = %Document{
        nodes: [%MDEx.Math{literal: "x^2 + y^2 = z^2", display_math: false}]
      }
      
      expected = %{"ops" => [%{"insert" => "x^2 + y^2 = z^2", "attributes" => %{"math" => "inline"}}]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts display math" do
      doc = %Document{
        nodes: [%MDEx.Math{literal: "\\sum_{i=1}^n x_i", display_math: true}]
      }
      
      expected = %{"ops" => [%{"insert" => "\\sum_{i=1}^n x_i", "attributes" => %{"math" => "display"}}]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts alerts with title" do
      doc = %Document{
        nodes: [
          %MDEx.Alert{
            alert_type: :warning,
            title: "Important",
            nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "This is a warning"}]}]
          }
        ]
      }
      
      expected = %{"ops" => [
        %{"insert" => "This is a warning"},
        %{"insert" => "\n", "attributes" => %{"alert" => "warning", "alert_title" => "Important"}}
      ]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts alerts without title" do
      doc = %Document{
        nodes: [
          %MDEx.Alert{
            alert_type: :note,
            title: nil,
            nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "This is a note"}]}]
          }
        ]
      }
      
      expected = %{"ops" => [
        %{"insert" => "This is a note"},
        %{"insert" => "\n", "attributes" => %{"alert" => "note"}}
      ]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts spoilered text" do
      doc = %Document{
        nodes: [%MDEx.SpoileredText{nodes: [%MDEx.Text{literal: "Hidden content"}]}]
      }
      
      expected = %{"ops" => [%{"insert" => "Hidden content", "attributes" => %{"spoiler" => true}}]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts wiki links" do
      doc = %Document{
        nodes: [%MDEx.WikiLink{url: "WikiPage", nodes: [%MDEx.Text{literal: "Wiki Page"}]}]
      }
      
      expected = %{"ops" => [%{"insert" => "Wiki Page", "attributes" => %{"link" => "WikiPage", "wikilink" => true}}]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts simple table" do
      doc = %Document{
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
      
      expected = %{"ops" => [
        %{"insert" => "Name"},
        %{"insert" => "\t"},
        %{"insert" => "Age"},
        %{"insert" => "\n", "attributes" => %{"table" => "header"}},
        %{"insert" => "John"},
        %{"insert" => "\t"},
        %{"insert" => "30"},
        %{"insert" => "\n", "attributes" => %{"table" => "row"}}
      ]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts HTML block" do
      doc = %Document{
        nodes: [%MDEx.HtmlBlock{literal: "<div>HTML content</div>"}]
      }
      
      expected = %{"ops" => [
        %{"insert" => "<div>HTML content</div>"},
        %{"insert" => "\n", "attributes" => %{"html" => "block"}}
      ]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts HTML inline" do
      doc = %Document{
        nodes: [%MDEx.HtmlInline{literal: "<span>inline HTML</span>"}]
      }
      
      expected = %{"ops" => [%{"insert" => "<span>inline HTML</span>", "attributes" => %{"html" => "inline"}}]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts short codes" do
      doc = %Document{
        nodes: [%MDEx.ShortCode{emoji: "😀", code: ":smile:"}]
      }
      
      expected = %{"ops" => [%{"insert" => "😀"}]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts raw content" do
      doc = %Document{
        nodes: [%MDEx.Raw{literal: "raw content"}]
      }
      
      expected = %{"ops" => [%{"insert" => "raw content"}]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts front matter" do
      doc = %Document{
        nodes: [%MDEx.FrontMatter{literal: "---\ntitle: Test\n---"}]
      }
      
      expected = %{"ops" => [
        %{"insert" => "---\ntitle: Test\n---"},
        %{"insert" => "\n", "attributes" => %{"front_matter" => true}}
      ]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end

    test "converts complex nested formatting" do
      doc = %Document{
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
      
      expected = %{"ops" => [
        %{"insert" => "Bold italic strike", "attributes" => %{
          "bold" => true, 
          "italic" => true, 
          "strike" => true
        }}
      ]}
      assert {:ok, ^expected} = DeltaConverter.convert(doc, %{custom_converters: %{}})
    end
  end
end