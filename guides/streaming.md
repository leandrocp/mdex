# Streaming Markdown

Use `MDEx.stream/2` when Markdown arrives in chunks from an LLM, file, or HTTP
response.

```elixir
chunks
|> MDEx.stream(options)
|> Enum.each(&consume/1)
```

The input is any `Enumerable` of binaries. The result is a lazy Elixir
`Stream`. MDEx parses each update and emits keyed documents:

```elixir
{id, %MDEx.Document{}}
```

The caller does not need to manage parser state.

## Output contract

Each document is parsed and ready to render. Render it in the format your
application needs:

```elixir
chunks
|> MDEx.stream(extension: [table: true])
|> Stream.map(fn {id, document} ->
  {id, MDEx.to_html!(document)}
end)
|> Enum.each(&update_output/1)
```

An id may appear more than once:

```elixir
{0, first_document}         # insert
{1, partial_document}       # insert
{0, updated_first_document} # replace an earlier chunk
{1, final_document}         # replace the open chunk at EOF
```

Apply these rules:

1. Insert a chunk when its id is new.
2. Replace a chunk when its id repeats.
3. Keep chunks in id order. A replacement does not move its chunk.
4. Any earlier id may repeat. Document-wide Markdown can change an earlier AST.
5. Normal Stream completion is EOF. There is no custom EOF chunk.

A chunk may contain more than one Markdown block. MDEx groups top-level nodes
by source range so consumers do not need to split Markdown themselves.
When raw HTML opens a container across Markdown blocks, MDEx keeps the whole
container in one keyed chunk. This keeps keyed DOM children independent when
`render: [unsafe: true]` is enabled.

MDEx emits a new immutable document for each update. It does not change a
document that it already emitted.

If the consumer stops early, MDEx does not parse input it has not read.

## Change the AST before rendering

Each emitted `%MDEx.Document{}` contains a parsed AST. You can change its nodes
before rendering it. Do not call `MDEx.parse_document!/2` again.

This example sends external links through a redirect service:

```elixir
def rewrite_links(document) do
  MDEx.Document.update_nodes(document, MDEx.Link, fn link ->
    url = "https://example.test/redirect?to=" <> URI.encode_www_form(link.url)
    %{link | url: url}
  end)
end

chunks
|> MDEx.stream()
|> Stream.map(fn {id, document} ->
  document = rewrite_links(document)
  {id, MDEx.to_html!(document)}
end)
|> Enum.each(&update_output/1)
```

Apply the transform to every emitted chunk, including repeated ids. A partial
link may become a complete link in a later update with the same id. A reference
link may also become available after its definition arrives.

### Whole-document limit

The document in `{id, document}` is one keyed chunk, not the full Markdown
response. A transform that only needs nodes in that chunk, such as rewriting a
link or adding attributes, works directly.

A transform that needs all content may produce a different result. Examples
include a table of contents, heading ids that must be unique across the whole
response, and numbering shared by several chunks. For those transforms, either
wait for the full source or keep state outside MDEx and account for any
repeated id.

## Lists and generated streams

```elixir
["# Hel", "lo\n\n", "Some **bold", " text**"]
|> MDEx.stream()
|> Stream.each(fn {_id, document} ->
  IO.write(MDEx.to_html!(document))
end)
|> Stream.run()
```

You can use normal `Stream` functions before and after `MDEx.stream/2`:

```elixir
chunk_source
|> MDEx.stream(options)
|> Stream.map(fn {id, document} ->
  {id, MDEx.to_json!(document)}
end)
|> Stream.filter(&interesting?/1)
|> Enum.each(&publish/1)
```

## File streams

`File.stream!/1` works without an adapter:

```elixir
rendered_chunks =
  "README.md"
  |> File.stream!()
  |> MDEx.stream()
  |> Enum.reduce(%{}, fn {id, document}, chunks ->
    Map.put(chunks, id, MDEx.to_html!(document))
  end)
```

The map keeps the latest rendered value for each id.

You can also read fixed-size binary chunks:

```elixir
"large.md"
|> File.stream!([], 2048)
|> MDEx.stream()
|> Enum.each(&consume/1)
```

A file or network chunk may split a UTF-8 code point. MDEx holds the incomplete
bytes until the next chunk. Invalid UTF-8 raises when the Stream reaches those
bytes. An incomplete code point at EOF also raises.

## Req response streams

Req's asynchronous response body is an Enumerable, so it can feed MDEx
directly:

```elixir
Req.get!(url, into: :self).body
|> MDEx.stream(extension: [table: true])
|> Enum.each(&consume/1)
```

The body does not need to be joined first. Req cancels the asynchronous request
if the consumer stops early.

## Partial Markdown

MDEx uses its fragment parser on the cumulative source. This keeps partial
output valid while more source is expected:

```elixir
["**Fol", "low**"]
|> MDEx.stream()
|> Enum.each(fn {_id, document} ->
  IO.inspect(MDEx.to_html!(document))
end)
```

The first update renders a closed `<strong>` element. The next update uses the
same id and replaces it. At EOF, MDEx parses the source without temporary
closing syntax.

## Phoenix LiveView

