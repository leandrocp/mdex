Mix.install([
  {:mdex, path: ".."},
  {:phoenix_live_view, "~> 0.20"},
  {:phoenix_playground, "~> 0.1"},
  {:html_entities, "~> 0.5"}
])

defmodule MDEx.LiveView do
  # unescape all but <pre> tags
  # MDEx eventually should mark which tags must be preserved
  # instead of trying to guess it, but it works
  # for a simple example or for simple use cases
  def unescape(html) do
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
  end

  # https://github.com/phoenixframework/phoenix_live_view/blob/1b1c9bc5e24fbb01dad24ce29279f852cf0ae6f6/lib/phoenix_component.ex#L791
  defmacro sigil_M({:<<>>, meta, [expr]}, []) do
    unless Macro.Env.has_var?(__CALLER__, {:assigns, nil}) do
      raise "~M requires a variable named \"assigns\" to exist and be set to a map"
    end

    # manipulate MDEx options here
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

    md =
      expr
      |> MDEx.to_html!(opts)
      |> MDEx.LiveView.unescape()
      |> IO.iodata_to_binary()

    options = [
      engine: Phoenix.LiveView.TagEngine,
      file: __CALLER__.file,
      line: __CALLER__.line + 1,
      caller: __CALLER__,
      indentation: meta[:indentation] || 0,
      source: md,
      tag_handler: Phoenix.LiveView.HTMLEngine
    ]

    EEx.compile_string(md, options)
  end
end

defmodule DemoLive do
  use Phoenix.LiveView
  use Phoenix.Component
  import MDEx.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket, path: "/?hello=world")}
  end

  def handle_params(_params, uri, socket) do
    IO.puts("Received a patch request to #{uri}")
    {:noreply, socket}
  end

  def render(assigns) do
    ~M"""
    # Phoenix LiveView Example

    Convert this markdown into a [Phoenix.LiveView.Rendered](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Rendered.html) struct.

    ## Examples

    * `.link` with `:href` expression - <.link href={URI.parse("https://elixir-lang.org")}>link to elixir-lang.org</.link>
    * `.link` with an @assign in `:patch` (see console logs) - <.link patch={@path}>link to @path</.link>

    ```php
    <?php echo 'Hello, World!'; ?>
    ```

    ```heex
    <%= @hello %>
    ```

    Elixir was created by José Valim.
    """
  end
end

PhoenixPlayground.start(live: DemoLive)
