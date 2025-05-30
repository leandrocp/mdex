Mix.install([
  {:mdex, path: ".."}
])

defmodule HighlightExample do
  import MDEx.Sigil

  def run do
    opts = [
      render: [unsafe: true]
    ]

    markdown = ~MD"""
    # Highlight Example

    Transform double equal signals into `<mark>` tags as described at https://www.markdownguide.org/extended-syntax/#highlight

    ==Because== I need to highlight these ==very important words== and also these ==other words too==
    """

    document =
      Kernel.update_in(markdown, [:document, Access.key!(:nodes), Access.all(), :text], fn %MDEx.Text{literal: literal} ->
        # break each text literal into blocks separated by =={text}==
        case Regex.split(~r/==.*?==/, literal, include_captures: true, trim: true) do
          # single text means no == == found
          [text] ->
            %MDEx.Text{literal: text}

          # return HtmlBlock <mark> for each == or just text
          blocks ->
            blocks =
              Enum.map(blocks, fn
                "==" <> rest ->
                  marked_text = "<mark>" <> String.replace_suffix(rest, "==", "</mark>")
                  %MDEx.HtmlBlock{literal: marked_text}

                text ->
                  %MDEx.Text{literal: text}
              end)

            %MDEx.Paragraph{nodes: blocks}
        end
      end)

    html = MDEx.to_html!(document, opts)
    File.write!("highlight.html", html)
    IO.puts(html)
  end
end

HighlightExample.run()