The MDEx id can be the id for a
[`Phoenix.LiveView.stream/4`](https://phoenix-live-view.hexdocs.pm/Phoenix.LiveView.html#stream/4)
entry.

Configure the id before you create the LiveView stream:

```elixir
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> stream_configure(:markdown, dom_id: fn {id, _document} ->
     "markdown-#{id}"
   end)
   |> stream(:markdown, [])}
end
```

Use the exact DOM id that LiveView gives to the template:

```heex
<div id="markdown" class="markdown-body" phx-update="stream">
  <div
    :for={{dom_id, {_id, document}} <- @streams.markdown}
    id={dom_id}
    class="contents"
  >
    {Phoenix.HTML.raw(MDEx.to_html!(document))}
  </div>
</div>
```

Use `Phoenix.HTML.raw/1` only after applying the MDEx safety options required by
your application.

### Read the source outside the LiveView callback

`Phoenix.LiveView.stream/4` reads its Enumerable in the LiveView process. Do
not pass it an LLM, socket, or other long-running source:

```elixir
# This blocks the LiveView callback until the source ends.
stream(socket, :markdown, MDEx.stream(long_running_chunks))
```

Read the MDEx Stream in a task and send each finite chunk to the LiveView:

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

def handle_async(:markdown_producer, {:ok, :ok}, socket) do
  {:noreply, socket}
end
```

You may also send a finite list and call `stream/4` once per batch:

```elixir
def handle_info({:markdown_chunks, chunks}, socket) do
  {:noreply, stream(socket, :markdown, chunks)}
end
```

When an id repeats, LiveView updates the same DOM child without moving it. This
also works when a lower id repeats after a higher id was inserted. LiveView
drops streamed data from socket state after each render, so the source and
MDEx state must stay in the producer.

`stream_async/4` does not forward chunks while its task runs. It waits for the
task result and then passes that result to `stream/4`.

### Start a new response

MDEx ids start at `0` for each Stream run. Reset the LiveView stream when the UI
shows one active response:

```elixir
socket = stream(socket, :markdown, [], reset: true)
```

For several active responses, include a response id in each DOM id. An MDEx id
is unique only within one Stream run.

## Runnable Phoenix example

[`examples/streaming.exs`](https://github.com/leandrocp/mdex/blob/main/examples/streaming.exs)
runs this path:

```text
Req.Response.Async Enumerable
  -> MDEx.stream/2
  -> one {id, document} chunk per message
  -> Phoenix.LiveView.stream_insert/4
  -> phx-update="stream"
```

Run it from the repository:

```shell
elixir examples/streaming.exs
```

The URL defaults to the raw MDEx README on GitHub. The example splits large
network reads into 64-byte chunks so updates stay visible. The controls include
pause and resume at a source chunk boundary, a delay of up to 1000 ms, and
optional auto-scroll. New keyed preview chunks use a short reveal animation
unless the browser requests reduced motion. Stream, pause, resume, stop, and
the delay slider stay in the sticky diagnostics panel while the page scrolls.

The example enables `render: [unsafe: true]` so raw HTML in the README is
visible. Use trusted URLs when reusing this setting. Lumis highlights partial
code fences. The page also shows source counts, MDEx updates, DOM chunks, and
current and peak memory for the producer and LiveView processes. A sticky
diagnostics panel beside the preview keeps this run data and the latest chunk
indexes visible while the page scrolls. The compact monospace activity uses
`+id` for inserts and `~id` for replacements.

## Adapting message-based sources

Prefer an `Enumerable` from the source when one is available. It composes with
`MDEx.stream/2` directly and may preserve upstream demand and cancellation.

Some sources only deliver chunks through process messages or callbacks. Adapt
those sources to an Elixir Stream at the application boundary with
`Stream.resource/3`:

```elixir
# This adapter belongs to the application, not MDEx.
defmodule MyApp.MarkdownMessageStream do
  def new(source) do
    Stream.resource(
      fn ->
        ref = make_ref()

        {:ok, subscription} =
          MyApp.MarkdownSource.subscribe(source, self(), ref)

        {ref, subscription}
      end,
      fn {ref, _subscription} = state ->
        receive do
          {:markdown_chunk, ^ref, chunk} when is_binary(chunk) ->
            {[chunk], state}

          {:markdown_done, ^ref} ->
            {:halt, state}

          {:markdown_error, ^ref, reason} ->
            raise "Markdown source failed: #{inspect(reason)}"
        end
      end,
      fn {_ref, subscription} ->
        MyApp.MarkdownSource.cancel(subscription)
      end
    )
  end
end
```

Replace `MyApp.MarkdownSource` and the message shapes with the API provided by
the source. The resulting value is a normal Stream:

```elixir
source
|> MyApp.MarkdownMessageStream.new()
|> MDEx.stream()
|> Enum.each(&consume/1)
```

`Stream.resource/3` gives the adapter a clear lifecycle:

1. Subscribe lazily in the first callback. `self()` is the process that
   enumerates the Stream.
2. Receive one binary chunk at a time in the second callback.
3. Return `{:halt, state}` when the source reports EOF.
4. Raise when the source reports an error.
5. Cancel or unsubscribe in the final callback. It runs when enumeration ends,
   fails, or the downstream consumer halts early.

Tag messages with a unique reference so concurrent streams and late messages
from an earlier subscription cannot be mixed. The adapter also owns any
timeout and source-specific cleanup policy.

### Backpressure

`Stream.resource/3` makes a message source look like an Enumerable, but it does
not make the producer demand-driven. If the producer sends chunks faster than
the Stream consumes them, messages accumulate in the receiving process.

For an unbounded or high-volume source, use its acknowledgement, pause, or
demand mechanism when available. Otherwise the application must define a
bounded buffer or an overflow policy. If the source already provides an
Enumerable with cancellation or demand, use that instead of a message adapter.

Subscription, buffering, timeouts, and cancellation are source concerns. MDEx
therefore does not add a separate `new/push/finish` API; it consumes the binary
Stream produced by the adapter.

## Options

Pass normal MDEx options as the second argument:

```elixir
chunks
|> MDEx.stream(
  extension: [strikethrough: true, table: true, tasklist: true],
  render: [unsafe: false],
  syntax_highlight: [
    engine: :lumis,
    opts: [formatter: {:html_inline, theme: "github_light"}]
  ]
)
|> Enum.each(&consume/1)
```
