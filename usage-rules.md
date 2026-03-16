# MDEx Usage Rules

MDEx is a fast, extensible Markdown library for Elixir. It parses Markdown into an AST (`MDEx.Document`) and renders to HTML, HEEx, JSON, XML, normalized Markdown, or Quill Delta.

This file is the source of truth for coding agents working with MDEx.

## Agent Defaults

1. **Prefer `~MD` for static content** - If the Markdown is a literal known at compile time, use the sigil.
2. **Use `use MDEx` in modules that render Markdown** - It adds `require MDEx` and `import MDEx.Sigil`.
3. **Use `HEEX` only when you need Phoenix semantics** - Components, `phx-*`, `{@assigns}`, or HEEx expressions.
4. **Use runtime functions for runtime content** - Database content, user input, files, API responses, LLM output.
5. **Use `MDEx.Document` when you need control** - AST transforms, plugins, streaming, custom renderers, inspection.
6. **Keep options explicit and minimal** - Only enable extensions and unsafe rendering when needed.

## Decision Guide

Choose the narrowest tool that fits the job.

### Static Markdown known at compile time

- Use `~MD[...]HTML` for HTML output.
- Use `~MD[...]HEEX` if the Markdown contains Phoenix components or HEEx expressions.
- Use bare `~MD[...]` if you want a compile-time `MDEx.Document`.

```elixir
defmodule MyApp.Page do
  use MDEx

  def hero do
    ~MD[
    # Hello

    This is **static** content.
    ]HTML
  end
end
```

### Dynamic Markdown available only at runtime

- Use `MDEx.to_html!/2` for normal rendering.
- Use `MDEx.to_heex!/2` only when runtime content needs Phoenix component support.
- Use `MDEx.parse_document!/2` if you need the AST instead of rendered output.

```elixir
html = MDEx.to_html!(markdown)

rendered = MDEx.to_heex!(markdown, assigns: assigns)
```

### AST inspection or transformation

- Use `MDEx.parse_document!/2` for a one-off AST.
- Use `MDEx.new/1` plus `MDEx.Document` pipeline functions for reusable flows.
- Use `MDEx.parse_fragment!/1` only when you need a single fragment node.

```elixir
doc =
  markdown
  |> MDEx.parse_document!()
  |> MDEx.Document.update_nodes(MDEx.Text, fn node ->
    %{node | literal: String.upcase(node.literal)}
  end)

MDEx.to_html!(doc)
```

### Streaming or chunked Markdown

- Use `MDEx.new(streaming: true)`.
- Append chunks with `MDEx.Document.put_markdown/2` or `Enum.into/2`.
- Render after each chunk with `MDEx.to_html!/1` or another `to_*` function.

```elixir
doc = MDEx.new(streaming: true)
doc = MDEx.Document.put_markdown(doc, "**Hel")
html = MDEx.to_html!(doc)

doc = MDEx.Document.put_markdown(doc, "lo**")
html = MDEx.to_html!(doc)
```

## Canonical API Choices

### `use MDEx`

Use this in modules that use `~MD` or `MDEx.to_heex!/2`.

```elixir
defmodule MyApp.Content do
  use MDEx
end
```

You can pass default sigil options:

```elixir
defmodule MyApp.Content do
  use MDEx,
    extension: [strikethrough: true],
    syntax_highlight: [formatter: {:html_inline, theme: "github_light"}]
end
```

### `~MD` sigil

Preferred for compile-time Markdown.

The sigil is opinionated: its defaults enable many extensions and `render: [unsafe: true]`. If you need stricter or more explicit behavior, either pass options to `use MDEx` or use the runtime `MDEx.to_*` / `MDEx.parse_*` functions directly.

- `~MD[...]` -> `MDEx.Document`
- `~MD[...]HTML` -> HTML string
- `~MD[...]HEEX` -> `Phoenix.LiveView.Rendered`
- `~MD[...]JSON` -> JSON string
- `~MD[...]XML` -> XML string
- `~MD[...]MD` -> normalized Markdown
- `~MD[...]DELTA` -> Quill Delta ops

