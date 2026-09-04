# Streaming Markdown

Two independent things are involved when Markdown arrives a piece at a time:

- **`MDEx.stream/2`** turns an Enumerable of chunks into keyed documents, so a UI
  updates only what changed.
- **`:auto_close`** closes Markdown syntax left open at the end of the source, so
  a half-written `**bold` renders as bold instead of literal asterisks. It is an
  option on every render, and on by default in `MDEx.stream/2`.

Use either on its own. If you already hold the whole response as a string and
only want it to render sensibly while it grows, you want `:auto_close`, not
`MDEx.stream/2`.

## `:auto_close`

```elixir
MDEx.to_html!("Some **bo")                     #=> "<p>Some **bo</p>"
MDEx.to_html!("Some **bo", auto_close: true)   #=> "<p>Some <strong>bo</strong></p>"
```

It closes emphasis, inline code, fenced blocks, links, images, tables, list
markers, and HTML tags. It works with every renderer and with
`MDEx.parse_document/2`, so AST transforms on partial source are possible too.

The trade-off is that a link whose URL is still arriving renders as a real link:

```elixir
MDEx.to_html!("a [x](htt", auto_close: true)   #=> ~s(<p>a <a href="htt">x</a></p>)
```

Pass `auto_close: false` if you would rather show the raw source until the
construct is finished, including inside `MDEx.stream/2`.

## `MDEx.stream/2`

The input is any `Enumerable` of binaries. The result is a lazy `Stream` of
`{id, %MDEx.Document{}}`. You do not manage parser state.

```elixir
chunks
|> MDEx.stream(extension: [table: true])
|> Enum.each(fn {id, document} ->
  replace_rendered_chunk(id, MDEx.to_html!(document))
end)
```

An id may appear more than once:

```elixir
{0, first}    # insert
{1, partial}  # insert
{0, revised}  # replace an earlier chunk
{1, final}    # replace at EOF if the AST changed
```

1. Insert a chunk when its id is new.
2. Replace a chunk when its id repeats. A replacement does not move it.
3. Any earlier id may repeat — a late link reference or footnote definition
   changes a block that was already emitted.
4. Normal Stream completion is EOF. There is no EOF chunk.

MDEx groups top-level nodes by source range, so a chunk may hold more than one
Markdown block and you never split Markdown yourself. Raw HTML that opens a
container across blocks stays in one keyed chunk. Emitted documents are
immutable. If the consumer stops early, MDEx does not read input it has not
reached.

### Collecting the final output

Keep the latest document per id and join them in order:

```elixir
html =
  chunks
  |> MDEx.stream()
  |> Stream.map(fn {id, document} -> {id, MDEx.to_html!(document)} end)
  |> Enum.into(%{})
  |> Enum.sort_by(&elem(&1, 0))
  |> Enum.map_join("\n", &elem(&1, 1))
```

### Transforming before rendering

Each emitted document holds a parsed AST — change it, do not parse it again:

```elixir
chunks
|> MDEx.stream()
|> Stream.map(fn {id, document} -> {id, MDEx.to_html!(rewrite_links(document))} end)
|> Enum.each(&update_output/1)
```

Apply the transform to every emitted chunk, including repeated ids.

A chunk is one keyed segment, not the whole response. Transforms that need the
whole document — a table of contents, ids unique across the response, numbering
shared by several chunks — need the complete source, or state you keep yourself
and reconcile when an id repeats.

## Sources

`File.stream!/1`, `Req`'s async body, and any other Enumerable work directly:

```elixir
"README.md" |> File.stream!([], 2048) |> MDEx.stream()

Req.get!(url, into: :self).body |> MDEx.stream(extension: [table: true])
```

Req cancels the request if the consumer stops early.

A chunk may split a UTF-8 code point. MDEx holds the incomplete bytes until the
next chunk. Invalid UTF-8 raises when the Stream reaches it, and so does an
incomplete code point at EOF.

### Sources that push

