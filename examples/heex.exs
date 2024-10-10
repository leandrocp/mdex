Mix.install([
  {:mdex, path: ".."},
  {:phoenix_live_view, "~> 0.20"}
])

defmodule MDEx.HEEx do
  # unescape HTML entities
  # https://github.com/sasa1977/erlangelist/blob/c5ddea9180732e56095b1a20b930dd5f686a62c0/site/lib/erlangelist/web/blog/code_highlighter.ex#L48-L62
  entities = [{"&amp;", ?&}, {"&lt;", ?<}, {"&gt;", ?>}, {"&quot;", ?"}, {"&#39;", ?'}]

  for {encoded, decoded} <- entities do
    defp unescape_html(unquote(encoded) <> rest), do: [unquote(decoded) | unescape_html(rest)]
  end

  defp unescape_html(<<c, rest::binary>>), do: [c | unescape_html(rest)]
  defp unescape_html(<<>>), do: []

  # unescape all but <pre> tags
  # MDEx eventually should mark which tags must be preserved
  # instead of trying to guess it, but it works
  # for a simple example or for simple use cases
  defp unescape(html) do
    ~r/(<pre.*?<\/pre>)/s
    |> Regex.split(html, include_captures: true)
    |> Enum.map(fn part ->
      if String.starts_with?(part, "<pre") do
        part
      else
        unescape_html(part)
      end
    end)
    |> Enum.join()
  end

  def to_html!(markdown, assigns \\ %{}) do
    opts = [
      render: [unsafe_: true]
    ]

    markdown
    |> MDEx.to_html!(opts)
    |> unescape()
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

  defp env do
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

```php
<?php echo 'Hello, World!'; ?>
```

```heex
<%= @hello %>
```
"""

html = MDEx.HEEx.to_html!(markdown, %{path: "https://elixir-lang.org"})
File.write!("heex.html", html)
IO.puts(html)
