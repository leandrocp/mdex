Mix.install([
  {:mdex, path: ".."},
  {:solid, "~> 0.15"}
])

markdown = """
# [Liquid](https://shopify.github.io/liquid/) Example

{{ lang.name | capitalize }}
"""

assigns = %{"lang" => %{"name" => "elixir"}}

html =
  markdown
  |> MDEx.parse_document!()
  |> MDEx.traverse_and_update(fn
    # render each text as liquid template
    {node, attrs, children} ->
      children =
        Enum.reduce(children, [], fn
          child, acc when is_binary(child) ->
            with {:ok, template} <- Solid.parse(child),
                 {:ok, rendered} <- Solid.render(template, assigns) do
              [to_string(rendered) | acc]
            else
              _ -> [child | acc]
            end

          child, acc ->
            [child | acc]
        end)
        |> Enum.reverse()

      {node, attrs, children}
  end)
  |> MDEx.to_html!()

File.write!("liquid.html", html)

IO.puts(html)
