# MDEx Stream API

Status: implemented on the development branch; not released.

## API decision

MDEx adds one public API for Markdown that arrives in chunks:

```elixir
MDEx.stream(chunks, options \\ [])
```

Input:

- any `Enumerable` that emits binaries
- normal MDEx document options

Output:

- a lazy Elixir `%Stream{}`
- `{id, %MDEx.Document{}}` for each update

```elixir
@type stream_id :: non_neg_integer()
@type stream_chunk :: {stream_id(), MDEx.Document.t()}

@spec stream(Enumerable.t(), MDEx.Document.options()) :: Enumerable.t()
```

The API does not expose a stream state struct or a `new/push/finish` protocol.
Its state stays inside `Stream.transform/5`.

`MDEx.new(streaming: true)` is deprecated. `MDEx.new/1` and
`MDEx.Document.put_markdown/3` remain supported for building one document.

## Why the output is keyed

Partial Markdown cannot use append-only output. For example, `Now **wri` must
render as valid HTML, then be replaced when `ting**` arrives.

The id tells a consumer when to insert or replace a chunk. The value is a
document, so the consumer may render HTML, CommonMark, XML, JSON, Quill Delta,
or read the AST.

Each update contains a new immutable document. MDEx does not change an earlier
document in place.

The document is the parsed AST. Consumers can change it before rendering:

```elixir
chunks
|> MDEx.stream()
|> Stream.map(fn {id, document} ->
  document =
    MDEx.Document.update_nodes(document, MDEx.Link, fn link ->
      %{link | url: rewrite_url(link.url)}
    end)

  {id, MDEx.to_html!(document)}
end)
```

The transform runs for each emitted document. It does not receive the full
response. Chunk-local transforms work directly. Transforms that need all
chunks must wait for the full source or keep their own state, including state
for repeated ids.

## Basic use

```elixir
chunks = ["# Hel", "lo\n\nNow **wri", "ting**"]

chunks
|> MDEx.stream()
|> Stream.map(fn {id, document} ->
  {id, MDEx.to_html!(document)}
end)
|> Enum.each(&update_output/1)
```

`File.stream!/1` works without an adapter:

```elixir
"README.md"
|> File.stream!([], 2048)
|> MDEx.stream(extension: [table: true])
|> Enum.each(&consume/1)
```

Req can also provide the source. For paced consumers, wrap Req's callback API
in a Stream so the HTTP producer waits for demand:

```elixir
url
|> req_stream()
|> MDEx.stream(options)
|> Enum.each(&consume/1)
```

See `MDExStreamingDemo.HTTPStream` in `examples/streaming.exs` for a complete
adapter with backpressure, a body-size limit, redirect checks, and public URL
validation.

MDEx holds an incomplete UTF-8 suffix when a file or network read splits a
code point. The caller does not need to fix those boundaries.

## Id rules

There is one source range at the tail that has not reached a later block
boundary. Earlier ranges keep their ids, but their ASTs may still change.

For this input:

```elixir
["# Done\n\nNow **wri", "ting**"]
```

the output has this form:

```elixir
{0, heading_document}           # insert
{1, partial_paragraph_document} # insert
{1, updated_paragraph_document} # replace
{1, final_paragraph_document}   # replace at EOF
```

The exact number of updates is private. The id rules are public:

1. Ids start at `0` for each Stream run.
2. Ids increase in order.
3. A repeated id replaces the earlier value for that id.
4. Any earlier id may be emitted again.
5. An id keeps its original position when it is replaced.
6. EOF emits the last chunk with a normal final parse, then ends the Stream.
7. Empty input emits no chunks.

One keyed document may hold several top-level Markdown blocks. A later link or
footnote definition can update an earlier keyed document after newer ids have
already been emitted.

The end of the Stream is the completion signal. There is no `done?` field or
EOF value. If downstream stops early, MDEx does not finalize unread input.

## Relationship to `put_markdown/3`

