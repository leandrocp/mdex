defmodule MDEx.JsonFormatTest do
  use ExUnit.Case

  @extension [
    strikethrough: true,
    tagfilter: true,
    table: true,
    autolink: true,
    tasklist: true,
    superscript: true,
    footnotes: true,
    description_lists: true,
    front_matter_delimiter: "---",
    multiline_block_quotes: true,
    math_dollars: true,
    math_code: true,
    shortcodes: true,
    underline: true,
    spoiler: true,
    greentext: true,
    insert: true
  ]

  def to_json(document, extension \\ []) do
    opts = [
      extension: Keyword.merge(@extension, extension),
      render: [unsafe: true]
    ]

    assert {:ok, json} = MDEx.to_json(document, opts)
    Jason.decode!(json, keys: :atoms!)
  end

  test "empty doc" do
    assert %{node_type: "MDEx.Document", nodes: []} = to_json("")
  end

  test "heading" do
    assert %{
             node_type: "MDEx.Document",
             nodes: [%{node_type: "MDEx.Heading", nodes: [%{node_type: "MDEx.Text", literal: "Title"}], level: 1, setext: false}]
           } = to_json("# Title")
  end

  test "insert" do
    assert %{
             node_type: "MDEx.Document",
             nodes: [
               %{
                 node_type: "MDEx.Paragraph",
                 nodes: [
                   %{node_type: "MDEx.Text", literal: "this is "},
                   %{node_type: "MDEx.Insert", nodes: [%{node_type: "MDEx.Text", literal: "inserted"}]},
                   %{node_type: "MDEx.Text", literal: " text"}
                 ]
               }
             ]
           } = to_json("this is ++inserted++ text")
  end

  test "highlight" do
    assert %{
             node_type: "MDEx.Document",
             nodes: [
               %{
                 node_type: "MDEx.Paragraph",
                 nodes: [
                   %{node_type: "MDEx.Text", literal: "this is "},
                   %{node_type: "MDEx.Highlight", nodes: [%{node_type: "MDEx.Text", literal: "marked"}]},
                   %{node_type: "MDEx.Text", literal: " text"}
                 ]
               }
             ]
           } = to_json("this is ==marked== text", highlight: true)
  end

  test "subtext" do
    assert %{
             node_type: "MDEx.Document",
             nodes: [
               %{node_type: "MDEx.Subtext", nodes: [%{node_type: "MDEx.Text", literal: "Some Subtext"}]}
             ]
           } = to_json("-# Some Subtext\n", subtext: true)
  end

  describe "parse_document" do
    test "uses defaults for omitted list fields" do
      assert %MDEx.Document{
               nodes: [%MDEx.List{list_type: :bullet, delimiter: :period, nodes: []}]
             } = parse_sparse_node("MDEx.List", nodes: [])
    end

    test "uses defaults for omitted list item fields" do
      assert %MDEx.Document{
               nodes: [%MDEx.ListItem{list_type: :bullet, delimiter: :period, nodes: []}]
             } = parse_sparse_node("MDEx.ListItem", nodes: [])
    end

    test "uses defaults for omitted table alignments" do
      assert %MDEx.Document{nodes: [%MDEx.Table{alignments: [], nodes: []}]} =
               parse_sparse_node("MDEx.Table", nodes: [])
    end

    test "uses defaults for omitted footnote reference texts" do
      assert %MDEx.Document{nodes: [%MDEx.FootnoteReference{texts: []}]} =
               parse_sparse_node("MDEx.FootnoteReference")
    end

    test "uses defaults for omitted alert type" do
      assert %MDEx.Document{nodes: [%MDEx.Alert{alert_type: :note, nodes: []}]} =
               parse_sparse_node("MDEx.Alert", nodes: [])
    end

    test "does not create atoms from invalid node_type values" do
      try do
        MDEx.parse_document({:json, ~s|{"node_type":"MDEx.Unknown","nodes":[]}|})
      rescue
        _ -> :ok
      end

      before = :erlang.system_info(:atom_count)

      prefix = "AtomDoS#{System.unique_integer([:positive])}"

      payload =
        Enum.reduce(1..100, "", fn i, nodes ->
          ~s|{"node_type":"#{prefix}#{i}","nodes":[#{nodes}]}|
        end)

      try do
        MDEx.parse_document({:json, payload})
      rescue
        _ -> :ok
      end

      assert :erlang.system_info(:atom_count) - before == 0
    end

    test "reuses atoms for valid node_type values" do
      payload =
        ~s|{"node_type":"MDEx.Document","nodes":[{"node_type":"MDEx.Paragraph","nodes":[{"node_type":"MDEx.Text","literal":"one"}]},{"node_type":"MDEx.Paragraph","nodes":[{"node_type":"MDEx.Text","literal":"two"}]}]}|

      assert {:ok, %MDEx.Document{nodes: [%MDEx.Paragraph{}, %MDEx.Paragraph{}]}} = MDEx.parse_document({:json, payload})
      before = :erlang.system_info(:atom_count)
      assert {:ok, %MDEx.Document{nodes: [%MDEx.Paragraph{}, %MDEx.Paragraph{}]}} = MDEx.parse_document({:json, payload})
      assert :erlang.system_info(:atom_count) - before == 0
    end
  end

  defp parse_sparse_node(node_type, fields \\ []) do
    node = fields |> Map.new() |> Map.put(:node_type, node_type)
    json = Jason.encode!(%{node_type: "MDEx.Document", nodes: [node]})
    MDEx.parse_document!({:json, json})
  end
end
