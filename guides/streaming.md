# Streaming

Markdown from LLM responses arrives a few tokens at a time. Rendering each chunk on its own produces broken HTML like unclosed `<strong>` tags, half-open code fences, and tables missing their closing pipes.

Streaming mode lets you feed those chunks into a document as they arrive and get valid output (HTML, etc) at every step. It buffers fragments, temporarily closes any open syntax before rendering, and when the next chunk arrives, replaces the temporary closings with real content.

## How it works

Three functions:

1. `MDEx.new(streaming: true)` - creates a document with a buffer and a fragment parser.
2. `MDEx.Document.put_markdown/2` - appends a chunk to the buffer. No parsing happens yet.
3. `MDEx.to_html!/1` (or any `MDEx.to_*`, or `MDEx.Document.run/1`) - flushes the buffer, closes open syntax, parses, renders.

The fragment parser keeps state between renders. Send `**Fol` and it produces `<strong>Fol</strong>`. Send `low**` next and it re-renders as `<strong>Follow</strong>`.

## Basic usage

```elixir
doc = MDEx.new(streaming: true)

# First chunk -- unclosed bold marker
doc = MDEx.Document.put_markdown(doc, "**Fol")
MDEx.to_html!(doc)
#=> "<p><strong>Fol</strong></p>"

# Second chunk closes it
doc = MDEx.Document.put_markdown(doc, "low**")
MDEx.to_html!(doc)
#=> "<p><strong>Follow</strong></p>"
```

Code fences, tables, lists, strikethrough, links -- same idea. The parser knows what's open and closes it until the real closing arrives.

## Piping chunks

```elixir
MDEx.new(streaming: true)
|> MDEx.Document.put_markdown("# Hel")
|> MDEx.Document.put_markdown("lo\n\nSome ")
|> MDEx.Document.put_markdown("**bold** text")
|> MDEx.to_html!()
#=> "<h1>Hello</h1>\n<p>Some <strong>bold</strong> text</p>"
```

## Using `Enum.into/2`

`MDEx.Document` implements `Collectable`, so you can collect string chunks:

```elixir
chunks = ["# Hel", "lo\n\n", "Some **bold** text"]

doc = Enum.into(chunks, MDEx.new(streaming: true))
MDEx.to_html!(doc)
#=> "<h1>Hello</h1>\n<p>Some <strong>bold</strong> text</p>"
```

Useful when you already have a list of chunks from an HTTP client or message queue.

## LiveView integration

If you're rendering an LLM response in a Phoenix LiveView, keep the document in assigns and append chunks as they arrive:

```elixir
defmodule MyAppWeb.ChatLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      document: MDEx.new(streaming: true),
      html: ""
    )}
  end

  def render(assigns) do
    ~H"""
    <div id="chat-output">{Phoenix.HTML.raw(@html)}</div>
    """
  end

  # Each chunk arrives as a message from your AI client
  def handle_info({:chunk, text}, socket) do
    document =
      socket.assigns.document
      |> MDEx.Document.put_markdown(text)

    html = MDEx.to_html!(document)

    {:noreply, assign(socket, document: document, html: html)}
  end

  def handle_info(:done, socket) do
    html = MDEx.to_html!(socket.assigns.document)
    {:noreply, assign(socket, html: html)}
  end
end
```

The document accumulates all chunks. Each `to_html!/1` call re-renders the full content with fragment completion applied.

## What gets completed

The fragment parser temporarily closes open syntax so every render produces valid output. It covers emphasis markers (`*`, `**`, `_`, `__`), code spans and fences, strikethrough (`~~`), highlight (`==`) and insert (`++`) markers, incomplete links and images, tables with missing pipes, partial list items, and math delimiters (`$`, `$$`).

## Options

Pass any standard MDEx options alongside `streaming: true`:

```elixir
MDEx.new(
  streaming: true,
  extension: [strikethrough: true, table: true, tasklist: true],
  render: [unsafe: true],
  syntax_highlight: [formatter: {:html_inline, theme: "github_light"}]
)
```

The fragment parser knows about extension syntax, so strikethrough and table constructs get completed correctly too.

## Demo

There's a full LiveView demo at `examples/streaming.exs` that simulates an AI response arriving chunk by chunk:

```bash
elixir examples/streaming.exs
```
