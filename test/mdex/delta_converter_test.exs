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
end