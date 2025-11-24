Mix.install([
  {:phoenix_playground, "~> 0.1"},
  {:req_embed, "~> 0.3"},
  {:mdex, path: ".."}
])

defmodule MarkdownLive do
  use Phoenix.LiveView
  import MDEx.Sigil

  def mount(_params, _session, socket) do
    {:ok, assign(socket, count: 0)}
  end

  def render(assigns) do
    ~MD"""
    # Markdown Live :fire:

    ## Setup

    All you need to do is:

    1. Install MDEx:

    ```elixir
    def deps do
      [
        # Not yet released but soon!
        {:mdex, "~> 0.11"}
      ]
    end
    ```

    2. Render Markdown with HEEx support:

    ```elixir
    import MDEx.Sigil
    ~MD[# Today is {DateTime.utc_now()}]HEEX
    ```

    ## Demo

    Today is **{DateTime.utc_now()}**

    <span>{@count}</span>
    <button phx-click="inc">+</button>

    <ReqEmbed.embed url="https://www.youtube.com/watch?v=XfELJU1mRMg" class="aspect-video" />

    Built with:

    - <.link href="https://crates.io/crates/comrak">comrak</.link>
    - <.link href="https://hex.pm/packages/mdex">mdex</.link>

    _And more..._

    <style type="text/css">
      body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
        line-height: 1.6;
        color: #333;
        background-color: #f9fafb;
        padding: 2em;
        max-width: 900px;
        margin: 0 auto;
      }

      h1, h2, h3 {
        font-weight: 600;
        line-height: 1.2;
        margin-top: 1.5em;
        margin-bottom: 0.5em;
      }

      h1 {
        font-size: 2.5em;
        color: #1a202c;
        padding-bottom: 0.3em;
      }

      h2 {
        font-size: 1.8em;
        color: #2d3748;
        margin-top: 1.8em;
      }

      p {
        margin-bottom: 1em;
        font-size: 1.05em;
      }

      pre {
        padding: 1.5em;
        border-radius: 8px;
        overflow-x: auto;
        margin: 1.5em 0;
        font-family: 'Monaco', 'Courier New', monospace;
        font-size: 0.95em;
        line-height: 1.5;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
      }

      code {
        font-family: 'Monaco', 'Courier New', monospace;
        padding: 0.2em 0.4em;
        border-radius: 3px;
        font-size: 0.9em;
      }

      pre code {
        background-color: transparent;
        color: inherit;
        padding: 0;
      }

      button {
        padding: 0.2em 0.8em;
        cursor: pointer;
      }

      ul {
        margin: 1.5em 0;
        padding-left: 1.5em;
      }

      li {
        margin-bottom: 0.5em;
        font-size: 1.05em;
      }
    }
    </style>
    """HEEX
  end

  def handle_event("inc", _params, socket) do
    {:noreply, assign(socket, count: socket.assigns.count + 1)}
  end
end

PhoenixPlayground.start(live: MarkdownLive, open_browser: true)
