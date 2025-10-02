defmodule MDEx.DocumentTest do
  use ExUnit.Case, async: true
  import MDEx.Sigil
  alias MDEx.Document

  doctest MDEx.Document, import: true, except: [:moduledoc]

  @document ~MD"""
  # Languages

    ## Elixir
    `elixir`

    ## Rust
    `rust`

  more
  """

  describe "Access behaviour" do
    test "fetch with empty document" do
      empty_doc = %MDEx.Document{nodes: []}

      assert empty_doc[MDEx.Code] == nil
      assert empty_doc[:code] == nil
      assert empty_doc[%MDEx.Text{literal: "test"}] == nil

      assert empty_doc[
               fn
                 %MDEx.Document{} -> true
                 _ -> false
               end
             ] == [empty_doc]

      assert empty_doc[fn _node -> false end] == nil
    end

    test "fetch with non-existent selector" do
      assert @document[MDEx.Table] == nil
      assert @document[:table] == nil
      assert @document[%MDEx.Text{literal: "nonexistent"}] == nil
      assert @document[fn _node -> false end] == nil
    end

    test "fetch with invalid atom selector" do
      assert_raise MDEx.InvalidSelector, fn ->
        @document[nil]
      end

      assert_raise FunctionClauseError, fn ->
        @document["string"]
      end
    end

    test "get_in" do
      assert get_in(@document, [:document, Access.all(), :code]) == [
               [%MDEx.Code{literal: "elixir", num_backticks: 1}, %MDEx.Code{literal: "rust", num_backticks: 1}]
             ]

      assert get_in(@document, [:document, Access.all(), %MDEx.Text{literal: "more"}]) == [[%MDEx.Text{literal: "more"}]]
    end

    test "update_in" do
      assert %MDEx.Document{
               nodes: [
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "Languages"}], level: 1, setext: false},
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "Elixir"}], level: 2, setext: false},
                 %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "ELIXIR", num_backticks: 1}]},
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "Rust"}], level: 2, setext: false},
                 %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "rust", num_backticks: 1}]},
                 %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
               ]
             } =
               update_in(@document, [:code, Access.key!(:literal)], fn literal ->
                 String.upcase(literal)
               end)
    end

    test "update_in all nested" do
      assert %MDEx.Document{
               nodes: [
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "Languages"}], level: 1, setext: false},
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "Elixir"}], level: 2, setext: false},
                 %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "ELIXIR"}]},
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "Rust"}], level: 2, setext: false},
                 %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "RUST"}]},
                 %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
               ]
             } =
               update_in(@document, [:document, Access.key!(:nodes), Access.all(), :code, Access.key!(:literal)], fn literal ->
                 String.upcase(literal)
               end)
    end

    test "fetch by struct" do
      assert @document[%MDEx.Text{literal: "more"}] == [%MDEx.Text{literal: "more"}]
    end

    test "fetch by module" do
      assert @document[MDEx.Code] == [%MDEx.Code{num_backticks: 1, literal: "elixir"}, %MDEx.Code{num_backticks: 1, literal: "rust"}]
    end

    test "fetch by atom shortcut" do
      assert @document[:code] == [%MDEx.Code{num_backticks: 1, literal: "elixir"}, %MDEx.Code{num_backticks: 1, literal: "rust"}]
    end

    test "fetch by function" do
      assert @document[&Map.has_key?(&1, :literal)] == [
               %MDEx.Text{literal: "Languages"},
               %MDEx.Text{literal: "Elixir"},
               %MDEx.Code{literal: "elixir", num_backticks: 1},
               %MDEx.Text{literal: "Rust"},
               %MDEx.Code{literal: "rust", num_backticks: 1},
               %MDEx.Text{literal: "more"}
             ]
    end

    test "get and update by struct key" do
      assert {
               %MDEx.Text{literal: "more"},
               %MDEx.Document{
                 nodes: [
                   %MDEx.Heading{nodes: [%MDEx.Text{literal: "Languages"}], level: 1, setext: false},
                   %MDEx.Heading{nodes: [%MDEx.Text{literal: "Elixir"}], level: 2, setext: false},
                   %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "elixir", num_backticks: 1}]},
                   %MDEx.Heading{nodes: [%MDEx.Text{literal: "Rust"}], level: 2, setext: false},
                   %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "rust", num_backticks: 1}]},
                   %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "MORE"}]}
                 ]
               }
             } =
               MDEx.Document.get_and_update(@document, %MDEx.Text{literal: "more"}, fn node ->
                 {node, %{node | literal: String.upcase(node.literal)}}
               end)

      assert {
               %MDEx.Code{literal: "rust", num_backticks: 1},
               %MDEx.Document{
                 nodes: [
                   %MDEx.Heading{nodes: [%MDEx.Text{literal: "Languages"}], level: 1, setext: false},
                   %MDEx.Heading{nodes: [%MDEx.Text{literal: "Elixir"}], level: 2, setext: false},
                   %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "elixir", num_backticks: 1}]},
                   %MDEx.Heading{nodes: [%MDEx.Text{literal: "Rust"}], level: 2, setext: false},
                   %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "RUST", num_backticks: 1}]},
                   %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
                 ]
               }
             } =
               MDEx.Document.get_and_update(@document, %MDEx.Code{num_backticks: 1, literal: "rust"}, fn node ->
                 {node, %{node | literal: String.upcase(node.literal)}}
               end)
    end

    test "get and update by module key" do
      assert {%MDEx.Text{literal: "Languages"},
              %MDEx.Document{
                nodes: [
                  %MDEx.Heading{nodes: [%MDEx.Text{literal: "LANGUAGES"}], level: 1, setext: false},
                  %MDEx.Heading{nodes: [%MDEx.Text{literal: "Elixir"}], level: 2, setext: false},
                  %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "elixir"}]},
                  %MDEx.Heading{nodes: [%MDEx.Text{literal: "Rust"}], level: 2, setext: false},
                  %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "rust"}]},
                  %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
                ]
              }} =
               MDEx.Document.get_and_update(@document, MDEx.Text, fn node ->
                 {node, %{node | literal: String.upcase(node.literal)}}
               end)

      assert {%MDEx.Code{num_backticks: 1, literal: "elixir"},
              %MDEx.Document{
                nodes: [
                  %MDEx.Heading{nodes: [%MDEx.Text{literal: "Languages"}], level: 1, setext: false},
                  %MDEx.Heading{nodes: [%MDEx.Text{literal: "Elixir"}], level: 2, setext: false},
                  %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "ELIXIR"}]},
                  %MDEx.Heading{nodes: [%MDEx.Text{literal: "Rust"}], level: 2, setext: false},
                  %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "rust"}]},
                  %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
                ]
              }} =
               MDEx.Document.get_and_update(@document, MDEx.Code, fn node ->
                 {node, %{node | literal: String.upcase(node.literal)}}
               end)
    end

    test "get and update by atom key" do
      assert {
               %MDEx.Code{literal: "elixir", num_backticks: 1},
               %MDEx.Document{
                 nodes: [
                   %MDEx.Heading{nodes: [%MDEx.Text{literal: "Languages"}], level: 1, setext: false},
                   %MDEx.Heading{nodes: [%MDEx.Text{literal: "Elixir"}], level: 2, setext: false},
                   %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "ELIXIR", num_backticks: 1}]},
                   %MDEx.Heading{nodes: [%MDEx.Text{literal: "Rust"}], level: 2, setext: false},
                   %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "rust", num_backticks: 1}]},
                   %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
                 ]
               }
             } =
               MDEx.Document.get_and_update(@document, :code, fn node ->
                 {node, %{node | literal: String.upcase(node.literal)}}
               end)
    end

    test "get and update by function key" do
      assert {%MDEx.Text{literal: "more"},
              %MDEx.Document{
                nodes: [
                  %MDEx.Heading{nodes: [%MDEx.Text{literal: "Languages"}], level: 1, setext: false},
                  %MDEx.Heading{nodes: [%MDEx.Text{literal: "Elixir"}], level: 2, setext: false},
                  %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "elixir", num_backticks: 1}]},
                  %MDEx.Heading{nodes: [%MDEx.Text{literal: "Rust"}], level: 2, setext: false},
                  %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "rust", num_backticks: 1}]},
                  %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "MORE"}]}
                ]
              }} =
               MDEx.Document.get_and_update(@document, &(Map.get(&1, :literal) == "more"), fn node ->
                 {node, %{node | literal: String.upcase(node.literal)}}
               end)
    end

    test "pop by struct key" do
      assert {
               :default,
               %MDEx.Document{
                 nodes: [
                   %MDEx.Heading{nodes: [%MDEx.Text{literal: "Languages"}], level: 1, setext: false},
                   %MDEx.Heading{nodes: [%MDEx.Text{literal: "Elixir"}], level: 2, setext: false},
                   %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "elixir", num_backticks: 1}]},
                   %MDEx.Heading{nodes: [%MDEx.Text{literal: "Rust"}], level: 2, setext: false},
                   %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "rust", num_backticks: 1}]},
                   %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
                 ]
               }
             } = MDEx.Document.pop(@document, %MDEx.List{}, :default)

      assert {
               %MDEx.Text{literal: "more"},
               %MDEx.Document{
                 nodes: [
                   %MDEx.Heading{nodes: [%MDEx.Text{literal: "Languages"}], level: 1, setext: false},
                   %MDEx.Heading{nodes: [%MDEx.Text{literal: "Elixir"}], level: 2, setext: false},
                   %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "elixir", num_backticks: 1}]},
                   %MDEx.Heading{nodes: [%MDEx.Text{literal: "Rust"}], level: 2, setext: false},
                   %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "rust", num_backticks: 1}]},
                   %MDEx.Paragraph{nodes: []}
                 ]
               }
             } = MDEx.Document.pop(@document, %MDEx.Text{literal: "more"})
    end

    test "pop by module key" do
      assert {
               %MDEx.Code{literal: "elixir", num_backticks: 1},
               %MDEx.Document{
                 nodes: [
                   %MDEx.Heading{nodes: [%MDEx.Text{literal: "Languages"}], level: 1, setext: false},
                   %MDEx.Heading{nodes: [%MDEx.Text{literal: "Elixir"}], level: 2, setext: false},
                   %MDEx.Paragraph{nodes: []},
                   %MDEx.Heading{nodes: [%MDEx.Text{literal: "Rust"}], level: 2, setext: false},
                   %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "rust", num_backticks: 1}]},
                   %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
                 ]
               }
             } = MDEx.Document.pop(@document, MDEx.Code)
    end

    test "pop by atom key" do
      assert {
               %MDEx.Code{literal: "elixir", num_backticks: 1},
               %MDEx.Document{
                 nodes: [
                   %MDEx.Heading{nodes: [%MDEx.Text{literal: "Languages"}], level: 1, setext: false},
                   %MDEx.Heading{nodes: [%MDEx.Text{literal: "Elixir"}], level: 2, setext: false},
                   %MDEx.Paragraph{nodes: []},
                   %MDEx.Heading{nodes: [%MDEx.Text{literal: "Rust"}], level: 2, setext: false},
                   %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "rust", num_backticks: 1}]},
                   %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
                 ]
               }
             } = MDEx.Document.pop(@document, :code)
    end

    test "pop with empty document" do
      empty_doc = %MDEx.Document{nodes: []}
      assert MDEx.Document.pop(empty_doc, MDEx.Code, :default) == {:default, empty_doc}
      assert MDEx.Document.pop(empty_doc, :code) == {nil, empty_doc}
    end

    test "pop with non-existent key" do
      assert MDEx.Document.pop(@document, MDEx.Table, :default) == {:default, @document}
      assert MDEx.Document.pop(@document, :table) == {nil, @document}
    end

    test "pop by integer index" do
      assert MDEx.Document.pop(@document, 2) == {%MDEx.Text{literal: "Languages"}, @document}
      assert MDEx.Document.pop(@document, 100) == {nil, @document}
      assert MDEx.Document.pop(@document, 100, :default) == {:default, @document}
    end

    test "get_and_update with empty document" do
      empty_doc = %MDEx.Document{nodes: []}

      assert MDEx.Document.get_and_update(empty_doc, MDEx.Code, fn node ->
               {node, %{node | literal: "updated"}}
             end) == {nil, empty_doc}

      assert MDEx.Document.get_and_update(empty_doc, :code, fn node ->
               {node, %{node | literal: "updated"}}
             end) == {nil, empty_doc}
    end

    test "get_and_update with non-existent key" do
      assert MDEx.Document.get_and_update(@document, MDEx.Table, fn node ->
               {node, node}
             end) == {nil, @document}

      assert MDEx.Document.get_and_update(@document, :table, fn node ->
               {node, node}
             end) == {nil, @document}
    end

    test "get_and_update by integer index" do
      assert MDEx.Document.get_and_update(@document, 2, fn node ->
               {node, %{node | literal: String.upcase(node.literal)}}
             end) == {%MDEx.Text{literal: "Languages"}, @document}

      assert MDEx.Document.get_and_update(@document, 100, fn node ->
               {node, node}
             end) == {nil, @document}
    end

    test "fetch by integer index" do
      assert %MDEx.Document{
               nodes: [
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "Languages"}], level: 1, setext: false},
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "Elixir"}], level: 2, setext: false},
                 %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "elixir", num_backticks: 1}]},
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "Rust"}], level: 2, setext: false},
                 %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "rust", num_backticks: 1}]},
                 %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
               ]
             } = @document[0]

      assert %MDEx.Heading{nodes: [%MDEx.Text{literal: "Languages"}], level: 1, setext: false} = @document[1]
      assert %MDEx.Text{literal: "Languages"} = @document[2]
      assert %MDEx.Text{literal: "more"} = @document[12]
    end

    test "fetch by integer index out of bounds" do
      assert @document[100] == nil
      assert @document[-1] == %MDEx.Text{literal: "more"}
      assert @document[-100] == nil
    end

    test "access with complex function selectors" do
      complex_selector = fn
        %MDEx.Code{literal: literal} when byte_size(literal) > 4 -> true
        _ -> false
      end

      assert @document[complex_selector] == [%MDEx.Code{num_backticks: 1, literal: "elixir"}]

      never_match = fn _ -> false end
      assert @document[never_match] == nil

      guarded_selector = fn
        %struct{literal: "rust"} when struct == MDEx.Code -> true
        _ -> false
      end

      assert @document[guarded_selector] == [%MDEx.Code{num_backticks: 1, literal: "rust"}]
    end

    test "access nested document operations" do
      nested_doc = ~MD"""
      # Main
      > Quote level 1
      >> Quote level 2
      >>> Quote level 3
      """

      quotes = nested_doc[MDEx.BlockQuote]
      assert length(quotes) == 3

      texts = nested_doc[MDEx.Text]
      assert length(texts) == 4
    end

    test "get_and_update function edge cases" do
      assert_raise MatchError, fn ->
        MDEx.Document.get_and_update(@document, MDEx.Code, fn _node ->
          :invalid_return
        end)
      end
    end
  end

  describe "traverse and update" do
    test "modify existing nodes" do
      assert %MDEx.Document{
               nodes: [
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "Languages"}], level: 1, setext: false},
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "Elixir"}], level: 2, setext: false},
                 %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "ex", num_backticks: 1}]},
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "Rust"}], level: 2, setext: false},
                 %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "rs", num_backticks: 1}]},
                 %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
               ]
             } =
               MDEx.traverse_and_update(@document, fn
                 %MDEx.Code{literal: "elixir"} = node ->
                   %{node | literal: "ex"}

                 %MDEx.Code{literal: "rust"} = node ->
                   %{node | literal: "rs"}

                 node ->
                   node
               end)
    end

    test "append child" do
      assert %MDEx.Document{
               nodes: [
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "Test"}], level: 1, setext: false},
                 %MDEx.Code{num_backticks: 1, literal: "foo = 1"}
               ]
             } =
               MDEx.traverse_and_update(~MD[# Test], fn
                 %MDEx.Document{nodes: nodes} = node ->
                   new = MDEx.parse_fragment!("`foo = 1`")
                   %{node | nodes: nodes ++ [new]}

                 node ->
                   node
               end)
    end

    test "pop existing node" do
      assert %MDEx.Document{
               nodes: [
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "Languages"}], level: 1, setext: false},
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "Elixir"}], level: 2, setext: false},
                 %MDEx.Paragraph{nodes: []},
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "Rust"}], level: 2, setext: false},
                 %MDEx.Paragraph{nodes: []},
                 %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
               ]
             } =
               MDEx.traverse_and_update(@document, fn
                 %MDEx.Code{} -> :pop
                 node -> node
               end)
    end
  end

  describe "traverse and update with accumulator" do
    test "modify existing nodes" do
      document = ~MD"""
      # Lang: `elixir`

      # Lang: `rust`

      more
      """

      assert {%MDEx.Document{
                nodes: [
                  %MDEx.Heading{nodes: [%MDEx.Text{literal: "Lang: "}, %MDEx.Code{num_backticks: 1, literal: "ex"}], level: 1, setext: false},
                  %MDEx.Heading{nodes: [%MDEx.Text{literal: "Lang: "}, %MDEx.Code{num_backticks: 1, literal: "rs"}], level: 1, setext: false},
                  %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
                ]
              },
              2} =
               MDEx.traverse_and_update(document, 0, fn
                 %MDEx.Code{literal: "elixir"} = node, acc ->
                   node = %{node | literal: "ex"}
                   {node, acc + 1}

                 %MDEx.Code{literal: "rust"} = node, acc ->
                   node = %{node | literal: "rs"}
                   {node, acc + 1}

                 node, acc ->
                   {node, acc}
               end)
    end

    test "control processing continuation" do
      document = ~MD"""
      # Lang: `elixir`

      # Lang: `rust`

      more
      """

      assert {%MDEx.Document{
                nodes: [
                  %MDEx.Heading{nodes: [%MDEx.Text{literal: "Lang: "}, %MDEx.Code{num_backticks: 1, literal: "ex"}], level: 1, setext: false},
                  %MDEx.Heading{nodes: [%MDEx.Text{literal: "Lang: "}, %MDEx.Code{num_backticks: 1, literal: "rust"}], level: 1, setext: false},
                  %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
                ]
              },
              :halted} =
               MDEx.traverse_and_update(document, :cont, fn
                 node, :halted ->
                   {node, :halted}

                 %MDEx.Code{literal: "elixir"} = node, :cont ->
                   node = %{node | literal: "ex"}
                   {node, :halted}

                 %MDEx.Code{literal: "rust"} = node, acc ->
                   node = %{node | literal: "rs"}
                   {node, acc}

                 node, acc ->
                   {node, acc}
               end)
    end
  end

  describe "String.Chars protocol" do
    test "to_string formats sigil to commonmark" do
      assert to_string(~MD[# Hello]) == "# Hello"
    end

    test "to_string resolves interpolation" do
      title = "Hello"
      assert to_string(~m[# #{title}]) == "# Hello"
    end

    test "to_string formats document to commonmark" do
      assert to_string(%MDEx.Document{}) == ""

      doc = %MDEx.Document{nodes: [%MDEx.BlockQuote{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "MDEx"}]}]}]}
      assert to_string(doc) == "> MDEx"
    end

    test "to_string formats fragment to commonmark" do
      assert to_string(%MDEx.Text{literal: "Hello"}) == "Hello"
    end
  end

  describe "Enumerable protocol" do
    test "empty document enumeration" do
      empty_doc = %MDEx.Document{nodes: []}

      assert Enum.count(empty_doc) == 1
      assert Enum.to_list(empty_doc) == [empty_doc]
      assert Enum.find(empty_doc, fn _node -> true end) == empty_doc
      assert Enum.member?(empty_doc, %MDEx.Text{literal: "test"}) == false
      assert Enum.member?(empty_doc, empty_doc) == true

      assert Enum.reduce(empty_doc, 0, fn _node, acc -> acc + 1 end) == 1
    end

    test "single node document enumeration" do
      doc = %MDEx.Document{nodes: [%MDEx.Text{literal: "single"}]}

      assert Enum.count(doc) == 2
      assert Enum.to_list(doc) == [doc, %MDEx.Text{literal: "single"}]
      assert Enum.at(doc, 0) == doc
      assert Enum.at(doc, 1) == %MDEx.Text{literal: "single"}
      assert Enum.at(doc, 2) == nil
    end

    test "deeply nested structure enumeration" do
      nested_doc = ~MD"""
      # Top
      > Quote
      >> Nested Quote
      """

      count = Enum.count(nested_doc)
      list = Enum.to_list(nested_doc)

      assert length(list) == count
      assert Enum.at(nested_doc, 0) == nested_doc
      assert Enum.at(nested_doc, count - 1) != nil
      assert Enum.at(nested_doc, count) == nil
    end

    test "enumeration with large document" do
      large_content = Enum.map(1..10, fn i -> "# Heading #{i}\nContent #{i}\n" end) |> Enum.join("\n")
      large_doc = MDEx.parse_document!(large_content)

      count = Enum.count(large_doc)
      assert count > 20

      first_items = Enum.take(large_doc, 5)
      assert length(first_items) == 5
      assert hd(first_items) == large_doc

      last_item = Enum.at(large_doc, count - 1)
      assert last_item != nil
    end

    test "enumeration halting behavior" do
      result =
        Enum.reduce_while(@document, [], fn
          %MDEx.Code{}, acc -> {:halt, [:found_code | acc]}
          node, acc -> {:cont, [node | acc]}
        end)

      assert [:found_code | _] = result
    end

    test "enumeration with early termination" do
      first_text =
        Enum.find(@document, fn
          %MDEx.Text{} -> true
          _ -> false
        end)

      assert %MDEx.Text{literal: "Languages"} = first_text
    end

    test "slice behavior for enumeration" do
      slice = Enum.slice(@document, 2..4)
      assert length(slice) == 3
      assert Enum.at(@document, 2) == hd(slice)
      assert Enum.at(@document, 4) == List.last(slice)
    end

    test "reduce" do
      assert Enum.reduce(@document, 0, fn
               %{literal: _literal}, acc ->
                 acc + 1

               _node, acc ->
                 acc
             end) == 6
    end

    test "map" do
      assert Enum.map(@document, fn %node{} ->
               inspect(node)
             end) == [
               "MDEx.Document",
               "MDEx.Heading",
               "MDEx.Text",
               "MDEx.Heading",
               "MDEx.Text",
               "MDEx.Paragraph",
               "MDEx.Code",
               "MDEx.Heading",
               "MDEx.Text",
               "MDEx.Paragraph",
               "MDEx.Code",
               "MDEx.Paragraph",
               "MDEx.Text"
             ]
    end

    test "count" do
      assert Enum.count(@document) == 13
    end

    test "find" do
      assert Enum.find(@document, nil, fn node -> node == %MDEx.Text{literal: "more"} end) == %MDEx.Text{literal: "more"}
    end

    test "member?" do
      assert Enum.member?(@document, %MDEx.Code{literal: "elixir", num_backticks: 1}) == true
      assert Enum.member?(@document, %MDEx.Text{literal: "more"}) == true
    end

    test "suspended" do
      assert [
               {%MDEx.Document{
                  nodes: [
                    %MDEx.Heading{nodes: [%MDEx.Text{literal: "Languages"}], level: 1, setext: false},
                    %MDEx.Heading{nodes: [%MDEx.Text{literal: "Elixir"}], level: 2, setext: false},
                    %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "elixir"}]},
                    %MDEx.Heading{nodes: [%MDEx.Text{literal: "Rust"}], level: 2, setext: false},
                    %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "rust"}]},
                    %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
                  ]
                }, 1}
             ] = Enum.zip(@document, [1])
    end
  end

  describe "Enum.at/3" do
    test "traversal order with Enum.at/2" do
      assert %MDEx.Document{
               nodes: [
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "Languages"}], level: 1, setext: false},
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "Elixir"}], level: 2, setext: false},
                 %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "elixir"}]},
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "Rust"}], level: 2, setext: false},
                 %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "rust"}]},
                 %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
               ]
             } = Enum.at(@document, 0)

      assert %MDEx.Heading{nodes: [%MDEx.Text{literal: "Languages"}], level: 1, setext: false} = Enum.at(@document, 1)
      assert %MDEx.Text{literal: "Languages"} = Enum.at(@document, 2)
      assert %MDEx.Code{num_backticks: 1, literal: "elixir"} = Enum.at(@document, 6)
      assert %MDEx.Text{literal: "more"} = Enum.at(@document, 12)
    end

    test "simple nested structure traversal" do
      doc = ~MD"""
      # Main
      Para
      """

      assert Enum.at(doc, 0) == doc
      assert Enum.at(doc, 1) == %MDEx.Heading{nodes: [%MDEx.Text{literal: "Main"}], level: 1, setext: false}
      assert Enum.at(doc, 2) == %MDEx.Text{literal: "Main"}
      assert Enum.at(doc, 3) == %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Para"}]}
      assert Enum.at(doc, 4) == %MDEx.Text{literal: "Para"}
    end

    test "complex nested structure traversal" do
      doc = ~MD"""
      # Title
      - Item 1
      - Item 2
      """

      assert Enum.at(doc, 0) == doc
      assert Enum.at(doc, 1) == %MDEx.Heading{nodes: [%MDEx.Text{literal: "Title"}], level: 1, setext: false}
      assert Enum.at(doc, 2) == %MDEx.Text{literal: "Title"}

      list_node = Enum.at(doc, 3)
      assert %MDEx.List{} = list_node
      assert list_node.list_type == :bullet

      first_item = Enum.at(doc, 4)
      assert %MDEx.ListItem{} = first_item

      first_paragraph = Enum.at(doc, 5)
      assert first_paragraph == %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Item 1"}]}

      assert Enum.at(doc, 6) == %MDEx.Text{literal: "Item 1"}

      second_item = Enum.at(doc, 7)
      assert %MDEx.ListItem{} = second_item

      second_paragraph = Enum.at(doc, 8)
      assert second_paragraph == %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Item 2"}]}

      assert Enum.at(doc, 9) == %MDEx.Text{literal: "Item 2"}
    end

    test "mixed content structure traversal" do
      doc = ~MD"""
      # Code Examples

      `inline`

      ```elixir
      def hello, do: :world
      ```
      """

      assert Enum.at(doc, 0) == doc
      assert Enum.at(doc, 1) == %MDEx.Heading{nodes: [%MDEx.Text{literal: "Code Examples"}], level: 1, setext: false}
      assert Enum.at(doc, 2) == %MDEx.Text{literal: "Code Examples"}
      assert Enum.at(doc, 3) == %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "inline"}]}
      assert Enum.at(doc, 4) == %MDEx.Code{num_backticks: 1, literal: "inline"}

      code_block = Enum.at(doc, 5)
      assert %MDEx.CodeBlock{info: "elixir", literal: "def hello, do: :world\n"} = code_block
    end

    test "out of bounds returns nil" do
      assert Enum.at(@document, 100) == nil
    end

    test "traversal consistency with other Enum functions" do
      nodes = Enum.to_list(@document)

      assert Enum.at(@document, 0) == Enum.at(nodes, 0)
      assert Enum.at(@document, 5) == Enum.at(nodes, 5)
      assert Enum.at(@document, 12) == Enum.at(nodes, 12)

      assert length(nodes) == Enum.count(@document)
    end

    test "negative index behavior" do
      total_count = Enum.count(@document)
      assert Enum.at(@document, -1) == Enum.at(@document, total_count - 1)
      assert Enum.at(@document, -2) == Enum.at(@document, total_count - 2)

      assert Enum.at(@document, -100) == nil
    end

    test "boundary index behavior" do
      total_count = Enum.count(@document)

      assert Enum.at(@document, total_count - 1) != nil
      assert Enum.at(@document, total_count) == nil

      assert Enum.at(@document, 0) == @document

      assert Enum.at(@document, 1000) == nil
    end
  end

  describe "Collectable protocol" do
    test "merge documents" do
      second = %MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "second"}]}]}

      assert Enum.into(
               second,
               %MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "first"}]}]}
             ) ==
               %MDEx.Document{
                 nodes: [
                   %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "first"}]},
                   %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "second"}]}
                 ]
               }
    end

    test "collect top-level nodes" do
      nodes = [
        %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "elixir", num_backticks: 1}]},
        %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "rust"}]},
        %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
      ]

      assert Enum.into(
               nodes,
               %MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "first"}]}]}
             ) ==
               %MDEx.Document{
                 nodes: [
                   %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "first"}]},
                   %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "elixir", num_backticks: 1}]},
                   %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "rust", num_backticks: 1}]},
                   %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
                 ]
               }
    end

    test "into empty document" do
      nodes = [%MDEx.Text{literal: "test"}, %MDEx.Code{literal: "code", num_backticks: 1}]
      empty_doc = %MDEx.Document{nodes: []}

      result = Enum.into(nodes, empty_doc)
      assert result.nodes == nodes
    end

    test "into document with empty collection" do
      initial_doc = %MDEx.Document{nodes: [%MDEx.Text{literal: "existing"}]}
      result = Enum.into([], initial_doc)
      assert result == initial_doc
    end

    test "into document with mixed node types" do
      mixed_nodes = [
        %MDEx.Text{literal: "text"},
        %MDEx.Code{literal: "code", num_backticks: 1},
        %MDEx.Heading{nodes: [%MDEx.Text{literal: "heading"}], level: 2, setext: false}
      ]

      assert %MDEx.Document{
               nodes: [
                 %MDEx.Text{literal: "existing"},
                 %MDEx.Text{literal: "text"},
                 %MDEx.Code{num_backticks: 1, literal: "code"},
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "heading"}], level: 2, setext: false}
               ]
             } = Enum.into(mixed_nodes, %MDEx.Document{nodes: [%MDEx.Text{literal: "existing"}]})
    end

    test "collectable protocol error handling" do
      assert_raise ArgumentError, fn ->
        Enum.into(["not a node"], %MDEx.Document{nodes: []})
      end

      assert_raise ArgumentError, fn ->
        Enum.into([%{invalid: "struct"}], %MDEx.Document{nodes: []})
      end
    end
  end

  test "modulefy!" do
    assert_raise MDEx.InvalidSelector, fn ->
      MDEx.Document.Access.modulefy!(nil)
    end

    assert MDEx.Document.Access.modulefy!(:code) == MDEx.Code
    assert MDEx.Document.Access.modulefy!(:code_block) == MDEx.CodeBlock
  end

  describe "wrap" do
    test "document" do
      document = MDEx.new(markdown: "# Heading")
      assert MDEx.Document.wrap(document) == document
    end

    test "nodes" do
      node = %MDEx.Heading{nodes: [%MDEx.Text{literal: "Wrapped"}], level: 2, setext: false}
      assert %{nodes: [^node]} = MDEx.Document.wrap(node)
    end
  end

  describe "put_options" do
    setup do
      [document: MDEx.new()]
    end

    test "update existing nested values", %{document: document} do
      document = Document.register_options(document, [:test])
      document = Document.put_options(document, test: 1, render: [escape: false, unsafe: true], extension: [table: true])

      assert get_in(document.options, [:test]) == 1
      refute get_in(document.options, [:render, :escape])
      assert get_in(document.options, [:render, :unsafe])
      assert get_in(document.options, [:extension, :table])
    end

    test "validate registered options", %{document: document} do
      document = Document.register_options(document, [:test])

      assert_raise ArgumentError, "unknown option :testt. Did you mean :test?", fn ->
        Document.put_options(document, testt: 1)
      end
    end

    test "validate built-in options", %{document: document} do
      assert_raise ArgumentError, fn ->
        Document.put_options(document, invalid: 1)
      end

      assert_raise NimbleOptions.ValidationError, fn ->
        Document.put_options(document, render: [foo: 1])
      end
    end

    test "put_built_in_options" do
      document = %Document{options: [render: [escape: true]]}
      document = Document.register_options(document, [:test])

      refute Document.put_built_in_options(document, render: [escape: false]).options[:render][:escape]
      refute Document.put_built_in_options(document, test: 1).options[:test]
    end

    test "put_user_options" do
      document = %Document{options: [render: [escape: true]]}
      document = Document.register_options(document, [:test])

      assert Document.put_user_options(document, render: [escape: false]).options[:render][:escape]
      assert Document.put_user_options(document, test: 1).options[:test] == 1
    end
  end

  describe "put_extension_options" do
    setup do
      [document: %Document{options: [extension: [table: true]]}]
    end

    test "update existing value", %{document: document} do
      document = Document.put_extension_options(document, table: false)
      refute get_in(document.options, [:extension, :table])
    end

    test "validate schema", %{document: document} do
      assert_raise NimbleOptions.ValidationError, fn ->
        Document.put_extension_options(document, foo: 1)
      end
    end

    test "keep other options groups" do
      document = %Document{options: [extension: [table: true], render: [escape: true]]}
      document = Document.put_extension_options(document, table: false)
      refute get_in(document.options, [:extension, :table])
      assert get_in(document.options, [:render, :escape])
    end
  end

  describe "put_render_options" do
    test "multiple options" do
      document = Document.put_render_options(%Document{}, hardbreaks: true, escape: true)
      assert get_in(document.options, [:render, :hardbreaks])
      assert get_in(document.options, [:render, :escape])
    end

    test "accept soft-deprecated unsafe_" do
      document = Document.put_render_options(%Document{}, unsafe_: true)
      refute get_in(document.options, [:render, :unsafe_])
      assert get_in(document.options, [:render, :unsafe])
    end
  end

  describe "put_syntax_highlight_options" do
    test "can disable" do
      document = Document.put_syntax_highlight_options(%Document{}, nil)
      refute get_in(document.options, [:syntax_highlight])
    end

    test "accept short config" do
      document = Document.put_syntax_highlight_options(%Document{}, formatter: :html_inline)
      assert get_in(document.options, [:syntax_highlight, :formatter]) == :html_inline
    end

    test "accept formatter extended options" do
      document = Document.put_syntax_highlight_options(%Document{}, formatter: {:html_inline, theme: "github_light"})
      assert {:html_inline, formatter_opts} = get_in(document.options, [:syntax_highlight, :formatter])
      assert formatter_opts[:theme] == "github_light"
    end
  end

  describe "put_node_in_document_root" do
    setup do
      document = MDEx.new(markdown: "# Test") |> Document.run()
      [document: document]
    end

    test "top", %{document: document} do
      assert %MDEx.Document{nodes: [%MDEx.HtmlBlock{literal: "<p>top</p>"}, %MDEx.Heading{level: 1}]} =
               Document.put_node_in_document_root(document, %MDEx.HtmlBlock{literal: "<p>top</p>"}, :top)
    end

    test "bottom", %{document: document} do
      assert %Document{nodes: [%MDEx.Heading{level: 1}, %MDEx.HtmlBlock{literal: "<p>bottom</p>"}]} =
               Document.put_node_in_document_root(document, %MDEx.HtmlBlock{literal: "<p>bottom</p>"}, :bottom)
    end
  end

  describe "update_nodes" do
    test "root nodes" do
      document =
        MDEx.new(
          markdown: """
          # Test

          ```mermaid
          1
          ```

          ```elixir
          foo = :bar
          ```

          ```mermaid
          2
          ```

          ## Done
          """
        )
        |> Document.run()

      selector = fn
        %MDEx.CodeBlock{info: "mermaid"} -> true
        _ -> false
      end

      assert %MDEx.Document{
               nodes: [
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "Test"}], level: 1, setext: false},
                 %MDEx.HtmlBlock{nodes: [], literal: "<pre>1</pre>", block_type: 0},
                 %MDEx.CodeBlock{info: "elixir"},
                 %MDEx.HtmlBlock{nodes: [], literal: "<pre>2</pre>", block_type: 0},
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "Done"}], level: 2, setext: false}
               ]
             } =
               Document.update_nodes(document, selector, fn node ->
                 %MDEx.HtmlBlock{
                   literal: "<pre>#{String.trim(node.literal)}</pre>",
                   nodes: []
                 }
               end)
    end

    # issue #202
    defp upcase(document, selector) do
      Document.update_nodes(document, selector, fn node ->
        %{node | literal: String.upcase(node.literal)}
      end)
    end

    test "all nested nodes" do
      markdown = """
      # foo
      bar
      ## baz
      foo
      """

      expected = "<h1>FOO</h1>\n<p>BAR</p>\n<h2>BAZ</h2>\n<p>FOO</p>"

      document =
        MDEx.new(markdown: markdown, render: [hardbreaks: true])
        |> Document.run()

      assert document
             |> Document.append_steps(upcase: fn document -> upcase(document, :text) end)
             |> MDEx.to_html!() == expected

      assert document
             |> Document.append_steps(upcase: fn document -> upcase(document, MDEx.Text) end)
             |> MDEx.to_html!() == expected

      selector = fn
        %MDEx.Text{} -> true
        _ -> false
      end

      assert document
             |> Document.append_steps(upcase: fn document -> upcase(document, selector) end)
             |> MDEx.to_html!() == expected

      assert document
             |> Document.append_steps(upcase: fn document -> upcase(document, %MDEx.Text{literal: "foo"}) end)
             |> MDEx.to_html!() == "<h1>FOO</h1>\n<p>bar</p>\n<h2>baz</h2>\n<p>FOO</p>"
    end
  end

  test "register_options" do
    assert %{registered_options: opts} = Document.register_options(%MDEx.Document{}, [])
    assert MapSet.equal?(opts, MapSet.new([:extension, :parse, :render, :sanitize, :syntax_highlight]))

    assert %{registered_options: opts} = Document.register_options(%MDEx.Document{}, [:foo])
    assert MapSet.equal?(opts, MapSet.new([:extension, :parse, :render, :sanitize, :foo, :syntax_highlight]))

    assert %{registered_options: opts} = Document.register_options(%MDEx.Document{}, [:foo, :foo])
    assert MapSet.equal?(opts, MapSet.new([:extension, :parse, :render, :sanitize, :foo, :syntax_highlight]))
  end

  describe "get_option" do
    test "get registered option" do
      document =
        MDEx.new()
        |> Document.register_options([:foo])
        |> Document.put_options(foo: 1)

      assert Document.get_option(document, :foo) == 1
    end

    test "returns default when not registered" do
      refute Document.get_option(MDEx.new(), :foo)
    end
  end

  describe "private storage" do
    test "get_private" do
      document = Document.put_private(%Document{}, :foo, :bar)
      assert Document.get_private(document, :foo) == :bar
    end

    test "get_private with default" do
      assert Document.get_private(%Document{}, :foo, :default) == :default
    end

    test "update_private" do
      document =
        %Document{}
        |> Document.put_private(:counter, 0)
        |> Document.update_private(:counter, 0, &(&1 + 1))

      assert Document.get_private(document, :counter) == 1
    end
  end

  describe "pipeline management" do
    test "append_steps" do
      document =
        MDEx.new()
        |> Document.append_steps(step1: fn doc -> doc end)

      assert :step1 in document.current_steps
      assert Keyword.has_key?(document.steps, :step1)
    end

    test "halt" do
      document = Document.halt(MDEx.new())

      assert document.halted
    end

    test "halt with exception" do
      {document, exception} = Document.halt(MDEx.new(), %RuntimeError{message: "test"})

      assert document.halted
      assert exception.message == "test"
    end
  end

  describe "run" do
    test "with no steps" do
      assert %MDEx.Document{halted: false} = Document.run(MDEx.new())
    end

    test "with single function step" do
      assert %MDEx.Document{private: %{title: "Test"}} =
               MDEx.new()
               |> Document.append_steps(add_title: fn doc -> Document.put_private(doc, :title, "Test") end)
               |> Document.run()
    end

    test "with multiple function steps" do
      assert %MDEx.Document{private: %{counter: 4}} =
               MDEx.new()
               |> Document.append_steps(
                 step1: fn doc -> Document.put_private(doc, :counter, 1) end,
                 step2: fn doc -> Document.update_private(doc, :counter, 0, &(&1 + 1)) end,
                 step3: fn doc -> Document.update_private(doc, :counter, 0, &(&1 * 2)) end
               )
               |> Document.run()
    end

    test "with MFA step" do
      defmodule TestMFA do
        def add_meta(doc, key, value), do: MDEx.Document.put_private(doc, key, value)
      end

      assert %MDEx.Document{private: %{author: "Jane"}} =
               MDEx.new()
               |> Document.append_steps(add: {TestMFA, :add_meta, [:author, "Jane"]})
               |> Document.run()
    end

    test "halts when step returns halted document" do
      assert %MDEx.Document{halted: true, private: %{before: true}} =
               MDEx.new()
               |> Document.append_steps(
                 before: fn doc -> Document.put_private(doc, :before, true) end,
                 halt: fn doc -> Document.halt(doc) end,
                 after: fn doc -> Document.put_private(doc, :after, true) end
               )
               |> Document.run()
    end

    test "halts with exception" do
      assert {%MDEx.Document{halted: true}, %RuntimeError{message: "error"}} =
               MDEx.new()
               |> Document.append_steps(
                 error: fn doc -> Document.halt(doc, %RuntimeError{message: "error"}) end,
                 skip: fn doc -> Document.put_private(doc, :skipped, true) end
               )
               |> Document.run()
    end

    test "modifies document nodes" do
      assert %MDEx.Document{nodes: [%MDEx.Heading{}, %MDEx.Paragraph{}]} =
               MDEx.new(markdown: "# Test")
               |> Document.append_steps(
                 add: fn doc ->
                   %{doc | nodes: doc.nodes ++ [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "new"}]}]}
                 end
               )
               |> Document.run()
    end

    test "preserves state across steps" do
      assert %MDEx.Document{private: %{count: 3, valid: true}} =
               MDEx.new(markdown: "# Title")
               |> Document.append_steps(
                 count: fn doc -> Document.put_private(doc, :count, Enum.count(doc)) end,
                 validate: fn doc -> Document.put_private(doc, :valid, Document.get_private(doc, :count) > 0) end
               )
               |> Document.run()
    end

    test "executes prepended steps first" do
      assert %MDEx.Document{private: %{order: [1, 2]}} =
               MDEx.new()
               |> Document.append_steps(second: fn doc -> Document.update_private(doc, :order, [], &(&1 ++ [2])) end)
               |> Document.prepend_steps(first: fn doc -> Document.put_private(doc, :order, [1]) end)
               |> Document.run()
    end

    test "with empty current_steps" do
      assert %MDEx.Document{private: %{}} =
               %MDEx.Document{steps: [test: fn doc -> Document.put_private(doc, :run, true) end], current_steps: []}
               |> Document.run()
    end

    test "with empty nodes and empty buffer" do
      assert %MDEx.Document{nodes: []} =
               %MDEx.Document{nodes: [], buffer: []}
               |> Document.run()
    end

    test "with empty nodes and buffer content" do
      assert %MDEx.Document{
               nodes: [
                 %MDEx.Heading{
                   nodes: [%MDEx.Text{literal: "Title"}],
                   level: 1,
                   setext: false
                 }
               ]
             } =
               %MDEx.Document{nodes: [], buffer: ["# Title"]}
               |> Document.run()
    end

    test "with nodes and empty buffer" do
      assert %MDEx.Document{
               nodes: [
                 %MDEx.Heading{
                   nodes: [%MDEx.Text{literal: "Existing"}],
                   level: 1,
                   setext: false
                 }
               ]
             } =
               MDEx.new(markdown: "# Existing")
               |> Document.run()
    end

    test "with nodes and buffer content" do
      assert %MDEx.Document{
               nodes: [
                 %MDEx.Heading{
                   nodes: [%MDEx.Text{literal: "First"}],
                   level: 1,
                   setext: false
                 },
                 %MDEx.Heading{
                   nodes: [%MDEx.Text{literal: "Second"}],
                   level: 1,
                   setext: false
                 }
               ]
             } =
               MDEx.new(markdown: "# First\n")
               |> Document.put_markdown("# Second")
               |> Document.run()
    end

    test "with nodes already parsed and buffer content" do
      assert %MDEx.Document{
               nodes: [
                 %MDEx.Heading{
                   nodes: [%MDEx.Text{literal: "First"}],
                   level: 1,
                   setext: false
                 },
                 %MDEx.Heading{
                   nodes: [%MDEx.Text{literal: "Second"}],
                   level: 1,
                   setext: false
                 }
               ]
             } =
               MDEx.new(markdown: "# First")
               |> Document.run()
               |> Document.put_markdown("# Second")
               |> Document.run()
    end

    test "default options" do
      assert %MDEx.Document{options: options} = MDEx.new() |> Document.run()

      refute options[:sanitize]
      assert [formatter: {:html_inline, _}] = options[:syntax_highlight]
    end

    test "preserves custom options" do
      assert %MDEx.Document{options: options} = MDEx.new(extension: [table: true]) |> Document.run()

      assert options[:extension][:table]
      refute options[:extension][:strikethrough]
    end
  end
end
