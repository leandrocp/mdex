defmodule MDEx.DeltaFormatTest do
  use ExUnit.Case

  describe "to_delta/1" do
    test "converts simple markdown text" do
      markdown = "Hello world"
      
      assert {:ok, %{"ops" => [
        %{"insert" => "Hello world"},
        %{"insert" => "\n"}
      ]}} = MDEx.to_delta(markdown)
    end

    test "converts bold text" do
      markdown = "**bold text**"
      
      assert {:ok, %{"ops" => [
        %{"insert" => "bold text", "attributes" => %{"bold" => true}},
        %{"insert" => "\n"}
      ]}} = MDEx.to_delta(markdown)
    end

    test "converts italic text" do
      markdown = "*italic text*"
      
      assert {:ok, %{"ops" => [
        %{"insert" => "italic text", "attributes" => %{"italic" => true}},
        %{"insert" => "\n"}
      ]}} = MDEx.to_delta(markdown)
    end

    test "converts inline code" do
      markdown = "`console.log('hello')`"
      
      assert {:ok, %{"ops" => [
        %{"insert" => "console.log('hello')", "attributes" => %{"code" => true}},
        %{"insert" => "\n"}
      ]}} = MDEx.to_delta(markdown)
    end

    test "converts heading level 1" do
      markdown = "# Main Title"
      
      assert {:ok, %{"ops" => [
        %{"insert" => "Main Title"},
        %{"insert" => "\n", "attributes" => %{"header" => 1}}
      ]}} = MDEx.to_delta(markdown)
    end

    test "converts heading level 2" do
      markdown = "## Subtitle"
      
      assert {:ok, %{"ops" => [
        %{"insert" => "Subtitle"},
        %{"insert" => "\n", "attributes" => %{"header" => 2}}
      ]}} = MDEx.to_delta(markdown)
    end

    test "converts multiple paragraphs" do
      markdown = "First paragraph\n\nSecond paragraph"
      
      assert {:ok, %{"ops" => [
        %{"insert" => "First paragraph"},
        %{"insert" => "\n"},
        %{"insert" => "Second paragraph"},
        %{"insert" => "\n"}
      ]}} = MDEx.to_delta(markdown)
    end

    test "converts mixed formatting" do
      markdown = "This has **bold** and *italic* and `code`"
      
      assert {:ok, %{"ops" => [
        %{"insert" => "This has "},
        %{"insert" => "bold", "attributes" => %{"bold" => true}},
        %{"insert" => " and "},
        %{"insert" => "italic", "attributes" => %{"italic" => true}},
        %{"insert" => " and "},
        %{"insert" => "code", "attributes" => %{"code" => true}},
        %{"insert" => "\n"}
      ]}} = MDEx.to_delta(markdown)
    end

    test "converts nested formatting" do
      markdown = "***bold italic***"
      
      assert {:ok, %{"ops" => [
        %{"insert" => "bold italic", "attributes" => %{"bold" => true, "italic" => true}},
        %{"insert" => "\n"}
      ]}} = MDEx.to_delta(markdown)
    end

    test "converts complex document" do
      markdown = """
      # Main Title

      This is a paragraph with **bold**, *italic*, and `code`.

      ## Subtitle

      Another paragraph here.
      """
      
      assert {:ok, %{"ops" => [
        %{"insert" => "Main Title"},
        %{"insert" => "\n", "attributes" => %{"header" => 1}},
        %{"insert" => "This is a paragraph with "},
        %{"insert" => "bold", "attributes" => %{"bold" => true}},
        %{"insert" => ", "},
        %{"insert" => "italic", "attributes" => %{"italic" => true}},
        %{"insert" => ", and "},
        %{"insert" => "code", "attributes" => %{"code" => true}},
        %{"insert" => "."},
        %{"insert" => "\n"},
        %{"insert" => "Subtitle"},
        %{"insert" => "\n", "attributes" => %{"header" => 2}},
        %{"insert" => "Another paragraph here."},
        %{"insert" => "\n"}
      ]}} = MDEx.to_delta(markdown)
    end

    test "handles empty markdown" do
      assert {:ok, %{"ops" => []}} = MDEx.to_delta("")
    end

    test "handles whitespace-only markdown" do
      assert {:ok, %{"ops" => []}} = MDEx.to_delta("   \n\n   ")
    end
  end

  describe "to_delta/2 with options" do
    test "accepts custom_converters option" do
      markdown = "Hello world"
      options = [custom_converters: %{}]
      
      assert {:ok, %{"ops" => [
        %{"insert" => "Hello world"},
        %{"insert" => "\n"}
      ]}} = MDEx.to_delta(markdown, options)
    end

    # Note: Testing invalid options directly is tricky since validation happens 
    # at the delta converter level, not at the main parse level
    # For now, we just test that valid options work
  end

  describe "to_delta!/1" do
    test "returns delta directly on success" do
      markdown = "**bold**"
      
      assert %{"ops" => [
        %{"insert" => "bold", "attributes" => %{"bold" => true}},
        %{"insert" => "\n"}
      ]} = MDEx.to_delta!(markdown)
    end

    test "raises on invalid input" do
      assert_raise MDEx.InvalidInputError, fn ->
        MDEx.to_delta!(%{invalid: "input"})
      end
    end
  end

  describe "to_delta with Document input" do
    test "converts Document struct directly" do
      doc = %MDEx.Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [%MDEx.Text{literal: "Direct document conversion"}]
          }
        ]
      }
      
      assert {:ok, %{"ops" => [
        %{"insert" => "Direct document conversion"},
        %{"insert" => "\n"}
      ]}} = MDEx.to_delta(doc)
    end
  end

  describe "to_delta with Pipe input" do
    test "converts Pipe struct" do
      pipe = MDEx.new(document: "*italic*")
      
      assert {:ok, %{"ops" => [
        %{"insert" => "italic", "attributes" => %{"italic" => true}},
        %{"insert" => "\n"}
      ]}} = MDEx.to_delta(pipe)
    end
  end

  describe "to_delta with fragment input" do
    test "converts single node fragment" do
      fragment = %MDEx.Text{literal: "Fragment text"}
      
      assert {:ok, %{"ops" => [
        %{"insert" => "Fragment text"}
      ]}} = MDEx.to_delta(fragment)
    end

    test "converts list of nodes fragment" do
      fragment = [
        %MDEx.Text{literal: "First "},
        %MDEx.Strong{nodes: [%MDEx.Text{literal: "bold"}]},
        %MDEx.Text{literal: " text"}
      ]
      
      assert {:ok, %{"ops" => [
        %{"insert" => "First "},
        %{"insert" => "bold", "attributes" => %{"bold" => true}},
        %{"insert" => " text"}
      ]}} = MDEx.to_delta(fragment)
    end
  end
end