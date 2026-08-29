# MDEx streaming progress

Last updated: 2026-08-29

## Goal

Add a lazy Elixir Stream API for Markdown chunks. MDEx should parse partial
Markdown and decide which output can no longer change.

Validate the API before release with:

- a Req and Phoenix LiveView example in MDEx
- Loopyard
- phoenix_streamdown
- Ash AI

See these files for public details:

- [`guides/streaming.md`](guides/streaming.md): user guide
- [`STREAMING_API.md`](STREAMING_API.md): API contract and design notes
- [`examples/streaming.exs`](examples/streaming.exs): runnable Phoenix example

## Branches

The MDEx branch is the pull request target. mdex_native and the three client
branches remain local and uncommitted.

| Project | Branch | Base |
| --- | --- | --- |
| MDEx | `lp-loopyard-streaming` | `931cb825` |
| mdex_native | `lp-mdex-stream-metadata` | `b3c77b2` |
| Loopyard | `lp-mdex-native-stream` | `8bc934a5` |
| phoenix_streamdown | `lp-mdex-native-stream` | `4757f76e` |
| Ash AI | `lp-mdex-native-stream` | `043461cc` |

Each client uses the local MDEx branch. MDEx uses the local mdex_native branch.
This tests the two unreleased APIs together.

## API

```elixir
File.stream!(path)
|> MDEx.stream(options)
|> Enum.each(&consume/1)
```

`MDEx.stream/2` accepts an Enumerable of binary chunks and returns a lazy
`%Stream{}`. It emits:

```elixir
{id, %MDEx.Document{}}
```

An id may repeat while that chunk is still open. A higher id makes all lower
ids stable. EOF emits the last chunk with a normal parse, then ends the Stream.

The API has no public parser state, frame, block, or `new/push/finish` type.

`MDEx.new/1` and `MDEx.Document.put_markdown/3` remain supported. Only
`MDEx.new(streaming: true)` is deprecated. It warns and keeps its current
behavior for now.

## MDEx changes

The Stream implementation:

- starts parser state when enumeration starts
- reads upstream only when downstream asks for a chunk
- emits keyed `MDEx.Document` values
- builds each document through `put_markdown/3`
- holds an incomplete UTF-8 suffix between source chunks
- keeps only the Markdown suffix that may still change
- uses fragment parsing for that open suffix
- uses normal parsing for stable chunks and EOF
- cleans up when the source ends, raises, or is stopped early
- raises bad chunks, invalid UTF-8, and upstream errors during enumeration

Covered Markdown cases include:

- loose lists
- partial tables
- tilde and longer backtick fences
- partial emphasis and links
- link references
- one-grapheme source chunks

Block boundaries come from CommonMark source positions. A gap between top-level
node line ranges marks a blank-line boundary. No regular expression parses
blank lines, fences, or link references.

A link that may use a later definition keeps its block and all following blocks
open. Partial tables have a separate guard because their temporary parser shape
can change when more source arrives.

## mdex_native changes

mdex_native adds `parse_document_with_metadata/2`.

It uses Comrak parser data to report the first top-level block that may use a
later link definition. It uses Comrak task-list nodes to keep `[x]` task marks
out of link-reference metadata.

MDEx uses the returned source line to keep only the required suffix open.

MDEx now requires mdex_native 0.2.9. That version must be released before this
MDEx branch can pass dependency setup without a local path.

## Phoenix LiveView findings

Use this process split:

```text
source Enumerable
  -> MDEx.stream/2 in a task or process
  -> finite {id, document} messages or lists
  -> Phoenix.LiveView.stream_insert/4 or stream/4
  -> keyed DOM children
```

Verified with Phoenix LiveView 1.2.11:

- `stream/4` reads the given Enumerable in the LiveView process.
- A long-running MDEx Stream must not be passed directly to `stream/4`.
- A `start_async/3` task may read MDEx and send finite updates while it runs.
- `stream_async/4` waits for its task result before it calls `stream/4`.
- `stream_insert/4` replaces an entry when its DOM id repeats.
- The parent needs `phx-update="stream"`.
- Each child must use the exact DOM id from LiveView.
- LiveView removes streamed values from socket state after rendering.
- A new response must reset the stream or add its own response id to each DOM
  id.

## Phoenix example

The example runs this path:

```text
Req async response
  -> 64-byte display chunks
  -> MDEx.stream/2
  -> LiveView process messages
  -> stream_insert/4
  -> LiveView stream DOM
```

