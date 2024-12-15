defmodule MDEx.DocumentTest do
  use ExUnit.Case, async: true
  import MDEx.Sigil
  doctest MDEx.Document, import: true

  @document ~M"""
  `elixir`

  `rust`

   more
  """

  describe "Access behaviour" do
    test "get_in" do
      assert get_in(@document, [:document, Access.all(), :code]) == [
               [%MDEx.Code{literal: "elixir", num_backticks: 1}, %MDEx.Code{literal: "rust", num_backticks: 1}]
             ]

      assert get_in(@document, [:document, Access.all(), %MDEx.Text{literal: "more"}]) == [[%MDEx.Text{literal: "more"}]]
    end

    test "update_in" do
      assert update_in(@document, [:code, Access.key!(:literal)], fn literal ->
               String.upcase(literal)
             end) ==
               %MDEx.Document{
                 nodes: [
                   %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "ELIXIR"}]},
                   %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "rust"}]},
                   %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
                 ]
               }
    end

    test "update_in all nested" do
      assert update_in(@document, [:document, Access.key!(:nodes), Access.all(), :code, Access.key!(:literal)], fn literal ->
               String.upcase(literal)
             end) ==
               %MDEx.Document{
                 nodes: [
                   %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "ELIXIR"}]},
                   %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "RUST"}]},
                   %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
                 ]
               }
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
               %MDEx.Code{num_backticks: 1, literal: "elixir"},
               %MDEx.Code{num_backticks: 1, literal: "rust"},
               %MDEx.Text{literal: "more"}
             ]
    end

    test "get and update by struct key" do
      assert MDEx.Document.get_and_update(@document, %MDEx.Text{literal: "more"}, fn node ->
               {node, %{node | literal: String.upcase(node.literal)}}
             end) ==
               {%MDEx.Text{literal: "more"},
                %MDEx.Document{
                  nodes: [
                    %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "elixir"}]},
                    %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "rust"}]},
                    %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "MORE"}]}
                  ]
                }}

      assert MDEx.Document.get_and_update(@document, %MDEx.Code{num_backticks: 1, literal: "rust"}, fn node ->
               {node, %{node | literal: String.upcase(node.literal)}}
             end) ==
               {%MDEx.Code{literal: "rust", num_backticks: 1},
                %MDEx.Document{
                  nodes: [
                    %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "elixir", num_backticks: 1}]},
                    %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "RUST", num_backticks: 1}]},
                    %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
                  ]
                }}
    end

    test "get and update by module key" do
      assert MDEx.Document.get_and_update(@document, MDEx.Text, fn node ->
               {node, %{node | literal: String.upcase(node.literal)}}
             end) ==
               {%MDEx.Text{literal: "more"},
                %MDEx.Document{
                  nodes: [
                    %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "elixir"}]},
                    %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "rust"}]},
                    %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "MORE"}]}
                  ]
                }}

      assert MDEx.Document.get_and_update(@document, MDEx.Code, fn node ->
               {node, %{node | literal: String.upcase(node.literal)}}
             end) ==
               {%MDEx.Code{num_backticks: 1, literal: "elixir"},
                %MDEx.Document{
                  nodes: [
                    %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "ELIXIR"}]},
                    %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "rust"}]},
                    %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
                  ]
                }}
    end

    test "get and update by atom key" do
      assert MDEx.Document.get_and_update(@document, :code, fn node ->
               {node, %{node | literal: String.upcase(node.literal)}}
             end) ==
               {%MDEx.Code{num_backticks: 1, literal: "elixir"},
                %MDEx.Document{
                  nodes: [
                    %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "ELIXIR"}]},
                    %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "rust"}]},
                    %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
                  ]
                }}
    end

    test "get and update by function key" do
      assert MDEx.Document.get_and_update(@document, &(Map.get(&1, :literal) == "more"), fn node ->
               {node, %{node | literal: String.upcase(node.literal)}}
             end) ==
               {%MDEx.Text{literal: "more"},
                %MDEx.Document{
                  nodes: [
                    %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "elixir"}]},
                    %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "rust"}]},
                    %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "MORE"}]}
                  ]
                }}
    end

    test "pop by struct key" do
      assert MDEx.Document.pop(@document, %MDEx.List{}, :default) ==
               {:default,
                %MDEx.Document{
                  nodes: [
                    %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "elixir"}]},
                    %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "rust"}]},
                    %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
                  ]
                }}

      assert MDEx.Document.pop(@document, %MDEx.Text{literal: "more"}) ==
               {%MDEx.Text{literal: "more"},
                %MDEx.Document{
                  nodes: [
                    %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "elixir"}]},
                    %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "rust"}]},
                    %MDEx.Paragraph{nodes: []}
                  ]
                }}
    end

    test "pop by module key" do
      assert MDEx.Document.pop(@document, MDEx.Code) ==
               {%MDEx.Code{num_backticks: 1, literal: "elixir"},
                %MDEx.Document{
                  nodes: [
                    %MDEx.Paragraph{nodes: []},
                    %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "rust"}]},
                    %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
                  ]
                }}
    end

    test "pop by atom key" do
      assert MDEx.Document.pop(@document, :code) ==
               {%MDEx.Code{num_backticks: 1, literal: "elixir"},
                %MDEx.Document{
                  nodes: [
                    %MDEx.Paragraph{nodes: []},
                    %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "rust"}]},
                    %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
                  ]
                }}
    end
  end

  describe "traverse and update" do
    test "modify existing nodes" do
      assert MDEx.traverse_and_update(@document, fn
               %MDEx.Code{literal: "elixir"} = node ->
                 %{node | literal: "ex"}

               %MDEx.Code{literal: "rust"} = node ->
                 %{node | literal: "rs"}

               node ->
                 node
             end) ==
               %MDEx.Document{
                 nodes: [
                   %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "ex"}]},
                   %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "rs"}]},
                   %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
                 ]
               }
    end

    test "append child" do
      assert MDEx.traverse_and_update(~M[# Test], fn
               %MDEx.Document{nodes: nodes} = node ->
                 new = MDEx.parse_fragment!("`foo = 1`")
                 %{node | nodes: nodes ++ [new]}

               node ->
                 node
             end) ==
               %MDEx.Document{
                 nodes: [
                   %MDEx.Heading{nodes: [%MDEx.Text{literal: "Test"}], level: 1, setext: false},
                   %MDEx.Code{num_backticks: 1, literal: "foo = 1"}
                 ]
               }
    end

    test "pop existing node" do
      assert MDEx.traverse_and_update(@document, fn
               %MDEx.Code{} -> :pop
               node -> node
             end) ==
               %MDEx.Document{nodes: [%MDEx.Paragraph{nodes: []}, %MDEx.Paragraph{nodes: []}, %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}]}
    end
  end

  describe "traverse and update with accumulator" do
    test "modify existing nodes" do
      document = ~M"""
      # Lang: `elixir`

      # Lang: `rust`

      more
      """

      assert MDEx.traverse_and_update(document, 0, fn
               %MDEx.Code{literal: "elixir"} = node, acc ->
                 node = %{node | literal: "ex"}
                 {node, acc + 1}

               %MDEx.Code{literal: "rust"} = node, acc ->
                 node = %{node | literal: "rs"}
                 {node, acc + 1}

               node, acc ->
                 {node, acc}
             end) ==
               {%MDEx.Document{
                  nodes: [
                    %MDEx.Heading{nodes: [%MDEx.Text{literal: "Lang: "}, %MDEx.Code{num_backticks: 1, literal: "ex"}], level: 1, setext: false},
                    %MDEx.Heading{nodes: [%MDEx.Text{literal: "Lang: "}, %MDEx.Code{num_backticks: 1, literal: "rs"}], level: 1, setext: false},
                    %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
                  ]
                }, 2}
    end

    test "control processing continuation" do
      document = ~M"""
      # Lang: `elixir`

      # Lang: `rust`

      more
      """

      assert MDEx.traverse_and_update(document, :cont, fn
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
             end) ==
               {%MDEx.Document{
                  nodes: [
                    %MDEx.Heading{nodes: [%MDEx.Text{literal: "Lang: "}, %MDEx.Code{num_backticks: 1, literal: "ex"}], level: 1, setext: false},
                    %MDEx.Heading{nodes: [%MDEx.Text{literal: "Lang: "}, %MDEx.Code{num_backticks: 1, literal: "rust"}], level: 1, setext: false},
                    %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
                  ]
                }, :halted}
    end
  end

  describe "String.Chars protocol" do
    test "to_string formats sigil to commonmark" do
      assert to_string(~M[# Hello]) == "# Hello"
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
    test "reduce" do
      assert Enum.reduce(@document, 0, fn
               %{literal: _literal}, acc ->
                 acc + 1

               _node, acc ->
                 acc
             end) == 3
    end

    test "map" do
      assert Enum.map(@document, fn %node{} ->
               inspect(node)
             end) == [
               "MDEx.Document",
               "MDEx.Paragraph",
               "MDEx.Code",
               "MDEx.Paragraph",
               "MDEx.Code",
               "MDEx.Paragraph",
               "MDEx.Text"
             ]
    end

    test "count" do
      assert Enum.count(@document) == 7
    end

    test "find" do
      assert Enum.find(@document, nil, fn node -> node == %MDEx.Text{literal: "more"} end) == %MDEx.Text{literal: "more"}
    end

    test "member?" do
      assert Enum.member?(@document, %MDEx.Code{literal: "elixir", num_backticks: 1}) == true
      assert Enum.member?(@document, %MDEx.Text{literal: "more"}) == true
    end

    test "suspended" do
      assert Enum.zip(@document, [1]) == [
               {%MDEx.Document{
                  nodes: [
                    %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "elixir", num_backticks: 1}]},
                    %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "rust"}]},
                    %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "more"}]}
                  ]
                }, 1}
             ]
    end
  end

  describe "Collectable protocol" do
    test "into document" do
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
  end

  test "modulefy!" do
    assert_raise MDEx.InvalidSelector, fn ->
      MDEx.Document.Access.modulefy!(nil) == 1
    end

    assert MDEx.Document.Access.modulefy!(:code) == MDEx.Code
    assert MDEx.Document.Access.modulefy!(:code_block) == MDEx.CodeBlock
  end
end
