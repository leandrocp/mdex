# MDEx streaming progress

Last updated: 2026-08-31

## Goal

Add one lazy Elixir Stream API for Markdown that arrives in chunks. MDEx owns
partial parsing, final parsing, and keyed updates. Consumers use normal Stream
functions and do not manage a parser state struct.

Validate the API before release with:

- a Req and Phoenix LiveView Playground in MDEx
- Loopyard
- phoenix_streamdown
- Ash AI

Public documentation:

- [`guides/streaming.md`](guides/streaming.md): user guide
- [`guides/plugins.md`](guides/plugins.md): plugin author rules
- [`STREAMING_API.md`](STREAMING_API.md): API contract and implementation notes
- [`examples/streaming.exs`](examples/streaming.exs): runnable Phoenix Playground

## Local branches

All client changes are local and uncommitted.

| Project | Branch | Base |
| --- | --- | --- |
| MDEx | `lp-stream-api` | `19248f5a03f3` |
| Loopyard | `lp-mdex-stream-api` | `8bc934a5c041` |
| phoenix_streamdown | `lp-mdex-stream-api` | `4757f76e809e` |
| Ash AI | `lp-mdex-stream-api` | `043461cc2e56` |

The MDEx proof also runs against the unchanged mdex_native `main` at
`1811a96148e6` and the released mdex_native 0.2.8 dependency. It does not call
or require `parse_document_with_metadata/2`.

## Public API

```elixir
File.stream!(path)
|> MDEx.stream(options)
|> Enum.each(&consume/1)
```

`MDEx.stream/2` accepts an Enumerable of binary source chunks and returns a
lazy `%Stream{}`. It emits:

```elixir
{id, %MDEx.Document{}}
```

The contract is:

1. Insert a document when its id is new.
2. Replace the document when its id repeats.
3. Keep documents in id order. Replacement does not move a document.
4. Any earlier id may repeat when later Markdown changes its AST.
5. Normal Stream completion is EOF. There is no custom EOF value.
6. Empty input emits no documents.

The exact number of updates and the source range assigned to one id are
private. One keyed document may contain several top-level Markdown blocks.

`MDEx.new/1` and `MDEx.Document.put_markdown/3` remain supported for one
document. `MDEx.new(streaming: true)` is deprecated. It warns and keeps its
current behavior for compatibility.

## MDEx implementation

For each source chunk, MDEx:

1. joins any incomplete UTF-8 suffix
2. appends the valid bytes to the cumulative source
3. completes partial syntax with the existing `MDEx.FragmentParser`
4. parses the cumulative source once with the existing
   `MDExNative.Comrak.parse_document/2`
5. derives keyed ranges from CommonMark source positions
6. compares each range's AST nodes with the previous parse
7. emits only new or changed ids

At EOF, MDEx parses the original cumulative source once without temporary
fragment completion and emits the final open id. The final keyed documents
reconstruct the same HTML as a normal full-source parse.

This design preserves document-wide behavior. A link or footnote definition
near the end can change an earlier AST, so MDEx emits that earlier id again.
No link-specific native metadata parser is needed.

The Stream lifecycle is lazy:

- state and plugins are initialized on enumeration
- upstream is read only when downstream asks for output
- an early downstream halt stops the upstream Enumerable
- cleanup runs on completion, halt, and error
- invalid chunks and UTF-8 errors raise during enumeration

Current cost: MDEx retains the cumulative source and the latest keyed AST
nodes, and it performs one cumulative parse per input chunk plus one final
parse. A future parser optimization can change that implementation without
changing the public Stream contract.

## AST transforms and plugins

Each emitted value is a parsed document. A consumer can update its AST before
rendering, for example to rewrite links:

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

The transform must run for every update, including repeated ids.

Plugins use the normal `:plugins` option. MDEx attaches them once when Stream
enumeration starts, applies their parser options before every parse, and runs
their pipeline steps for every emitted document.

An emitted document is one keyed chunk, not the whole response. Chunk-local
transforms work. Full-response behavior needs a final full parse or external
state. This includes tables of contents, global numbering, globally unique
generated ids, shared root assets, collected footnotes, and raw Markdown
preprocessing. The guide lists the behavior of every plugin linked from the
README.

## Phoenix LiveView integration

Use this process split:

```text
source Enumerable
  -> MDEx.stream/2 in a task or producer process
  -> one finite {id, document} message at a time
  -> Phoenix.LiveView.stream_insert/4
  -> keyed phx-update="stream" DOM children
```

Verified with Phoenix LiveView 1.2.11:

- `stream/4` reads its Enumerable in the LiveView process, so it must not
  receive a long-running network or LLM source directly.
- `start_async/3` can read MDEx and send finite updates while it runs.
- `stream_async/4` waits for the task result before passing it to `stream/4`.
- `stream_insert/4` replaces an existing DOM id without moving it.
- A lower id can be replaced after a higher id was inserted.
- The parent needs `phx-update="stream"`, and each child uses LiveView's exact
  DOM id.
- A new response must reset the stream or include a response id in each DOM
  id.

## MDEx Playground

`examples/streaming.exs` runs:

```text
Req.Response.Async Enumerable
  -> 64-byte display chunks
  -> MDEx.stream/2
  -> LiveView messages
  -> stream_insert/4
  -> keyed DOM children
```

The Playground includes:

- a URL field that defaults to the raw MDEx README
- direct Req streaming through `into: :self`
- a delay slider from 0 to 1000 ms
- an auto-scroll checkbox
- raw HTML rendering for the default MDEx README
- Lumis highlighting for partial code fences
- a collapsible, Lumis-highlighted "How it works" card below the controls
- a subtle, reduced-motion-aware reveal for new preview chunks
- source byte and chunk counts
- MDEx update and replacement counts
- keyed DOM chunk counts
- a sticky diagnostics panel beside the preview
- compact index activity for inserts and replacements
- current and peak memory for the producer and LiveView processes in the same panel