It includes:

- a URL field that defaults to the raw MDEx README
- a response body-size limit
- task cancellation and stale-message checks
- a delay slider from 0 to 1000 ms
- an auto-scroll checkbox
- Lumis highlighting for partial code fences
- a Lumis-highlighted "How it works" panel
- source byte and chunk counts
- MDEx update and replacement counts
- stable and open DOM chunk counts
- current and peak memory for the producer and LiveView processes

## Loopyard validation

The old code parsed each viewer's full Markdown snapshots. It used blank-line
and fence rules, plus a JavaScript hook for the open HTML tail.

The old code failed 6 of 18 focused cases:

- partial bold and links were not closed for display
- tilde and four-backtick fences split at the wrong place
- a loose list became several lists
- a later link definition changed an earlier stable block

The local branch reads the backend Enumerable once:

```text
backend stream
  -> raw event handling
  -> text chunks
  -> MDEx.stream/2 once per agent turn
  -> keyed Markdown updates
  -> existing 100 ms buffer
  -> LiveView stream inserts
```

Raw events still handle storage, tools, status, final text, timeouts, and stale
stream checks. Parsed documents are shared through PubSub.

The branch removes the custom Markdown parser, JavaScript hook, and
phoenix_streamdown dependency. The 100 ms buffer keeps the newest value for
each id, not only the last value it receives.

## phoenix_streamdown validation

The released code repairs and splits the full Markdown string before it calls
MDEx. The local branch removes those parsing modules:

```text
source chunks -> MDEx.stream/2 -> LiveView stream -> component
```

MDEx owns Markdown parsing, partial syntax, ids, and EOF. phoenix_streamdown
keeps static rendering, components, styles, themes, and optional animation.

Its ReqLLM example now sends model text chunks through MDEx and inserts the
keyed documents into a LiveView stream.

## Ash AI validation

Ash AI already uses MDEx for final HTML. Its generated UI used full text
snapshots, and its tool loop built a list for each model step before yielding
events.

The local branch makes the tool loop lazy and stops the provider when
downstream stops. The generated job:

```text
provider stream
  -> persist raw events
  -> text chunks
  -> MDEx.stream/2
  -> conversation PubSub topic
  -> LiveView or LiveComponent stream inserts
```

Final stored messages still use the normal static MDEx renderer.

## Test results

Completed:

- mdex_native: 4 Rust tests and 56 Elixir tests (22 doctests and 34 tests)
- mdex_native: Clippy with warnings denied, Rust format, Elixir format, and
  `git diff --check`
- MDEx: 14 focused Stream tests
- MDEx: 812 full tests (62 doctests and 750 tests)
- MDEx: compile with warnings denied, docs with warnings denied, format, and
  `git diff --check`
- Phoenix example: 2 integration tests, including the raw GitHub README
- Phoenix example: delay, auto-scroll, partial Lumis highlighting, the "How it
  works" panel, and non-zero telemetry values
- Loopyard: 1,901 tests passed; 122 environment tests excluded
- Loopyard: focused stream tests, asset build, compile with warnings denied,
  format, and `git diff --check`
- phoenix_streamdown library: `mix ci`, 24 tests, Credo, and Dialyzer
- phoenix_streamdown example: 8 tests and pre-commit checks on Elixir 1.19.3
  with OTP 28.5
- Ash AI: 351 tests passed; 28 excluded
- Ash AI: compile, format, dependency audit, Credo, Sobelow, ExDoc, ExUnit, and
  Dialyzer
- all five worktrees: `git diff --check`

The Ash AI `reuse` check was not run because `pipx` was not installed.

## Work before release

- Define support for plugins that read or change the whole document.
- Review whether the API is ready for MDEx 0.14.
- Release mdex_native 0.2.9 and its precompiled files.
- Run MDEx CI against mdex_native 0.2.9 from Hex.
- Replace each client's local MDEx path with the released version.
- Run each client's CI on its declared Elixir and OTP versions.
- Open separate client pull requests only after those checks pass.

## Local test notes

Ash AI database tests used a temporary PostgreSQL 17 server with pgvector. The
server was stopped after the tests.

The exact Elixir and OTP versions pinned by the phoenix_streamdown example were
not installed. Its checks passed on the nearest installed stable pair: Elixir
1.19.3 and OTP 28.5.
