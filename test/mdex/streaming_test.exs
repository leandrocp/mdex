defmodule MDEx.StreamingTest do
  use ExUnit.Case, async: true

  # alias MDEx.BlockQuote
  alias MDEx.Code
  alias MDEx.CodeBlock
  alias MDEx.Emph
  alias MDEx.Heading
  alias MDEx.Image
  alias MDEx.Link
  alias MDEx.List
  alias MDEx.ListItem
  alias MDEx.Paragraph
  alias MDEx.SoftBreak
  alias MDEx.Strikethrough
  alias MDEx.Strong
  alias MDEx.TaskItem
  alias MDEx.Text

  test "build gradually with complete chunks" do
    chunks = [
      "# Title\n",
      "## Subtitle"
    ]

    assert [
             %Heading{level: 1, nodes: [%Text{literal: "Title"}]},
             %Heading{level: 2, nodes: [%Text{literal: "Subtitle"}]}
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
  end

  test "build gradually with incomplete chunks" do
    chunks = [
      "#",
      " Title\n"
    ]

    assert [%Heading{level: 1, nodes: [%Text{literal: "Title"}]}] =
             Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
  end

  test "preserves trailing spaces between chunks" do
    chunks = [
      "# Hello ",
      "World"
    ]

    assert [
             %MDEx.Heading{
               nodes: [
                 %MDEx.Text{literal: "Hello"},
                 %MDEx.Text{literal: " World"}
               ],
               level: 1,
               setext: false
             }
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
  end

  test "hard line breaks cause a new paragraph" do
    chunks = [
      "# Title\n\n",
      "Content here"
    ]

    assert [%Heading{nodes: [%Text{literal: "Title"}]}, %Paragraph{nodes: [%Text{literal: "Content here"}]}] =
             Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
  end

  test "handles multiple spaces between chunks" do
    chunks = [
      "Some text  ",
      " with spaces"
    ]

    assert [
             %Paragraph{
               nodes: [
                 %Text{literal: "Some text"},
                 %Text{literal: "   with spaces"}
               ]
             }
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
  end

  test "preserves spaces in heading" do
    chunks = [
      "# CommonMark Complete ",
      "Reference Guide\n\n"
    ]

    assert [
             %Heading{
               nodes: [
                 %Text{literal: "CommonMark Complete"},
                 %Text{literal: " Reference Guide"}
               ]
             }
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
  end

  test "preserves spaces in paragraph text" do
    chunks = [
      "This is some ",
      "text    with ",
      "preserved spaces"
    ]

    assert [
             %Paragraph{
               nodes: [
                 %MDEx.Text{literal: "This is some"},
                 %MDEx.Text{literal: " text    with"},
                 %MDEx.Text{literal: " preserved spaces"}
               ]
             }
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
                 %Text{literal: "Hello"},
                 %Text{literal: " "},
                 %Text{literal: "World"}
               ]
             }
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
  end

  test "incomplete code fragments across chunks" do
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
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
                 %Text{literal: "Hello"},
                 %Text{literal: " Coding"},
                 %Text{literal: " World"}
               ]
             }
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
                 %MDEx.Text{literal: "This is"},
                 %MDEx.Text{literal: " the first"},
                 %MDEx.Text{literal: " sentence."},
                 %MDEx.Text{literal: " This is"},
                 %MDEx.Text{literal: " the second."}
               ]
             }
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
                         %Text{literal: "Item"},
                         %Text{literal: " One"}
                       ]
                     }
                   ]
                 }
               ]
             }
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
                 %Text{literal: "Some paragraph"},
                 %Text{literal: " text here."}
               ]
             }
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
           ] = Enum.reduce(chunks, MDEx.new(extension: [strikethrough: true]), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
  end

  test "collect individual document nodes" do
    chunks = [
      %Heading{level: 1, setext: false, nodes: [%Text{literal: "Title"}]}
    ]

    assert [%Heading{level: 1, nodes: [%Text{literal: "Title"}], setext: false}] =
             Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
  end

  test "incomplete link with only text part" do
    chunks = [
      "[CommonMark "
    ]

    [
      %MDEx.Paragraph{
        nodes: [
          %Link{
            nodes: [
              %MDEx.Text{literal: "CommonMark "}
            ],
            url: "mdex:incomplete-link",
            title: ""
          }
        ]
      }
    ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
  end

  test "incomplete link with incomplete url" do
    chunks = [
      "[CommonMark ",
      "spec](https://commonmark"
    ]

    [
      %MDEx.Paragraph{
        nodes: [
          %Link{
            nodes: [
              %MDEx.Text{literal: "CommonMark spec"}
            ],
            url: "https://commonmark",
            title: ""
          }
        ]
      }
    ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
  end

  test "link split across chunks" do
    chunks = [
      "[CommonMark ",
      "spec](https://commonmark",
      ".org)"
    ]

    [
      %MDEx.Paragraph{
        nodes: [
          %Link{
            nodes: [
              %MDEx.Text{literal: "CommonMark spec"}
            ],
            url: "https://commonmark.org",
            title: ""
          }
        ]
      }
    ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
  end

  test "image alt text split" do
    chunks = [
      "![Small ic",
      "on](https://example.com/icon.png)"
    ]

    [
      %MDEx.Paragraph{
        nodes: [
          %Image{
            nodes: [%MDEx.Text{literal: "Small icon"}],
            url: "https://example.com/icon.png",
            title: ""
          }
        ]
      }
    ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
               literal: "IO.puts"
             },
             %CodeBlock{
               info: "rust",
               literal: "print"
             }
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
             %MDEx.Heading{nodes: [%MDEx.Text{literal: "Streaming"}], level: 1, setext: false},
             %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "Starting streaming..."}]},
             %MDEx.Heading{nodes: [%MDEx.Text{literal: "Code Blocks"}], level: 2, setext: false},
             %MDEx.Paragraph{nodes: [%MDEx.Strong{nodes: [%MDEx.Text{literal: "Elixir"}]}, %MDEx.Text{literal: " example:"}]},
             %MDEx.CodeBlock{
               nodes: [],
               fenced: true,
               fence_char: "`",
               fence_length: 3,
               fence_offset: 0,
               info: "elixir",
               literal: "defmodule StreamDemo do\n"
             }
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
             %MDEx.Heading{nodes: [%MDEx.Text{literal: "Streaming"}], level: 1, setext: false},
             %MDEx.Paragraph{nodes: [%MDEx.Code{num_backticks: 1, literal: "Starting streaming..."}]},
             %MDEx.Heading{nodes: [%MDEx.Text{literal: "Code Blocks"}], level: 2, setext: false},
             %MDEx.Paragraph{nodes: [%MDEx.Strong{nodes: [%MDEx.Text{literal: "Elixir"}]}, %MDEx.Text{literal: " example:"}]},
             %MDEx.CodeBlock{
               nodes: [],
               fenced: true,
               fence_char: "`",
               fence_length: 3,
               fence_offset: 0,
               info: "elixir",
               literal: "defmodule StreamDemo do\n  def stream(chunks), do: @magic\nend\n"
             },
             %MDEx.Paragraph{nodes: [%MDEx.Strong{nodes: [%MDEx.Text{literal: "Rust"}]}, %MDEx.Text{literal: " example:"}]},
             %MDEx.CodeBlock{
               nodes: [],
               fenced: true,
               fence_char: "`",
               fence_length: 3,
               fence_offset: 0,
               info: "rust",
               literal: "fn parse_document<'a>"
             }
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
  end

  test "fenced code block followed by heading" do
    options = [
      extension: [
        alerts: true,
        autolink: true,
        footnotes: true,
        shortcodes: true,
        strikethrough: true,
        table: true,
        tagfilter: true,
        tasklist: true
      ],
      parse: [
        relaxed_autolinks: true,
        relaxed_tasklist_matching: true
      ],
      render: [
        github_pre_lang: true,
        full_info_string: true,
        unsafe: true
      ],
      syntax_highlight: [formatter: {:html_inline, theme: "github_light"}]
    ]

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
      "```rust\nfn parse_document<'a>",
      "(env: Env<'a>, md: &str, options: ExOptions) -> NifResult<Term<'a>>\n",
      "```\n\n",
      "## Links and Images\n\n",
      "[MDEx",
      " Repository](",
      "(https://github.com/leandrocp/mdex))\n",
      "![Image",
      "](https://placehold.co/400x100/green/white?text=Image) ",
      "## TODO\n\n"
    ]

    assert [
             %Heading{nodes: [%Text{literal: "Streaming"}], level: 1, setext: false},
             %Paragraph{nodes: [%Code{num_backticks: 1, literal: "Starting streaming..."}]},
             %Heading{nodes: [%Text{literal: "Code Blocks"}], level: 2, setext: false},
             %Paragraph{nodes: [%Strong{nodes: [%Text{literal: "Elixir"}]}, %Text{literal: " example:"}]},
             %CodeBlock{
               nodes: [],
               fenced: true,
               fence_char: "`",
               fence_length: 3,
               fence_offset: 0,
               info: "elixir",
               literal: "defmodule StreamDemo do\n  def stream(chunks), do: @magic\nend\n"
             },
             %Paragraph{nodes: [%Strong{nodes: [%Text{literal: "Rust"}]}, %Text{literal: " example:"}]},
             %CodeBlock{
               nodes: [],
               fenced: true,
               fence_char: "`",
               fence_length: 3,
               fence_offset: 0,
               info: "rust",
               literal: "fn parse_document<'a>(env: Env<'a>, md: &str, options: ExOptions) -> NifResult<Term<'a>>\n"
             },
             %Heading{nodes: [%Text{literal: "Links and Images"}], level: 2, setext: false},
             %Paragraph{
               nodes: [
                 %Link{nodes: [%Text{literal: "MDEx Repository"}], url: "(https://github.com/leandrocp/mdex)", title: ""},
                 %SoftBreak{},
                 %Image{nodes: [%Text{literal: "Image"}], url: "https://placehold.co/400x100/green/white?text=Image", title: ""}
               ]
             },
             %Heading{nodes: [%Text{literal: "TODO"}], level: 2, setext: false}
           ] = Enum.reduce(chunks, MDEx.new(options), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
               num_rows: 0,
               num_nonempty_cells: 0
             }
           ] = Enum.reduce(chunks, MDEx.new(extension: [table: true]), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
               num_rows: 1,
               num_nonempty_cells: 1
             }
           ] = Enum.reduce(chunks, MDEx.new(extension: [table: true]), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
  end

  test "emoji" do
    chunks = [
      "# Emoji :r\n",
      "ocket: `:r\n",
      "ocket:`\n\n",
      ":smile:"
    ]

    assert [
             %MDEx.Heading{
               nodes: [
                 %MDEx.Text{literal: "Emoji "},
                 %MDEx.ShortCode{code: "rocket", emoji: "🚀"},
                 %MDEx.Text{literal: " "},
                 %MDEx.Code{num_backticks: 1, literal: ":rocket:"}
               ],
               level: 1,
               setext: false
             },
             %MDEx.Paragraph{nodes: [%MDEx.ShortCode{code: "smile", emoji: "😄"}]}
           ] = Enum.reduce(chunks, MDEx.new(extension: [shortcodes: true]), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
  end

  test "task list with formatting" do
    chunks = [
      "- [x] **Phase ",
      "1:** Setup\n",
      "- [ ] Testing"
    ]

    assert [
             %List{
               nodes: [
                 %TaskItem{
                   checked: true,
                   nodes: [
                     %Paragraph{
                       nodes: [
                         %Strong{
                           nodes: [
                             %Text{literal: "Phase"},
                             %Text{literal: " 1:"}
                           ]
                         },
                         %Text{literal: " Setup"}
                       ]
                     }
                   ]
                 },
                 %TaskItem{
                   checked: false,
                   nodes: [
                     %Paragraph{
                       nodes: [
                         %Text{literal: "Testing"}
                       ]
                     }
                   ]
                 }
               ]
             }
           ] = Enum.reduce(chunks, MDEx.new(extension: [tasklist: true]), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
  end

  test "task list retains emphasis across chunks" do
    options = [extension: [tasklist: true], parse: [relaxed_tasklist_matching: true]]

    chunks = [
      "- [x] Collect *n",
      "odes*\n"
    ]

    assert [
             %List{
               nodes: [
                 %TaskItem{
                   checked: true,
                   nodes: [
                     %Paragraph{
                       nodes: [
                         %Text{literal: "Collect "},
                         %Emph{
                           nodes: [
                             %Text{literal: "n"},
                             %Text{literal: "odes"}
                           ]
                         }
                       ]
                     }
                   ]
                 }
               ]
             }
           ] =
             Enum.reduce(chunks, MDEx.new(options), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
  end

  test "task list replaces previous states without duplication" do
    options = [extension: [tasklist: true], parse: [relaxed_tasklist_matching: true]]

    chunks = [
      "## TODO\n\n",
      "- [x] Collect *n",
      "odes*\n",
      "- [x] Collect heading\n",
      "- [x] Collect code\n",
      "- [ ] Collect table\n"
    ]

    document = Enum.reduce(chunks, MDEx.new(options), fn chunk, doc -> Enum.into([chunk], doc) end)

    assert [
             %Heading{nodes: [%Text{literal: "TODO"}], level: 2, setext: false},
             %List{
               nodes: [
                 %TaskItem{
                   checked: true,
                   nodes: [
                     %Paragraph{
                       nodes: [
                         %Text{literal: "Collect "},
                         %Emph{
                           nodes: [
                             %Text{literal: "n"},
                             %Text{literal: "odes"}
                           ]
                         }
                       ]
                     }
                   ]
                 },
                 %TaskItem{
                   checked: true,
                   nodes: [
                     %Paragraph{nodes: [%Text{literal: "Collect heading"}]}
                   ]
                 },
                 %TaskItem{
                   checked: true,
                   nodes: [
                     %Paragraph{nodes: [%Text{literal: "Collect code"}]}
                   ]
                 },
                 %TaskItem{
                   checked: false,
                   nodes: [
                     %Paragraph{nodes: [%Text{literal: "Collect table"}]}
                   ]
                 }
               ]
             }
           ] = document.nodes
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
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
             %Paragraph{
               nodes: [
                 %Text{literal: "First line"},
                 %Text{literal: "  \nSecond line"}
               ]
             }
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
  end

  test "escaped characters across chunks" do
    chunks = [
      "\\*not ital",
      "ic\\*"
    ]

    assert [
             %Paragraph{
               nodes: [
                 %Text{literal: "*not ital"},
                 %Text{literal: "ic*"}
               ]
             }
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
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
           ] = Enum.reduce(chunks, MDEx.new(), fn chunk, doc -> Enum.into([chunk], doc) end).nodes
  end
end
