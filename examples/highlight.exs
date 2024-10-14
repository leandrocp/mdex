Mix.install([
  {:mdex, path: ".."}
])

opts = [
  render: [unsafe_: true]
]

markdown = """
# Highlight Example

Transform double equal signals into `<mark>` tags as described at https://www.markdownguide.org/extended-syntax/#highlight

==Because== I need to highlight these ==very important words== and also these ==other words too==
"""

ast =
  markdown
  |> MDEx.parse_document!()
  |> MDEx.traverse_and_update(fn
    # wrap each pair of == with <mark> tags
    {node, attrs, children} ->
      children =
        Enum.reduce(children, [], fn
          child, _acc when is_binary(child) ->
            new =
              Regex.split(~r/==.*?==/, child, include_captures: true, trim: true)
              |> Enum.map(fn
                "==" <> rest ->
                  marked_text = "<mark>" <> String.replace_suffix(rest, "==", "</mark>")
                  {"html_block", %{"literal" => marked_text}, []}

                text ->
                  text
              end)

            Enum.reverse(new)

          child, acc ->
            [child | acc]
        end)
        |> Enum.reverse()

      {node, attrs, children}
  end)

html = MDEx.to_html!(ast, opts)

File.write!("highlight.html", html)

IO.puts(html)
