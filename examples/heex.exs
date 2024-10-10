Mix.install([
  {:mdex, path: ".."},
  {:phoenix_live_view, "~> 0.20"}
])

defmodule MDEx.HEEx do
  # unescape HTML entities
  # https://github.com/sasa1977/erlangelist/blob/c5ddea9180732e56095b1a20b930dd5f686a62c0/site/lib/erlangelist/web/blog/code_highlighter.ex#L48-L62
  entities = [{"&amp;", ?&}, {"&lt;", ?<}, {"&gt;", ?>}, {"&quot;", ?"}, {"&#39;", ?'}]

  for {encoded, decoded} <- entities do
    def unescape_html(unquote(encoded) <> rest), do: [unquote(decoded) | unescape_html(rest)]
  end

  def unescape_html(<<c, rest::binary>>), do: [c | unescape_html(rest)]
  def unescape_html(<<>>), do: []

  def to_html!(markdown, assigns \\ %{}) do
    opts = [
      render: [unsafe_: true],
      features: [sanitize: true]
    ]

    markdown
    |> MDEx.to_html!(opts)
    |> unescape_html()
    |> IO.iodata_to_binary()
    |> render_heex!(assigns)
  end

  defp render_heex!(html, assigns) do
    env = env()

    opts = [
      source: html,
      engine: Phoenix.LiveView.TagEngine,
      tag_handler: Phoenix.LiveView.HTMLEngine,
      file: "nofile",
      caller: env,
      line: 1,
      indentation: 0
    ]

    {rendered, _} =
      html
      |> EEx.compile_string(opts)
      |> Code.eval_quoted([assigns: assigns], env)

    Phoenix.HTML.Safe.to_iodata(rendered)
  end

  def env do
    import Phoenix.Component, warn: false
    __ENV__
  end
end

markdown = """
# Phoenix HEEx Example

## Examples

`@path = <%= @path %>`

* `.link` with `:href` expression - <.link href={URI.parse("https://elixir-lang.org")}>link to elixir-lang.org</.link>
* `.link` with an @assign - <.link href={@path}>link to @path</.link>
"""

html = MDEx.HEEx.to_html!(markdown, %{path: "https://elixir-lang.org"})
File.write!("heex.html", html)
IO.puts(html)