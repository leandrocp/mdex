Mix.install([:req, :benchee, :earmark, :md, :cmark, :mdex])

defmodule Benchmark do
  @markdown """
  # CommonMark Sample Document

  This is a **sample document** written in _CommonMark_ to test Markdown parsers.

  ## Headers

  # H1 Header
  ## H2 Header
  ### H3 Header
  #### H4 Header
  ##### H5 Header
  ###### H6 Header

  ## Emphasis

  - *Italic*
  - _Italic_
  - **Bold**
  - __Bold__
  - ***Bold and italic***
  - ___Bold and italic___

  ## Lists

  ### Unordered

  - Item 1
    - Subitem 1.1
      - Subitem 1.1.1
  - Item 2

  ### Ordered

  1. First
  2. Second
     1. Second.A
     2. Second.B
  3. Third

  ## Links and Images

  [CommonMark](https://commonmark.org)

  ![CommonMark Logo](https://commonmark.org/help/images/logo-small.png)

  ## Code

  Inline \`code\` and blocks:

  \```
  def hello_world():
      print("Hello, world!")
  \```

  Indented code block:

      function test() {
          return true;
      }

  ## Blockquotes

  > This is a blockquote.
  >
  > > Nested blockquote.

  ## Horizontal Rule

  ---

  ## Tables

  | Syntax    | Description |
  |-----------|-------------|
  | Header    | Title       |
  | Paragraph | Text        |

  ## HTML

  <div style="color: red;">This is raw HTML</div>

  ## Escaping

  \*Not italic\* and \# Not a header

  ## Hard Line Breaks

  Roses are red,
  Violets are blue.

  ## Task List (GitHub-Flavored Markdown)

  - [x] Task completed
  - [ ] Task not completed

  ---

  *The end.*
  """

  def run do
    Benchee.run(%{
      "earmark" => fn -> Earmark.as_html(@markdown) end,
      "md" => fn -> Md.generate(@markdown) end,
      "cmark" => fn -> Cmark.to_html(@markdown) end,
      "mdex_to_html/1" => fn -> MDEx.to_html(@markdown, syntax_highlight: nil) end,
      "mdex_sigil_MD" => fn ->
        import MDEx.Sigil

        ~MD"""
        # CommonMark Sample Document

        This is a **sample document** written in _CommonMark_ to test Markdown parsers.

        ## Headers

        # H1 Header
        ## H2 Header
        ### H3 Header
        #### H4 Header
        ##### H5 Header
        ###### H6 Header

        ## Emphasis

        - *Italic*
        - _Italic_
        - **Bold**
        - __Bold__
        - ***Bold and italic***
        - ___Bold and italic___

        ## Lists

        ### Unordered

        - Item 1
          - Subitem 1.1
            - Subitem 1.1.1
        - Item 2

        ### Ordered

        1. First
        2. Second
           1. Second.A
           2. Second.B
        3. Third

        ## Links and Images

        [CommonMark](https://commonmark.org)

        ![CommonMark Logo](https://commonmark.org/help/images/logo-small.png)

        ## Code

        Inline \`code\` and blocks:

        \```
        def hello_world():
            print("Hello, world!")
        \```

        Indented code block:

            function test() {
                return true;
            }

        ## Blockquotes

        > This is a blockquote.
        >
        > > Nested blockquote.

        ## Horizontal Rule

        ---

        ## Tables

        | Syntax    | Description |
        |-----------|-------------|
        | Header    | Title       |
        | Paragraph | Text        |

        ## HTML

        <div style="color: red;">This is raw HTML</div>

        ## Escaping

        \*Not italic\* and \# Not a header

        ## Hard Line Breaks

        Roses are red,
        Violets are blue.

        ## Task List (GitHub-Flavored Markdown)

        - [x] Task completed
        - [ ] Task not completed

        ---

        *The end.*
        """
      end
    })
  end
end

Benchmark.run()
