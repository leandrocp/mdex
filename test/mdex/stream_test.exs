defmodule MDEx.StreamTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias MDEx.Document

  # alias MDEx.BlockQuote
  alias MDEx.Code
  alias MDEx.CodeBlock
  alias MDEx.Emph
  alias MDEx.Heading
  alias MDEx.HtmlBlock
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

  defp streaming_document(options \\ []) do
    options
    |> MDEx.new()
    |> MDEx.Document.put_private(:fragment_completion, true)
  end

  defp nodes(chunks, document \\ streaming_document()) do
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
           ] = nodes(chunks, streaming_document(extension: [strikethrough: true]))
  end

  test "simple insert" do
    chunks = [
      "++inserted ",
      "text++"
    ]

    assert [
             %Paragraph{
               nodes: [
                 %MDEx.Insert{nodes: [%Text{literal: "inserted text"}]}
               ]
             }
           ] = nodes(chunks, streaming_document(extension: [insert: true]))
  end

  test "simple highlight" do
    chunks = [
      "==marked ",
      "text=="
    ]

    assert [
             %Paragraph{
               nodes: [
                 %MDEx.Highlight{nodes: [%Text{literal: "marked text"}]}
               ]
             }
           ] = nodes(chunks, streaming_document(extension: [highlight: true]))
  end

  test "incomplete insert across chunks" do
    chunks = [
      "++inserted ",
      "text"
    ]

    assert [
             %Paragraph{
               nodes: [
                 %MDEx.Insert{nodes: [%Text{literal: "inserted text"}]}
               ]
             }
           ] = nodes(chunks, streaming_document(extension: [insert: true]))
  end

  test "incomplete highlight across chunks" do
    chunks = [
      "==marked ",
      "text"
    ]

    assert [
             %Paragraph{
               nodes: [
                 %MDEx.Highlight{nodes: [%Text{literal: "marked text"}]}
               ]
             }
           ] = nodes(chunks, streaming_document(extension: [highlight: true]))
  end

  test "simple subtext" do
    chunks = [
      "-# Some ",
      "Subtext"
    ]

    assert [
             %MDEx.Subtext{
               nodes: [
                 %Text{literal: "Some Subtext"}
               ]
             }
           ] = nodes(chunks, streaming_document(extension: [subtext: true]))
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

  test "incomplete link label crossing newline stays as text" do
    chunks = [
      "[foo\nbar"
    ]

    assert [
             %MDEx.Paragraph{
               nodes: [
                 %Text{literal: "[foo"},
                 %SoftBreak{},
                 %Text{literal: "bar"}
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
               nodes: [
                 %MDEx.Link{
                   url: "https://commonmark",
                   nodes: [%MDEx.Text{literal: "CommonMark spec"}]
                 }
               ]
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

  test "table header" do
    chunks = ["| Lang | Version |\n"]

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
           ] = nodes(chunks, streaming_document(extension: [table: true]))
  end

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
           ] = nodes(chunks, streaming_document(extension: [table: true]))
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
           ] = nodes(chunks, streaming_document(extension: [table: true]))
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

  test "task list with formatting" do
    chunks = [
      "- [x] **Phase ",
      "1:** Setup\n",
      "- [ ] Testing"
    ]

    options = [
      extension: [tasklist: true],
      parse: [relaxed_tasklist_matching: true]
    ]

    assert [
             %List{
               nodes: [
                 %MDEx.TaskItem{
                   checked: true,
                   nodes: [
                     %Paragraph{
                       nodes: [
                         %Strong{
                           nodes: [
                             %Text{literal: "Phase 1:"}
                           ]
                         },
                         %Text{literal: " Setup"}
                       ]
                     }
                   ]
                 },
                 %MDEx.TaskItem{
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
           ] = nodes(chunks, streaming_document(options))
  end

  test "task list retains emphasis across chunks" do
    options = [
      extension: [tasklist: true],
      parse: [relaxed_tasklist_matching: true]
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
             nodes(chunks, streaming_document(options))
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

  test "autolink detection across chunks" do
    chunks = [
      "Visit https://common",
      "mark.org for specs"
    ]

    assert [
             %Paragraph{
               nodes: [
                 %Text{literal: "Visit "},
                 %MDEx.Link{
                   url: "https://commonmark.org",
                   nodes: [%Text{literal: "https://commonmark.org"}]
                 },
                 %Text{literal: " for specs"}
               ]
             }
           ] = nodes(chunks, streaming_document(extension: [autolink: true]))
  end

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

  describe "space-flanked asterisk (not emphasis)" do
    test "arithmetic expression with * stays unchanged" do
      chunks = ["5 * 0 = ?"]

      assert [
               %Paragraph{nodes: [%Text{literal: "5 * 0 = ?"}]}
             ] = nodes(chunks)
    end

    test "multiple space-flanked * stays unchanged" do
      chunks = ["2 * 3 ", "* 4"]

      assert [
               %Paragraph{nodes: [%Text{literal: "2 * 3 * 4"}]}
             ] = nodes(chunks)
    end
  end

  describe "incomplete HTML tag stripping" do
    test "incomplete tag at end is stripped" do
      chunks = ["Hello <div"]

      assert [
               %Paragraph{nodes: [%Text{literal: "Hello"}]}
             ] = nodes(chunks)
    end

    test "complete tag is preserved" do
      chunks = ["<br> hello"]

      assert [
               %Paragraph{nodes: [%MDEx.HtmlInline{literal: "<br>"}, %Text{literal: " hello"}]}
             ] = nodes(chunks)
    end
  end

  describe "proper nesting order for multiple unclosed markers" do
    test "**bold _under closes inner first" do
      chunks = ["**bold _under"]

      assert [
               %Paragraph{
                 nodes: [
                   %Strong{nodes: [%Text{literal: "bold "}, %Emph{nodes: [%Text{literal: "under"}]}]}
                 ]
               }
             ] = nodes(chunks)
    end
  end

  describe "multi-flush streaming (run between chunks)" do
    # These tests exercise the fragment_state persistence across
    # multiple run() calls, unlike the nodes() helper which buffers
    # all chunks and flushes once.

    defp multi_flush_nodes(chunks, document) do
      Enum.reduce(chunks, document, fn chunk, doc ->
        Enum.into([chunk], doc)
        |> MDEx.Document.run()
      end)
      |> Map.get(:nodes)
    end

    test "fragment state tracks unclosed token across flushes" do
      doc = streaming_document()

      # First flush: ** opens bold, FragmentParser completes it
      doc = Enum.into(["**bold "], doc) |> MDEx.Document.run()
      state = MDEx.Document.get_private(doc, :fragment_state)
      assert %MDEx.FragmentParser.State{last_unclosed_token: "**"} = state
    end

    test "complete link then more text across flushes" do
      assert [
               %Paragraph{nodes: nodes}
             ] =
               multi_flush_nodes(
                 ["[click](https://example.com) ", "more text"],
                 streaming_document()
               )

      assert %MDEx.Link{url: "https://example.com"} = hd(nodes)
    end

    test "code block complete in single flush then text" do
      assert [
               %CodeBlock{literal: "hello\n"},
               %Paragraph{nodes: [%Text{literal: "after"}]}
             ] =
               multi_flush_nodes(
                 ["```\nhello\n```\n", "after"],
                 streaming_document()
               )
    end

    test "plain text across multiple flushes" do
      assert [
               %Paragraph{nodes: nodes}
             ] =
               multi_flush_nodes(
                 ["Hello ", "world ", "!"],
                 streaming_document()
               )

      text =
        Enum.map_join(nodes, "", fn
          %Text{literal: t} -> t
          %SoftBreak{} -> " "
        end)

      assert text =~ "Hello"
      assert text =~ "world"
    end

    test "continues trailing html block without injecting a newline" do
      assert [
               %HtmlBlock{literal: "<div>foobar</div>"}
             ] =
               multi_flush_nodes(
                 ["<div>foo", "bar</div>"],
                 streaming_document()
               )
    end

    test "preserves incomplete html across multiple flushes" do
      assert [
               %HtmlBlock{literal: "<div>foo</div>"}
             ] =
               multi_flush_nodes(
                 ["<div", ">foo<", "/div>"],
                 streaming_document()
               )
    end

    test "continues trailing title" do
      assert [
               %Heading{nodes: [%Text{literal: "Title"}]}
             ] =
               multi_flush_nodes(
                 ["# Tit", "le"],
                 streaming_document()
               )
    end
  end

  test "deprecates the MDEx.new streaming option while preserving compatibility" do
    warning =
      capture_io(:stderr, fn ->
        document = MDEx.new(streaming: true) |> Document.put_markdown("**partial")
        assert MDEx.to_html!(document) == "<p><strong>partial</strong></p>"
      end)

    assert warning =~ "the :streaming option is deprecated"
    assert warning =~ "MDEx.stream/2"
  end

  test "returns a native lazy Stream" do
    parent = self()

    chunks =
      Stream.resource(
        fn ->
          send(parent, :started)
          ["# One", "\n\nTwo"]
        end,
        fn
          [chunk | rest] -> {[chunk], rest}
          [] -> {:halt, []}
        end,
        fn _state -> send(parent, :closed) end
      )

    stream = MDEx.stream(chunks)

    assert %Stream{} = stream
    refute_received :started

    assert [{0, %Document{}}] = Enum.take(stream, 1)
    assert_received :started
    assert_received :closed
  end

  test "emits keyed tail replacements and finalizes at EOF" do
    events =
      ["# Hel", "lo\n\nNow **wri", "ting**"]
      |> MDEx.stream()
      |> Enum.map(fn {id, document} -> {id, MDEx.to_html!(document)} end)

    assert events == [
             {0, "<h1>Hel</h1>"},
             {0, "<h1>Hello</h1>"},
             {1, "<p>Now <strong>wri</strong></p>"},
             {1, "<p>Now <strong>writing</strong></p>"},
             {1, "<p>Now <strong>writing</strong></p>"}
           ]
  end

  test "emits no chunks for empty input" do
    assert [] = Enum.to_list(MDEx.stream([]))
    assert [] = Enum.to_list(MDEx.stream([""]))
  end

  test "buffers UTF-8 code points divided across chunks" do
    events = MDEx.stream(["ol", <<0xC3>>, <<0xA1>>, "\n\n# Next"])

    assert final_html(events) == MDEx.to_html!("olá\n\n# Next")
  end

  test "raises lazily for incomplete or invalid UTF-8" do
    incomplete = MDEx.stream(["ol", <<0xC3>>])
    invalid = MDEx.stream([<<0xFF>>])

    assert %Stream{} = incomplete

    assert_raise ArgumentError, ~r/end-of-input with incomplete UTF-8/, fn ->
      Enum.to_list(incomplete)
    end

    assert_raise ArgumentError, ~r/received invalid UTF-8/, fn ->
      Enum.to_list(invalid)
    end
  end

  test "raises lazily when the source emits a non-binary" do
    stream = MDEx.stream(["valid", :not_a_binary])

    assert_raise ArgumentError, ~r/expected a binary chunk/, fn ->
      Enum.to_list(stream)
    end
  end

  test "can be enumerated again when its source is repeatable" do
    stream = MDEx.stream(["# One\n\n", "Two"])

    assert Enum.map(stream, &elem(&1, 0)) == Enum.map(stream, &elem(&1, 0))
    assert final_html(stream) == MDEx.to_html!("# One\n\nTwo")
  end

  test "stops requesting upstream chunks when downstream halts" do
    parent = self()

    chunks =
      Stream.resource(
        fn -> 0 end,
        fn
          0 ->
            {["**fir"], 1}

          1 ->
            send(parent, :requested_unseen_chunk)
            {["st**"], 2}

          2 ->
            {:halt, 2}
        end,
        fn _state -> send(parent, :source_closed) end
      )

    assert [{0, document}] = chunks |> MDEx.stream() |> Enum.take(1)
    assert MDEx.to_html!(document) == "<p><strong>fir</strong></p>"
    refute_received :requested_unseen_chunk
    assert_received :source_closed
  end

  test "propagates upstream failures and closes the source" do
    parent = self()

    chunks =
      Stream.resource(
        fn -> 0 end,
        fn
          0 -> {["# Started"], 1}
          1 -> raise "upstream failed"
        end,
        fn _state -> send(parent, :source_closed) end
      )

    assert_raise RuntimeError, "upstream failed", fn ->
      chunks |> MDEx.stream() |> Enum.to_list()
    end

    assert_received :source_closed
  end

  test "applies parser options and preserves final rendering across chunk boundaries" do
    options = [extension: [strikethrough: true, table: true, tasklist: true]]

    markdown = """
    # Status

    - [x] ~~prototype~~ Stream

    | API | Value |
    | --- | --- |
    | input | Enumerable |
    """

    chunks = ["# Sta", "tus\n\n- [x] ~~proto", "type~~ Stream\n\n| API |", " Value |\n| --- | --- |\n| input | Enumerable |\n"]

    events = MDEx.stream(chunks, options)

    assert final_html(events) == MDEx.to_html!(markdown, options)
    assert Enum.all?(events, fn {_id, document} -> document.buffer == [] end)
  end

  test "matches the final put_markdown document for document-wide constructs" do
    options = [extension: [table: true]]

    cases = [
      ["- one\n\n", "- two\n\n"],
      ["~~~~\nalpha\n\n", "beta\n~~~~\n"],
      ["Read [the docs].\n\nNext paragraph.\n\n", "[the docs]: https://example.com\n"],
      ["| Name | Value |\n| --- | --- |\n|", " mdex | Stream |\n"]
    ]

    for chunks <- cases do
      document =
        Enum.reduce(chunks, MDEx.new(options), fn chunk, document ->
          Document.put_markdown(document, chunk)
        end)
        |> Document.run()

      assert final_html(MDEx.stream(chunks, options)) == MDEx.to_html!(document)
    end
  end

  test "derives blank block boundaries from parser source positions" do
    for separator <- ["\n\n", "\n \t\n", "\r\n\r\n", "\r\n \t\r\n"] do
      events = Enum.to_list(MDEx.stream(["First#{separator}Second"]))

      assert [{0, first}, {1, partial_second}, {1, final_second}] = events
      assert MDEx.to_html!(first) == "<p>First</p>"
      assert MDEx.to_html!(partial_second) == "<p>Second</p>"
      assert MDEx.to_html!(final_second) == "<p>Second</p>"
      refute Enum.any?(events, fn {_id, document} -> Keyword.has_key?(document.options, :streaming) end)
    end

    assert [{0, joined}, {0, finalized}] = Enum.to_list(MDEx.stream(["First\nSecond"]))
    assert MDEx.to_html!(joined) == "<p>First\nSecond</p>"
    assert MDEx.to_html!(finalized) == "<p>First\nSecond</p>"
  end

  test "re-emits an earlier id when document-wide syntax changes its AST" do
    reference_events =
      Enum.to_list(
        MDEx.stream([
          "Read [the docs].\n\nAnother paragraph.\n\nTail.\n\n",
          "[the docs]: https://example.com\n"
        ])
      )

    assert [{0, unresolved}, {1, tail}, {0, linked}, {1, final_tail}] = reference_events
    assert MDEx.to_html!(unresolved) =~ "<p>Read [the docs].</p>"
    assert MDEx.to_html!(linked) =~ ~s(<a href="https://example.com">the docs</a>)
    assert MDEx.to_html!(tail) == "<p>Tail.</p>"
    assert MDEx.to_html!(final_tail) == MDEx.to_html!(tail)

    ids = Enum.map(reference_events, &elem(&1, 0))
    assert ids == [0, 1, 0, 1]
  end

  test "preserves a late footnote definition across keyed documents" do
    chunks = [
      "Fact.[^note]\n\nAnother paragraph.\n\n",
      "[^note]: More context.\n"
    ]

    options = [extension: [footnotes: true]]
    events = Enum.to_list(MDEx.stream(chunks, options))

    assert Enum.count(events, fn {id, _document} -> id == 0 end) == 2
    assert final_html(events) == MDEx.to_html!(Enum.join(chunks), options)
    assert final_html(events) =~ ~s(<section class="footnotes")
  end

  test "does not treat task items as link references" do
    task_events =
      Enum.to_list(MDEx.stream(["- [x] done\n\nNext"], extension: [tasklist: true]))

    assert [{0, task}, {1, next}, {1, final_next}] = task_events
    assert MDEx.to_html!(task) =~ ~s(type="checkbox" checked="")
    assert MDEx.to_html!(next) == "<p>Next</p>"
    assert MDEx.to_html!(final_next) == "<p>Next</p>"
  end

  test "parses the cumulative source once per input chunk and once at EOF" do
    source = "First **bold**\n\nSecond `code`\n\n- Third\n  - nested **strong**"

    {calls, events} =
      trace_parser_calls(fn ->
        Enum.to_list(MDEx.stream([source]))
      end)

    assert calls == [:parse_document, :parse_document]
    assert [{0, stable}, {1, _partial}, {1, final}] = events
    assert stable.nodes == MDEx.parse_document!("First **bold**\n\nSecond `code`\n\n").nodes
    assert MDEx.to_html!(final) == MDEx.to_html!("- Third\n  - nested **strong**")
    assert [%MDEx.List{sourcepos: %{start: {5, 1}}}] = final.nodes
  end

  test "allows each streamed AST to be changed before rendering" do
    chunks = [
      "Intro [site](https://example.com/a",
      ").\n\nRead [the docs].\n\n",
      "[the docs]: https://example.com/docs\n"
    ]

    rewrite_links = fn document ->
      Document.update_nodes(document, MDEx.Link, fn link ->
        %{link | url: "https://proxy.test/?target=" <> URI.encode_www_form(link.url)}
      end)
    end

    transformed_events =
      chunks
      |> MDEx.stream()
      |> Enum.map(fn {id, document} -> {id, rewrite_links.(document)} end)

    expected =
      chunks
      |> Enum.join()
      |> MDEx.parse_document!()
      |> rewrite_links.()
      |> MDEx.to_html!()

    assert final_html(transformed_events) == expected

    assert Enum.any?(transformed_events, fn {_id, document} ->
             MDEx.to_html!(document) =~ "https://proxy.test/?target=https%3A%2F%2Fexample.com%2Fdocs"
           end)
  end

  test "runs document plugins on reused stable and EOF ASTs" do
    rewrite_links = fn document ->
      Document.append_steps(document,
        rewrite_links: fn document ->
          Document.update_nodes(document, MDEx.Link, fn link ->
            %{link | url: "https://proxy.test/?target=" <> URI.encode_www_form(link.url)}
          end)
        end
      )
    end

    events =
      Enum.to_list(
        MDEx.stream(
          ["[one](https://example.com/one)\n\n[two](https://example.com/two)"],
          plugins: [rewrite_links]
        )
      )

    assert [{0, stable}, {1, _partial}, {1, final}] = events
    assert MDEx.to_html!(stable) =~ "target=https%3A%2F%2Fexample.com%2Fone"
    assert MDEx.to_html!(final) =~ "target=https%3A%2F%2Fexample.com%2Ftwo"
  end

  test "attaches plugins once and applies their parser options before parsing" do
    test_process = self()

    plugin = fn document ->
      send(test_process, :plugin_attached)

      document
      |> Document.put_extension_options(table: true)
      |> Document.append_steps(
        plugin_step: fn document ->
          send(test_process, :plugin_step_ran)
          document
        end
      )
    end

    stream =
      MDEx.stream(
        ["| A |\n| --- |\n| B |\n\nTail"],
        plugins: [plugin]
      )

    refute_received :plugin_attached
    events = Enum.to_list(stream)

    assert [{0, stable}, {1, _partial}, {1, final}] = events
    assert MDEx.to_html!(stable) =~ "<table>"
    assert MDEx.to_html!(final) == "<p>Tail</p>"

    assert_received :plugin_attached
    refute_received :plugin_attached

    for _event <- events do
      assert_received :plugin_step_ran
    end

    refute_received :plugin_step_ran
  end

  defp final_html(events) do
    {ids, documents} =
      Enum.reduce(events, {[], %{}}, fn {id, document}, {ids, documents} ->
        ids = if Map.has_key?(documents, id), do: ids, else: ids ++ [id]
        {ids, Map.put(documents, id, document)}
      end)

    Enum.map_join(ids, "\n", fn id -> documents |> Map.fetch!(id) |> MDEx.to_html!() end)
  end

  defp trace_parser_calls(fun) do
    Elixir.Code.ensure_loaded!(MDExNative.Comrak)
    tracee = self()
    tracer = spawn_link(fn -> collect_parser_calls([]) end)

    :erlang.trace(tracee, true, [:call, {:tracer, tracer}])
    :erlang.trace_pattern({MDExNative.Comrak, :parse_document, 2}, true, [:local])

    on_exit(fn ->
      :erlang.trace_pattern({MDExNative.Comrak, :parse_document, 2}, false, [:local])
      Process.exit(tracer, :kill)
    end)

    result = fun.()
    :erlang.trace(tracee, false, [:call])
    reference = :erlang.trace_delivered(tracee)
    assert_receive {:trace_delivered, ^tracee, ^reference}
    send(tracer, {:get_calls, self()})
    assert_receive {:parser_calls, calls}
    {calls, result}
  end

  defp collect_parser_calls(calls) do
    receive do
      {:trace, _pid, :call, {MDExNative.Comrak, name, _args}} ->
        collect_parser_calls([name | calls])

      {:get_calls, caller} ->
        send(caller, {:parser_calls, Enum.reverse(calls)})
    end
  end
end
