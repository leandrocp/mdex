# Streaming Markdown

> #### Unreleased {: .warning}
>
> This API is on the development branch. It is not on Hex yet.

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
{1, partial_document}       # insert the open tail
{1, updated_document}       # replace the tail
{1, final_document}         # replace it with the EOF parse
```

Apply these rules:

1. Insert a chunk when its id is new.
2. Replace a chunk when its id repeats.
3. After MDEx emits a higher id, all lower ids are stable.
4. Only the highest id may change.
5. Normal Stream completion is EOF. There is no custom EOF chunk.

A chunk may contain more than one Markdown block. This can happen when a link
reference or another document-wide rule may change several blocks together.

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
wait for the full source or keep state outside MDEx and account for repeated
tail ids.

## Plugins

Pass plugins through the normal `:plugins` option:

```elixir
chunks
|> MDEx.stream(plugins: [MDExGFM])
|> Stream.map(fn {id, document} ->
  {id, MDEx.to_html!(document)}
end)
```

MDEx attaches each plugin once when Stream enumeration starts. Extension and
parse options set by `attach/2` apply to every parse. Render options set by
`attach/2` apply when each emitted document is rendered. Plugin pipeline steps
then run on every emitted document, including updates with a repeated id.

Each run starts from the prepared plugin configuration. Changes that a plugin
makes to one emitted document are not carried into the next update.

The keyed document limit still applies:

- An AST transform that only needs the current chunk works directly.
- Assets injected at the document root may appear in more than one keyed
  chunk.
- Sequence numbers and generated IDs restart for each keyed chunk. They are not
  unique across the full response.
- A plugin cannot build a table of contents or other full-response result
  without external state.
- `attach/2` runs before MDEx reads source chunks, so it receives a document
  with an empty Markdown buffer. A plugin that preprocesses the raw Markdown
  buffer is not compatible with `MDEx.stream/2`; use the one-document API.

For the plugins listed in the MDEx README, this means:

- `mdex_gfm` parser options apply normally.
- `mdex_custom_heading_id` processes headings within each keyed chunk.
- `mdex_mermaid`, `mdex_katex`, `mdex_video_embed`, and `mdex_mermex` process
  each keyed chunk separately. Configure document-wide assets and globally
  unique IDs outside the Markdown stream when needed.
- `mdex_multiline_cells` preprocesses the Markdown buffer and should be used
  after the complete Markdown response is available.

See the [Plugins guide](plugins.html#streaming-plugins) for the plugin-author
contract.

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
"README.md"
|> File.stream!()
|> MDEx.stream()
|> Enum.each(fn {id, document} ->
  cache({id, :html}, MDEx.to_html!(document))
end)
```

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

Req can return a response body that implements `Enumerable`:

```elixir
response = Req.get!(url, into: :self)

response.body
|> MDEx.stream(extension: [table: true])
|> Enum.each(&consume/1)
```

The body does not need to be joined first. The process that reads the response
must also own its timeout, body-size limit, and cancellation rules.

## Partial Markdown

MDEx uses its fragment parser for the current chunk. This keeps partial output
valid while more source is expected:

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

Fragment parsing supports partial emphasis, code spans, code fences, links,
images, tables, lists, math, HTML, and other enabled syntax.

## `put_markdown/3`

`MDEx.Document.put_markdown/3` is not deprecated. Use it to build one full
document for an AST pipeline:

```elixir
document =
  MDEx.new()
  |> MDEx.Document.put_markdown("# Release notes\n\n")
  |> MDEx.Document.put_markdown("Version **1.0**")

MDEx.to_html!(document)
#=> "<h1>Release notes</h1>\n<p>Version <strong>1.0</strong></p>"
```

Use `MDEx.stream/2` for an Enumerable of chunks. It uses the same Markdown
input path and enables fragment parsing only for the current chunk.

`MDEx.new(streaming: true)` is deprecated. It still warns and works for now.

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

When an id repeats, LiveView updates the same DOM child. A higher id adds a new
child. LiveView drops streamed data from socket state after each render, so the
source and MDEx parser state must stay in the producer.

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
Req response body
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
a delay of up to 1000 ms and optional auto-scroll.

Lumis highlights partial code fences. The page also shows source counts, MDEx
updates, DOM chunks, and current and peak memory for the producer and LiveView
processes.

## Client tests

The API has local test branches in three clients:

- Loopyard reads each backend Stream once, sends text chunks through MDEx, and
  shares keyed documents with its LiveViews.
- phoenix_streamdown removes its Markdown repair and block split code. MDEx
  parses the source; phoenix_streamdown keeps components, styles, and optional
  animation.
- Ash AI sends its lazy tool-loop output through MDEx, then sends keyed
  documents through PubSub to LiveView or LiveComponent code.

In each client, MDEx owns Markdown parsing, partial syntax, stable ids, and EOF.
The client owns transport, cancellation, pacing, and response ids.

## Push-only sources

If a source only sends process messages, adapt it at the process boundary with
`Stream.resource/3`. The adapter must define subscribe, EOF, error,
cancellation, and cleanup behavior. MDEx does not add a separate
`new/push/finish` API for this case.

## Options and plugins

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

Plugins that read or change the whole document may not match a render made from
separate keyed documents. Their support is not defined yet. See
[`STREAMING_API.md`](https://github.com/leandrocp/mdex/blob/main/STREAMING_API.md)
for the API contract and open release work.
