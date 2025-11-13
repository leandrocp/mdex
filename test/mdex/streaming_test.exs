defmodule MDEx.StreamingTest do
  use ExUnit.Case, async: true

  # alias MDEx.BlockQuote
  alias MDEx.Code
  alias MDEx.CodeBlock
  alias MDEx.Emph
  alias MDEx.Heading
  # alias MDEx.Image
  # alias MDEx.Link
  alias MDEx.List
  alias MDEx.ListItem
  alias MDEx.Paragraph
  alias MDEx.SoftBreak
  alias MDEx.Strikethrough
  alias MDEx.Strong
  # alias MDEx.TaskItem
  alias MDEx.Text

  defp nodes(chunks, document \\ MDEx.new(streaming: true)) do
    Enum.reduce(chunks, document, fn chunk, doc -> Enum.into([chunk], doc) end)
    |> MDEx.Document.run()
    |> Map.get(:nodes)
  end

  test "build gradually with complete chunks" do
    chunks = [
      "# Title\n",
      "## Subtitle"
    ]

    assert [
             %Heading{level: 1, nodes: [%Text{literal: "Title"}]},
             %Heading{level: 2, nodes: [%Text{literal: "Subtitle"}]}
           ] = nodes(chunks)
  end

  test "build gradually with incomplete chunks" do
    chunks = [
      "#",
      " Title",
      " **Bold"
    ]

    assert [
             %MDEx.Heading{
               level: 1,
               nodes: [
                 %MDEx.Text{literal: "Title "},
                 %MDEx.Strong{nodes: [%MDEx.Text{literal: "Bold"}]}
               ],
               setext: false
             }
           ] = nodes(chunks)
  end

  test "build gradually with mixed chunks" do
    chunks = [
      "#",
      " Title\n",
      "##",
      [" ", ["Subtitle"]],
      %Heading{level: 3, setext: false, nodes: [%Text{literal: "Level 3"}]}
    ]

    assert [
             %Heading{level: 1, nodes: [%Text{literal: "Title"}]},
             %Heading{level: 2, nodes: [%Text{literal: "Subtitle"}]},
             %Heading{level: 3, nodes: [%Text{literal: "Level 3"}]}
           ] = nodes(chunks)
  end

  test "preserves trailing spaces between chunks" do
    chunks = [
      "# Hello ",
      "World"
    ]

    assert [
             %MDEx.Heading{
               nodes: [
                 %MDEx.Text{literal: "Hello World"}
               ],
               level: 1,
               setext: false
             }
           ] = nodes(chunks)
  end

  test "hard line breaks cause a new paragraph" do
    chunks = [
      "# Title\n\n",
      "Content here"
    ]

    assert [
             %Heading{
               nodes: [
                 %Text{literal: "Title"}
               ]
             },
             %Paragraph{nodes: [%Text{literal: "Content here"}]}
           ] = nodes(chunks)
  end

  test "hard line breaks chunks" do
    chunks = [
      "# Title\n",
      "## Subtitle\n",
      "\n\n",
      "`code`"
    ]

    assert [
             %MDEx.Heading{nodes: [%MDEx.Text{literal: "Title"}], level: 1, setext: false},
             %MDEx.Heading{nodes: [%MDEx.Text{literal: "Subtitle"}], level: 2, setext: false},
             %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "code"}]}
           ] = nodes(chunks)
  end

  test "handles multiple spaces between chunks" do
    chunks = [
      "Some text  ",
      " with spaces"
    ]

    assert [
             %Paragraph{
               nodes: [
                 %Text{literal: "Some text   with spaces"}
               ]
             }
           ] = nodes(chunks)
  end

  test "preserves whitespace with emphasis markers" do
    chunks = [
      "**Bold text** ",
      "more text"
    ]

    assert [
             %Paragraph{
               nodes: [
                 %Strong{nodes: [%Text{literal: "Bold text"}]},
                 %Text{literal: " more text"}
               ]
             }
           ] = nodes(chunks)
  end

  test "preserves spaces in heading" do
    chunks = [
      "# CommonMark Complete ",
      "Reference Guide\n\n"
    ]

    assert [
             %Heading{
               nodes: [
                 %Text{literal: "CommonMark Complete Reference Guide"}
               ]
             }
           ] = nodes(chunks)
  end

  test "preserves spaces in paragraph text" do
    chunks = [
      "This is some ",
      "text    with ",
      "preserved spaces"
    ]

    assert [
             %MDEx.Paragraph{
               nodes: [
                 %MDEx.Text{literal: "This is some text    with preserved spaces"}
               ]
             }
           ] = nodes(chunks)
  end

  test "handle empty chunks" do
    chunks = [
      "Hello ",
      "",
      "World"
    ]

    assert [
             %Paragraph{
               nodes: [
                 %Text{literal: "Hello World"}
               ]
             }
           ] = nodes(chunks)
  end

  test "incomplete code fragments" do
    chunks = [
      "`Enum",
      ".count( [ 1, 2, 3 ] )"
    ]

    assert [
             %Paragraph{
               nodes: [
                 %Code{num_backticks: 1, literal: "Enum.count( [ 1, 2, 3 ] )"}
               ]
             }
           ] = nodes(chunks)
  end

  test "incomplete code fragments up to completed code" do
    chunks = [
      "`Enum",
      ".count( [ 1, 2, 3 ] )",
      "`",
      " <- count"
    ]

    assert [
             %Paragraph{
               nodes: [
                 %Code{num_backticks: 1, literal: "Enum.count( [ 1, 2, 3 ] )"},
                 %Text{literal: " <- count"}
               ]
             }
           ] = nodes(chunks)
  end

  test "simple emphasis completion" do
    chunks = [
      "*bold ",
      "text*"
    ]

    assert [
             %Paragraph{
               nodes: [
                 %Emph{nodes: [%Text{literal: "bold text"}]}
               ]
             }
           ] = nodes(chunks)
  end

  test "simple code completion" do
    chunks = [
      "`hello ",
      "world`"
    ]

    assert [
             %Paragraph{
               nodes: [
                 %Code{num_backticks: 1, literal: "hello world"}
               ]
             }
           ] = nodes(chunks)
  end

  test "heading with word boundary" do
    chunks = [
      "# Hello ",
      "Coding ",
      "World"
    ]

    assert [
             %Heading{
               level: 1,
               nodes: [
                 %Text{literal: "Hello Coding World"}
               ]
             }
           ] = nodes(chunks)
  end

  test "paragraph with multiple sentences" do
    chunks = [
      "This is ",
      "the first ",
      "sentence. ",
      "This is ",
      "the second."
    ]

    assert [
             %Paragraph{
               nodes: [
                 %MDEx.Text{literal: "This is the first sentence. This is the second."}
               ]
             }
           ] = nodes(chunks)
  end

  test "simple list creation" do
    chunks = [
      "- Item ",
      "One"
    ]

    assert [
             %List{
               nodes: [
                 %ListItem{
                   nodes: [
                     %Paragraph{
                       nodes: [
                         %Text{literal: "Item One"}
                       ]
                     }
                   ]
                 }
               ]
             }
           ] = nodes(chunks)
  end

  test "mixed content with preserved spacing" do
    chunks = [
      "# Title\n\n",
      "Some paragraph ",
      "text here."
    ]

    assert [
             %Heading{nodes: [%Text{literal: "Title"}]},
             %Paragraph{
               nodes: [
                 %Text{literal: "Some paragraph text here."}
               ]
             }
           ] = nodes(chunks)
  end

  test "soft breaks in list items" do
    chunks = [
      "- Item 1\nContinue"
    ]

    assert [
             %List{
               nodes: [
                 %ListItem{
                   nodes: [
                     %Paragraph{
                       nodes: [
                         %Text{literal: "Item 1"},
                         %SoftBreak{},
                         %Text{literal: "Continue"}
                       ]
                     }
                   ]
                 }
               ]
             }
           ] = nodes(chunks)
  end

  test "simple strikethrough" do
    chunks = [
      "~~deleted ",
      "text~~"
    ]

    assert [
             %Paragraph{
               nodes: [
                 %Strikethrough{nodes: [%Text{literal: "deleted text"}]}
               ]
             }
           ] = nodes(chunks, MDEx.new(extension: [strikethrough: true], streaming: true))
  end

  test "bold emphasis across chunks" do
    chunks = [
      "**strong ",
      "text**"
    ]

    assert [
             %Paragraph{
               nodes: [
                 %Strong{nodes: [%Text{literal: "strong text"}]}
               ]
             }
           ] = nodes(chunks)
  end

  test "collect individual document nodes" do
    chunks = [
      %Heading{level: 1, setext: false, nodes: [%Text{literal: "Title"}]}
    ]

    assert [%Heading{level: 1, nodes: [%Text{literal: "Title"}], setext: false}] = nodes(chunks)
  end

  test "triple emphasis across chunks" do
    chunks = [
      "***bo",
      "th*** text"
    ]

    assert [
             %Paragraph{
               nodes: [
                 %Emph{
                   nodes: [
                     %Strong{
                       nodes: [
                         %Text{literal: "both"}
                       ]
                     }
                   ]
                 },
                 %Text{literal: " text"}
               ]
             }
           ] = nodes(chunks)
  end

  test "mixed emphasis syntax" do
    chunks = [
      "**bo",
      "ld** and *ital",
      "ic*"
    ]

    assert [
             %Paragraph{
               nodes: [
                 %Strong{nodes: [%Text{literal: "bold"}]},
                 %Text{literal: " and "},
                 %Emph{nodes: [%Text{literal: "italic"}]}
               ]
             }
           ] = nodes(chunks)
  end

  test "incomplete link with only text part" do
    chunks = [
      "[CommonMark "
    ]

    assert [
             %MDEx.Paragraph{
               nodes: [
                 %MDEx.Link{nodes: [%MDEx.Text{literal: "CommonMark"}], url: "mdex:incomplete-link", title: ""}
               ]
             }
           ] = nodes(chunks)
  end

  test "incomplete link with incomplete url" do
    chunks = [
      "[CommonMark ",
      "spec](https://commonmark"
    ]

    assert [
             %MDEx.Paragraph{
               nodes: [%MDEx.Text{literal: "[CommonMark spec](https://commonmark"}]
             }
           ] = nodes(chunks)
  end

  test "link split across chunks" do
    chunks = [
      "[CommonMark ",
      "spec](https://commonmark",
      ".org)"
    ]

    assert [
             %MDEx.Paragraph{
               nodes: [%MDEx.Link{nodes: [%MDEx.Text{literal: "CommonMark spec"}], url: "https://commonmark.org", title: ""}]
             }
           ] = nodes(chunks)
  end

  test "incomplete image" do
    chunks = [
      "![Small ic"
    ]

    assert [
             %MDEx.Paragraph{
               nodes: [
                 %MDEx.Image{
                   nodes: [
                     %MDEx.Text{literal: "Small ic"}
                   ],
                   url: "mdex:incomplete-link",
                   title: ""
                 }
               ]
             }
           ] = nodes(chunks)
  end

  test "image alt text split" do
    chunks = [
      "![Small ic",
      "on](https://example.com/icon.png)"
    ]

    assert [
             %MDEx.Paragraph{
               nodes: [
                 %MDEx.Image{
                   nodes: [
                     %MDEx.Text{literal: "Small icon"}
                   ],
                   url: "https://example.com/icon.png",
                   title: ""
                 }
               ]
             }
           ] = nodes(chunks)
  end

  test "only fenced" do
    chunks = [
      "```"
    ]

    assert [
             %CodeBlock{
               info: "",
               literal: ""
             }
           ] = nodes(chunks)
  end

  test "fenced with info" do
    chunks = [
      "```elixir"
    ]

    assert [
             %CodeBlock{
               info: "elixir",
               literal: ""
             }
           ] = nodes(chunks)
  end

  test "fenced code block with incomplete literal" do
    chunks = [
      "```elixir\n",
      "defmodule Demo do"
    ]

    assert [
             %CodeBlock{
               info: "elixir",
               literal: "defmodule Demo do\n"
             }
           ] = nodes(chunks)
  end

  test "fenced code block across chunks" do
    chunks = [
      "```elixir\n",
      "defmodule Demo do\n",
      "  def hello, do: :world\n",
      "end\n",
      "```"
    ]

    assert [
             %CodeBlock{
               info: "elixir",
               literal: "defmodule Demo do\n  def hello, do: :world\nend\n"
             }
           ] = nodes(chunks)
  end

  test "multiple fenced code block across chunks" do
    chunks = [
      "```elixir\n",
      "IO.puts",
      "\n```",
      "\n```",
      "rust\nprint\n",
      "```"
    ]

    assert [
             %CodeBlock{
               info: "elixir",
               literal: "IO.puts\n"
             },
             %CodeBlock{
               info: "rust",
               literal: "print\n"
             }
           ] = nodes(chunks)
  end

  test "incomplete strong at the end" do
    chunks = [
      "# Streaming\n",
      "`Starting ",
      "streaming...`\n\n",
      "## Code Blocks\n\n",
      "**Elixir"
    ]

    assert [
             %MDEx.Heading{nodes: [%MDEx.Text{literal: "Streaming"}], level: 1, setext: false},
             %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "Starting streaming..."}]},
             %MDEx.Heading{nodes: [%MDEx.Text{literal: "Code Blocks"}], level: 2, setext: false},
             %MDEx.Paragraph{nodes: [%MDEx.Strong{nodes: [%MDEx.Text{literal: "Elixir"}]}]}
           ] = nodes(chunks)
  end

  test "incomplete first code block" do
    chunks = [
      "# Streaming\n",
      "`Starting ",
      "streaming...`\n\n",
      "## Code Blocks\n\n",
      "**Elixir",
      "** example:\n",
      "```",
      "elixir\n",
      "defmodule StreamDemo do\n"
    ]

    assert [
             %MDEx.Heading{
               level: 1,
               nodes: [%MDEx.Text{literal: "Streaming"}],
               setext: false
             },
             %MDEx.Paragraph{
               nodes: [%MDEx.Code{num_backticks: 1, literal: "Starting streaming..."}]
             },
             %MDEx.Heading{
               level: 2,
               nodes: [%MDEx.Text{literal: "Code Blocks"}],
               setext: false
             },
             %MDEx.Paragraph{
               nodes: [%MDEx.Strong{nodes: [%MDEx.Text{literal: "Elixir"}]}, %MDEx.Text{literal: " example:"}]
             },
             %MDEx.CodeBlock{
               fence_char: "`",
               fence_length: 3,
               fence_offset: 0,
               fenced: true,
               info: "elixir",
               literal: "defmodule StreamDemo do\n",
               nodes: []
             }
           ] = nodes(chunks)
  end

  test "incomplete second code block" do
    chunks = [
      "# Streaming\n",
      "`Starting ",
      "streaming...`\n\n",
      "## Code Blocks\n\n",
      "**Elixir",
      "** example:\n",
      "```",
      "elixir\n",
      "defmodule StreamDemo do\n",
      "  def stream(chunks), do: @magic\n",
      "end\n",
      "```\n",
      "**Rust** example:\n",
      "```rust\nfn parse_document<'a>"
    ]

    assert [
             %MDEx.Heading{
               level: 1,
               nodes: [%MDEx.Text{literal: "Streaming"}],
               setext: false
             },
             %MDEx.Paragraph{
               nodes: [%MDEx.Code{num_backticks: 1, literal: "Starting streaming..."}]
             },
             %MDEx.Heading{
               level: 2,
               nodes: [%MDEx.Text{literal: "Code Blocks"}],
               setext: false
             },
             %MDEx.Paragraph{
               nodes: [%MDEx.Strong{nodes: [%MDEx.Text{literal: "Elixir"}]}, %MDEx.Text{literal: " example:"}]
             },
             %MDEx.CodeBlock{
               fence_char: "`",
               fence_length: 3,
               fence_offset: 0,
               fenced: true,
               info: "elixir",
               literal: "defmodule StreamDemo do\n  def stream(chunks), do: @magic\nend\n",
               nodes: []
             },
             %MDEx.Paragraph{
               nodes: [%MDEx.Strong{nodes: [%MDEx.Text{literal: "Rust"}]}, %MDEx.Text{literal: " example:"}]
             },
             %MDEx.CodeBlock{
               fence_char: "`",
               fence_length: 3,
               fence_offset: 0,
               fenced: true,
               info: "rust",
               literal: "fn parse_document<'a>\n",
               nodes: []
             }
           ] = nodes(chunks)
  end

  # FIXME
  # test "table header" do
  #   document = MDEx.new(extension: [table: true])
  #   document = Enum.into(["| Lang | Version |\n"], document)
  #
  #   assert [
  #            %MDEx.Table{
  #              nodes: [
  #                %MDEx.TableRow{
  #                  nodes: [
  #                    %MDEx.TableCell{nodes: [%MDEx.Text{literal: "Lang"}]},
  #                    %MDEx.TableCell{nodes: [%MDEx.Text{literal: "Version"}]}
  #                  ],
  #                  header: true
  #                }
  #              ],
  #              alignments: [:none, :none],
  #              num_columns: 2,
  #              num_rows: 0,
  #              num_nonempty_cells: 0
  #            }
  #          ] = document.nodes
  # end

  test "table with incomplete header separator" do
    chunks = [
      "| Lang | Version |\n",
      "| ---- | -------"
    ]

    assert [
             %MDEx.Table{
               nodes: [
                 %MDEx.TableRow{
                   nodes: [
                     %MDEx.TableCell{nodes: [%MDEx.Text{literal: "Lang"}]},
                     %MDEx.TableCell{nodes: [%MDEx.Text{literal: "Version"}]}
                   ],
                   header: true
                 }
               ],
               alignments: [:none, :none],
               num_columns: 2,
               num_rows: 1,
               num_nonempty_cells: 2
             }
           ] = nodes(chunks, MDEx.new(extension: [table: true], streaming: true))
  end

  test "table with incomplete row" do
    chunks = [
      "| Lang | Version |\n",
      "| ---- | ------- |\n",
      "| Elixir"
    ]

    assert [
             %MDEx.Table{
               nodes: [
                 %MDEx.TableRow{
                   nodes: [
                     %MDEx.TableCell{nodes: [%MDEx.Text{literal: "Lang"}]},
                     %MDEx.TableCell{nodes: [%MDEx.Text{literal: "Version"}]}
                   ],
                   header: true
                 },
                 %MDEx.TableRow{
                   nodes: [
                     %MDEx.TableCell{nodes: [%MDEx.Text{literal: "Elixir"}]},
                     %MDEx.TableCell{nodes: []}
                   ],
                   header: false
                 }
               ],
               alignments: [:none, :none],
               num_columns: 2,
               num_rows: 2,
               num_nonempty_cells: 4
             }
           ] = nodes(chunks, MDEx.new(extension: [table: true], streaming: true))
  end

  # FIXME
  # test "emoji" do
  #   chunks = [
  #     "# Emoji :r\n",
  #     "ocket: `:r\n",
  #     "ocket:`\n\n",
  #     ":smile:"
  #   ]
  #
  #   assert [
  #            %MDEx.Heading{
  #              nodes: [
  #                %MDEx.Text{literal: "Emoji "},
  #                %MDEx.ShortCode{code: "rocket", emoji: "🚀"},
  #                %MDEx.Text{literal: " "},
  #                %MDEx.Code{num_backticks: 1, literal: ":rocket:"}
  #              ],
  #              level: 1,
  #              setext: false
  #            },
  #            %MDEx.Paragraph{nodes: [%MDEx.ShortCode{code: "smile", emoji: "😄"}]}
  #          ] = Enum.reduce(chunks, MDEx.new(extension: [shortcodes: true]), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
  # end

  # FIXME
  # test "task list with formatting" do
  #   chunks = [
  #     "- [x] **Phase ",
  #     "1:** Setup\n",
  #     "- [ ] Testing"
  #   ]
  #
  #   assert [
  #            %List{
  #              nodes: [
  #                %TaskItem{
  #                  checked: true,
  #                  nodes: [
  #                    %Paragraph{
  #                      nodes: [
  #                        %Strong{
  #                          nodes: [
  #                            %Text{literal: "Phase"},
  #                            %Text{literal: " 1:"}
  #                          ]
  #                        },
  #                        %Text{literal: " Setup"}
  #                      ]
  #                    }
  #                  ]
  #                },
  #                %TaskItem{
  #                  checked: false,
  #                  nodes: [
  #                    %Paragraph{
  #                      nodes: [
  #                        %Text{literal: "Testing"}
  #                      ]
  #                    }
  #                  ]
  #                }
  #              ]
  #            }
  #          ] = Enum.reduce(chunks, MDEx.new(extension: [tasklist: true]), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
  # end

  test "task list retains emphasis across chunks" do
    options = [
      extension: [tasklist: true],
      parse: [relaxed_tasklist_matching: true],
      streaming: true
    ]

    chunks = [
      "- [x] Collect *n",
      "odes*\n"
    ]

    assert [
             %MDEx.List{
               bullet_char: "-",
               delimiter: :period,
               is_task_list: true,
               list_type: :bullet,
               marker_offset: 0,
               nodes: [
                 %MDEx.TaskItem{
                   nodes: [
                     %MDEx.Paragraph{
                       nodes: [
                         %MDEx.Text{literal: "Collect "},
                         %MDEx.Emph{nodes: [%MDEx.Text{literal: "nodes"}]}
                       ]
                     }
                   ],
                   checked: true,
                   marker: "x"
                 }
               ],
               padding: 2,
               start: 1,
               tight: true
             }
           ] =
             nodes(chunks, MDEx.new(options))
  end

  test "nested blockquotes with formatting" do
    chunks = [
      "> **Important No",
      "te**: This is important\n",
      "> \n",
      "> > Nested quote"
    ]

    assert [
             %MDEx.BlockQuote{
               nodes: [
                 %MDEx.Paragraph{
                   nodes: [
                     %MDEx.Strong{nodes: [%MDEx.Text{literal: "Important Note"}]},
                     %MDEx.Text{literal: ": This is important"}
                   ]
                 },
                 %MDEx.BlockQuote{nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Nested quote"}]}]}
               ]
             }
           ] = nodes(chunks)
  end

  # FIXME
  # test "autolink detection across chunks" do
  #   document = MDEx.new(extension: [autolink: true])
  #   document = Enum.into(["Visit https://common"], document)
  #   document = Enum.into(["mark.org for specs"], document)
  #
  #   assert %Document{
  #            nodes: [
  #              %Paragraph{
  #                nodes: [
  #                  %Text{literal: "Visit "},
  #                  %Link{
  #                    url: "https://common",
  #                    nodes: [%Text{literal: "https://commonmark.org for specs"}]
  #                  }
  #                ]
  #              }
  #            ]
  #          } = document
  # end

  test "line breaks with trailing spaces" do
    chunks = [
      "First line  \n",
      "Second line"
    ]

    assert [
             %MDEx.Paragraph{
               nodes: [
                 %MDEx.Text{literal: "First line"},
                 %MDEx.LineBreak{},
                 %MDEx.Text{literal: "Second line"}
               ]
             }
           ] = nodes(chunks)
  end

  test "escaped characters across chunks" do
    chunks = [
      "\\*not ital",
      "ic\\*"
    ]

    assert [
             %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "*not italic*"}]}
           ] = nodes(chunks)
  end

  test "complex nested list with code" do
    chunks = [
      "1. **Setup:**\n",
      "   ```bash\n",
      "   mix deps.get\n",
      "   ```\n",
      "2. Run tests"
    ]

    assert [
             %MDEx.List{
               nodes: [
                 %MDEx.ListItem{
                   nodes: [
                     %MDEx.Paragraph{nodes: [%MDEx.Strong{nodes: [%MDEx.Text{literal: "Setup:"}]}]},
                     %MDEx.CodeBlock{
                       nodes: [],
                       fenced: true,
                       fence_char: "`",
                       fence_length: 3,
                       fence_offset: 0,
                       info: "bash",
                       literal: "mix deps.get\n"
                     }
                   ],
                   list_type: :ordered,
                   marker_offset: 0,
                   padding: 3,
                   start: 1,
                   delimiter: :period,
                   bullet_char: "",
                   tight: false,
                   is_task_list: false
                 },
                 %MDEx.ListItem{
                   nodes: [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Run tests"}]}],
                   list_type: :ordered,
                   marker_offset: 0,
                   padding: 3,
                   start: 2,
                   delimiter: :period,
                   bullet_char: "",
                   tight: false,
                   is_task_list: false
                 }
               ],
               list_type: :ordered,
               marker_offset: 0,
               padding: 3,
               start: 1,
               delimiter: :period,
               bullet_char: "",
               tight: true,
               is_task_list: false
             }
           ] = nodes(chunks)
  end
end
