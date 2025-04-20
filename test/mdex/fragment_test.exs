defmodule MDEx.FragmentTest do
  use ExUnit.Case, async: true

  @paragraph_node MDEx.parse_fragment!("""
                  Lang: `elixir`
                  """)

  @code_node MDEx.parse_fragment!("`:elixir`")

  describe "Access behaviour" do
    test "get_in nodes" do
      assert get_in(@paragraph_node, [:paragraph, Access.all(), :code]) == [[%MDEx.Code{literal: "elixir", num_backticks: 1}]]
      assert get_in(@paragraph_node, [:paragraph, Access.all(), %MDEx.Text{literal: "Lang: "}]) == [[%MDEx.Text{literal: "Lang: "}]]
    end

    test "get_in single node" do
      assert get_in(@code_node, [Access.key!(:literal)]) == ":elixir"
    end

    test "update_in" do
      assert update_in(@paragraph_node, [:code, Access.key!(:literal)], fn literal ->
               String.upcase(literal)
             end) == %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Lang: "}, %MDEx.Code{num_backticks: 1, literal: "ELIXIR"}]}
    end

    test "update_in single node" do
      assert update_in(@code_node, [Access.key!(:literal)], fn literal ->
               String.upcase(literal)
             end) == %MDEx.Code{num_backticks: 1, literal: ":ELIXIR"}
    end
  end

  describe "traverse and update" do
    test "modify existing nodes" do
      assert MDEx.traverse_and_update(@paragraph_node, fn
               %MDEx.Code{literal: "elixir"} = node ->
                 %{node | literal: "ex"}

               node ->
                 node
             end) == %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Lang: "}, %MDEx.Code{num_backticks: 1, literal: "ex"}]}
    end
  end
end
