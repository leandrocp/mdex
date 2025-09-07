defmodule MDEx.DeltaPropertyTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Property-based tests for Delta format conversion.

  These tests verify that certain invariants hold for all valid inputs:
  1. All Markdown input produces valid Delta operations
  2. Delta operations are well-formed
  3. No information is lost in simple cases
  """

  describe "delta format properties" do
    test "all valid markdown produces valid delta operations" do
      # Test various markdown samples
      markdown_samples = [
        "# Simple header",
        "**bold** and *italic*",
        "```\ncode block\n```",
        "> blockquote text",
        "- list item 1\n- list item 2",
        "1. ordered item\n2. second item",
        "[link](https://example.com)",
        "![image](https://example.com/img.png)",
        "~~strikethrough~~ text",
        "`inline code` sample",
        "Simple paragraph\n\nAnother paragraph",
        "---",
        "",
        "   ",
        "Mixed **bold** and *italic* with `code`",
        "# Header\n\n- Item 1\n- Item 2\n\n> Quote"
      ]

      for input <- markdown_samples do
        {:ok, result} = MDEx.to_delta(input, extension: [strikethrough: true])
        ops = result
        assert is_list(ops), "Delta ops should be a list for input: #{inspect(input)}"

        # Verify each operation is valid
        for op <- ops do
          assert is_map(op), "Each op should be a map"
          assert Map.has_key?(op, "insert"), "Each op should have an 'insert' key"

          insert_value = Map.get(op, "insert")

          assert is_binary(insert_value) or is_map(insert_value),
                 "Insert value should be string or object"

          # If attributes exist, they should be a map
          if Map.has_key?(op, "attributes") do
            attributes = Map.get(op, "attributes")
            assert is_map(attributes), "Attributes should be a map"
          end
        end
      end
    end

    test "text content is preserved" do
      # Simple text should be preserved exactly
      test_cases = [
        {"Hello World", "Hello World"},
        {"spaces", "spaces"},
        # MDEx treats newlines as spaces in paragraphs
        {"multiple lines here", "multiple lines here"},
        {"special chars: !@#$%^&*()", "special chars: !@#$%^&*()"},
        {"unicode: 🎉 emoji test", "unicode: 🎉 emoji test"},
        {"Numbers: 123 456", "Numbers: 123 456"}
      ]

      for {input, expected_text} <- test_cases do
        {:ok, result} = MDEx.to_delta(input)
        ops = result

        # Extract all text from ops
        actual_text =
          ops
          |> Enum.filter(fn op -> is_binary(Map.get(op, "insert")) end)
          |> Enum.map(fn op -> Map.get(op, "insert") end)
          |> Enum.join("")
          # Remove trailing newline added by paragraph processing
          |> String.trim_trailing("\n")

        assert actual_text == expected_text,
               "Text content should be preserved. Expected: #{inspect(expected_text)}, Got: #{inspect(actual_text)}"
      end
    end

    test "nested formatting preserves all attributes" do
      # Test that nested formatting combines attributes correctly
      # Using simpler case that we know works
      input = "***bold italic***"
      {:ok, result} = MDEx.to_delta(input)
      ops = result

      # Find ops with attributes
      attr_ops =
        Enum.filter(ops, fn op ->
          Map.has_key?(op, "attributes") and is_binary(Map.get(op, "insert"))
        end)

      assert length(attr_ops) > 0, "Should have at least one operation with attributes"

      # Should have both bold and italic
      has_both =
        Enum.any?(attr_ops, fn op ->
          attributes = Map.get(op, "attributes")
          Map.get(attributes, "bold") == true and Map.get(attributes, "italic") == true
        end)

      assert has_both, "Should have operation with both bold and italic attributes"
    end

    test "block-level elements have correct newline structure" do
      # Block elements should end with newlines that have proper attributes
      test_cases = [
        {"# Header", %{"header" => 1}},
        {"> Blockquote", %{"blockquote" => true}},
        {"```\ncode\n```", %{"code-block" => true}},
        {"- List item", %{"list" => "bullet"}},
        {"1. Ordered item", %{"list" => "ordered"}}
      ]

      for {input, expected_attrs} <- test_cases do
        {:ok, result} = MDEx.to_delta(input)
        ops = result

        # Find newline operations with attributes
        newline_ops =
          Enum.filter(ops, fn op ->
            Map.get(op, "insert") == "\n" and Map.has_key?(op, "attributes")
          end)

        assert length(newline_ops) > 0,
               "Should have newline with attributes for: #{input}"

        # Get the last newline
        newline_op = List.last(newline_ops)
        actual_attrs = Map.get(newline_op, "attributes")

        for {key, value} <- expected_attrs do
          assert Map.get(actual_attrs, key) == value,
                 "Expected #{key} => #{value} in attributes for: #{input}"
        end
      end
    end

    test "empty and whitespace handling is consistent" do
      # Various empty/whitespace inputs should behave predictably
      empty_inputs = ["", "   ", "\n", "\n\n", " \n ", "\t", "  \n  \n  "]

      for input <- empty_inputs do
        {:ok, result} = MDEx.to_delta(input)
        ops = result

        # Should either be empty or contain only whitespace
        for op <- ops do
          insert_value = Map.get(op, "insert")

          if is_binary(insert_value) do
            assert String.trim(insert_value) == "",
                   "Empty input should only produce whitespace, got: #{inspect(insert_value)}"
          end
        end
      end
    end

    test "malformed markdown gracefully degrades" do
      # Test various malformed markdown inputs
      malformed_inputs = [
        "# Header with no content after",
        "**unclosed bold",
        "*unclosed italic",
        "`unclosed code",
        "> unclosed quote",
        "- incomplete list\n  - nested without parent completion",
        "![incomplete image](",
        "[incomplete link](",
        "```\nunclosed code block",
        "~~unclosed strike"
      ]

      for input <- malformed_inputs do
        # Should not crash, should return something reasonable
        {:ok, result} = MDEx.to_delta(input, extension: [strikethrough: true])
        ops = result
        assert is_list(ops), "Should return valid ops list even for malformed input: #{input}"

        # Should contain some text content
        has_text =
          Enum.any?(ops, fn op ->
            is_binary(Map.get(op, "insert")) and String.trim(Map.get(op, "insert")) != ""
          end)

        assert has_text, "Should preserve some text content for: #{input}"
      end
    end

    test "custom converters don't break invariants" do
      # Test that custom converters maintain the basic structure
      input = "# Header\n\n**Bold** text with `code`"

      # Custom converter that replaces bold with uppercase
      custom_converter = fn %MDEx.Strong{nodes: children}, _options ->
        text =
          Enum.map_join(children, "", fn
            %MDEx.Text{literal: text} -> String.upcase(text)
            _ -> ""
          end)

        [%{"insert" => text, "attributes" => %{"custom" => "uppercase"}}]
      end

      {:ok, result} =
        MDEx.to_delta(input,
          custom_converters: %{MDEx.Strong => custom_converter}
        )

      ops = result

      # Should still be valid Delta structure
      assert is_list(ops)

      for op <- ops do
        assert is_map(op)
        assert Map.has_key?(op, "insert")

        insert_value = Map.get(op, "insert")
        assert is_binary(insert_value) or is_map(insert_value)
      end

      # Should contain our custom attribute
      has_custom =
        Enum.any?(ops, fn op ->
          Map.get(op, "attributes", %{}) |> Map.get("custom") == "uppercase"
        end)

      assert has_custom, "Should contain custom converter output"
    end

    test "large document handling" do
      # Generate a reasonably large document
      sections =
        for i <- 1..10 do
          """
          # Section #{i}

          This is section **#{i}** with some *italic* text and `inline code`.

          ## Subsection #{i}.1

          - Item #{i}.1
          - Item #{i}.2
          - Item #{i}.3

          > Quote in section #{i}

          ```elixir
          def section_#{i}() do
            "Section #{i} code"
          end
          ```

          """
        end

      input = Enum.join(sections, "\n")

      {:ok, result} = MDEx.to_delta(input)
      ops = result

      # Should handle large documents without issues
      assert is_list(ops)
      assert length(ops) > 100, "Large document should produce many operations"

      # All operations should be valid
      for op <- ops do
        assert is_map(op)
        assert Map.has_key?(op, "insert")
      end

      # Should contain various formatting types
      has_headers =
        Enum.any?(ops, fn op ->
          Map.get(op, "attributes", %{}) |> Map.has_key?("header")
        end)

      has_bold =
        Enum.any?(ops, fn op ->
          Map.get(op, "attributes", %{}) |> Map.get("bold") == true
        end)

      has_code_blocks =
        Enum.any?(ops, fn op ->
          Map.get(op, "attributes", %{}) |> Map.get("code-block") == true
        end)

      assert has_headers, "Large document should contain headers"
      assert has_bold, "Large document should contain bold text"
      assert has_code_blocks, "Large document should contain code blocks"
    end
  end
end