`MDEx.stream/2` pulls. When a source pushes instead — process messages, a
callback, PubSub fan-out — adapt it at the application boundary with
`Stream.resource/3`, and read it in a task rather than in a process that must
stay responsive:

```elixir
def new(source) do
  Stream.resource(
    fn ->
      ref = make_ref()
      {:ok, _subscription} = MyApp.Source.subscribe(source, self(), ref)
      ref
    end,
    fn ref ->
      receive do
        {:chunk, ^ref, chunk} -> {[chunk], ref}
        {:done, ^ref} -> {:halt, ref}
        {:error, ^ref, reason} -> raise "source failed: #{inspect(reason)}"
      end
    end,
    fn ref -> MyApp.Source.cancel(ref) end
  )
end
```

Tag messages with a unique reference so late messages from an earlier
subscription cannot be mixed in. The final callback runs when enumeration ends,
fails, or the consumer halts early.

`Stream.resource/3` does not make the producer demand-driven. If it outruns the
consumer, messages accumulate in the receiving process. Use the source's own
acknowledgement or pause mechanism when it has one, otherwise bound the buffer
yourself. Subscription, buffering, timeouts, and cancellation belong to the
source, which is why MDEx consumes a binary Stream rather than offering its own
push API.

## Phoenix LiveView

An MDEx id can be the id of a `Phoenix.LiveView.stream/4` entry. Configure the
`dom_id` before creating the LiveView stream:

```elixir
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> stream_configure(:markdown, dom_id: fn {id, _document} -> "markdown-#{id}" end)
   |> stream(:markdown, [])}
end
```

```heex
<div id="markdown" class="markdown-body" phx-update="stream">
  <div :for={{dom_id, {_id, document}} <- @streams.markdown} id={dom_id} class="contents">
    {Phoenix.HTML.raw(MDEx.to_html!(document))}
  </div>
</div>
```

Use `Phoenix.HTML.raw/1` only after applying the safety options your application
needs.

`Phoenix.LiveView.stream/4` reads its Enumerable inside the LiveView process, so
never hand it a long-running source. Read it in a task and forward each chunk:

```elixir
def start_markdown(socket, chunks) do
  live_view = self()

  start_async(socket, :markdown_producer, fn ->
    chunks
    |> MDEx.stream(@mdex_options)
    |> Enum.each(&send(live_view, {:markdown_chunk, &1}))
  end)
end

def handle_info({:markdown_chunk, chunk}, socket) do
  {:noreply, stream_insert(socket, :markdown, chunk)}
end
```

A repeated id updates the same DOM child in place without moving it, including
when a lower id repeats after a higher one was inserted. LiveView drops streamed
data from socket state after each render, so the source and MDEx state must stay
in the producer. `stream_async/4` does not forward chunks while its task runs.

Ids restart at `0` for each Stream run, so reset the LiveView stream when a new
response begins:

```elixir
socket = stream(socket, :markdown, [], reset: true)
```

For several concurrent responses, include a response id in each DOM id.

## Runnable example

[`examples/streaming.exs`](https://github.com/leandrocp/mdex/blob/main/examples/streaming.exs)
runs `Req` → `MDEx.stream/2` → `stream_insert/4` → `phx-update="stream"` with
Lumis highlighting, an adjustable delay, and live metrics:

```shell
elixir examples/streaming.exs
```

It enables `render: [unsafe: true]` so raw HTML in the fetched README is visible.
Use trusted URLs when reusing that setting.

## Options

`MDEx.stream/2` takes the same options as the other render functions:

```elixir
chunks
|> MDEx.stream(
  extension: [strikethrough: true, table: true, tasklist: true],
  syntax_highlight: [engine: :lumis, opts: [formatter: {:html_inline, theme: "github_light"}]],
  auto_close: false
)
|> Enum.each(&consume/1)
```

Plugins attach once when enumeration starts, and their steps run on every
emitted document, including repeated ids. Their parser options apply before
parsing, but their steps only ever see one keyed chunk. A plugin that
preprocesses `document.buffer` does not fit `MDEx.stream/2` — collect the full
source and use the one-document API instead.