`MDEx.Document.put_markdown/3` is the lower-level API for adding source to one
document. It remains useful for AST pipelines and full document renders.

Use the two APIs as follows:

```elixir
# An Enumerable of chunks
File.stream!(path)
|> MDEx.stream(options)
|> Enum.each(&consume/1)

# One document built in steps
document =
  MDEx.new(options)
  |> MDEx.Document.put_markdown(first_chunk)
  |> MDEx.Document.put_markdown(second_chunk)

MDEx.to_html!(document)
```

`MDEx.stream/2` uses the same parser options and document plugin pipeline as
`put_markdown/3`. It parses the cumulative, fragment-completed source once per
input chunk. At EOF it parses the original source once without temporary
completion.

Tests must keep these rules true:

- source chunk boundaries do not add or remove bytes
- the final Stream render matches a full document render
- the open chunk uses the same fragment parser as MDEx
- parse and render options reach each document
- EOF removes temporary fragment closing syntax

## Lazy behavior

The Stream uses `Stream.transform/5`:

- parser state is created when enumeration starts
- upstream chunks are read only when downstream asks for them
- normal EOF emits the final document
- an early halt does not act like EOF
- cleanup runs after completion, halt, or error
- a second run creates new state when the source can be read again
- bad chunks, invalid UTF-8, and upstream errors raise during enumeration

`Stream.transform/5` is available in Elixir 1.14. MDEx requires Elixir 1.15 or
later.

## Parser reuse

Each source chunk causes one cumulative parse. MDEx derives keyed source ranges
from CommonMark source positions, compares their AST nodes with the previous
parse, and emits only new or changed ranges. It does not parse each keyed range
again.

This keeps document-wide parser behavior. For example, a link definition at
the end of the source can change a link node in an earlier range. MDEx emits
that earlier id again. The implementation needs no link-specific parser
metadata and no mdex_native API change.

## Plugins

Plugins use the normal `:plugins` option. MDEx attaches them once in the lazy
Stream initializer and keeps the resulting document as an immutable template.
This makes parser options configured by a plugin available to cumulative and
final parses.

For each emitted update, MDEx starts from the template, installs the parsed
nodes, and runs the configured pipeline steps. The completed document is not
used as the template for the next update. Plugin state from one update does not
leak into a repeated id.

This supports parser-configuration plugins and chunk-local AST transforms. It
does not provide full-response plugin semantics. Root assets may be repeated,
sequence IDs restart per keyed chunk, and a step cannot inspect other chunks
that were already emitted.

Plugin attachment happens before the source Enumerable is read. A plugin that
rewrites `document.buffer` in `attach/2` is not compatible with this API and
must use the one-document pipeline after the full source is available.

## Phoenix LiveView

Phoenix LiveView streams store keyed DOM updates. They do not keep MDEx parser
state and do not read a long-running source in the background.

This split is required:

```text
source Enumerable
  -> MDEx.stream/2 in a task or process
  -> finite {id, document} messages or lists
  -> Phoenix.LiveView.stream_insert/4 or stream/4
  -> phx-update="stream" DOM children
```