```elixir
use MDEx

doc = ~MD[# Title]
html = ~MD[# Title]HTML
json = ~MD[# Title]JSON
```

### `MDEx.to_html!/2`

Use for runtime Markdown when you only need HTML.

```elixir
MDEx.to_html!("# Hello")
MDEx.to_html!(markdown, extension: [table: true, strikethrough: true])
```

### `MDEx.to_heex!/2`

Use for runtime Markdown that must support Phoenix components or HEEx expressions.

- `MDEx.to_heex!/2` is a macro, so `use MDEx` or `require MDEx` must be in scope.
- It automatically enables `extension: [phoenix_heex: true]` and `render: [unsafe: true]`.
- Prefer `~MD[...]HEEX` when the content is static.

```elixir
defmodule MyAppWeb.PageLive do
  use Phoenix.LiveView
  use MDEx

  def render(assigns) do
    markdown = "# {@title}\n\n<.link href={@href}>Open</.link>"
    MDEx.to_heex!(markdown, assigns: assigns)
  end
end
```

### `MDEx.parse_document!/2`

Use when you want the full AST.

```elixir
doc = MDEx.parse_document!(markdown)
```

It also accepts tagged JSON input:

```elixir
doc = MDEx.parse_document!({:json, json})
```

### `MDEx.parse_fragment!/1`

Use when you expect a single fragment node and want to inject or wrap it later.

```elixir
heading = MDEx.parse_fragment!("# Title")
```

Treat this API as experimental.

### `MDEx.new/1`

Use this as the entrypoint for pipelines, plugins, streaming, assigns, and reusable option sets.

```elixir
doc =
  MDEx.new(
    markdown: markdown,
    extension: [table: true],
    syntax_highlight: [formatter: {:html_inline, theme: "github_light"}]
  )
```

## HEEx Rules

Use HEEx support only when the Markdown contains Phoenix-specific syntax.

Choose HEEx when the Markdown includes:

- `<.link>`, `<.button>`, or other function components
- fully qualified components
- `phx-*` bindings
- `{@assign}` or other HEEx expressions
- EEx blocks mixed into Markdown

Prefer plain HTML rendering when the content is just Markdown plus ordinary HTML.

```elixir
def render(assigns) do
  ~MD"""
  # {@title}

  <.button phx-click="save">Save</.button>
  """HEEX
end
```

Important details:

- The `assigns` variable must be in scope for `~MD[...]HEEX`.
- Component imports are not automatic. Import your component modules the same way you would in normal HEEx.
- `to_html!/2` does not understand Phoenix components. Use HEEx APIs first, then convert to HTML if needed.

```elixir
MDEx.to_heex!(markdown, assigns: assigns)
|> MDEx.to_html!()
```

## Document API

`MDEx.Document` is the right abstraction when the agent needs to manipulate or inspect Markdown structurally.

Common operations:

- `MDEx.Document.put_options/2`
- `MDEx.Document.put_render_options/2`
- `MDEx.Document.put_plugins/2`
- `MDEx.Document.assign/2` and `assign/3`
- `MDEx.Document.append_steps/2`
- `MDEx.Document.update_nodes/3`
- `MDEx.Document.put_private/3`, `get_private/3`, `update_private/4`
- `MDEx.Document.put_markdown/2`
- `MDEx.Document.wrap/1`
- `MDEx.Document.run/1`

```elixir
doc =
  MDEx.new(markdown: "# Title")
  |> MDEx.Document.put_options(extension: [table: true])
  |> MDEx.Document.put_render_options(unsafe: true)
  |> MDEx.Document.append_steps(custom_step: &my_transform/1)

html = MDEx.to_html!(doc)
```

## Plugins

Plugins attach behavior to the document pipeline.

Preferred ways to use plugins:

1. One-off rendering: pass `plugins: [...]` to `MDEx.to_*`.
2. Reusable pipeline: attach the plugin to `MDEx.new(...)`.
3. Manual control: call `MDEx.Document.put_plugins/2`.

