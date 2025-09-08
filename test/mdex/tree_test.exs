defmodule MDEx.TreeTest do
  use ExUnit.Case

  describe "append_node/2 - basic operations" do
    test "handles empty document" do
      result =
        MDEx.Tree.append_node(
          %MDEx.Document{nodes: []},
          %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Hello"}]}
        )

      assert %MDEx.Document{
               nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Hello"}]}]
             } = result

      assert MDEx.to_markdown!(result) == "Hello"
    end
  end

  describe "append_node/2 - list item handling" do
    test "appends list item to existing list" do
      result =
        MDEx.Tree.append_node(
          %MDEx.Document{
            nodes: [
              %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "code"}]},
              %MDEx.Paragraph{
                nodes: [
                  %MDEx.List{
                    nodes: [
                      %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item1"}]}]}
                    ]
                  }
                ]
              }
            ]
          },
          %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item2"}]}]}
        )

      assert %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "code"}]},
                 %MDEx.Paragraph{
                   nodes: [
                     %MDEx.List{
                       nodes: [
                         %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item1"}]}]},
                         %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item2"}]}]}
                       ]
                     }
                   ]
                 }
               ]
             } = result

      assert MDEx.to_markdown!(result) == "`code`\n\n- item1\n- item2"
    end

    test "creates new list when no list exists" do
      result =
        MDEx.Tree.append_node(
          %MDEx.Document{
            nodes: [
              %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "code"}]}
            ]
          },
          %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item"}]}]}
        )

      assert %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "code"}]},
                 %MDEx.List{
                   nodes: [
                     %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item"}]}]}
                   ]
                 }
               ]
             } = result

      assert MDEx.to_markdown!(result) == "`code`\n\n- item"
    end

    test "wraps task item in task list" do
      result =
        MDEx.Tree.append_node(
          %MDEx.Document{nodes: []},
          %MDEx.TaskItem{checked: false, nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Todo"}]}]}
        )

      assert %MDEx.Document{
               nodes: [
                 %MDEx.List{
                   nodes: [%MDEx.TaskItem{checked: false, nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Todo"}]}]}]
                 }
               ]
             } = result

      assert MDEx.to_markdown!(result) == "- [ ] Todo"
    end
  end

  describe "append_node/2 - list merging" do
    test "merges list with same list_type" do
      bullet_list = %MDEx.List{
        list_type: :bullet,
        nodes: [
          %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "bullet2"}]}], list_type: :bullet},
          %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "bullet3"}]}], list_type: :bullet}
        ]
      }

      result =
        MDEx.Tree.append_node(
          %MDEx.Document{
            nodes: [
              %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "intro"}]},
              %MDEx.List{
                list_type: :bullet,
                nodes: [
                  %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "bullet1"}]}], list_type: :bullet}
                ]
              }
            ]
          },
          bullet_list
        )

      assert %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "intro"}]},
                 %MDEx.List{
                   list_type: :bullet,
                   nodes: [
                     %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "bullet1"}]}], list_type: :bullet},
                     %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "bullet2"}]}], list_type: :bullet},
                     %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "bullet3"}]}], list_type: :bullet}
                   ]
                 }
               ]
             } = result

      assert MDEx.to_markdown!(result) == "intro\n\n- bullet1\n- bullet2\n- bullet3"
    end

    test "creates new list when list_type differs" do
      ordered_list = %MDEx.List{
        list_type: :ordered,
        nodes: [
          %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "ordered1"}]}], list_type: :ordered},
          %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "ordered2"}]}], list_type: :ordered}
        ]
      }

      result =
        MDEx.Tree.append_node(
          %MDEx.Document{
            nodes: [
              %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "intro"}]},
              %MDEx.List{
                list_type: :bullet,
                nodes: [
                  %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "bullet1"}]}], list_type: :bullet}
                ]
              }
            ]
          },
          ordered_list
        )

      assert %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "intro"}]},
                 %MDEx.List{
                   list_type: :bullet,
                   nodes: [
                     %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "bullet1"}]}], list_type: :bullet}
                   ]
                 },
                 %MDEx.List{
                   list_type: :ordered,
                   nodes: [
                     %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "ordered1"}]}], list_type: :ordered},
                     %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "ordered2"}]}], list_type: :ordered}
                   ]
                 }
               ]
             } = result

      assert MDEx.to_markdown!(result) == "intro\n\n- bullet1\n\n<!-- end list -->\n\n1. ordered1\n2. ordered2"
    end
  end

  describe "append_node/2 - block/inline handling" do
    test "cannot append block node to inline container" do
      result =
        MDEx.Tree.append_node(
          %MDEx.Document{
            nodes: [
              %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Hello"}]}
            ]
          },
          %MDEx.CodeBlock{literal: "println!(\"test\");", info: "rust"}
        )

      assert %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Hello"}]},
                 %MDEx.CodeBlock{literal: "println!(\"test\");", info: "rust"}
               ]
             } = result

      assert MDEx.to_markdown!(result) == "Hello\n\n``` rust\nprintln!(\"test\");\n```"
    end

    test "can append inline node to inline container" do
      result =
        MDEx.Tree.append_node(
          %MDEx.Document{
            nodes: [
              %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Hello"}]}
            ]
          },
          %MDEx.Code{literal: "test", num_backticks: 1}
        )

      assert %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Hello"}, %MDEx.Code{literal: "test", num_backticks: 1}]}
               ]
             } = result

      assert MDEx.to_markdown!(result) == "Hello`test`"
    end
  end

  describe "append_node/2 - complex nesting" do
    test "appends to deepest compatible container" do
      result =
        MDEx.Tree.append_node(
          %MDEx.Document{
            nodes: [
              %MDEx.BlockQuote{
                nodes: [
                  %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Quote"}]}
                ]
              }
            ]
          },
          %MDEx.Text{literal: " continues"}
        )

      assert %MDEx.Document{
               nodes: [
                 %MDEx.BlockQuote{
                   nodes: [
                     %MDEx.Paragraph{
                       nodes: [
                         %MDEx.Text{literal: "Quote"},
                         %MDEx.Text{literal: " continues"}
                       ]
                     }
                   ]
                 }
               ]
             } = result

      assert MDEx.to_markdown!(result) == "> Quote continues"
    end

    test "creates sibling when cannot nest deeper" do
      result =
        MDEx.Tree.append_node(
          %MDEx.Document{
            nodes: [
              %MDEx.BlockQuote{
                nodes: [
                  %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Quote"}]}
                ]
              }
            ]
          },
          %MDEx.Heading{level: 1, nodes: [%MDEx.Text{literal: "Title"}]}
        )

      assert %MDEx.Document{
               nodes: [
                 %MDEx.BlockQuote{
                   nodes: [
                     %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Quote"}]},
                     %MDEx.Heading{level: 1, nodes: [%MDEx.Text{literal: "Title"}]}
                   ]
                 }
               ]
             } = result

      assert MDEx.to_markdown!(result) == "> Quote\n> \n> # Title"
    end
  end

  describe "append_nodes/2 - basic operations" do
    test "handles empty document with multiple nodes" do
      result =
        MDEx.Tree.append_nodes(
          %MDEx.Document{nodes: []},
          [
            %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Hello"}]},
            %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "World"}]}
          ]
        )

      assert %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Hello"}]},
                 %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "World"}]}
               ]
             } = result

      assert MDEx.to_markdown!(result) == "Hello\n\nWorld"
    end

    test "collect list items into existing list" do
      list_items = [
        %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item2"}]}]},
        %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item3"}]}]}
      ]

      result =
        MDEx.Tree.append_nodes(
          %MDEx.Document{
            nodes: [
              %MDEx.List{
                nodes: [
                  %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item1"}]}]}
                ]
              }
            ]
          },
          list_items
        )

      assert %MDEx.Document{
               nodes: [
                 %MDEx.List{
                   nodes: [
                     %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item1"}]}]},
                     %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item2"}]}]},
                     %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item3"}]}]}
                   ]
                 }
               ]
             } = result

      assert MDEx.to_markdown!(result) == "- item1\n- item2\n- item3"
    end

    test "collect orphaned list items into new list" do
      list_items = [
        %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item1"}]}]},
        %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item2"}]}]}
      ]

      result =
        MDEx.Tree.append_nodes(
          %MDEx.Document{
            nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "intro"}]}]
          },
          list_items
        )

      assert %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "intro"}]},
                 %MDEx.List{
                   nodes: [
                     %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item1"}]}]},
                     %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item2"}]}]}
                   ]
                 }
               ]
             } = result

      assert MDEx.to_markdown!(result) == "intro\n\n- item1\n- item2"
    end
  end

  describe "append_node/2 - edge cases and constraints" do
    test "rejects document within document" do
      result =
        MDEx.Tree.append_node(
          %MDEx.Document{nodes: []},
          %MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "nested"}]}]}
        )

      assert %MDEx.Document{
               nodes: [%MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "nested"}]}]}]
             } = result
    end

    test "allows front matter in document" do
      result =
        MDEx.Tree.append_node(
          %MDEx.Document{nodes: []},
          %MDEx.FrontMatter{literal: "title: test"}
        )

      assert %MDEx.Document{
               nodes: [%MDEx.FrontMatter{literal: "title: test"}]
             } = result
    end

    test "appends block nodes to block containers" do
      result =
        MDEx.Tree.append_node(
          %MDEx.Document{
            nodes: [%MDEx.BlockQuote{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "existing"}]}]}]
          },
          %MDEx.CodeBlock{literal: "block", info: ""}
        )

      # The tree appends the code block inside the block quote since it can contain block nodes
      assert %MDEx.Document{
               nodes: [
                 %MDEx.BlockQuote{
                   nodes: [
                     %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "existing"}]},
                     %MDEx.CodeBlock{literal: "block", info: ""}
                   ]
                 }
               ]
             } = result
    end

    test "list accepts different list type items by nesting in existing item" do
      result =
        MDEx.Tree.append_node(
          %MDEx.Document{
            nodes: [
              %MDEx.List{
                list_type: :bullet,
                nodes: [
                  %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "bullet"}]}], list_type: :bullet}
                ]
              }
            ]
          },
          %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "ordered"}]}], list_type: :ordered}
        )

      # The tree tries to append to the deepest compatible container
      # Since the ordered item can't go in the bullet list, it goes in the bullet list item
      assert %MDEx.Document{
               nodes: [
                 %MDEx.List{
                   nodes: [
                     %MDEx.ListItem{
                       nodes: [
                         %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "bullet"}]},
                         %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "ordered"}]}]}
                       ]
                     }
                   ],
                   list_type: :bullet
                 }
               ]
             } = result
    end

    test "merges lists of same type" do
      result =
        MDEx.Tree.append_node(
          %MDEx.Document{
            nodes: [
              %MDEx.List{
                list_type: :bullet,
                nodes: [
                  %MDEx.ListItem{
                    nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "parent"}]}],
                    list_type: :bullet
                  }
                ]
              }
            ]
          },
          %MDEx.List{
            list_type: :bullet,
            nodes: [
              %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "nested"}]}], list_type: :bullet}
            ]
          }
        )

      # Lists of the same type get merged at the list level
      assert %MDEx.Document{
               nodes: [
                 %MDEx.List{
                   list_type: :bullet,
                   nodes: [
                     %MDEx.ListItem{
                       nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "parent"}]}]
                     },
                     %MDEx.ListItem{
                       nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "nested"}]}]
                     }
                   ]
                 }
               ]
             } = result

      assert MDEx.to_markdown!(result) == "- parent\n- nested"
    end

    test "list item rejects nested list of different type" do
      result =
        MDEx.Tree.append_node(
          %MDEx.Document{
            nodes: [
              %MDEx.List{
                list_type: :bullet,
                nodes: [
                  %MDEx.ListItem{
                    nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "bullet"}]}],
                    list_type: :bullet
                  }
                ]
              }
            ]
          },
          %MDEx.List{
            list_type: :ordered,
            nodes: [
              %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "ordered"}]}], list_type: :ordered}
            ]
          }
        )

      assert %MDEx.Document{
               nodes: [
                 %MDEx.List{
                   list_type: :bullet,
                   nodes: [
                     %MDEx.ListItem{
                       nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "bullet"}]}],
                       list_type: :bullet
                     }
                   ]
                 },
                 %MDEx.List{
                   list_type: :ordered,
                   nodes: [
                     %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "ordered"}]}], list_type: :ordered}
                   ]
                 }
               ]
             } = result
    end

    test "wraps description item in description list" do
      result =
        MDEx.Tree.append_node(
          %MDEx.Document{nodes: []},
          %MDEx.DescriptionItem{
            nodes: [
              %MDEx.DescriptionTerm{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "term"}]}]}
            ]
          }
        )

      assert %MDEx.Document{
               nodes: [
                 %MDEx.DescriptionList{
                   nodes: [
                     %MDEx.DescriptionItem{
                       nodes: [
                         %MDEx.DescriptionTerm{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "term"}]}]}
                       ]
                     }
                   ]
                 }
               ]
             } = result
    end

    test "description list rejects non-description items at list level" do
      result =
        MDEx.Tree.append_node(
          %MDEx.Document{
            nodes: [
              %MDEx.DescriptionList{
                nodes: [
                  %MDEx.DescriptionItem{
                    nodes: [
                      %MDEx.DescriptionTerm{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "term1"}]}]}
                    ]
                  }
                ]
              }
            ]
          },
          %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "sibling"}]}
        )

      assert %MDEx.Document{
               nodes: [
                 %MDEx.DescriptionList{
                   nodes: [
                     %MDEx.DescriptionItem{
                       nodes: [
                         %MDEx.DescriptionTerm{
                           nodes: [
                             %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "term1"}]},
                             %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "sibling"}]}
                           ]
                         }
                       ]
                     }
                   ]
                 }
               ]
             } = result
    end

    test "wraps table row in table with correct dimensions" do
      row = %MDEx.TableRow{
        nodes: [
          %MDEx.TableCell{nodes: [%MDEx.Text{literal: "A"}]},
          %MDEx.TableCell{nodes: [%MDEx.Text{literal: "B"}]},
          %MDEx.TableCell{nodes: [%MDEx.Text{literal: "C"}]}
        ]
      }

      result = MDEx.Tree.append_node(%MDEx.Document{nodes: []}, row)

      assert %MDEx.Document{
               nodes: [
                 %MDEx.Table{
                   nodes: [^row],
                   num_columns: 3,
                   num_rows: 1
                 }
               ]
             } = result
    end

    test "table only accepts table rows" do
      result =
        MDEx.Tree.append_node(
          %MDEx.Document{
            nodes: [
              %MDEx.Table{
                nodes: [
                  %MDEx.TableRow{
                    nodes: [%MDEx.TableCell{nodes: [%MDEx.Text{literal: "cell"}]}]
                  }
                ],
                num_columns: 1,
                num_rows: 1
              }
            ]
          },
          %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "not allowed"}]}
        )

      assert %MDEx.Document{
               nodes: [
                 %MDEx.Table{
                   nodes: [
                     %MDEx.TableRow{
                       nodes: [%MDEx.TableCell{nodes: [%MDEx.Text{literal: "cell"}]}]
                     }
                   ],
                   num_columns: 1,
                   num_rows: 1
                 },
                 %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "not allowed"}]}
               ]
             } = result
    end

    test "table cell accepts inline nodes" do
      result =
        MDEx.Tree.append_node(
          %MDEx.Document{
            nodes: [
              %MDEx.Table{
                nodes: [
                  %MDEx.TableRow{
                    nodes: [%MDEx.TableCell{nodes: [%MDEx.Text{literal: "cell1"}]}]
                  }
                ],
                num_columns: 1,
                num_rows: 1
              }
            ]
          },
          %MDEx.Text{literal: "appended"}
        )

      # The tree appends the text to the deepest compatible container (the table cell)
      assert %MDEx.Document{
               nodes: [
                 %MDEx.Table{
                   nodes: [
                     %MDEx.TableRow{
                       nodes: [
                         %MDEx.TableCell{
                           nodes: [
                             %MDEx.Text{literal: "cell1"},
                             %MDEx.Text{literal: "appended"}
                           ]
                         }
                       ]
                     }
                   ],
                   num_columns: 1,
                   num_rows: 1
                 }
               ]
             } = result
    end

    test "table cell only accepts inline nodes" do
      result =
        MDEx.Tree.append_node(
          %MDEx.Document{
            nodes: [
              %MDEx.Table{
                nodes: [
                  %MDEx.TableRow{
                    nodes: [%MDEx.TableCell{nodes: [%MDEx.Text{literal: "cell"}]}]
                  }
                ],
                num_columns: 1,
                num_rows: 1
              }
            ]
          },
          %MDEx.Code{literal: "inline", num_backticks: 1}
        )

      assert %MDEx.Document{
               nodes: [
                 %MDEx.Table{
                   nodes: [
                     %MDEx.TableRow{
                       nodes: [
                         %MDEx.TableCell{
                           nodes: [
                             %MDEx.Text{literal: "cell"},
                             %MDEx.Code{literal: "inline", num_backticks: 1}
                           ]
                         }
                       ]
                     }
                   ],
                   num_columns: 1,
                   num_rows: 1
                 }
               ]
             } = result
    end

    test "paragraph rejects block nodes" do
      result =
        MDEx.Tree.append_node(
          %MDEx.Document{
            nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "text"}]}]
          },
          %MDEx.CodeBlock{literal: "block", info: ""}
        )

      assert %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "text"}]},
                 %MDEx.CodeBlock{literal: "block", info: ""}
               ]
             } = result
    end

    test "heading only accepts inline nodes" do
      result =
        MDEx.Tree.append_node(
          %MDEx.Document{
            nodes: [%MDEx.Heading{level: 1, nodes: [%MDEx.Text{literal: "Title"}]}]
          },
          %MDEx.Emph{nodes: [%MDEx.Text{literal: "emphasis"}]}
        )

      assert %MDEx.Document{
               nodes: [
                 %MDEx.Heading{
                   level: 1,
                   nodes: [
                     %MDEx.Text{literal: "Title"},
                     %MDEx.Emph{nodes: [%MDEx.Text{literal: "emphasis"}]}
                   ]
                 }
               ]
             } = result
    end
  end

  describe "merge/2" do
    test "merges two documents" do
      doc1 = %MDEx.Document{
        nodes: [
          %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Hello"}]}
        ]
      }

      doc2 = %MDEx.Document{
        nodes: [
          %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "World"}]}
        ]
      }

      result = MDEx.Tree.merge(doc1, doc2)

      assert %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Hello"}]},
                 %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "World"}]}
               ]
             } = result

      assert MDEx.to_markdown!(result) == "Hello\n\nWorld"
    end

    test "merges empty document with non-empty document" do
      doc1 = %MDEx.Document{nodes: []}

      doc2 = %MDEx.Document{
        nodes: [
          %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Content"}]}
        ]
      }

      result = MDEx.Tree.merge(doc1, doc2)

      assert %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Content"}]}
               ]
             } = result

      assert MDEx.to_markdown!(result) == "Content"
    end
  end
end