The
[`Phoenix.LiveView.stream/4` docs](https://phoenix-live-view.hexdocs.pm/Phoenix.LiveView.html#stream/4)
define the DOM contract:

- the parent has a unique id and `phx-update="stream"`
- each child uses the exact DOM id from `@streams.name`
- `stream_insert/4` updates an entry when its DOM id already exists
- LiveView drops streamed entries from socket state after rendering

The LiveView 1.2.11 source also shows that `stream/4` reads the given Enumerable
in the LiveView process. It keeps the last insert for a repeated DOM id within
one render.

### Configure ids

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

Do not change `dom_id` in the template. Check that `class="contents"` matches
the application's CSS and access needs. Apply the required MDEx safety options
before using `Phoenix.HTML.raw/1`.

### Read MDEx outside the callback

This blocks a LiveView callback until the source ends:

```elixir
stream(socket, :markdown, MDEx.stream(long_running_chunks))
```

Run the source in a task and send finite updates:

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

`start_async/3` works here because the task reads MDEx and sends updates while
it runs. `stream_async/4` is different: it waits for the task result, then gives
that result to `stream/4`.

A client may send finite batches instead:

```elixir
def handle_info({:markdown_chunks, chunks}, socket) do
  {:noreply, stream(socket, :markdown, chunks)}
end
```

LiveView may keep only the newest value when one batch has several updates for
the same id. This is safe because the newest value replaces the same keyed
chunk.

The source and MDEx state stay in the producer. The LiveView stream only sends
DOM changes.

Reset the LiveView stream for a new response, or add a response id to each DOM
id. MDEx ids are local to one Stream run.

## Client validation

Three local client branches test the same API.

### Loopyard

Loopyard already has an Enumerable for each backend turn. The branch reads it
once:

```elixir
backend.stream(session, prompt)
|> Stream.each(&send(chat_agent, {:stream_event, &1}))
|> Stream.flat_map(fn
  %Event.TextDelta{text: text} -> [text]
  _event -> []
end)
|> MDEx.stream(mdex_options)
|> Enum.each(&send(chat_agent, {:markdown_update, &1}))
```

Raw events still handle storage, tools, status, and final text. Parsed
documents are shared with all viewers. The branch removes the custom Markdown
split code and JavaScript update hook.

Loopyard's existing 100 ms raw text coalescer remains for raw event state. It
does not parse or buffer the keyed MDEx documents.

### phoenix_streamdown

The released package repairs and splits a full Markdown string before it calls
MDEx. The local branch adds a separate chunk-source path:

```text
source chunks -> MDEx.stream/2 -> LiveView stream -> component
```

MDEx parses Markdown and owns ids on that path. The existing full-snapshot
component, Remend, and Blocks remain for backward compatibility.

### Ash AI

Ash AI already uses MDEx for final HTML. Its local branch makes the tool loop
lazy and sends text chunks through MDEx:

```elixir
prompt_messages
|> AshAi.ToolLoop.stream(options)
|> Stream.flat_map(fn
  {:content, chunk} -> [chunk]
  _event -> []
end)
|> MDEx.stream(markdown_options())
|> Enum.each(&consume_markdown/1)
```

This validates the reusable ToolLoop and its provider cancellation. The local
proof does not change Ash AI's generated Phoenix UI or persistence format.

## Parser requirements

The parser must keep these cases correct:

- a loose list stays one list
- a partial table does not become stable too soon
- tilde fences and longer backtick fences use parser rules
- partial emphasis, links, tables, math, HTML, and fences render as valid
  open chunks
- a later link or footnote definition re-emits every earlier id whose AST changed
- a blank line at the current end of input does not always create a new id

The implementation uses CommonMark source positions for block boundaries. It
does not use regular expressions to parse blank lines, fences, or references.

## Release checklist

- [x] Add `MDEx.stream/2` with `Stream.transform/5`.
- [x] Keep all stream state private.
- [x] Complete cumulative partial input with the existing fragment parser.
- [x] Parse the cumulative source once per input chunk and once at EOF.
- [x] Reuse parsed AST nodes instead of parsing each keyed range again.
- [x] Handle UTF-8 code points split across chunks.
- [x] Test errors, cleanup, early halt, and EOF.
- [x] Test final output against full document parsing.
- [x] Add a Phoenix Playground example with Req and LiveView.
- [x] Test local branches for Loopyard, phoenix_streamdown, and Ash AI.
- [x] Document the keyed-document limit for plugin authors and users.
- [ ] Run each client against the released MDEx package.

## Known plugin limit

A plugin that needs the whole response cannot treat one keyed document as the
whole Markdown input. Use external state or run that plugin after collecting
the complete source. The public id contract does not change for this case.
