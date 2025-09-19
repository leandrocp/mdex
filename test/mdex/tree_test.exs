defmodule MDEx.TreeTest do
  use ExUnit.Case, async: true

  alias MDEx.Code
  alias MDEx.CodeBlock
  alias MDEx.Document
  alias MDEx.Heading
  alias MDEx.Paragraph
  alias MDEx.Strong
  alias MDEx.Text
  alias MDEx.Tree

  describe "append" do
    test "block into document" do
      assert Tree.append(
               %Document{},
               [%Paragraph{nodes: [%Text{literal: "foo"}]}]
             ) ==
               %Document{nodes: [%Paragraph{nodes: [%Text{literal: "foo"}]}]}

      assert Tree.append(
               %Document{},
               [%Heading{level: 1, nodes: [%Text{literal: "foo"}]}]
             ) ==
               %Document{nodes: [%Heading{nodes: [%Text{literal: "foo"}], level: 1, setext: false}]}
    end

    test "blocks into document" do
      assert Tree.append(
               %Document{},
               [
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "foo"}], level: 1, setext: false},
                 %MDEx.List{
                   nodes: [
                     %MDEx.ListItem{
                       nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "bar"}]}],
                       list_type: :bullet,
                       marker_offset: 0,
                       padding: 2,
                       start: 1,
                       delimiter: :period,
                       bullet_char: "-",
                       tight: false,
                       is_task_list: false
                     }
                   ],
                   list_type: :bullet,
                   marker_offset: 0,
                   padding: 2,
                   start: 1,
                   delimiter: :period,
                   bullet_char: "-",
                   tight: true,
                   is_task_list: false
                 }
               ]
             ) ==
               %MDEx.Document{
                 nodes: [
                   %MDEx.Heading{nodes: [%MDEx.Text{literal: "foo"}], level: 1, setext: false},
                   %MDEx.List{
                     nodes: [
                       %MDEx.ListItem{
                         nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "bar"}]}],
                         list_type: :bullet,
                         marker_offset: 0,
                         padding: 2,
                         start: 1,
                         delimiter: :period,
                         bullet_char: "-",
                         tight: false,
                         is_task_list: false
                       }
                     ],
                     list_type: :bullet,
                     marker_offset: 0,
                     padding: 2,
                     start: 1,
                     delimiter: :period,
                     bullet_char: "-",
                     tight: true,
                     is_task_list: false
                   }
                 ]
               }
    end

    test "mixed into document" do
      assert Tree.append(
               %Document{},
               [
                 %Paragraph{nodes: [%Text{literal: "foo"}]},
                 %Strong{nodes: [%Text{literal: " bar"}]},
                 %CodeBlock{literal: "puts"},
                 %Code{literal: "puts"}
               ]
             ) ==
               %MDEx.Document{
                 nodes: [
                   %MDEx.Paragraph{
                     nodes: [%MDEx.Text{literal: "foo"}, %MDEx.Strong{nodes: [%MDEx.Text{literal: " bar"}]}]
                   },
                   %MDEx.CodeBlock{
                     nodes: [],
                     fenced: true,
                     fence_char: "`",
                     fence_length: 3,
                     fence_offset: 0,
                     info: "",
                     literal: "puts"
                   },
                   %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "puts"}]}
                 ]
               }
    end

    test "paragraph into paragraph" do
      assert Tree.append(
               %Document{nodes: [%Paragraph{nodes: [%Text{literal: "foo"}]}]},
               [%Paragraph{nodes: [%Text{literal: "bar"}]}]
             ) ==
               %Document{
                 nodes: [
                   %Paragraph{nodes: [%Text{literal: "foo"}]},
                   %Paragraph{nodes: [%Text{literal: "bar"}]}
                 ]
               }
    end

    test "heading into paragraph" do
      assert Tree.append(
               %Document{nodes: [%Paragraph{nodes: [%Text{literal: "foo"}]}]},
               [%Heading{level: 1, nodes: [%Text{literal: "bar"}]}]
             ) ==
               %Document{
                 nodes: [
                   %Paragraph{nodes: [%Text{literal: "foo"}]},
                   %Heading{nodes: [%Text{literal: "bar"}], level: 1, setext: false}
                 ]
               }
    end

    test "text into block" do
      assert Tree.append(
               %Document{nodes: [%Paragraph{nodes: [%Text{literal: "foo"}]}]},
               [%Text{literal: " bar"}]
             ) ==
               %Document{nodes: [%Paragraph{nodes: [%Text{literal: "foo bar"}]}]}

      assert Tree.append(
               %Document{nodes: [%Heading{nodes: [%Text{literal: "foo"}], level: 1, setext: false}]},
               [%Text{literal: " bar"}]
             ) ==
               %Document{nodes: [%Heading{nodes: [%Text{literal: "foo bar"}], level: 1, setext: false}]}
    end

    test "multiple text into block" do
      assert Tree.append(
               %Document{nodes: [%Paragraph{nodes: [%Text{literal: "foo"}]}]},
               [%Text{literal: " bar"}, %Text{literal: " baz"}]
             ) ==
               %Document{nodes: [%Paragraph{nodes: [%Text{literal: "foo bar baz"}]}]}

      assert Tree.append(
               %Document{nodes: [%Heading{nodes: [%Text{literal: "foo"}], level: 1, setext: false}]},
               [%Text{literal: " bar"}, %Text{literal: " baz"}]
             ) ==
               %Document{nodes: [%Heading{nodes: [%Text{literal: "foo bar baz"}], level: 1, setext: false}]}
    end

    test "text into text" do
      assert Tree.append(
               %Document{nodes: [%Paragraph{nodes: [%Text{literal: "foo"}]}]},
               [%Text{literal: " bar"}]
             ) ==
               %Document{nodes: [%Paragraph{nodes: [%Text{literal: "foo bar"}]}]}
    end

    test "list item into list" do
      assert Tree.append(
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
                         tight: false,
                         is_task_list: false
                       }
                     ],
                     list_type: :bullet,
                     marker_offset: 0,
                     padding: 2,
                     start: 1,
                     delimiter: :period,
                     bullet_char: "-",
                     tight: true,
                     is_task_list: false
                   }
                 ]
               },
               [
                 %MDEx.ListItem{
                   nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "bar"}]}],
                   list_type: :bullet,
                   marker_offset: 0,
                   padding: 2,
                   start: 1,
                   delimiter: :period,
                   bullet_char: "-",
                   tight: false,
                   is_task_list: false
                 }
               ]
             ) ==
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
                         tight: false,
                         is_task_list: false
                       },
                       %MDEx.ListItem{
                         nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "bar"}]}],
                         list_type: :bullet,
                         marker_offset: 0,
                         padding: 2,
                         start: 1,
                         delimiter: :period,
                         bullet_char: "-",
                         tight: false,
                         is_task_list: false
                       }
                     ],
                     list_type: :bullet,
                     marker_offset: 0,
                     padding: 2,
                     start: 1,
                     delimiter: :period,
                     bullet_char: "-",
                     tight: true,
                     is_task_list: false
                   }
                 ]
               }
    end

    test "task item into list with existing list item" do
      assert Tree.append(
               %MDEx.Document{
                 nodes: [
                   %MDEx.List{
                     nodes: [
                       %MDEx.ListItem{
                         nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Item 1"}]}],
                         list_type: :bullet,
                         marker_offset: 0,
                         padding: 2,
                         start: 1,
                         delimiter: :period,
                         bullet_char: "-",
                         tight: false,
                         is_task_list: false
                       }
                     ],
                     list_type: :bullet,
                     marker_offset: 0,
                     padding: 2,
                     start: 1,
                     delimiter: :period,
                     bullet_char: "-",
                     tight: true,
                     is_task_list: true
                   }
                 ]
               },
               [
                 %MDEx.TaskItem{
                   nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Item 2"}]}],
                   checked: false,
                   marker: ""
                 }
               ]
             ) ==
               %MDEx.Document{
                 nodes: [
                   %MDEx.List{
                     nodes: [
                       %MDEx.ListItem{
                         nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Item 1"}]}],
                         list_type: :bullet,
                         marker_offset: 0,
                         padding: 2,
                         start: 1,
                         delimiter: :period,
                         bullet_char: "-",
                         tight: false,
                         is_task_list: false
                       },
                       %MDEx.TaskItem{
                         nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Item 2"}]}],
                         checked: false,
                         marker: ""
                       }
                     ],
                     list_type: :bullet,
                     marker_offset: 0,
                     padding: 2,
                     start: 1,
                     delimiter: :period,
                     bullet_char: "-",
                     tight: true,
                     is_task_list: true
                   }
                 ]
               }
    end

    test "list item into non-list create list" do
      assert Tree.append(
               %MDEx.Document{},
               [
                 %MDEx.ListItem{
                   nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "foo"}]}],
                   list_type: :bullet,
                   marker_offset: 0,
                   padding: 2,
                   start: 1,
                   delimiter: :period,
                   bullet_char: "-",
                   tight: false,
                   is_task_list: false
                 }
               ]
             ) ==
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
                         tight: false,
                         is_task_list: false
                       }
                     ],
                     list_type: :bullet,
                     marker_offset: 0,
                     padding: 2,
                     start: 1,
                     delimiter: :period,
                     bullet_char: "-",
                     tight: false,
                     is_task_list: false
                   }
                 ]
               }
    end

    test "task item into non-list create list" do
      assert Tree.append(
               %MDEx.Document{},
               [
                 %MDEx.TaskItem{
                   nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "foo"}]}],
                   checked: false,
                   marker: ""
                 }
               ]
             ) ==
               %MDEx.Document{
                 nodes: [
                   %MDEx.List{
                     nodes: [
                       %MDEx.TaskItem{
                         nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "foo"}]}],
                         checked: false,
                         marker: ""
                       }
                     ],
                     list_type: :bullet,
                     marker_offset: 0,
                     padding: 2,
                     start: 1,
                     delimiter: :period,
                     bullet_char: "-",
                     tight: false,
                     is_task_list: true
                   }
                 ]
               }
    end

    test "text into code" do
      assert Tree.append(
               %MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "puts"}]}]},
               [%MDEx.Text{literal: "('Hello')"}]
             ) ==
               %MDEx.Document{
                 nodes: [
                   %MDEx.Paragraph{
                     nodes: [
                       %MDEx.Code{num_backticks: 1, literal: "puts('Hello')"}
                     ]
                   }
                 ]
               }
    end

    test "code into code" do
      assert Tree.append(
               %MDEx.Document{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "puts"}]}]},
               [%MDEx.Code{num_backticks: 1, literal: " 'Hello'"}]
             ) ==
               %MDEx.Document{
                 nodes: [
                   %MDEx.Paragraph{
                     nodes: [
                       %MDEx.Code{num_backticks: 1, literal: "puts 'Hello'"}
                     ]
                   }
                 ]
               }
    end

    test "codeblock into codeblock with same attributes" do
      assert Tree.append(
               %MDEx.Document{
                 nodes: [
                   %MDEx.CodeBlock{
                     nodes: [],
                     fenced: true,
                     fence_char: "`",
                     fence_length: 3,
                     fence_offset: 0,
                     info: "elixir",
                     literal: "@foo\n"
                   }
                 ]
               },
               [
                 %MDEx.CodeBlock{
                   nodes: [],
                   fenced: true,
                   fence_char: "`",
                   fence_length: 3,
                   fence_offset: 0,
                   info: "elixir",
                   literal: "@bar"
                 }
               ]
             ) ==
               %MDEx.Document{
                 nodes: [
                   %MDEx.CodeBlock{
                     nodes: [],
                     fenced: true,
                     fence_char: "`",
                     fence_length: 3,
                     fence_offset: 0,
                     info: "elixir",
                     literal: "@foo\n@bar"
                   }
                 ]
               }
    end

    test "codeblock into codeblock with different attributes" do
      assert Tree.append(
               %MDEx.Document{
                 nodes: [
                   %MDEx.CodeBlock{
                     nodes: [],
                     fenced: true,
                     fence_char: "`",
                     fence_length: 3,
                     fence_offset: 0,
                     info: "elixir",
                     literal: "@foo"
                   }
                 ]
               },
               [
                 %MDEx.CodeBlock{
                   nodes: [],
                   fenced: true,
                   fence_char: "`",
                   fence_length: 3,
                   fence_offset: 0,
                   info: "rust",
                   literal: "const FOO: i32 = 10;"
                 }
               ]
             ) ==
               %MDEx.Document{
                 nodes: [
                   %MDEx.CodeBlock{
                     nodes: [],
                     fenced: true,
                     fence_char: "`",
                     fence_length: 3,
                     fence_offset: 0,
                     info: "elixir",
                     literal: "@foo"
                   },
                   %MDEx.CodeBlock{
                     nodes: [],
                     fenced: true,
                     fence_char: "`",
                     fence_length: 3,
                     fence_offset: 0,
                     info: "rust",
                     literal: "const FOO: i32 = 10;"
                   }
                 ]
               }
    end
  end
end