```elixir
MDEx.to_html!(markdown, plugins: [MDExGFM])

MDEx.new(markdown: markdown)
|> MDExGFM.attach()
|> MDEx.to_html!()
```

Plugin entries can be:

- a module, like `MDExGFM`
- a `{module, options}` tuple
- a function that receives and returns a document

### Writing plugins

Custom plugins should usually:

1. `register_options/2` for custom options
2. `put_options/2` to merge user input
3. `append_steps/2` to transform the document

```elixir
defmodule MyPlugin do
  alias MDEx.Document

  def attach(document, options \\ []) do
    document
    |> Document.register_options([:my_option])
    |> Document.put_options(options)
    |> Document.append_steps(transform: &transform/1)
  end

  defp transform(document) do
    Document.update_nodes(document, MDEx.CodeBlock, fn node ->
      %MDEx.HtmlBlock{literal: "<pre>#{node.literal}</pre>"}
    end)
  end
end
```

Use `document.private` helpers for plugin state instead of overloading assigns.

## Streaming Rules

Streaming mode is especially useful for LLM or SSE output.

- Always set `streaming: true` on document creation.
- Keep the same document instance across chunks.
- `put_markdown/2` appends chunks to the document buffer.
- `Enum.into(chunks, doc)` is the cleanest way to accumulate many chunks.
- Any `to_*` call flushes the buffer, completes open syntax temporarily, and re-renders.

```elixir
doc = Enum.into(["# Hel", "lo\n\n", "**world**"], MDEx.new(streaming: true))
html = MDEx.to_html!(doc)
```

If you want to replace prior content instead of appending, create a fresh document.

## Output Formats

Use the renderer that matches the integration point.

| Format | Main API | Typical use |
| --- | --- | --- |
| HTML | `to_html!/2` or `~MD[...]HTML` | Web pages, emails, rendered output |
| HEEx | `to_heex!/2` or `~MD[...]HEEX` | LiveView templates with components |
| JSON | `to_json!/2` or `~MD[...]JSON` | Serialization, APIs, tests |
| XML | `to_xml!/2` or `~MD[...]XML` | CommonMark XML interop |
| Markdown | `to_markdown!/2` on `MDEx.Document`, or `~MD[...]MD` | Normalization, round-tripping |
| Delta | `to_delta!/2` or `~MD[...]DELTA` | Quill and rich text editors |

### Delta converters

Use `custom_converters` when a node should map to custom Delta operations.

```elixir
MDEx.to_delta!(markdown,
  custom_converters: %{
    MDEx.Image => fn image, _opts ->
      [%{"insert" => %{"image" => image.url}}]
    end
  }
)
```

## Options That Matter Most

### `extension:`

Turn on Markdown syntax that is not enabled by default.

Common examples:

```elixir
extension: [
  table: true,
  strikethrough: true,
  tasklist: true,
  autolink: true,
  footnotes: true,
  math_dollars: true,
  phoenix_heex: true
]
```

### `parse:`

Use for parsing behavior tweaks.

```elixir
parse: [smart: true, default_info_string: "text"]
```

### `render:`

Use for output behavior.

```elixir
render: [
  unsafe: true,
  github_pre_lang: true,
  full_info_string: true,
  hardbreaks: true
]
```

### `syntax_highlight:`

Use built-in lumis highlighting or disable it.

```elixir
syntax_highlight: [formatter: {:html_inline, theme: "github_light"}]
syntax_highlight: [formatter: {:html_linked, theme: "onedark"}]
syntax_highlight: nil
```

### `sanitize:`

Use when allowing raw HTML but still needing safe output.

```elixir
sanitize: MDEx.Document.default_sanitize_options()
```

### `codefence_renderers:`

Use when specific code fence info strings should render custom output.

```elixir
MDEx.to_html!(markdown,
  codefence_renderers: %{
    "chart" => fn _lang, _meta, code -> SvgCharts.render!(code) end
  }
)
```

## Safety Rules