Current proof:

- `Mix.install/2` uses the repository lockfile so a cached local MDEx build
  fetches its transitive dependencies
- adjacent blocks advance after a later stable boundary instead of keeping the
  mutable tail id open
- raw HTML containers stay in one keyed document; a browser-standard fragment
  parse kept the first README wrapper ids as direct siblings
- the standalone Phoenix Playground script compiles
- the default raw GitHub URL produced 201 MDEx updates through
  `Req.Response.Async`
- the current branch README produced 243 updates across 45 ids with 64-byte
  source chunks; its final keyed HTML matched a normal full-source parse
- an incomplete Elixir fence rendered Lumis spans

The in-app browser was not connected for the MDEx Playground visual check in
this run. The phoenix_streamdown client below provides the browser-level
LiveView proof for the same keyed update path.

## Loopyard proof

The released Loopyard code has a custom blank-line and fence parser plus a
JavaScript hook. The local branch removes both and removes the
phoenix_streamdown dependency.

The backend Enumerable is read once per agent turn:

```text
backend events
  -> raw event side effects and persistence
  -> TextDelta source chunks
  -> Loopyard.Markdown.stream/1
  -> MDEx.stream/2
  -> typed PubSub keyed documents
  -> WorkspaceLive, OperatorLive, and MessageLive stream_insert/4
```

MDEx owns Markdown parsing and partial syntax. Loopyard keeps domain work:
stale-turn checks, persistence, tool events, status, and publishing one parsed
update to all viewers. The existing raw text coalescer remains for raw event
state; it does not parse Markdown.

The proof covers:

- partial inline syntax and code fences
- lazy upstream reads
- final HTML equal to a full parse
- ids `[0, 1, 0, 1]` for a late reference definition
- a real isolated LiveView replacing the earlier DOM child
- finalized backend text preventing a later EOF update from recreating a
  streaming bubble
- switching agents clearing the previous agent's keyed Markdown stream
- static showcase renders that do not have a LiveView stream assign

`Loopyard.ChatAgent` remains below its enforced 1,700-line cap. Stream source
orchestration lives in a small `Loopyard.ChatAgent.StreamTask` module.

## phoenix_streamdown proof

The local branch adds:

- `PhoenixStreamdown.stream/2`, a thin options wrapper around `MDEx.stream/2`
- `PhoenixStreamdown.markdown_chunk/1`, which renders an emitted document
- a LiveView example using `start_async/3`, `stream_insert/4`, and exact keyed
  DOM ids

The existing `markdown/1`, `Remend`, and `Blocks` APIs remain for backward
compatibility with full-snapshot callers. New chunk sources use MDEx as the
Markdown source of truth.

The example consumes `ReqLLM.StreamResponse.tokens/1` directly. Its completed
assistant message keeps the latest document for each id instead of running the
raw response through the old block splitter.

Browser tests verify:

- the in-progress state is visible
- incomplete code fences contain Lumis-highlighted spans before completion
- a late link definition replaces an earlier chunk
- the replacement remains correct after the response completes

## Ash AI proof

Ash AI's `ToolLoop.stream/2` previously converted each provider stream to a
list before it emitted content events. The local branch uses the Enumerable
suspension continuation so one provider chunk is pulled for each downstream
demand.

The tested composition is:

```text
ReqLLM provider Stream
  -> AshAi.ToolLoop.stream/2
  -> Stream.flat_map/2 for {:content, chunk}
  -> MDEx.stream/2
```

Stopping after the first MDEx update closes and cancels the provider without
reading its second source chunk. A full run emits ids `[0, 1, 0, 1]`, and its
final keyed HTML matches a normal full parse.

This proof changes the reusable ToolLoop only. It does not yet change Ash AI's
generated Phoenix UI or persistence format.

## Verified results

- MDEx against unchanged mdex_native `main`: 820 passed (62 doctests and 758
  tests)
- MDEx against released mdex_native 0.2.8: 820 passed (62 doctests and 758
  tests)
- MDEx final checks: warnings-as-errors compile, formatting, CI-mode Credo,
  docs with warnings as errors, and `git diff --check` passed
- phoenix_streamdown `mix ci`: 71 passed, with Credo and Dialyzer passing
- phoenix_streamdown example `mix precommit`: 8 browser tests passed
- Ash AI `mix check`: 350 passed, 28 excluded; compiler, formatting, dependency
  audit, Credo, Sobelow, docs, Dialyzer, and REUSE checks passed
- Loopyard's full CI test selection on Elixir 1.19 and OTP 28: 1,905 passed,
  122 excluded
- Loopyard warnings-as-errors compile, formatting, locked frontend install,
  asset build, and `git diff --check` passed
- MDEx Playground: compile, real default URL, final equivalence, and partial
  Lumis checks passed

The validation changes described here remain local and uncommitted.

## Release decision

The Stream API does not need an mdex_native change or a new mdex_native
release. [mdex_native PR #60](https://github.com/leandrocp/mdex_native/pull/60)
was closed after the repository and client checks passed.

Before an MDEx release:

1. review the Stream contract for the next MDEx release
2. commit and update MDEx PR #397
3. run remote CI across the supported Elixir and OTP versions
4. release MDEx without waiting for a new mdex_native release
5. replace each client path dependency with the released MDEx version
6. open separate client pull requests only after their declared-version CI is
   green
