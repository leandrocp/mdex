defmodule MDEx.StreamTest do
  use ExUnit.Case, async: true
  doctest MDEx.Stream, import: true

  test "stream to document" do
    stream =
      ["Hello ", "World"]
      |> Enum.into(MDEx.stream())
      |> Stream.map(fn
        %MDEx.Text{literal: literal} ->
          %MDEx.Text{literal: String.upcase(literal)}

        node ->
          node
      end)

    assert Enum.into(stream, %MDEx.Document{}) == %MDEx.Document{
             nodes: [
               %MDEx.Paragraph{
                 nodes: [
                   %MDEx.Text{literal: "HELLO WORLD"}
                 ]
               }
             ]
           }
  end

  test "collect iodata" do
    assert Enum.into(["# Title"], MDEx.stream()).document == %MDEx.Document{
             nodes: [
               %MDEx.Heading{
                 level: 1,
                 setext: false,
                 nodes: [
                   %MDEx.Text{literal: "Title"}
                 ]
               }
             ]
           }
  end

  test "collect document nodes" do
    assert Enum.into(
             [
               %MDEx.Heading{
                 level: 1,
                 setext: false,
                 nodes: [
                   %MDEx.Text{literal: "Title"}
                 ]
               }
             ],
             MDEx.stream()
           ).document ==
             %MDEx.Document{
               nodes: [
                 %MDEx.Heading{
                   level: 1,
                   setext: false,
                   nodes: [
                     %MDEx.Text{literal: "Title"}
                   ]
                 }
               ]
             }
  end

  test "collect incomplete chunks" do
    assert Enum.into(["`puts"], MDEx.stream()).document ==
             %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{
                   nodes: [
                     %MDEx.Code{num_backticks: 1, literal: "puts"}
                   ]
                 }
               ]
             }

    assert Enum.into(["`puts", "('Hello')"], MDEx.stream()).document ==
             %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{
                   nodes: [
                     %MDEx.Code{num_backticks: 1, literal: "puts('Hello')"}
                   ]
                 }
               ]
             }

    assert Enum.into(["`puts", "('Hello')", "`"], MDEx.stream()).document ==
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

  test "collect mixed incomplete chunks" do
    assert Enum.into(
             ["This is ", "*it"],
             MDEx.stream()
           ).document ==
             %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{
                   nodes: [
                     %MDEx.Text{literal: "This is "},
                     %MDEx.Emph{
                       nodes: [
                         %MDEx.Text{literal: "it"}
                       ]
                     }
                   ]
                 }
               ]
             }

    assert Enum.into(
             ["This is ", "*it", "alic **bo"],
             MDEx.stream()
           ).document ==
             %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{
                   nodes: [
                     %MDEx.Text{literal: "This is "},
                     %MDEx.Emph{
                       nodes: [
                         %MDEx.Text{literal: "italic "},
                         %MDEx.Strong{nodes: [%MDEx.Text{literal: "bo"}]}
                       ]
                     }
                   ]
                 }
               ]
             }

    assert Enum.into(
             ["This is ", "*it", "alic **bo", "ld** text"],
             MDEx.stream()
           ).document ==
             %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{
                   nodes: [
                     %MDEx.Text{literal: "This is "},
                     %MDEx.Emph{
                       nodes: [
                         %MDEx.Text{literal: "italic "},
                         %MDEx.Strong{nodes: [%MDEx.Text{literal: "bold"}]},
                         %MDEx.Text{literal: " text"}
                       ]
                     }
                   ]
                 }
               ]
             }

    assert Enum.into(
             ["This is ", "*it", "alic **bo", "ld** text* across chunks."],
             MDEx.stream()
           ).document ==
             %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{
                   nodes: [
                     %MDEx.Text{literal: "This is "},
                     %MDEx.Emph{
                       nodes: [
                         %MDEx.Text{literal: "italic "},
                         %MDEx.Strong{nodes: [%MDEx.Text{literal: "bold"}]},
                         %MDEx.Text{literal: " text"}
                       ]
                     },
                     %MDEx.Text{literal: " across chunks."}
                   ]
                 }
               ]
             }
  end

  test "inline fragments into heading" do
    assert Enum.into(
             ["# Hel", "lo ", "*Wor"],
             MDEx.stream()
           ).document ==
             %MDEx.Document{
               nodes: [
                 %MDEx.Heading{
                   nodes: [
                     %MDEx.Text{literal: "Hello "},
                     %MDEx.Emph{nodes: [%MDEx.Text{literal: "Wor"}]}
                   ],
                   level: 1,
                   setext: false
                 }
               ]
             }

    assert Enum.into(
             ["# Hel", "lo ", "*Wor", "ld*"],
             MDEx.stream()
           ).document ==
             %MDEx.Document{
               nodes: [
                 %MDEx.Heading{
                   nodes: [
                     %MDEx.Text{literal: "Hello "},
                     %MDEx.Emph{nodes: [%MDEx.Text{literal: "World"}]}
                   ],
                   level: 1,
                   setext: false
                 }
               ]
             }
  end

  test "preserve whitespace between" do
    assert Enum.into(["# foo", " bar", "baz ", "  quux  "], MDEx.stream()).document == %MDEx.Document{
             nodes: [
               %MDEx.Heading{
                 level: 1,
                 setext: false,
                 nodes: [
                   %MDEx.Text{literal: "foo barbaz   quux"}
                 ]
               }
             ]
           }
  end

  test "list item into empty document creates a list" do
    assert Enum.into(["- Item 1"], MDEx.stream()).document == %MDEx.Document{
             nodes: [
               %MDEx.List{
                 nodes: [
                   %MDEx.ListItem{
                     nodes: [
                       %MDEx.Paragraph{
                         nodes: [
                           %MDEx.Text{literal: "Item 1"}
                         ]
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

  test "list with incomplete fragments" do
    assert Enum.into(["Here's a list:\n\n", "* First"], MDEx.stream()).document == %MDEx.Document{
             nodes: [
               %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Here's a list:"}]},
               %MDEx.List{
                 nodes: [
                   %MDEx.ListItem{
                     nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "First"}]}],
                     list_type: :bullet,
                     marker_offset: 0,
                     padding: 2,
                     start: 1,
                     delimiter: :period,
                     bullet_char: "*",
                     tight: false,
                     is_task_list: false
                   }
                 ],
                 list_type: :bullet,
                 marker_offset: 0,
                 padding: 2,
                 start: 1,
                 delimiter: :period,
                 bullet_char: "*",
                 tight: true,
                 is_task_list: false
               }
             ]
           }

    assert Enum.into(
             [
               "Here's a list:\n\n",
               "* First",
               " item\n",
               "* Second",
               " item\n\n",
               "And more text."
             ],
             MDEx.stream()
           ).document == %MDEx.Document{
             nodes: [
               %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Here's a list:"}]},
               %MDEx.List{
                 nodes: [
                   %MDEx.ListItem{
                     nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "First item"}]}],
                     list_type: :bullet,
                     marker_offset: 0,
                     padding: 2,
                     start: 1,
                     delimiter: :period,
                     bullet_char: "*",
                     tight: false,
                     is_task_list: false
                   },
                   %MDEx.ListItem{
                     nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Second item"}]}],
                     list_type: :bullet,
                     marker_offset: 0,
                     padding: 2,
                     start: 1,
                     delimiter: :period,
                     bullet_char: "*",
                     tight: false,
                     is_task_list: false
                   }
                 ],
                 list_type: :bullet,
                 marker_offset: 0,
                 padding: 2,
                 start: 1,
                 delimiter: :period,
                 bullet_char: "*",
                 tight: true,
                 is_task_list: false
               },
               %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "And more text."}]}
             ]
           }
  end

  test "code block" do
    assert Enum.into(["```"], MDEx.stream()).document == %MDEx.Document{
             nodes: [
               %MDEx.CodeBlock{
                 nodes: [],
                 fenced: true,
                 fence_char: "`",
                 fence_length: 3,
                 fence_offset: 0,
                 info: "",
                 literal: ""
               }
             ]
           }

    assert Enum.into(["```", "elixir"], MDEx.stream()).document == %MDEx.Document{
             nodes: [
               %MDEx.CodeBlock{
                 nodes: [],
                 fenced: true,
                 fence_char: "`",
                 fence_length: 3,
                 fence_offset: 0,
                 info: "elixir",
                 literal: ""
               }
             ]
           }

    assert Enum.into(["```", "elixir\n", "def foo"], MDEx.stream()).document == %MDEx.Document{
             nodes: [
               %MDEx.CodeBlock{
                 nodes: [],
                 fenced: true,
                 fence_char: "`",
                 fence_length: 3,
                 fence_offset: 0,
                 info: "elixir",
                 literal: "def foo"
               }
             ]
           }

    assert Enum.into(["```elixir\n", "def foo, do: :bar\n", "```"], MDEx.stream()).document == %MDEx.Document{
             nodes: [
               %MDEx.CodeBlock{
                 nodes: [],
                 fenced: true,
                 fence_char: "`",
                 fence_length: 3,
                 fence_offset: 0,
                 info: "elixir",
                 literal: "def foo, do: :bar\n"
               }
             ]
           }
  end

  test "strikethrough" do
    assert Enum.into(["~~stri"], MDEx.stream(extension: [strikethrough: true])).document ==
             %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{
                   nodes: [
                     %MDEx.Strikethrough{nodes: [%MDEx.Text{literal: "stri"}]}
                   ]
                 }
               ]
             }

    assert Enum.into(["~~stri", "ke~~"], MDEx.stream(extension: [strikethrough: true])).document ==
             %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{
                   nodes: [
                     %MDEx.Strikethrough{nodes: [%MDEx.Text{literal: "strike"}]}
                   ]
                 }
               ]
             }

    assert Enum.into(["~", "~text~~"], MDEx.stream(extension: [strikethrough: true])).document ==
             %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{
                   nodes: [
                     %MDEx.Strikethrough{nodes: [%MDEx.Text{literal: "text"}]}
                   ]
                 }
               ]
             }

    assert Enum.into(
             ["This is ", "~~stri", "ke **bo", "ld**~~ text"],
             MDEx.stream(extension: [strikethrough: true])
           ).document ==
             %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{
                   nodes: [
                     %MDEx.Text{literal: "This is "},
                     %MDEx.Strikethrough{
                       nodes: [
                         %MDEx.Text{literal: "strike "},
                         %MDEx.Strong{nodes: [%MDEx.Text{literal: "bold"}]}
                       ]
                     },
                     %MDEx.Text{literal: " text"}
                   ]
                 }
               ]
             }

    assert Enum.into(
             ["~~*ital", "ic* and `co", "de`~~"],
             MDEx.stream(extension: [strikethrough: true])
           ).document ==
             %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{
                   nodes: [
                     %MDEx.Strikethrough{
                       nodes: [
                         %MDEx.Emph{nodes: [%MDEx.Text{literal: "italic"}]},
                         %MDEx.Text{literal: " and "},
                         %MDEx.Code{num_backticks: 1, literal: "code"}
                       ]
                     }
                   ]
                 }
               ]
             }

    assert Enum.into(
             ["~~first~~ and ", "~~sec", "ond~~"],
             MDEx.stream(extension: [strikethrough: true])
           ).document ==
             %MDEx.Document{
               nodes: [
                 %MDEx.Paragraph{
                   nodes: [
                     %MDEx.Strikethrough{nodes: [%MDEx.Text{literal: "first"}]},
                     %MDEx.Text{literal: " and "},
                     %MDEx.Strikethrough{nodes: [%MDEx.Text{literal: "second"}]}
                   ]
                 }
               ]
             }
  end

  test "respect soft breaks" do
    assert Enum.into(["- Item 1\nContinue"], MDEx.stream()).document == %MDEx.Document{
             nodes: [
               %MDEx.List{
                 nodes: [
                   %MDEx.ListItem{
                     nodes: [
                       %MDEx.Paragraph{
                         nodes: [
                           %MDEx.Text{literal: "Item 1"},
                           %MDEx.SoftBreak{},
                           %MDEx.Text{literal: "Continue"}
                         ]
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

  test "Enum.list" do
    stream = Enum.into(["# My", [" Title"]], MDEx.stream())

    assert Enum.to_list(stream) == [
             %MDEx.Heading{nodes: [%MDEx.Text{literal: "My"}], level: 1, setext: false},
             %MDEx.Text{literal: " "},
             %MDEx.Text{literal: "Title"}
           ]
  end

  test "Enum.take" do
    stream = Enum.into(["# My", [" Title"]], MDEx.stream())

    assert Enum.take(stream, 3) == [
             %MDEx.Heading{nodes: [%MDEx.Text{literal: "My"}], level: 1, setext: false},
             %MDEx.Text{literal: " "},
             %MDEx.Text{literal: "Title"}
           ]
  end
end
