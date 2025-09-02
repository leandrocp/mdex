defmodule MDEx.TreeTest do
  use ExUnit.Case

  describe "can_contain?/2 - document containment" do
    test "document can contain block nodes" do
      assert MDEx.Tree.can_contain?(%MDEx.Document{}, %MDEx.Paragraph{})
      assert MDEx.Tree.can_contain?(%MDEx.Document{}, %MDEx.FrontMatter{})
      refute MDEx.Tree.can_contain?(%MDEx.Document{}, %MDEx.Text{})
      refute MDEx.Tree.can_contain?(%MDEx.Document{}, %MDEx.Document{})
    end
  end

  describe "can_contain?/2 - list containment" do
    test "list can only contain list items and task items" do
      assert MDEx.Tree.can_contain?(%MDEx.List{}, %MDEx.ListItem{})
      assert MDEx.Tree.can_contain?(%MDEx.List{}, %MDEx.TaskItem{})
      refute MDEx.Tree.can_contain?(%MDEx.List{}, %MDEx.Paragraph{})
    end
  end

  describe "can_contain?/2 - inline containment" do
    test "inline containers can contain inline nodes" do
      assert MDEx.Tree.can_contain?(%MDEx.Paragraph{}, %MDEx.Text{})
      assert MDEx.Tree.can_contain?(%MDEx.Paragraph{}, %MDEx.Code{})
      refute MDEx.Tree.can_contain?(%MDEx.Paragraph{}, %MDEx.CodeBlock{})
    end
  end

  describe "can_contain?/2 - table containment" do
    test "table containment is strict" do
      assert MDEx.Tree.can_contain?(%MDEx.Table{}, %MDEx.TableRow{})
      assert MDEx.Tree.can_contain?(%MDEx.TableRow{}, %MDEx.TableCell{})
      refute MDEx.Tree.can_contain?(%MDEx.Table{}, %MDEx.TableCell{})
    end

    test "table cells can contain inline nodes" do
      assert MDEx.Tree.can_contain?(%MDEx.TableCell{}, %MDEx.Text{literal: "cell text"})
      assert MDEx.Tree.can_contain?(%MDEx.TableCell{}, %MDEx.Code{literal: "code"})
      refute MDEx.Tree.can_contain?(%MDEx.TableCell{}, %MDEx.Paragraph{nodes: []})
    end
  end

  describe "can_contain?/2 - strict comrak compliance" do
    test "front matter can only be in document" do
      assert MDEx.Tree.can_contain?(%MDEx.Document{}, %MDEx.FrontMatter{})
      refute MDEx.Tree.can_contain?(%MDEx.Paragraph{}, %MDEx.FrontMatter{})
      refute MDEx.Tree.can_contain?(%MDEx.List{}, %MDEx.FrontMatter{})
    end

    test "inline containers cannot contain block nodes" do
      code_block = %MDEx.CodeBlock{literal: "test"}

      refute MDEx.Tree.can_contain?(%MDEx.Paragraph{}, code_block)
      refute MDEx.Tree.can_contain?(%MDEx.Emph{}, code_block)
      refute MDEx.Tree.can_contain?(%MDEx.Strong{}, code_block)
      refute MDEx.Tree.can_contain?(%MDEx.Link{}, code_block)
    end

    test "block containers can contain most block nodes but not list items" do
      paragraph = %MDEx.Paragraph{nodes: []}
      code_block = %MDEx.CodeBlock{literal: "test"}
      list_item = %MDEx.ListItem{nodes: []}

      assert MDEx.Tree.can_contain?(%MDEx.BlockQuote{}, paragraph)
      assert MDEx.Tree.can_contain?(%MDEx.ListItem{}, code_block)
      refute MDEx.Tree.can_contain?(%MDEx.BlockQuote{}, list_item)
      refute MDEx.Tree.can_contain?(%MDEx.ListItem{}, list_item)
    end

    test "leaf nodes cannot contain anything" do
      text = %MDEx.Text{literal: "text"}

      refute MDEx.Tree.can_contain?(%MDEx.Text{}, text)
      refute MDEx.Tree.can_contain?(%MDEx.Code{}, text)
      refute MDEx.Tree.can_contain?(%MDEx.ThematicBreak{}, text)
      refute MDEx.Tree.can_contain?(%MDEx.CodeBlock{}, text)
      refute MDEx.Tree.can_contain?(%MDEx.HtmlBlock{}, text)
    end
  end

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

  describe "append_node/2 - list handling" do
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

    test "adds sibling when node cannot be contained" do
      result =
        MDEx.Tree.append_node(
          %MDEx.Document{
            nodes: [
              %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "code"}]},
              %MDEx.Paragraph{
                nodes: [
                  %MDEx.List{
                    nodes: [
                      %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item"}]}]}
                    ]
                  }
                ]
              }
            ]
          },
          %MDEx.CodeBlock{literal: "println!(\"Hello\");", info: "rust"}
        )

      assert %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{nodes: [%MDEx.Code{literal: "code"}]},
                 %MDEx.Paragraph{
                   nodes: [
                     %MDEx.List{
                       nodes: [
                         %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item"}]}]}
                       ]
                     },
                     %MDEx.CodeBlock{literal: "println!(\"Hello\");", info: "rust"}
                   ]
                 }
               ]
             } = result

      assert MDEx.to_markdown!(result) == "`code`\n\n- item\n\n<!-- end list -->\n\n``` rust\nprintln!(\"Hello\");\n```"
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

    test "appends multiple list items to existing list" do
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
          [
            %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item2"}]}]},
            %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item3"}]}]}
          ]
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

    test "handles mixed block types" do
      result =
        MDEx.Tree.append_nodes(
          %MDEx.Document{
            nodes: [
              %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "paragraph"}]},
              %MDEx.List{
                nodes: [
                  %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item1"}]}]}
                ]
              }
            ]
          },
          [
            %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item2"}]}]},
            %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item3"}]}]},
            %MDEx.CodeBlock{literal: "puts hello", info: "ruby"},
            %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "after code"}]}
          ]
        )

      assert %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "paragraph"}]},
                 %MDEx.List{
                   nodes: [
                     %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item1"}]}]},
                     %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item2"}]}]},
                     %MDEx.ListItem{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "item3"}]}]}
                   ]
                 },
                 %MDEx.CodeBlock{literal: "puts hello", info: "ruby"},
                 %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "after code"}]}
               ]
             } = result

      assert MDEx.to_markdown!(result) == "paragraph\n\n- item1\n- item2\n- item3\n\n<!-- end list -->\n\n``` ruby\nputs hello\n```\n\nafter code"
    end
  end

  describe "merge/2 - basic operations" do
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
