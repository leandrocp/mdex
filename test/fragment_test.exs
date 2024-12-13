defmodule MDEx.FragmentTest do
  use ExUnit.Case, async: true

  @fragment MDEx.parse_fragment!("""
            Lang: `elixir`
            """)

  describe "Access behaviour" do
    test "get_in" do
      assert get_in(@fragment, [:paragraph, Access.all(), :code]) == [[%MDEx.Code{literal: "elixir", num_backticks: 1}]]
      assert get_in(@fragment, [:paragraph, Access.all(), %MDEx.Text{literal: "Lang: "}]) == [[%MDEx.Text{literal: "Lang: "}]]
    end

    test "update_in" do
      assert update_in(@fragment, [:code, Access.key!(:literal)], fn literal ->
               String.upcase(literal)
             end) == %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Lang: "}, %MDEx.Code{num_backticks: 1, literal: "ELIXIR"}]}
    end
  end

  describe "traverse and update" do
    test "modify existing nodes" do
      assert MDEx.traverse_and_update(@fragment, fn
               %MDEx.Code{literal: "elixir"} = node ->
                 %{node | literal: "ex"}

               node ->
                 node
             end) == %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Lang: "}, %MDEx.Code{num_backticks: 1, literal: "ex"}]}
    end
  end
end
