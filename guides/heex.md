# HEEx Integration

MDEx integrates with Phoenix LiveView's HEEx templates, allowing you to use Markdown alongside Phoenix components, `phx-*` bindings, and Elixir expressions.

## When to Use HEEx Integration

Use HEEx integration when you need:

- Phoenix components (like `<.link>`, `<.button>`, or custom components) inside Markdown
- LiveView bindings (`phx-click`, `phx-submit`, etc.)
- Elixir expressions that evaluate at runtime (`{@var}`)

For static Markdown without Phoenix components, use the regular `~MD[...]HTML` modifier or `MDEx.to_html/2` instead.

## Setup

Add `use MDEx` to your module to enable both `require MDEx` (for `to_heex/2`) and `import MDEx.Sigil` (for the `~MD` sigil):

```elixir
defmodule MyAppWeb.PageLive do
  use Phoenix.LiveView
  use MDEx

  # Now you can use ~MD[...]HEEX and MDEx.to_heex/2
end
```

## Two Approaches

### `~MD[...]HEEX` Sigil (Compile-time)

The preferred approach for LiveView templates. The Markdown is parsed at compile-time for optimal performance:

```elixir
def render(assigns) do
  ~MD"""
  # Welcome, {@username}!

  <.link href={@profile_url}>View Profile</.link>
  """HEEX
end
```

### `MDEx.to_heex/2` Macro (Runtime)

For dynamic content or when the sigil isn't available. The template is evaluated at runtime:

```elixir
def render(assigns) do
  markdown = fetch_markdown_from_database()

  MDEx.to_heex!(markdown, assigns: assigns)
end
```

Note: Calling `to_heex/2` repeatedly at runtime may impact performance. Prefer the sigil when possible.

## Using Assigns

Pass variables to your Markdown templates using the `{@var}` syntax:

```elixir
def render(assigns) do
  ~MD"""
  Welcome back, **{@user.name}**!

  You have {@notification_count} unread notifications.
  """HEEX
end
```

The old `<%= @var %>` EEx syntax also works for compatibility.

## Phoenix Components

Use any Phoenix component directly in your Markdown:

```elixir
~MD"""
# Navigation

- <.link navigate={~p"/home"}>Home</.link>
- <.link navigate={~p"/about"}>About</.link>

<.button phx-click="save">Save Changes</.button>

<MyAppWeb.Components.card title={@card_title}>
  Card content here
</MyAppWeb.Components.card>
"""HEEX
```

> #### Component imports are not automatic {: .info}
>
> MDEx does not automatically import components. To use function components with the dot notation:
>
> - Import `Phoenix.Component` for core components like `<.link>`
> - Import your app's components module (e.g., `import MyAppWeb.CoreComponents`)
> - Or use fully qualified names: `<Phoenix.Component.link href="/">Home</Phoenix.Component.link>`
>
> In Phoenix applications, `use MyAppWeb, :live_view` typically handles these imports for you.

## Elixir Expressions

Embed Elixir expressions using curly braces:

```elixir
~MD"""
Today is _{Calendar.strftime(DateTime.utc_now(), "%B %d, %Y")}_

<%= for item <- @items do %>
  - {item.name}: **{item.status}**
<% end %>
"""HEEX
```

## Converting HEEx to HTML String

When you need the final HTML as a string (e.g., for emails or static pages):

```elixir
MDEx.to_heex!(markdown, assigns: assigns)
|> MDEx.to_html!()
```

## Full Example

```elixir
defmodule MyAppWeb.BlogLive do
  use Phoenix.LiveView
  use MDEx

  def mount(_params, _session, socket) do
    {:ok, assign(socket, title: "My Post", likes: 42)}
  end

  def render(assigns) do
    ~MD"""
    # {@title}

    This post has **{@likes}** likes.

    <.button phx-click="like">Like this post</.button>

    ---

    Built with <.link href="https://hex.pm/packages/mdex">MDEx</.link>
    """HEEX
  end

  def handle_event("like", _, socket) do
    {:noreply, update(socket, :likes, &(&1 + 1))}
  end
end
```
