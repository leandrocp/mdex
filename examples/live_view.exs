Mix.install([
  {:mdex, path: ".."},
  {:phoenix_live_view, "~> 0.20"},
  {:phoenix_playground, "~> 0.1"}
])

defmodule MDEx.LiveView do
  # unescape HTML entities
  # https://github.com/sasa1977/erlangelist/blob/c5ddea9180732e56095b1a20b930dd5f686a62c0/site/lib/erlangelist/web/blog/code_highlighter.ex#L48-L62
  entities = [{"&amp;", ?&}, {"&lt;", ?<}, {"&gt;", ?>}, {"&quot;", ?"}, {"&#39;", ?'}]

  for {encoded, decoded} <- entities do
    def unescape_html(unquote(encoded) <> rest) do
      [unquote(decoded) | unescape_html(rest)]
    end
  end

  def unescape_html(<<c, rest::binary>>) do
    [c | unescape_html(rest)]
  end

  def unescape_html(<<>>) do
    []
  end

  # https://github.com/phoenixframework/phoenix_live_view/blob/1b1c9bc5e24fbb01dad24ce29279f852cf0ae6f6/lib/phoenix_component.ex#L791
  defmacro sigil_M({:<<>>, meta, [expr]}, []) do
    unless Macro.Env.has_var?(__CALLER__, {:assigns, nil}) do
      raise "~M requires a variable named \"assigns\" to exist and be set to a map"
    end

    md =
      expr
      # manipulate MDEx options here
      |> MDEx.to_html!()
      |> MDEx.LiveView.unescape_html()
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

    * `.link` with an @assign in `:patch` (see console logs) -  <.link patch={@path}>link to @path</.link>
    """
  end
end

PhoenixPlayground.start(live: DemoLive)
