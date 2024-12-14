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

  def assert_parse_document(document, expected, opts \\ []) do
    extension = Keyword.get(opts, :extension, [])

    opts = [
      extension: Keyword.merge(@extension, extension),
      render: Keyword.get(opts, :render, [])
    ]

    assert MDEx.parse_document(document, opts) == {:ok, expected}
  end

  test "front matter" do
    assert_parse_document(
      """
      ---
      title: MDEx
      ---
      """,
      %MDEx.Document{nodes: [%MDEx.FrontMatter{literal: "---\ntitle: MDEx\n---\n"}]}
    )
  end

  test "block quote" do
    assert_parse_document(
      """
      > MDEx
      """,
      %MDEx.Document{nodes: [%MDEx.BlockQuote{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "MDEx"}]}]}]}
    )
  end

  describe "list" do
    test "bullet" do
      assert_parse_document(
        """
        * foo
        * bar
        """,
        %MDEx.Document{
          nodes: [
            %MDEx.List{
              nodes: [
                %MDEx.ListItem{
                  nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "foo"}]}],
                  list_type: :bullet,
                  marker_offset: 0,
                  padding: 2,
                  start: 1,
                  delimiter: :period,
                  bullet_char: "*",
                  tight: false
                },
                %MDEx.ListItem{
                  nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "bar"}]}],
                  list_type: :bullet,
                  marker_offset: 0,
                  padding: 2,
                  start: 1,
                  delimiter: :period,
                  bullet_char: "*",
                  tight: false
                }
              ],
              list_type: :bullet,
              marker_offset: 0,
              padding: 2,
              start: 1,
              delimiter: :period,
              bullet_char: "*",
              tight: true
            }
          ]
        }
      )
    end

    test "mixed" do
      assert_parse_document(
        """
        - foo
        - bar
        + baz
        """,
        %MDEx.Document{
          nodes: [
            %MDEx.List{
              nodes: [
                %MDEx.ListItem{
                  nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "foo"}]}],
                  list_type: :bullet,
                  marker_offset: 0,
                  padding: 2,
                  start: 1,
                  delimiter: :period,
                  bullet_char: "-",
                  tight: false
                },
                %MDEx.ListItem{
                  nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "bar"}]}],
                  list_type: :bullet,
                  marker_offset: 0,
                  padding: 2,
                  start: 1,
                  delimiter: :period,
                  bullet_char: "-",
                  tight: false
                }
              ],
              list_type: :bullet,
              marker_offset: 0,
              padding: 2,
              start: 1,
              delimiter: :period,
              bullet_char: "-",
              tight: true
            },
            %MDEx.List{
              nodes: [
                %MDEx.ListItem{
                  nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "baz"}]}],
                  list_type: :bullet,
                  marker_offset: 0,
                  padding: 2,
                  start: 1,
                  delimiter: :period,
                  bullet_char: "+",
                  tight: false
                }
              ],
              list_type: :bullet,
              marker_offset: 0,
              padding: 2,
              start: 1,
              delimiter: :period,
              bullet_char: "+",
              tight: true
            }
          ]
        }
      )
    end

    test "ordered" do
      assert_parse_document(
        """
        - foo
        - bar
        - baz
        """,
        %MDEx.Document{
          nodes: [
            %MDEx.List{
              nodes: [
                %MDEx.ListItem{
                  nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "foo"}]}],
                  list_type: :bullet,
                  marker_offset: 0,
                  padding: 2,
                  start: 1,
                  delimiter: :period,
                  bullet_char: "-",
                  tight: false
                },
                %MDEx.ListItem{
                  nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "bar"}]}],
                  list_type: :bullet,
                  marker_offset: 0,
                  padding: 2,
                  start: 1,
                  delimiter: :period,
                  bullet_char: "-",
                  tight: false
                },
                %MDEx.ListItem{
                  nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "baz"}]}],
                  list_type: :bullet,
                  marker_offset: 0,
                  padding: 2,
                  start: 1,
                  delimiter: :period,
                  bullet_char: "-",
                  tight: false
                }
              ],
              list_type: :bullet,
              marker_offset: 0,
              padding: 2,
              start: 1,
              delimiter: :period,
              bullet_char: "-",
              tight: true
            }
          ]
        }
      )
    end
  end

  test "description list" do
    assert_parse_document(
      """
      MDEx

      : Built with Elixir and Rust
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.DescriptionList{
            nodes: [
              %MDEx.DescriptionItem{
                nodes: [
                  %MDEx.DescriptionTerm{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "MDEx"}]}]},
                  %MDEx.DescriptionDetails{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Built with Elixir and Rust"}]}]}
                ],
                marker_offset: 0,
                padding: 2
              }
            ]
          }
        ]
      }
    )
  end

  test "code block" do
    assert_parse_document(
      """
      ```elixir
      String.trim(" MDEx ")
      ```
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.CodeBlock{
            nodes: [],
            fenced: true,
            fence_char: "`",
            fence_length: 3,
            fence_offset: 0,
            info: "elixir",
            literal: "String.trim(\" MDEx \")\n"
          }
        ]
      }
    )
  end

  test "html block" do
    assert_parse_document(
      """
      <h1>MDEx</h1>
      """,
      %MDEx.Document{nodes: [%MDEx.HtmlBlock{nodes: [], block_type: 6, literal: "<h1>MDEx</h1>\n"}]}
    )
  end

  test "heading" do
    assert_parse_document(
      """
      # level_1
      ###### level_6
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.Heading{nodes: [%MDEx.Text{literal: "level_1"}], level: 1, setext: false},
          %MDEx.Heading{nodes: [%MDEx.Text{literal: "level_6"}], level: 6, setext: false}
        ]
      }
    )
  end

  test "thematic break" do
    assert_parse_document(
      """
      ***
      ---
      """,
      %MDEx.Document{nodes: [%MDEx.ThematicBreak{}, %MDEx.ThematicBreak{}]}
    )
  end

  test "footnote" do
    assert_parse_document(
      """
      footnote[^1]

      [^1]: ref
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "footnote"}, %MDEx.FootnoteReference{name: "1", ref_num: 1, ix: 1}]},
          %MDEx.FootnoteDefinition{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "ref"}]}], name: "1", total_references: 1}
        ]
      }
    )
  end

  test "table" do
    assert_parse_document(
      """
      | foo | bar |
      | --- | --- |
      | baz | bim |
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.Table{
            nodes: [
              %MDEx.TableRow{
                nodes: [%MDEx.TableCell{nodes: [%MDEx.Text{literal: "foo"}]}, %MDEx.TableCell{nodes: [%MDEx.Text{literal: "bar"}]}],
                header: true
              },
              %MDEx.TableRow{
                nodes: [%MDEx.TableCell{nodes: [%MDEx.Text{literal: "baz"}]}, %MDEx.TableCell{nodes: [%MDEx.Text{literal: "bim"}]}],
                header: false
              }
            ],
            alignments: [:none, :none],
            num_columns: 2,
            num_rows: 1,
            num_nonempty_cells: 2
          }
        ]
      }
    )

    assert_parse_document(
      """
      | abc | defghi |
      :-: | -----------:
      bar | baz
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.Table{
            nodes: [
              %MDEx.TableRow{
                nodes: [%MDEx.TableCell{nodes: [%MDEx.Text{literal: "abc"}]}, %MDEx.TableCell{nodes: [%MDEx.Text{literal: "defghi"}]}],
                header: true
              },
              %MDEx.TableRow{
                nodes: [%MDEx.TableCell{nodes: [%MDEx.Text{literal: "bar"}]}, %MDEx.TableCell{nodes: [%MDEx.Text{literal: "baz"}]}],
                header: false
              }
            ],
            alignments: [:center, :right],
            num_columns: 2,
            num_rows: 1,
            num_nonempty_cells: 2
          }
        ]
      }
    )
  end

  test "task item" do
    assert_parse_document(
      """
      * [x] Done
      * [ ] Not done
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.List{
            nodes: [
              %MDEx.TaskItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Done"}]}], checked: true, marker: "x"},
              %MDEx.TaskItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Not done"}]}], checked: false, marker: ""}
            ],
            list_type: :bullet,
            marker_offset: 0,
            padding: 2,
            start: 1,
            delimiter: :period,
            bullet_char: "*",
            tight: true,
            is_task_list: true
          }
        ]
      }
    )
  end

  @tag :skip
  test "breaks" do
    assert_parse_document(
      """
      foo
      bar
      """,
      %MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "foo"}, %MDEx.SoftBreak{}, %MDEx.Text{literal: "bar"}]}]}
    )

    assert_parse_document(
      """
      foo
      bar
      """,
      :fixme,
      render: [hardbreaks: true]
    )
  end

  test "code" do
    assert_parse_document(
      """
      `String.trim(" MDEx ")`
      """,
      %MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "String.trim(\" MDEx \")"}]}]}
    )
  end

  test "html inline" do
    assert_parse_document(
      """
      <a><bab><c2c>
      """,
      %MDEx.Document{
        nodes: [%MDEx.Paragraph{nodes: [%MDEx.HtmlInline{literal: "<a>"}, %MDEx.HtmlInline{literal: "<bab>"}, %MDEx.HtmlInline{literal: "<c2c>"}]}]
      }
    )
  end

  test "emph, strong, strikethrough, superscript" do
    assert_parse_document(
      """
      *emph*
      **strong**
      ~strikethrough~
      X^2^
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [
              %MDEx.Emph{nodes: [%MDEx.Text{literal: "emph"}]},
              %MDEx.SoftBreak{},
              %MDEx.Strong{nodes: [%MDEx.Text{literal: "strong"}]},
              %MDEx.SoftBreak{},
              %MDEx.Strikethrough{nodes: [%MDEx.Text{literal: "strikethrough"}]},
              %MDEx.SoftBreak{},
              %MDEx.Text{literal: "X"},
              %MDEx.Superscript{nodes: [%MDEx.Text{literal: "2"}]}
            ]
          }
        ]
      }
    )
  end

  test "link" do
    assert_parse_document(
      """
      [foo]: /url "title"

      [foo]
      """,
      %MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Link{nodes: [%MDEx.Text{literal: "foo"}], title: "title", url: "/url"}]}]}
    )
  end

  test "image" do
    assert_parse_document(
      """
      ![foo](/url "title")
      """,
      %MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Image{nodes: [%MDEx.Text{literal: "foo"}], title: "title", url: "/url"}]}]}
    )
  end

  test "shortcode" do
    assert_parse_document(
      """
      :smile:
      """,
      %MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.ShortCode{code: "smile", emoji: "😄"}]}]}
    )
  end

  test "math" do
    assert_parse_document(
      """
      $1 + 2$ and $$x = y$$

      $`1 + 2`$
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [
              %MDEx.Math{dollar_math: true, display_math: false, literal: "1 + 2"},
              %MDEx.Text{literal: " and "},
              %MDEx.Math{dollar_math: true, display_math: true, literal: "x = y"}
            ]
          },
          %MDEx.Paragraph{nodes: [%MDEx.Math{dollar_math: false, display_math: false, literal: "1 + 2"}]}
        ]
      }
    )
  end

  test "multiline block quote" do
    assert_parse_document(
      """
      >>>
      A paragraph.

      - item one
      - item two
      >>>
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.MultilineBlockQuote{
            nodes: [
              %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "A paragraph."}]},
              %MDEx.List{
                nodes: [
                  %MDEx.ListItem{
                    nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item one"}]}],
                    list_type: :bullet,
                    marker_offset: 0,
                    padding: 2,
                    start: 1,
                    delimiter: :period,
                    bullet_char: "-",
                    tight: false
                  },
                  %MDEx.ListItem{
                    nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item two"}]}],
                    list_type: :bullet,
                    marker_offset: 0,
                    padding: 2,
                    start: 1,
                    delimiter: :period,
                    bullet_char: "-",
                    tight: false
                  }
                ],
                list_type: :bullet,
                marker_offset: 0,
                padding: 2,
                start: 1,
                delimiter: :period,
                bullet_char: "-",
                tight: true
              }
            ],
            fence_length: 3,
            fence_offset: 0
          }
        ]
      }
    )
  end

  describe "wiki links" do
    test "title before pipe" do
      assert_parse_document(
        """
        [[repo|https://github.com/leandrocp/mdex]]
        """,
        %MDEx.Document{
          nodes: [%MDEx.Paragraph{nodes: [%MDEx.WikiLink{nodes: [%MDEx.Text{literal: "repo"}], url: "https://github.com/leandrocp/mdex"}]}]
        },
        extension: [wikilinks_title_before_pipe: true]
      )
    end

    test "title after pipe" do
      assert_parse_document(
        """
        [[https://github.com/leandrocp/mdex|repo]]
        """,
        %MDEx.Document{
          nodes: [%MDEx.Paragraph{nodes: [%MDEx.WikiLink{nodes: [%MDEx.Text{literal: "repo"}], url: "https://github.com/leandrocp/mdex"}]}]
        },
        extension: [wikilinks_title_after_pipe: true]
      )
    end
  end

  test "spoiler" do
    assert_parse_document(
      """
      Darth Vader is ||Luke's father||
      """,
      %MDEx.Document{
        nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Darth Vader is "}, %MDEx.SpoileredText{nodes: [%MDEx.Text{literal: "Luke's father"}]}]}]
      }
    )
  end

  test "greentext" do
    assert_parse_document(
      """
      > one
      > > two
      > three
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.BlockQuote{
            nodes: [
              %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "one"}]},
              %MDEx.BlockQuote{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "two"}]}]},
              %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "three"}]}
            ]
          }
        ]
      }
    )
  end
end
