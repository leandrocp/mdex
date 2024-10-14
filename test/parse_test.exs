defmodule MDEx.ParseTest do
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
    greentext: true
  ]

  def assert_parse_document(document, expected, extension \\ []) do
    opts = [
      extension: Keyword.merge(@extension, extension)
    ]

    assert MDEx.parse_document(document, opts) == {:ok, expected}
  end

  test "text" do
    assert_parse_document("mdex", [{"document", %{}, [{"paragraph", %{}, ["mdex"]}]}])
  end

  test "front matter" do
    assert_parse_document(
      """
      ---
      title: MDEx
      ---
      """,
      [{"document", %{}, [{"front_matter", %{"content" => "---\ntitle: MDEx\n---\n"}, []}]}]
    )
  end

  test "block quote" do
    assert_parse_document(
      """
      > MDEx
      """,
      [{"document", %{}, [{"block_quote", %{}, [{"paragraph", %{}, ["MDEx"]}]}]}]
    )
  end

  describe "list" do
    test "unordered" do
      assert_parse_document(
        """
        - foo
          - bar
            - baz
              - boo
        """,
        [
          {"document", %{},
           [
             {"list",
              %{
                "list_type" => "bullet",
                "marker_offset" => 0,
                "padding" => 2,
                "start" => 1,
                "delimiter" => "period",
                "bullet_char" => "-",
                "tight" => true
              },
              [
                {"item",
                 %{
                   "list_type" => "bullet",
                   "marker_offset" => 0,
                   "padding" => 2,
                   "start" => 1,
                   "delimiter" => "period",
                   "bullet_char" => "-",
                   "tight" => false
                 },
                 [
                   {"paragraph", %{}, ["foo"]},
                   {"list",
                    %{
                      "list_type" => "bullet",
                      "marker_offset" => 0,
                      "padding" => 2,
                      "start" => 1,
                      "delimiter" => "period",
                      "bullet_char" => "-",
                      "tight" => true
                    },
                    [
                      {"item",
                       %{
                         "list_type" => "bullet",
                         "marker_offset" => 0,
                         "padding" => 2,
                         "start" => 1,
                         "delimiter" => "period",
                         "bullet_char" => "-",
                         "tight" => false
                       },
                       [
                         {"paragraph", %{}, ["bar"]},
                         {"list",
                          %{
                            "list_type" => "bullet",
                            "marker_offset" => 0,
                            "padding" => 2,
                            "start" => 1,
                            "delimiter" => "period",
                            "bullet_char" => "-",
                            "tight" => true
                          },
                          [
                            {"item",
                             %{
                               "list_type" => "bullet",
                               "marker_offset" => 0,
                               "padding" => 2,
                               "start" => 1,
                               "delimiter" => "period",
                               "bullet_char" => "-",
                               "tight" => false
                             },
                             [
                               {"paragraph", %{}, ["baz"]},
                               {"list",
                                %{
                                  "list_type" => "bullet",
                                  "marker_offset" => 0,
                                  "padding" => 2,
                                  "start" => 1,
                                  "delimiter" => "period",
                                  "bullet_char" => "-",
                                  "tight" => true
                                },
                                [
                                  {"item",
                                   %{
                                     "list_type" => "bullet",
                                     "marker_offset" => 0,
                                     "padding" => 2,
                                     "start" => 1,
                                     "delimiter" => "period",
                                     "bullet_char" => "-",
                                     "tight" => false
                                   }, [{"paragraph", %{}, ["boo"]}]}
                                ]}
                             ]}
                          ]}
                       ]}
                    ]}
                 ]}
              ]}
           ]}
        ]
      )
    end

    test "ordered" do
      assert_parse_document(
        """
        1. foo
        2.
        3. bar
        """,
        [
          {"document", %{},
           [
             {"list",
              %{
                "list_type" => "ordered",
                "marker_offset" => 0,
                "padding" => 3,
                "start" => 1,
                "delimiter" => "period",
                "bullet_char" => "",
                "tight" => true
              },
              [
                {"item",
                 %{
                   "list_type" => "ordered",
                   "marker_offset" => 0,
                   "padding" => 3,
                   "start" => 1,
                   "delimiter" => "period",
                   "bullet_char" => "",
                   "tight" => false
                 }, [{"paragraph", %{}, ["foo"]}]},
                {"item",
                 %{
                   "list_type" => "ordered",
                   "marker_offset" => 0,
                   "padding" => 3,
                   "start" => 2,
                   "delimiter" => "period",
                   "bullet_char" => "",
                   "tight" => false
                 }, []},
                {"item",
                 %{
                   "list_type" => "ordered",
                   "marker_offset" => 0,
                   "padding" => 3,
                   "start" => 3,
                   "delimiter" => "period",
                   "bullet_char" => "",
                   "tight" => false
                 }, [{"paragraph", %{}, ["bar"]}]}
              ]}
           ]}
        ]
      )
    end
  end

  test "description list" do
    assert_parse_document(
      """
      MDEx

      : Built with Elixir and Rust
      """,
      [
        {"document", %{},
         [
           {"description_list", %{},
            [
              {"description_item", %{"marker_offset" => 0, "padding" => 2},
               [
                 {"description_term", %{}, [{"paragraph", %{}, ["MDEx"]}]},
                 {"description_details", %{}, [{"paragraph", %{}, ["Built with Elixir and Rust"]}]}
               ]}
            ]}
         ]}
      ]
    )
  end

  test "code block" do
    assert_parse_document(
      """
      ```elixir
      String.trim(" MDEx ")
      ```
      """,
      [
        {"document", %{},
         [
           {"code_block",
            %{
              "fenced" => true,
              "fence_char" => "`",
              "fence_length" => 3,
              "fence_offset" => 0,
              "info" => "elixir",
              "literal" => "String.trim(\" MDEx \")\n"
            }, []}
         ]}
      ]
    )
  end

  test "html block" do
    assert_parse_document(
      """
      <h1>MDEx</h1>
      """,
      [
        {"document", %{},
         [
           {"html_block", %{"block_type" => 6, "literal" => "<h1>MDEx</h1>\n"}, []}
         ]}
      ]
    )
  end

  test "header" do
    assert_parse_document(
      """
      # level_1
      ###### level_6
      """,
      [
        {"document", %{},
         [
           {"heading", %{"level" => 1, "setext" => false}, ["level_1"]},
           {"heading", %{"level" => 6, "setext" => false}, ["level_6"]}
         ]}
      ]
    )
  end

  test "footnote" do
    assert_parse_document(
      """
      footnote[^1]

      [^1]: ref
      """,
      [
        {"document", %{},
         [
           {"paragraph", %{}, ["footnote", {"footnote_reference", %{"name" => "1", "ref_num" => 1, "ix" => 1}, []}]},
           {"footnote_definition", %{"name" => "1", "total_references" => 1}, [{"paragraph", %{}, ["ref"]}]}
         ]}
      ]
    )
  end

  test "table" do
    assert_parse_document(
      """
      | foo | bar |
      | --- | --- |
      | baz | bim |
      """,
      [
        {"document", %{},
         [
           {"table", %{"alignments" => ["none", "none"], "num_columns" => 2, "num_rows" => 1, "num_nonempty_cells" => 2},
            [
              {"table_row", %{"header" => true}, [{"table_cell", %{}, ["foo"]}, {"table_cell", %{}, ["bar"]}]},
              {"table_row", %{"header" => false}, [{"table_cell", %{}, ["baz"]}, {"table_cell", %{}, ["bim"]}]}
            ]}
         ]}
      ]
    )

    assert_parse_document(
      """
      | abc | defghi |
      :-: | -----------:
      bar | baz
      """,
      [
        {"document", %{},
         [
           {"table", %{"alignments" => ["center", "right"], "num_columns" => 2, "num_rows" => 1, "num_nonempty_cells" => 2},
            [
              {"table_row", %{"header" => true}, [{"table_cell", %{}, ["abc"]}, {"table_cell", %{}, ["defghi"]}]},
              {"table_row", %{"header" => false}, [{"table_cell", %{}, ["bar"]}, {"table_cell", %{}, ["baz"]}]}
            ]}
         ]}
      ]
    )
  end

  test "task item" do
    assert_parse_document(
      """
      * [x] Done
      * [ ] Not done
      """,
      [
        {"document", %{},
         [
           {"list",
            %{
              "list_type" => "bullet",
              "marker_offset" => 0,
              "padding" => 2,
              "start" => 1,
              "delimiter" => "period",
              "bullet_char" => "*",
              "tight" => true
            },
            [
              {"task_item", %{"checked" => true, "symbol" => "x"}, [{"paragraph", %{}, ["Done"]}]},
              {"task_item", %{"checked" => false}, [{"paragraph", %{}, ["Not done"]}]}
            ]}
         ]}
      ]
    )
  end

  test "link" do
    assert_parse_document(
      """
      [foo]: /url "title"

      [foo]
      """,
      [{"document", %{}, [{"paragraph", %{}, [{"link", %{"url" => "/url", "title" => "title"}, ["foo"]}]}]}]
    )
  end

  test "image" do
    assert_parse_document(
      """
      ![foo](/url "title")
      """,
      [{"document", %{}, [{"paragraph", %{}, [{"image", %{"url" => "/url", "title" => "title"}, ["foo"]}]}]}]
    )
  end

  test "code" do
    assert_parse_document(
      """
      `String.trim(" MDEx ")`
      """,
      [{"document", %{}, [{"paragraph", %{}, [{"code", %{"num_backticks" => 1, "literal" => "String.trim(\" MDEx \")"}, []}]}]}]
    )
  end

  test "shortcode" do
    assert_parse_document(
      """
      :smile:
      """,
      [{"document", %{}, [{"paragraph", %{}, [{"short_code", %{"code" => "smile", "emoji" => "😄"}, []}]}]}]
    )
  end

  test "math" do
    assert_parse_document(
      """
      $1 + 2$ and $$x = y$$

      $`1 + 2`$
      """,
      [
        {"document", %{},
         [
           {"paragraph", %{},
            [
              {"math", %{"dollar_math" => true, "display_math" => false, "literal" => "1 + 2"}, []},
              " and ",
              {"math", %{"dollar_math" => true, "display_math" => true, "literal" => "x = y"}, []}
            ]},
           {"paragraph", %{}, [{"math", %{"dollar_math" => false, "display_math" => false, "literal" => "1 + 2"}, []}]}
         ]}
      ]
    )
  end

  describe "wiki links" do
    test "title before pipe" do
      assert_parse_document(
        """
        [[repo|https://github.com/leandrocp/mdex]]
        """,
        [{"document", %{}, [{"paragraph", %{}, [{"wiki_link", %{"url" => "https://github.com/leandrocp/mdex"}, ["repo"]}]}]}],
        wikilinks_title_before_pipe: true
      )
    end

    test "title after pipe" do
      assert_parse_document(
        """
        [[https://github.com/leandrocp/mdex|repo]]
        """,
        [{"document", %{}, [{"paragraph", %{}, [{"wiki_link", %{"url" => "https://github.com/leandrocp/mdex"}, ["repo"]}]}]}],
        wikilinks_title_after_pipe: true
      )
    end
  end

  test "spoiler" do
    assert_parse_document(
      """
      Darth Vader is ||Luke's father||
      """,
      [{"document", %{}, [{"paragraph", %{}, ["Darth Vader is ", {"spoilered_text", %{}, ["Luke's father"]}]}]}]
    )
  end

  test "greentext" do
    assert_parse_document(
      """
      > one
      > > two
      > three
      """,
      [
        {"document", %{},
         [{"block_quote", %{}, [{"paragraph", %{}, ["one"]}, {"block_quote", %{}, [{"paragraph", %{}, ["two"]}]}, {"paragraph", %{}, ["three"]}]}]}
      ]
    )
  end
end
