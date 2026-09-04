# MDEx Usage Rules

MDEx parses Markdown into an AST (`MDEx.Document`). It can render HTML, HEEx,
JSON, XML, CommonMark, or Quill Delta.

This file gives API rules for developers and coding agents.

## Agent Defaults

1. **Prefer `~MD` for static content** - If the Markdown is a literal known at compile time, use the sigil.
2. **Use `use MDEx` in modules that render Markdown** - It adds `require MDEx` and `import MDEx.Sigil`.
3. **Use `HEEX` only when you need Phoenix semantics** - Components, `phx-*`, `{@assigns}`, or HEEx expressions.
4. **Use runtime functions for runtime content** - Database content, user input, files, API responses, LLM output.
5. **Use `MDEx.Document` when you need control** - AST transforms, plugins, custom renderers, inspection.
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

- Pass the source Enumerable to `MDEx.stream/2`.
- Read `{id, %MDEx.Document{}}` chunks.
- Insert a new id and replace a repeated id.
- Treat all lower ids as stable after a higher id appears.
- Treat normal Stream completion as EOF.

```elixir
chunks
|> MDEx.stream(extension: [table: true])
|> Enum.each(fn {id, document} ->
  replace_rendered_chunk(id, MDEx.to_html!(document))
end)
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
    syntax_highlight: [engine: :lumis, opts: [formatter: {:html_inline, theme: "github_light"}]]
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

Use this as the entry point for document pipelines, plugins, assigns, and
shared option sets. Use `MDEx.stream/2` for an Enumerable of Markdown chunks.

```elixir
doc =
  MDEx.new(
    markdown: markdown,
    extension: [table: true],
    syntax_highlight: [engine: :lumis, opts: [formatter: {:html_inline, theme: "github_light"}]]
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

## Moving from Earmark

Most Earmark ports are direct, but do not copy options blindly. Earmark renders raw HTML by default; MDEx drops it unless you opt in with `render: [unsafe: true]`. For untrusted content, pair that with `sanitize:` instead of matching Earmark's default behavior.

```elixir
# Earmark
{:ok, html, _messages} = Earmark.as_html(markdown)

# MDEx
{:ok, html} = MDEx.to_html(markdown)
```

Use bang functions the same way:

```elixir
# Earmark
html = Earmark.as_html!(markdown)

# MDEx
html = MDEx.to_html!(markdown)
```

If the old code expected raw HTML to survive, make the choice explicit:

```elixir
MDEx.to_html!(markdown, render: [unsafe: true])
```

For user content, prefer sanitizing:

```elixir
MDEx.to_html!(markdown,
  render: [unsafe: true],
  sanitize: MDEx.Document.default_sanitize_options()
)
```

### GFM options

Replace `gfm: true` with the `MDExGFM` plugin when you want GitHub Flavored Markdown behavior such as task lists:

```elixir
# Earmark
Earmark.as_html!(markdown, gfm: true)

# MDEx
MDEx.to_html!(markdown,
  plugins: [MDExGFM],
  render: [unsafe: true]
)
```

If you only need one feature, enable the MDEx option directly:

```elixir
MDEx.to_html!(markdown, extension: [table: true, strikethrough: true, tasklist: true])
```

### Common option replacements

| Earmark | MDEx |
| --- | --- |
| `breaks: true` | `render: [hardbreaks: true]` |
| `smartypants: true` | `parse: [smart: true]` |
| `gfm: true` | `plugins: [MDExGFM]` or explicit `extension:` options |
| raw HTML by default | `render: [unsafe: true]`, plus `sanitize:` for untrusted content |

### AST ports

Earmark's AST is HTML-shaped tuples. MDEx returns a `%MDEx.Document{}` with typed nodes, source positions, options, and pipeline state.

```elixir
# Earmark
{:ok, ast, _messages} = Earmark.Parser.as_ast(markdown)

# MDEx
{:ok, document} = MDEx.parse_document(markdown)
```

For structural changes, rewrite tuple-walking code with `MDEx.Document.update_nodes/3` or `MDEx.traverse_and_update/2`.

```elixir
document =
  markdown
  |> MDEx.parse_document!()
  |> MDEx.Document.update_nodes(MDEx.Text, fn node ->
    %{node | literal: String.upcase(node.literal)}
  end)
```

### Output differences to expect

- MDEx emits compact CommonMark-style HTML, so whitespace will differ from Earmark.
- Code block classes differ: Earmark commonly emits `class="elixir"`; MDEx emits `class="language-elixir"` unless a plugin or renderer changes it.
- Task lists need GFM support in MDEx. Without it, `- [x] Ship it` is plain list text.
- Raw HTML is wrapped according to CommonMark parsing rules and is still controlled by `render: [unsafe: true]`.

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

Use `MDEx.stream/2` for LLM, SSE, file, or HTTP response chunks.

- Pass any Enumerable of binary chunks directly to `MDEx.stream/2`.
- Insert a chunk when its id is new.
- Replace a chunk when its id repeats.
- Keep chunks in id order. Replacing an earlier id does not move it.
- Render each document. MDEx closes partial syntax for the open chunk.
- EOF emits a replacement only when removing partial syntax changes the AST.
- Change the emitted AST before rendering when the transform only needs one
  keyed document.
- Do not assume an emitted document contains the full Markdown response.
- Plugins attach once when Stream enumeration starts. Their pipeline steps run
  on every emitted document, including repeated ids.
- Plugin parser options apply before parsing, but plugin steps remain local to
  one keyed document.
- Do not use a plugin that preprocesses `document.buffer` with
  `MDEx.stream/2`. Use the one-document API after collecting the full source.
- Use normal Stream completion as EOF.

```elixir
["# Hel", "lo\n\n", "**world**"]
|> MDEx.stream()
|> Enum.each(fn {id, document} ->
  replace_rendered_chunk(id, MDEx.to_html!(document))
end)
```

### Partial Markdown

`:auto_close` closes Markdown syntax left open at the end of the source, so
`Some **bo` renders as bold rather than literal asterisks. It works on every
render function, defaults to `false`, and defaults to `true` in `MDEx.stream/2`.

```elixir
MDEx.to_html!(source, auto_close: true)
chunks |> MDEx.stream(auto_close: false)
```

Use it when you hold the whole response as a string and only need it to render
sensibly while it grows. Use `MDEx.stream/2` when you have the chunks and want
keyed output.

`MDEx.new(streaming: true)` is deprecated. Use `:auto_close`.
`MDEx.Document.put_markdown/3` is for composing a document from separate pieces
of Markdown, not for feeding chunks — it renders the AST back to Markdown on
every call, which is slower and loses blank lines, list looseness, and table
delimiter rows.

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

Use Lumis, use Syntect, or disable highlighting.

```elixir
syntax_highlight: [engine: :lumis, opts: [formatter: {:html_inline, theme: "github_light"}]]
syntax_highlight: [engine: :syntect, opts: [theme: "Catppuccin Macchiato"]]
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
8. **Using `MDEx.new(streaming: true)`** - It is deprecated; use `auto_close: true`.
9. **Putting inline nodes at the root** - Wrap them in a block container.
10. **Using plugins without attaching or passing them** - They do nothing until attached.
11. **Feeding stream chunks to `MDEx.Document.put_markdown/3`** - It composes documents; use `MDEx.stream/2` for chunks.

## Recommended Patterns

### Static site or fixed template content

Use `use MDEx` plus `~MD[...]HTML`.

### LiveView content with components

Use `use MDEx` plus `~MD[...]HEEX`.

### User-generated Markdown from a database

Use `MDEx.to_html!/2` and consider sanitization if raw HTML is enabled.

### LLM chat output

Pass the provider's text chunks through `MDEx.stream/2`. Insert new ids and
replace repeated ids.

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
- `mdex_multiline_cells` - multi-line cells in Markdown tables

## Reference Links

- HexDocs: https://hexdocs.pm/mdex
- `MDEx.Document`: https://hexdocs.pm/mdex/MDEx.Document.html
- `MDEx.Sigil`: https://hexdocs.pm/mdex/MDEx.Sigil.html
- Plugins guide: https://hexdocs.pm/mdex/plugins.html
- HEEx guide: https://hexdocs.pm/mdex/heex.html
- Streaming guide: https://hexdocs.pm/mdex/streaming.html
- Safety guide: https://hexdocs.pm/mdex/safety.html
- Earmark migration guide: https://hexdocs.pm/mdex/earmark_to_mdex.html
- Code block decorators guide: https://hexdocs.pm/mdex/code_block_decorators.html
