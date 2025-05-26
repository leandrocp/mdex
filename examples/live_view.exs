Mix.install([
  {:mdex, path: ".."},
  {:phoenix_live_view, "~> 1.0"},
  {:phoenix_playground, "~> 0.1"}
])

defmodule HEExExample do
  use Phoenix.LiveView
  import MDEx.Sigil

  def mount(_params, _session, socket) do
    {:ok, assign(socket, count: 0, url: "https://elixir-lang.org")}
  end

  def render(assigns) do
    ~MD"""
    # Phoenix HEEx Example

    ## Assigns

    `@url` = <%= @url %>

    ### `.link` with an @assign

    ```heex
    <.link href={@url}>link to elixir-lang</.link>
    ```

    <.link href={@url}>link to elixir-lang</.link>

    ### `.link` with `:href` expression

    ```heex
    <.link href={URI.parse("https://elixir-lang.org")}>link to elixir-lang</.link>
    ```

    <.link href={URI.parse("https://elixir-lang.org")}>link to elixir-lang</.link>

    ## Code Blocks

    ```php
    <?php echo 'Hello, World!'; ?>
    ```

    ```heex
    <%= @hello %>
    { @hello }
    ```

    ## Events

    Counter Example:

    <span><%= @count %></span>
    <button phx-click="inc">+</button>
    <button phx-click="dec">-</button>

    <style type="text/css">
      body { padding: 1em; }
    </style>
    """HEEX
  end

  def handle_event("inc", _params, socket) do
    {:noreply, assign(socket, count: socket.assigns.count + 1)}
  end

  def handle_event("dec", _params, socket) do
    {:noreply, assign(socket, count: socket.assigns.count - 1)}
  end
end

PhoenixPlayground.start(live: HEExExample)
