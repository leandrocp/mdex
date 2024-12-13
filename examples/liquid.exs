Mix.install([
  {:mdex, path: ".."},
  {:solid, "~> 0.15"}
])

defmodule LiquidExample do
  def run do
    markdown = """
    # [Liquid](https://shopify.github.io/liquid/) Example

    ## Lang
    {{ lang.name | capitalize }}

    ## Projects {% assign projects = "phoenix, phoenix, live_view, beacon" | split: ", " %}
    {{ projects | uniq | join: ", " }}

    Updated at {{ "now" | date: "%Y-%m-%d %H:%M" }}
    """

    assigns = %{"lang" => %{"name" => "elixir"}}

    with {:ok, parsed} <- Solid.parse(markdown),
         {:ok, rendered} <- Solid.render(parsed, assigns) do
      binary = IO.iodata_to_binary(rendered)
      html = MDEx.to_html!(binary)
      File.write!("liquid.html", html)
      IO.puts(html)
    end
  end
end

LiquidExample.run()
