Mix.install([
  {:mdex, path: ".."},
  {:phoenix_live_view, "~> 0.20"},
  {:html_entities, "~> 0.5"}
])

defmodule MDEx.HEEx do
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
        HtmlEntities.decode(part)
      end
    end)
    |> Enum.join()
    |> IO.iodata_to_binary()
  end

  def to_html!(markdown, assigns \\ %{}) do
    opts = [
      extension: [
        strikethrough: true,
        tagfilter: true,
        table: true,
        tasklist: true,
        footnotes: true,
        shortcodes: true
      ],
      parse: [
        relaxed_tasklist_matching: true
      ],
      render: [
        unsafe_: true
      ]
    ]

    markdown
    |> MDEx.to_html!(opts)
    |> unescape()
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

    rendered
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
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

Elixir was created by José Valim.
"""

html = MDEx.HEEx.to_html!(markdown, %{path: "https://elixir-lang.org"})
File.write!("heex.html", html)
IO.puts(html)
