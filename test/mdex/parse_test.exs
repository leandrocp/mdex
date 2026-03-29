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
    greentext: true,
    insert: true
  ]

  def assert_parse_markdown(markdown, expected, opts \\ []) do
    extension = Keyword.get(opts, :extension, [])

    opts = [
      extension: Keyword.merge(@extension, extension),
      render: Keyword.get(opts, :render, [])
    ]

    assert {:ok, document} = MDEx.parse_document(markdown, opts)
    assert document.nodes == expected.nodes
  end

  test "front matter" do
    assert_parse_markdown(
      """
      ---
      title: MDEx
      ---
      """,
      %MDEx.Document{nodes: [%MDEx.FrontMatter{literal: "---\ntitle: MDEx\n---\n", sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {3, 3}}}]}
    )
  end

  test "block quote" do
    assert_parse_markdown(
      """
      > MDEx
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.BlockQuote{
            nodes: [
              %MDEx.Paragraph{
                nodes: [%MDEx.Text{literal: "MDEx", sourcepos: %MDEx.Sourcepos{start: {1, 3}, end: {1, 6}}}],
                sourcepos: %MDEx.Sourcepos{start: {1, 3}, end: {1, 6}}
              }
            ],
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 6}}
          }
        ]
      }
    )
  end

  describe "list" do
    test "bullet" do
      assert_parse_markdown(
        """
        * foo
        * bar
        """,
        %MDEx.Document{
          nodes: [
            %MDEx.List{
              nodes: [
                %MDEx.ListItem{
                  nodes: [
                    %MDEx.Paragraph{
                      nodes: [%MDEx.Text{literal: "foo", sourcepos: %MDEx.Sourcepos{start: {1, 3}, end: {1, 5}}}],
                      sourcepos: %MDEx.Sourcepos{start: {1, 3}, end: {1, 5}}
                    }
                  ],
                  list_type: :bullet,
                  marker_offset: 0,
                  padding: 2,
                  start: 1,
                  delimiter: :period,
                  bullet_char: "*",
                  tight: false,
                  sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 5}}
                },
                %MDEx.ListItem{
                  nodes: [
                    %MDEx.Paragraph{
                      nodes: [%MDEx.Text{literal: "bar", sourcepos: %MDEx.Sourcepos{start: {2, 3}, end: {2, 5}}}],
                      sourcepos: %MDEx.Sourcepos{start: {2, 3}, end: {2, 5}}
                    }
                  ],
                  list_type: :bullet,
                  marker_offset: 0,
                  padding: 2,
                  start: 1,
                  delimiter: :period,
                  bullet_char: "*",
                  tight: false,
                  sourcepos: %MDEx.Sourcepos{start: {2, 1}, end: {2, 5}}
                }
              ],
              list_type: :bullet,
              marker_offset: 0,
              padding: 2,
              start: 1,
              delimiter: :period,
              bullet_char: "*",
              tight: true,
              sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {2, 5}}
            }
          ]
        }
      )
    end

    test "mixed" do
      assert_parse_markdown(
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
                  nodes: [
                    %MDEx.Paragraph{
                      nodes: [%MDEx.Text{literal: "foo", sourcepos: %MDEx.Sourcepos{start: {1, 3}, end: {1, 5}}}],
                      sourcepos: %MDEx.Sourcepos{start: {1, 3}, end: {1, 5}}
                    }
                  ],
                  list_type: :bullet,
                  marker_offset: 0,
                  padding: 2,
                  start: 1,
                  delimiter: :period,
                  bullet_char: "-",
                  tight: false,
                  sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 5}}
                },
                %MDEx.ListItem{
                  nodes: [
                    %MDEx.Paragraph{
                      nodes: [%MDEx.Text{literal: "bar", sourcepos: %MDEx.Sourcepos{start: {2, 3}, end: {2, 5}}}],
                      sourcepos: %MDEx.Sourcepos{start: {2, 3}, end: {2, 5}}
                    }
                  ],
                  list_type: :bullet,
                  marker_offset: 0,
                  padding: 2,
                  start: 1,
                  delimiter: :period,
                  bullet_char: "-",
                  tight: false,
                  sourcepos: %MDEx.Sourcepos{start: {2, 1}, end: {2, 5}}
                }
              ],
              list_type: :bullet,
              marker_offset: 0,
              padding: 2,
              start: 1,
              delimiter: :period,
              bullet_char: "-",
              tight: true,
              sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {2, 5}}
            },
            %MDEx.List{
              nodes: [
                %MDEx.ListItem{
                  nodes: [
                    %MDEx.Paragraph{
                      nodes: [%MDEx.Text{literal: "baz", sourcepos: %MDEx.Sourcepos{start: {3, 3}, end: {3, 5}}}],
                      sourcepos: %MDEx.Sourcepos{start: {3, 3}, end: {3, 5}}
                    }
                  ],
                  list_type: :bullet,
                  marker_offset: 0,
                  padding: 2,
                  start: 1,
                  delimiter: :period,
                  bullet_char: "+",
                  tight: false,
                  sourcepos: %MDEx.Sourcepos{start: {3, 1}, end: {3, 5}}
                }
              ],
              list_type: :bullet,
              marker_offset: 0,
              padding: 2,
              start: 1,
              delimiter: :period,
              bullet_char: "+",
              tight: true,
              sourcepos: %MDEx.Sourcepos{start: {3, 1}, end: {3, 5}}
            }
          ]
        }
      )
    end

    test "ordered" do
      assert_parse_markdown(
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
                  nodes: [
                    %MDEx.Paragraph{
                      nodes: [%MDEx.Text{literal: "foo", sourcepos: %MDEx.Sourcepos{start: {1, 3}, end: {1, 5}}}],
                      sourcepos: %MDEx.Sourcepos{start: {1, 3}, end: {1, 5}}
                    }
                  ],
                  list_type: :bullet,
                  marker_offset: 0,
                  padding: 2,
                  start: 1,
                  delimiter: :period,
                  bullet_char: "-",
                  tight: false,
                  sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 5}}
                },
                %MDEx.ListItem{
                  nodes: [
                    %MDEx.Paragraph{
                      nodes: [%MDEx.Text{literal: "bar", sourcepos: %MDEx.Sourcepos{start: {2, 3}, end: {2, 5}}}],
                      sourcepos: %MDEx.Sourcepos{start: {2, 3}, end: {2, 5}}
                    }
                  ],
                  list_type: :bullet,
                  marker_offset: 0,
                  padding: 2,
                  start: 1,
                  delimiter: :period,
                  bullet_char: "-",
                  tight: false,
                  sourcepos: %MDEx.Sourcepos{start: {2, 1}, end: {2, 5}}
                },
                %MDEx.ListItem{
                  nodes: [
                    %MDEx.Paragraph{
                      nodes: [%MDEx.Text{literal: "baz", sourcepos: %MDEx.Sourcepos{start: {3, 3}, end: {3, 5}}}],
                      sourcepos: %MDEx.Sourcepos{start: {3, 3}, end: {3, 5}}
                    }
                  ],
                  list_type: :bullet,
                  marker_offset: 0,
                  padding: 2,
                  start: 1,
                  delimiter: :period,
                  bullet_char: "-",
                  tight: false,
                  sourcepos: %MDEx.Sourcepos{start: {3, 1}, end: {3, 5}}
                }
              ],
              list_type: :bullet,
              marker_offset: 0,
              padding: 2,
              start: 1,
              delimiter: :period,
              bullet_char: "-",
              tight: true,
              sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {3, 5}}
            }
          ]
        }
      )
    end
  end

  test "description list" do
    assert_parse_markdown(
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
                  %MDEx.DescriptionTerm{
                    nodes: [
                      %MDEx.Paragraph{
                        nodes: [%MDEx.Text{literal: "MDEx", sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 4}}}],
                        sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 4}}
                      }
                    ],
                    sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 4}}
                  },
                  %MDEx.DescriptionDetails{
                    nodes: [
                      %MDEx.Paragraph{
                        nodes: [%MDEx.Text{literal: "Built with Elixir and Rust", sourcepos: %MDEx.Sourcepos{start: {3, 3}, end: {3, 28}}}],
                        sourcepos: %MDEx.Sourcepos{start: {3, 3}, end: {3, 28}}
                      }
                    ],
                    sourcepos: %MDEx.Sourcepos{start: {3, 1}, end: {3, 28}}
                  }
                ],
                marker_offset: 0,
                padding: 2,
                sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {3, 28}}
              }
            ],
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {3, 28}}
          }
        ]
      }
    )
  end

  test "code block" do
    assert_parse_markdown(
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
            literal: "String.trim(\" MDEx \")\n",
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {3, 3}}
          }
        ]
      }
    )
  end

  test "html block" do
    assert_parse_markdown(
      """
      <h1>MDEx</h1>
      """,
      %MDEx.Document{
        nodes: [%MDEx.HtmlBlock{nodes: [], block_type: 6, literal: "<h1>MDEx</h1>\n", sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 13}}}]
      }
    )
  end

  test "heading" do
    assert_parse_markdown(
      """
      # level_1
      ###### level_6
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.Heading{
            nodes: [%MDEx.Text{literal: "level_1", sourcepos: %MDEx.Sourcepos{start: {1, 3}, end: {1, 9}}}],
            level: 1,
            setext: false,
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 9}}
          },
          %MDEx.Heading{
            nodes: [%MDEx.Text{literal: "level_6", sourcepos: %MDEx.Sourcepos{start: {2, 8}, end: {2, 14}}}],
            level: 6,
            setext: false,
            sourcepos: %MDEx.Sourcepos{start: {2, 1}, end: {2, 14}}
          }
        ]
      }
    )
  end

  test "thematic break" do
    assert_parse_markdown(
      """
      ***
      ---
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.ThematicBreak{sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 3}}},
          %MDEx.ThematicBreak{sourcepos: %MDEx.Sourcepos{start: {2, 1}, end: {2, 3}}}
        ]
      }
    )
  end

  test "footnote" do
    assert_parse_markdown(
      """
      footnote[^1]

      [^1]: ref
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [
              %MDEx.Text{literal: "footnote", sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 8}}},
              %MDEx.FootnoteReference{
                name: "1",
                ref_num: 1,
                ix: 1,
                texts: [{"^", 1}, {"1", 1}],
                sourcepos: %MDEx.Sourcepos{start: {1, 9}, end: {1, 12}}
              }
            ],
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 12}}
          },
          %MDEx.FootnoteDefinition{
            nodes: [
              %MDEx.Paragraph{
                nodes: [%MDEx.Text{literal: "ref", sourcepos: %MDEx.Sourcepos{start: {3, 7}, end: {3, 9}}}],
                sourcepos: %MDEx.Sourcepos{start: {3, 7}, end: {3, 9}}
              }
            ],
            name: "1",
            total_references: 1,
            sourcepos: %MDEx.Sourcepos{start: {3, 1}, end: {3, 9}}
          }
        ]
      }
    )
  end

  test "inline footnote" do
    assert_parse_markdown(
      """
      footnote^[inline content]
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [
              %MDEx.Text{literal: "footnote", sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 8}}},
              %MDEx.FootnoteReference{name: "__inline_1", ref_num: 1, ix: 1, texts: [], sourcepos: %MDEx.Sourcepos{start: {1, 9}, end: {1, 25}}}
            ],
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 25}}
          },
          %MDEx.FootnoteDefinition{
            nodes: [
              %MDEx.Paragraph{
                nodes: [%MDEx.Text{literal: "inline content", sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 14}}}],
                sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 0}}
              }
            ],
            name: "__inline_1",
            total_references: 1,
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 0}}
          }
        ]
      },
      extension: [inline_footnotes: true]
    )
  end

  test "table" do
    assert_parse_markdown(
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
                nodes: [
                  %MDEx.TableCell{
                    nodes: [%MDEx.Text{literal: "foo", sourcepos: %MDEx.Sourcepos{start: {1, 3}, end: {1, 5}}}],
                    sourcepos: %MDEx.Sourcepos{start: {1, 2}, end: {1, 6}}
                  },
                  %MDEx.TableCell{
                    nodes: [%MDEx.Text{literal: "bar", sourcepos: %MDEx.Sourcepos{start: {1, 9}, end: {1, 11}}}],
                    sourcepos: %MDEx.Sourcepos{start: {1, 8}, end: {1, 12}}
                  }
                ],
                header: true,
                sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 13}}
              },
              %MDEx.TableRow{
                nodes: [
                  %MDEx.TableCell{
                    nodes: [%MDEx.Text{literal: "baz", sourcepos: %MDEx.Sourcepos{start: {3, 3}, end: {3, 5}}}],
                    sourcepos: %MDEx.Sourcepos{start: {3, 2}, end: {3, 6}}
                  },
                  %MDEx.TableCell{
                    nodes: [%MDEx.Text{literal: "bim", sourcepos: %MDEx.Sourcepos{start: {3, 9}, end: {3, 11}}}],
                    sourcepos: %MDEx.Sourcepos{start: {3, 8}, end: {3, 12}}
                  }
                ],
                header: false,
                sourcepos: %MDEx.Sourcepos{start: {3, 1}, end: {3, 13}}
              }
            ],
            alignments: [:none, :none],
            num_columns: 2,
            num_rows: 2,
            num_nonempty_cells: 4,
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {3, 13}}
          }
        ]
      }
    )

    assert_parse_markdown(
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
                nodes: [
                  %MDEx.TableCell{
                    nodes: [%MDEx.Text{literal: "abc", sourcepos: %MDEx.Sourcepos{start: {1, 3}, end: {1, 5}}}],
                    sourcepos: %MDEx.Sourcepos{start: {1, 2}, end: {1, 6}}
                  },
                  %MDEx.TableCell{
                    nodes: [%MDEx.Text{literal: "defghi", sourcepos: %MDEx.Sourcepos{start: {1, 9}, end: {1, 14}}}],
                    sourcepos: %MDEx.Sourcepos{start: {1, 8}, end: {1, 15}}
                  }
                ],
                header: true,
                sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 16}}
              },
              %MDEx.TableRow{
                nodes: [
                  %MDEx.TableCell{
                    nodes: [%MDEx.Text{literal: "bar", sourcepos: %MDEx.Sourcepos{start: {3, 1}, end: {3, 3}}}],
                    sourcepos: %MDEx.Sourcepos{start: {3, 1}, end: {3, 4}}
                  },
                  %MDEx.TableCell{
                    nodes: [%MDEx.Text{literal: "baz", sourcepos: %MDEx.Sourcepos{start: {3, 7}, end: {3, 9}}}],
                    sourcepos: %MDEx.Sourcepos{start: {3, 6}, end: {3, 9}}
                  }
                ],
                header: false,
                sourcepos: %MDEx.Sourcepos{start: {3, 1}, end: {3, 9}}
              }
            ],
            alignments: [:center, :right],
            num_columns: 2,
            num_rows: 2,
            num_nonempty_cells: 4,
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {3, 9}}
          }
        ]
      }
    )
  end

  test "task item" do
    assert_parse_markdown(
      """
      * [x] Done
      * [ ] Not done
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.List{
            nodes: [
              %MDEx.TaskItem{
                nodes: [
                  %MDEx.Paragraph{
                    nodes: [%MDEx.Text{literal: "Done", sourcepos: %MDEx.Sourcepos{start: {1, 7}, end: {1, 10}}}],
                    sourcepos: %MDEx.Sourcepos{start: {1, 7}, end: {1, 10}}
                  }
                ],
                checked: true,
                marker: "x",
                sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 10}}
              },
              %MDEx.TaskItem{
                nodes: [
                  %MDEx.Paragraph{
                    nodes: [%MDEx.Text{literal: "Not done", sourcepos: %MDEx.Sourcepos{start: {2, 7}, end: {2, 14}}}],
                    sourcepos: %MDEx.Sourcepos{start: {2, 7}, end: {2, 14}}
                  }
                ],
                checked: false,
                marker: "",
                sourcepos: %MDEx.Sourcepos{start: {2, 1}, end: {2, 14}}
              }
            ],
            list_type: :bullet,
            marker_offset: 0,
            padding: 2,
            start: 1,
            delimiter: :period,
            bullet_char: "*",
            tight: true,
            is_task_list: true,
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {2, 14}}
          }
        ]
      }
    )
  end

  test "breaks" do
    assert_parse_markdown(
      """
      foo
      bar
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [
              %MDEx.Text{literal: "foo", sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 3}}},
              %MDEx.SoftBreak{sourcepos: %MDEx.Sourcepos{start: {1, 4}, end: {1, 4}}},
              %MDEx.Text{literal: "bar", sourcepos: %MDEx.Sourcepos{start: {2, 1}, end: {2, 3}}}
            ],
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {2, 3}}
          }
        ]
      }
    )

    assert_parse_markdown(
      """
      foo
      bar
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [
              %MDEx.Text{literal: "foo", sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 3}}},
              %MDEx.SoftBreak{sourcepos: %MDEx.Sourcepos{start: {1, 4}, end: {1, 4}}},
              %MDEx.Text{literal: "bar", sourcepos: %MDEx.Sourcepos{start: {2, 1}, end: {2, 3}}}
            ],
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {2, 3}}
          }
        ]
      },
      render: [hardbreaks: true]
    )
  end

  test "code" do
    assert_parse_markdown(
      """
      `String.trim(" MDEx ")`
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [%MDEx.Code{num_backticks: 1, literal: "String.trim(\" MDEx \")", sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 23}}}],
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 23}}
          }
        ]
      }
    )
  end

  test "html inline" do
    assert_parse_markdown(
      """
      <a><bab><c2c>
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [
              %MDEx.HtmlInline{literal: "<a>", sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 3}}},
              %MDEx.HtmlInline{literal: "<bab>", sourcepos: %MDEx.Sourcepos{start: {1, 4}, end: {1, 8}}},
              %MDEx.HtmlInline{literal: "<c2c>", sourcepos: %MDEx.Sourcepos{start: {1, 9}, end: {1, 13}}}
            ],
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 13}}
          }
        ]
      }
    )
  end

  test "emph, strong, strikethrough, superscript" do
    assert_parse_markdown(
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
              %MDEx.Emph{
                nodes: [%MDEx.Text{literal: "emph", sourcepos: %MDEx.Sourcepos{start: {1, 2}, end: {1, 5}}}],
                sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 6}}
              },
              %MDEx.SoftBreak{sourcepos: %MDEx.Sourcepos{start: {1, 7}, end: {1, 7}}},
              %MDEx.Strong{
                nodes: [%MDEx.Text{literal: "strong", sourcepos: %MDEx.Sourcepos{start: {2, 3}, end: {2, 8}}}],
                sourcepos: %MDEx.Sourcepos{start: {2, 1}, end: {2, 10}}
              },
              %MDEx.SoftBreak{sourcepos: %MDEx.Sourcepos{start: {2, 11}, end: {2, 11}}},
              %MDEx.Strikethrough{
                nodes: [%MDEx.Text{literal: "strikethrough", sourcepos: %MDEx.Sourcepos{start: {3, 2}, end: {3, 14}}}],
                sourcepos: %MDEx.Sourcepos{start: {3, 1}, end: {3, 15}}
              },
              %MDEx.SoftBreak{sourcepos: %MDEx.Sourcepos{start: {3, 16}, end: {3, 16}}},
              %MDEx.Text{literal: "X", sourcepos: %MDEx.Sourcepos{start: {4, 1}, end: {4, 1}}},
              %MDEx.Superscript{
                nodes: [%MDEx.Text{literal: "2", sourcepos: %MDEx.Sourcepos{start: {4, 3}, end: {4, 3}}}],
                sourcepos: %MDEx.Sourcepos{start: {4, 2}, end: {4, 4}}
              }
            ],
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {4, 4}}
          }
        ]
      }
    )
  end

  test "link" do
    assert_parse_markdown(
      """
      [foo]: /url "title"

      [foo]
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [
              %MDEx.Link{
                nodes: [%MDEx.Text{literal: "foo", sourcepos: %MDEx.Sourcepos{start: {3, 2}, end: {3, 4}}}],
                title: "title",
                url: "/url",
                sourcepos: %MDEx.Sourcepos{start: {3, 1}, end: {3, 5}}
              }
            ],
            sourcepos: %MDEx.Sourcepos{start: {3, 1}, end: {3, 5}}
          }
        ]
      }
    )
  end

  test "image" do
    assert_parse_markdown(
      """
      ![foo](/url "title")
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [
              %MDEx.Image{
                nodes: [%MDEx.Text{literal: "foo", sourcepos: %MDEx.Sourcepos{start: {1, 3}, end: {1, 5}}}],
                title: "title",
                url: "/url",
                sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 20}}
              }
            ],
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 20}}
          }
        ]
      }
    )
  end

  test "shortcode" do
    assert_parse_markdown(
      """
      :smile:
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [%MDEx.ShortCode{code: "smile", emoji: "😄", sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 7}}}],
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 7}}
          }
        ]
      }
    )
  end

  test "math" do
    assert_parse_markdown(
      """
      $1 + 2$ and $$x = y$$

      $`1 + 2`$
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [
              %MDEx.Math{dollar_math: true, display_math: false, literal: "1 + 2", sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 7}}},
              %MDEx.Text{literal: " and ", sourcepos: %MDEx.Sourcepos{start: {1, 8}, end: {1, 12}}},
              %MDEx.Math{dollar_math: true, display_math: true, literal: "x = y", sourcepos: %MDEx.Sourcepos{start: {1, 13}, end: {1, 21}}}
            ],
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 21}}
          },
          %MDEx.Paragraph{
            nodes: [%MDEx.Math{dollar_math: false, display_math: false, literal: "1 + 2", sourcepos: %MDEx.Sourcepos{start: {3, 1}, end: {3, 9}}}],
            sourcepos: %MDEx.Sourcepos{start: {3, 1}, end: {3, 9}}
          }
        ]
      }
    )
  end

  test "multiline block quote" do
    assert_parse_markdown(
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
              %MDEx.Paragraph{
                nodes: [%MDEx.Text{literal: "A paragraph.", sourcepos: %MDEx.Sourcepos{start: {2, 1}, end: {2, 12}}}],
                sourcepos: %MDEx.Sourcepos{start: {2, 1}, end: {2, 12}}
              },
              %MDEx.List{
                nodes: [
                  %MDEx.ListItem{
                    nodes: [
                      %MDEx.Paragraph{
                        nodes: [%MDEx.Text{literal: "item one", sourcepos: %MDEx.Sourcepos{start: {4, 3}, end: {4, 10}}}],
                        sourcepos: %MDEx.Sourcepos{start: {4, 3}, end: {4, 10}}
                      }
                    ],
                    list_type: :bullet,
                    marker_offset: 0,
                    padding: 2,
                    start: 1,
                    delimiter: :period,
                    bullet_char: "-",
                    tight: false,
                    sourcepos: %MDEx.Sourcepos{start: {4, 1}, end: {4, 10}}
                  },
                  %MDEx.ListItem{
                    nodes: [
                      %MDEx.Paragraph{
                        nodes: [%MDEx.Text{literal: "item two", sourcepos: %MDEx.Sourcepos{start: {5, 3}, end: {5, 10}}}],
                        sourcepos: %MDEx.Sourcepos{start: {5, 3}, end: {5, 3}}
                      }
                    ],
                    list_type: :bullet,
                    marker_offset: 0,
                    padding: 2,
                    start: 1,
                    delimiter: :period,
                    bullet_char: "-",
                    tight: false,
                    sourcepos: %MDEx.Sourcepos{start: {5, 1}, end: {5, 3}}
                  }
                ],
                list_type: :bullet,
                marker_offset: 0,
                padding: 2,
                start: 1,
                delimiter: :period,
                bullet_char: "-",
                tight: true,
                sourcepos: %MDEx.Sourcepos{start: {4, 1}, end: {5, 10}}
              }
            ],
            fence_length: 3,
            fence_offset: 0,
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {6, 3}}
          }
        ]
      }
    )
  end

  describe "wiki links" do
    test "title before pipe" do
      assert_parse_markdown(
        """
        [[repo|https://github.com/leandrocp/mdex]]
        """,
        %MDEx.Document{
          nodes: [
            %MDEx.Paragraph{
              nodes: [
                %MDEx.WikiLink{
                  nodes: [%MDEx.Text{literal: "repo", sourcepos: %MDEx.Sourcepos{start: {1, 3}, end: {1, 6}}}],
                  url: "https://github.com/leandrocp/mdex",
                  sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 42}}
                }
              ],
              sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 42}}
            }
          ]
        },
        extension: [wikilinks_title_before_pipe: true]
      )
    end

    test "title after pipe" do
      assert_parse_markdown(
        """
        [[https://github.com/leandrocp/mdex|repo]]
        """,
        %MDEx.Document{
          nodes: [
            %MDEx.Paragraph{
              nodes: [
                %MDEx.WikiLink{
                  nodes: [%MDEx.Text{literal: "repo", sourcepos: %MDEx.Sourcepos{start: {1, 37}, end: {1, 40}}}],
                  url: "https://github.com/leandrocp/mdex",
                  sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 42}}
                }
              ],
              sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 42}}
            }
          ]
        },
        extension: [wikilinks_title_after_pipe: true]
      )
    end
  end

  test "spoiler" do
    assert_parse_markdown(
      """
      Darth Vader is ||Luke's father||
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [
              %MDEx.Text{literal: "Darth Vader is ", sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 15}}},
              %MDEx.SpoileredText{
                nodes: [%MDEx.Text{literal: "Luke's father", sourcepos: %MDEx.Sourcepos{start: {1, 18}, end: {1, 30}}}],
                sourcepos: %MDEx.Sourcepos{start: {1, 16}, end: {1, 32}}
              }
            ],
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 32}}
          }
        ]
      }
    )
  end

  test "insert" do
    assert_parse_markdown(
      """
      this is ++inserted++ text
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [
              %MDEx.Text{literal: "this is ", sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 8}}},
              %MDEx.Insert{
                nodes: [%MDEx.Text{literal: "inserted", sourcepos: %MDEx.Sourcepos{start: {1, 11}, end: {1, 18}}}],
                sourcepos: %MDEx.Sourcepos{start: {1, 9}, end: {1, 20}}
              },
              %MDEx.Text{literal: " text", sourcepos: %MDEx.Sourcepos{start: {1, 21}, end: {1, 25}}}
            ],
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 25}}
          }
        ]
      }
    )
  end

  test "highlight" do
    assert_parse_markdown(
      """
      this is ==marked== text
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [
              %MDEx.Text{literal: "this is ", sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 8}}},
              %MDEx.Highlight{
                nodes: [%MDEx.Text{literal: "marked", sourcepos: %MDEx.Sourcepos{start: {1, 11}, end: {1, 16}}}],
                sourcepos: %MDEx.Sourcepos{start: {1, 9}, end: {1, 18}}
              },
              %MDEx.Text{literal: " text", sourcepos: %MDEx.Sourcepos{start: {1, 19}, end: {1, 23}}}
            ],
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 23}}
          }
        ]
      },
      extension: [highlight: true]
    )
  end

  test "subtext" do
    assert_parse_markdown(
      "-# Some Subtext\n",
      %MDEx.Document{
        nodes: [
          %MDEx.Subtext{
            nodes: [%MDEx.Text{literal: "Some Subtext", sourcepos: %MDEx.Sourcepos{start: {1, 4}, end: {1, 15}}}],
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 15}}
          }
        ]
      },
      extension: [subtext: true]
    )
  end

  test "greentext" do
    assert_parse_markdown(
      """
      > one
      > > two
      > three
      """,
      %MDEx.Document{
        nodes: [
          %MDEx.BlockQuote{
            nodes: [
              %MDEx.Paragraph{
                nodes: [%MDEx.Text{literal: "one", sourcepos: %MDEx.Sourcepos{start: {1, 3}, end: {1, 5}}}],
                sourcepos: %MDEx.Sourcepos{start: {1, 3}, end: {1, 5}}
              },
              %MDEx.BlockQuote{
                nodes: [
                  %MDEx.Paragraph{
                    nodes: [%MDEx.Text{literal: "two", sourcepos: %MDEx.Sourcepos{start: {2, 5}, end: {2, 7}}}],
                    sourcepos: %MDEx.Sourcepos{start: {2, 5}, end: {2, 7}}
                  }
                ],
                sourcepos: %MDEx.Sourcepos{start: {2, 3}, end: {2, 7}}
              },
              %MDEx.Paragraph{
                nodes: [%MDEx.Text{literal: "three", sourcepos: %MDEx.Sourcepos{start: {3, 3}, end: {3, 7}}}],
                sourcepos: %MDEx.Sourcepos{start: {3, 3}, end: {3, 7}}
              }
            ],
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {3, 7}}
          }
        ]
      }
    )
  end

  test "subscript" do
    assert_parse_markdown(
      "H~2~O",
      %MDEx.Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [
              %MDEx.Text{literal: "H", sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 1}}},
              %MDEx.Subscript{
                nodes: [%MDEx.Text{literal: "2", sourcepos: %MDEx.Sourcepos{start: {1, 3}, end: {1, 3}}}],
                sourcepos: %MDEx.Sourcepos{start: {1, 2}, end: {1, 4}}
              },
              %MDEx.Text{literal: "O", sourcepos: %MDEx.Sourcepos{start: {1, 5}, end: {1, 5}}}
            ],
            sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 5}}
          }
        ]
      },
      extension: [subscript: true]
    )
  end

  describe "sourcepos" do
    test "text" do
      assert {:ok, document} = MDEx.parse_document("hello world\n")

      assert [
               %MDEx.Paragraph{
                 sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 11}},
                 nodes: [
                   %MDEx.Text{
                     literal: "hello world",
                     sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 11}}
                   }
                 ]
               }
             ] = document.nodes
    end

    test "heading and paragraph" do
      assert {:ok, document} = MDEx.parse_document("# Hello\nworld\n")

      assert [
               %MDEx.Heading{
                 nodes: [
                   %MDEx.Text{
                     literal: "Hello",
                     sourcepos: %MDEx.Sourcepos{start: {1, 3}, end: {1, 7}}
                   }
                 ],
                 level: 1,
                 setext: false,
                 closed: false,
                 sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 7}}
               },
               %MDEx.Paragraph{
                 nodes: [
                   %MDEx.Text{
                     literal: "world",
                     sourcepos: %MDEx.Sourcepos{start: {2, 1}, end: {2, 5}}
                   }
                 ],
                 sourcepos: %MDEx.Sourcepos{start: {2, 1}, end: {2, 5}}
               }
             ] = document.nodes
    end

    test "nested nodes have sourcepos" do
      assert {:ok, document} = MDEx.parse_document("**bold**\n")

      assert [
               %MDEx.Paragraph{
                 sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 8}},
                 nodes: [
                   %MDEx.Strong{
                     sourcepos: %MDEx.Sourcepos{start: {1, 1}, end: {1, 8}},
                     nodes: [
                       %MDEx.Text{
                         literal: "bold",
                         sourcepos: %MDEx.Sourcepos{start: {1, 3}, end: {1, 6}}
                       }
                     ]
                   }
                 ]
               }
             ] = document.nodes
    end

    test "document root" do
      assert {:ok, document} = MDEx.parse_document("hello\n")
      assert %MDEx.Sourcepos{start: {0, 0}, end: {0, 0}} = document.sourcepos
    end
  end
end