- Raw HTML is omitted by default.
- Raw HTML requires `render: [unsafe: true]`.
- Use `render: [escape: true]` if you want raw HTML rendered as escaped text.
- If unsafe HTML is enabled for untrusted content, also set `sanitize:`.
- Use `MDEx.safe_html/2` when you need to sanitize an HTML string directly.

```elixir
MDEx.to_html!(markdown,
  render: [unsafe: true],
  sanitize: MDEx.Document.default_sanitize_options()
)
```

## AST and Traversal Patterns

Use these when the agent needs structural changes rather than string replacement.

### Access and Enum protocols

`MDEx.Document` implements `Access`, `Enumerable`, and `Collectable`.

```elixir
doc = MDEx.parse_document!(markdown)

headings = doc[MDEx.Heading]
first_node = doc[0]
texts = doc[:text]
count = Enum.count(doc)
```

### Tree traversal

Prefer structural transforms with `MDEx.traverse_and_update/2` or `MDEx.Document.update_nodes/3`.

```elixir
doc =
  MDEx.parse_document!(markdown)
  |> MDEx.traverse_and_update(fn
    %MDEx.Text{literal: text} = node -> %{node | literal: String.upcase(text)}
    node -> node
  end)
```

### Wrapping inline nodes

Inline nodes cannot be document roots. Wrap them first.

```elixir
doc = MDEx.Document.wrap(%MDEx.Text{literal: "Hello"})
```

## Common Mistakes

1. **Using `to_html!/2` for Phoenix components** - Use HEEx APIs instead.
2. **Using runtime rendering for static literals** - Prefer the sigil.
3. **Forgetting `use MDEx` or `require MDEx`** - Required for `~MD` and `to_heex!/2`.
4. **Assuming HTML is allowed by default** - Raw HTML is omitted unless `unsafe: true` is set.
5. **Forgetting required extensions** - Tables, strikethrough, math, footnotes, and similar syntax need explicit options unless a plugin enables them.
6. **Treating `parse_fragment!/1` like a full document parser** - It is for one fragment node.
7. **Expecting component imports to be automatic in HEEx** - Import or fully qualify them yourself.
8. **Replacing streaming content with `put_markdown/2`** - It appends; create a new document if you want replacement.
9. **Putting inline nodes at the root** - Wrap them in a block container.
10. **Using plugins without attaching or passing them** - They do nothing until attached.

## Recommended Patterns

### Static site or fixed template content

Use `use MDEx` plus `~MD[...]HTML`.

### LiveView content with components

Use `use MDEx` plus `~MD[...]HEEX`.

### User-generated Markdown from a database

Use `MDEx.to_html!/2` and consider sanitization if raw HTML is enabled.

### LLM chat output

Use `MDEx.new(streaming: true)` and keep the document in state between chunks.

### Reusable Markdown processing pipeline

Use `MDEx.new/1`, attach plugins, append steps, then render.

### Custom semantic transforms

Parse to `MDEx.Document`, change nodes structurally, then render.

## Plugin Ecosystem

- `mdex_gfm` - GitHub Flavored Markdown helpers
- `mdex_mermaid` - Mermaid diagrams in code blocks
- `mdex_katex` - KaTeX math rendering
- `mdex_video_embed` - privacy-respecting video embeds
- `mdex_custom_heading_id` - custom heading IDs
- `mdex_mermex` - server-side Mermaid rendering with Mermex

## Reference Links

- HexDocs: https://hexdocs.pm/mdex
- `MDEx.Document`: https://hexdocs.pm/mdex/MDEx.Document.html
- `MDEx.Sigil`: https://hexdocs.pm/mdex/MDEx.Sigil.html
- Plugins guide: https://hexdocs.pm/mdex/plugins.html
- HEEx guide: https://hexdocs.pm/mdex/heex.html
- Streaming guide: https://hexdocs.pm/mdex/streaming.html
- Safety guide: https://hexdocs.pm/mdex/safety.html
- Code block decorators guide: https://hexdocs.pm/mdex/code_block_decorators.html
