defmodule MDEx.Document.TraversalTest do
  use ExUnit.Case, async: true

  alias MDEx.Document.Traversal

  describe "traverse_and_update/2" do
    test "handles fragments" do
      text = %MDEx.Text{literal: "test"}
      assert %{literal: "TEST"} = Traversal.traverse_and_update(text, fn node -> %{node | literal: String.upcase(node.literal)} end)
    end

    test "skips nil nodes in nested list" do
      document = %MDEx.Document{
        nodes: [
          %MDEx.List{
            nodes: [
              %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "keep"}]}]},
              %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "remove"}]}]}
            ]
          }
        ]
      }

      document =
        Traversal.traverse_and_update(document, fn
          %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "remove"}]}]} -> nil
          node -> node
        end)

      assert [
               %MDEx.List{
                 start: 1,
                 nodes: [
                   %MDEx.ListItem{
                     nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "keep"}]}],
                     list_type: :bullet,
                     marker_offset: 0,
                     padding: 2,
                     start: 1,
                     delimiter: :period,
                     bullet_char: "-",
                     tight: true,
                     is_task_list: false
                   }
                 ],
                 delimiter: :period,
                 padding: 2,
                 list_type: :bullet,
                 marker_offset: 0,
                 bullet_char: "-",
                 tight: true,
                 is_task_list: false
               }
             ] = document.nodes
    end
  end

  describe "traverse_and_update/3" do
    test "handles non-node documents with accumulator" do
      text = %MDEx.Text{literal: "test"}
      {_result, acc} = Traversal.traverse_and_update(text, 0, fn node, acc -> {node, acc + 1} end)
      assert acc == 2
    end

    test "skips nil nodes with accumulator in nested list" do
      document = %MDEx.Document{
        nodes: [
          %MDEx.List{
            nodes: [
              %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "a"}]}]},
              %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "b"}]}]}
            ]
          }
        ]
      }

      {document, count} =
        Traversal.traverse_and_update(document, 0, fn
          %MDEx.ListItem{}, acc -> {nil, acc + 1}
          node, acc -> {node, acc}
        end)

      assert [
               %MDEx.List{
                 start: 1,
                 nodes: [],
                 delimiter: :period,
                 padding: 2,
                 list_type: :bullet,
                 marker_offset: 0,
                 bullet_char: "-",
                 tight: true,
                 is_task_list: false
               }
             ] = document.nodes

      assert count == 2
    end
  end
end
