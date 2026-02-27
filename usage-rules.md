# MDEx Usage Rules

MDEx is a fast and extensible Markdown parser for Elixir. It provides multiple output formats (HTML, HEEx, JSON, XML, Delta), syntax highlighting, plugins, and a powerful Document API for programmatic manipulation.

## Core Principles

1. **Prefer the ~MD Sigil** - It's the most idiomatic and performant approach (compile-time parsing)
2. **Use `use MDEx`** - Sets up the module with `require MDEx` and `import MDEx.Sigil`
3. **Use Document API for Manipulation** - Leverage the Req-like pipeline for transformations
4. **Enable Extensions as Needed** - Start minimal, add features progressively
5. **Chain Operations** - Compose transformations instead of nesting
6. **Leverage Protocols** - Use Access, Enumerable, and Collectable for tree operations

## Decision Guide: When to Use What

### Choose Your Approach

**Use `~MD[...]HTML` sigil when:**
- Content is static or known at compile-time
- Working with templates that have EEx assigns
- Performance is critical (compile-time = zero runtime parsing cost)
- Content won't change based on runtime data
- You're rendering in templates or views

**Use `~MD[...]HEEX` sigil when:**
- You need Phoenix LiveView components in Markdown
- Using `phx-*` bindings or Elixir expressions
- Rendering content with Phoenix function components like `<.link>`
- Building LiveView templates with Markdown

**Use `MDEx.to_html!/2` when:**
- Content comes from user input or database
- Markdown is dynamic and changes at runtime
- You need quick one-off conversions
- Working with external data sources
- Simple use case without manipulation

**Use `MDEx.to_heex!/2` when:**
- Dynamic content needs Phoenix component support at runtime
- Processing user-generated content with LiveView components
- Note: Prefer `~MD[...]HEEX` for static content (better performance)

**Use Document API (`MDEx.new/1` + pipeline) when:**
- You need to transform or manipulate the AST
- Building custom plugins
- Applying multiple transformations
- Need to inspect or modify nodes programmatically
- Working with streaming content
- Require complex preprocessing or postprocessing

**Use `MDEx.parse_document!/2` when:**
- You only need the AST (not HTML output)
- Building custom renderers
- Extracting structured data (TOC, metadata, etc.)
- Analyzing document structure
- Converting to non-HTML formats

**Use `MDEx.parse_fragment!/2` when:**
- Parsing a single Markdown element
- You expect exactly one node as result
- Building custom inline parsers

### Output Format Selection

| Format | Function | Use Case |
|--------|----------|----------|
| **HTML** | `to_html!/2` | Web rendering (most common) |
| **HEEx** | `to_heex!/2` | Phoenix LiveView with components |
| **JSON** | `to_json!/2` | API responses, data interchange |
| **XML** | `to_xml!/2` | Legacy systems, XML workflows |
| **Markdown** | `to_markdown!/2` | Normalize or reformat Markdown |
| **Delta** | `to_delta!/2` | Rich text editors (Quill) |

### Streaming vs Non-Streaming

**Use streaming (`streaming: true`) when:**
- Content arrives in chunks (AI responses, SSE)
- LiveView with incremental updates
- Real-time collaborative editing
- Progressive rendering is needed

**Use non-streaming (default) when:**
- You have complete Markdown upfront
- Single-shot conversions
- Static content rendering
- Batch processing

### Troubleshooting Quick Reference

**Problem: HTML is being escaped**
```elixir
# Solution: Enable unsafe mode (be careful!)
MDEx.to_html!(markdown, render: [unsafe: true])
```

**Problem: Phoenix components not rendering**
```elixir
# Solution: Use to_heex!/2 or ~MD[...]HEEX, not to_html!/2
~MD[<.link href="/">Home</.link>]HEEX
# Or at runtime:
MDEx.to_heex!(markdown, assigns: assigns)
```

**Problem: Syntax highlighting not working**
```elixir
# Solution: Ensure formatter is configured
syntax_highlight: [formatter: {:html_inline, theme: "onedark"}]
```

**Problem: Code decorators not working**
```elixir
# Solution: Enable both required render options
render: [github_pre_lang: true, full_info_string: true]
```

**Problem: Streaming not accumulating content**
```elixir
# Solution: Use Enum.into/2, not put_markdown/2
document = Enum.into(["chunk"], document)
```

**Problem: Table/strikethrough not rendering**
```elixir
# Solution: Enable GFM extensions
extension: [table: true, strikethrough: true]
```

**Problem: Can't use inline node as document root**
```elixir
# Solution: Wrap it in a block container
doc = MDEx.Document.wrap(inline_node)
```

**Problem: Plugins not being applied**
```elixir
# Solution: Use :plugins option or attach in pipeline
MDEx.to_html!(markdown, plugins: [MDExGFM])
# Or:
MDEx.new(markdown: md) |> MDExGFM.attach() |> MDEx.to_html!()
```

## Basic Usage

### Module Setup

Use the `use MDEx` macro to set up your module:

```elixir
defmodule MyApp.Content do
  use MDEx  # Adds: require MDEx, import MDEx.Sigil

  def render(markdown) do
    ~MD[#{markdown}]HTML
  end
end
```

### Simple Conversions

The most common use case is converting Markdown to HTML:

```elixir
# Using to_html! (runtime parsing)
MDEx.to_html!("# Hello World")
#=> "<h1>Hello World</h1>"

# With options
MDEx.to_html!("Hello ~world~", extension: [strikethrough: true])
#=> "<p>Hello <del>world</del></p>"

# With plugins (one-off usage)
MDEx.to_html!("# Title", plugins: [MDExGFM])
```

### Using the ~MD Sigil (PREFERRED)

**Always prefer the ~MD sigil when possible** - it compiles Markdown at compile-time, making it significantly faster and more idiomatic:

```elixir
use MDEx  # Or: import MDEx.Sigil

# Compile to HTML at compile-time
~MD[# Hello World]HTML
#=> "<h1>Hello World</h1>"

# Get Document AST (default, no modifier)
~MD[# Hello World]
#=> %MDEx.Document{nodes: [...]}

# Works with assigns
assigns = %{name: "Elixir"}
~MD[# Hello <%= @name %>]HTML
#=> "<h1>Hello Elixir</h1>"
```

### All Sigil Modifiers

```elixir
use MDEx

# No modifier - returns Document AST
~MD[# Hello]
#=> %MDEx.Document{nodes: [...]}

# HTML - returns HTML string
~MD[# Hello]HTML
#=> "<h1>Hello</h1>"

# HEEX - returns Phoenix.LiveView.Rendered (requires LiveView)
~MD[<.link href="/">Home</.link>]HEEX
#=> %Phoenix.LiveView.Rendered{...}

# JSON - returns JSON AST string
~MD[# Hello]JSON
#=> "{\"nodes\":[...]}"

# XML - returns XML with CommonMark DTD
~MD[# Hello]XML
#=> "<?xml version=\"1.0\"?>..."

# MD - returns normalized Markdown
~MD[#   Hello   ]MD
#=> "# Hello"

# DELTA - returns Quill Delta operations
~MD[# Hello]DELTA
#=> [%{"insert" => "Hello"}, %{"insert" => "\n", "attributes" => %{"header" => 1}}]
```

## Phoenix LiveView Integration (HEEx)

MDEx supports Phoenix LiveView components directly in Markdown via the HEEX modifier and `to_heex!/2` function.

### Using ~MD[...]HEEX (Compile-time)

```elixir
use MDEx

# Phoenix function components work directly
~MD[
# Welcome

<.link href="/" class="btn">Home</.link>

Click <.button phx-click="save">Save</.button> to continue.
]HEEX

# With assigns
assigns = %{user: %{name: "Alice"}}
~MD[
# Hello <%= @user.name %>

<.link navigate={~p"/users/#{@user.name}"}>Profile</.link>
]HEEX
```

### Using to_heex!/2 (Runtime)

```elixir
# Runtime HEEx conversion (use sparingly - slower than sigil)
markdown = "# Hello\n\n<.link href=\"/\">Home</.link>"
MDEx.to_heex!(markdown, assigns: %{})

# With assigns
MDEx.to_heex!("Welcome <%= @name %>", assigns: %{name: "World"})
```

### HEEx Requirements

- Requires Phoenix LiveView (`phoenix_live_view ~> 1.0`)
- Must use `use MDEx` or `require MDEx` for macros
- Automatically enables: `extension: [phoenix_heex: true]` and `render: [unsafe: true]`
- The `assigns` variable must be in scope for HEEX modifier

## Output Formats

MDEx supports multiple output formats from the same Markdown source:

```elixir
markdown = "# Hello **World**"

# HTML
MDEx.to_html!(markdown)
#=> "<h1>Hello <strong>World</strong></h1>"

# HEEx (with Phoenix components support)
MDEx.to_heex!(markdown, assigns: %{})
#=> %Phoenix.LiveView.Rendered{...}

# JSON
MDEx.to_json!(markdown)
#=> "{\"nodes\":[{\"nodes\":[{\"literal\":\"Hello \",\"node_type\":\"MDEx.Text\"}..."

# XML
MDEx.to_xml!(markdown)
#=> "<?xml version=\"1.0\" encoding=\"UTF-8\"?>..."

# Markdown (normalized)
doc = MDEx.parse_document!(markdown)
MDEx.to_markdown!(doc)
#=> "# Hello **World**"

# Quill Delta (for rich text editors)
MDEx.to_delta!(markdown)
#=> [%{"insert" => "Hello "}, %{"insert" => "World", "attributes" => %{"bold" => true}}, ...]
```

### Delta Format with Custom Converters

Customize how specific nodes convert to Delta operations:

```elixir
custom_converters = %{
  # Custom table rendering
  MDEx.Table => fn table, _opts ->
    [%{"insert" => "[Table: #{table.num_rows} rows]"}]
  end,

  # Skip math nodes
  MDEx.Math => fn _math, _opts -> :skip end,

  # Custom image handling
  MDEx.Image => fn image, _opts ->
    [%{"insert" => %{"image" => image.url}}]
  end
}

MDEx.to_delta!(markdown, custom_converters: custom_converters)
```

## Document API and AST Manipulation

MDEx provides a powerful Document API for programmatic manipulation of Markdown:

```elixir
# Create a document with options
document = MDEx.new(
  markdown: "# Hello",
  extension: [table: true, strikethrough: true],
  render: [unsafe: false],
  plugins: [MDExGFM]
)

# Parse and get AST
doc = MDEx.parse_document!("# Hello **World**")
#=> %MDEx.Document{nodes: [%MDEx.Heading{...}]}

# Parse a single fragment
node = MDEx.parse_fragment!("**bold**")
#=> %MDEx.Strong{nodes: [%MDEx.Text{literal: "bold"}]}

# Access nodes using protocols
doc[MDEx.Heading]  # Get all headings
doc[:text]         # Get all text nodes (atom shorthand)
doc[0]             # Get first node (depth-first traversal)
doc[-1]            # Get last node

# Access by function
doc[fn node -> Map.get(node, :level) == 1 end]

# Enumerate over all nodes
Enum.count(doc)
Enum.map(doc, fn node -> inspect(node) end)
Enum.filter(doc, fn node -> is_struct(node, MDEx.Code) end)

# Update nodes with Access
update_in(doc, [Access.at(1), :literal], &String.upcase/1)

# Traverse and update
MDEx.traverse_and_update(doc, fn
  %MDEx.Text{literal: text} = node -> %{node | literal: String.upcase(text)}
  node -> node
end)

# With accumulator
MDEx.traverse_and_update(doc, [], fn node, acc ->
  case node do
    %MDEx.Heading{} -> {node, [node | acc]}
    _ -> {node, acc}
  end
end)
```

### Document Pipeline (Req-like API)

Chain operations using the pipeline API:

```elixir
MDEx.new(markdown: "# Title")
|> MDEx.Document.put_options(extension: [table: true])
|> MDEx.Document.put_render_options(unsafe: true)
|> MDEx.Document.append_steps(custom_step: &my_transform/1)
|> MDEx.to_html!()
```

### Assigns

Store and access assigns in documents:

```elixir
doc = MDEx.new(markdown: "# Hello <%= @name %>")
|> MDEx.Document.assign(name: "World")
|> MDEx.Document.assign(:count, 42)

# Access in pipeline steps or HEEx rendering
doc.assigns.name  #=> "World"
```

### Private Storage

Store plugin-specific data:

```elixir
doc
|> MDEx.Document.put_private(:my_plugin, :processed, true)
|> MDEx.Document.get_private(:my_plugin, :processed, false)
|> MDEx.Document.update_private(:my_plugin, :count, 0, &(&1 + 1))
```

### Protocols

MDEx.Document implements several protocols for flexible manipulation:

- **Access** - Get/update nodes by index, type, or function
- **Enumerable** - Use Enum functions (map, filter, reduce, etc.)
- **Collectable** - Build documents by collecting nodes or chunks
- **String.Chars** - Convert to CommonMark with `to_string/1`
- **Inspect** - Pretty-print document tree

## Plugins

MDEx supports a plugin system via the Document pipeline API. Plugins use `append_steps/2` to inject transformation steps.

### Using Plugins

Three ways to use plugins:

```elixir
# 1. Via :plugins option (one-off conversions)
MDEx.to_html!(markdown, plugins: [MDExGFM])
MDEx.to_html!(markdown, plugins: [{MDExMermaid, mermaid_version: "11"}])

# 2. Via attach in pipeline
MDEx.new(markdown: "# Title")
|> MDExGFM.attach()
|> MDExMermaid.attach(mermaid_version: "11")
|> MDEx.to_html!()

# 3. Via put_plugins
MDEx.new(markdown: "# Title")
|> MDEx.Document.put_plugins([MDExGFM, {MDExMermaid, mermaid_version: "11"}])
|> MDEx.to_html!()
```

## Plugins

- [mdex_gfm](https://hex.pm/packages/mdex_gfm) - Enable [GitHub Flavored Markdown](https://github.github.com/gfm) (GFM)
- [mdex_mermaid](https://hex.pm/packages/mdex_mermaid) - Render [Mermaid](https://mermaid.js.org) diagrams in code blocks
- [mdex_katex](https://hex.pm/packages/mdex_katex) - Render math formulas using [KaTeX](https://katex.org)
- [mdex_video_embed](https://hex.pm/packages/mdex_video_embed) - Privacy-respecting video embeds from code blocks
- [mdex_custom_heading_id](https://hex.pm/packages/mdex_custom_heading_id) - Custom heading IDs for markdown headings
- [mdex_mermex](https://hex.pm/packages/mdex_mermex) - Render [Mermaid](https://mermaid.js.org) diagrams server-side using Mermex (Rust NIF)

See [Plugins Guide](https://hexdocs.pm/mdex/plugins.html) for more.

### Writing Custom Plugins

Plugins are modules that manipulate the Document through pipeline steps:

```elixir
defmodule MyPlugin do
  alias MDEx.Document

  def attach(document, options \\ []) do
    document
    # Register custom options
    |> Document.register_options([:my_option])
    # Merge user options
    |> Document.put_options(options)
    # Add transformation steps
    |> Document.append_steps(
      enable_unsafe: &enable_unsafe/1,
      inject_content: &inject_content/1,
      transform_nodes: &transform_nodes/1
    )
  end

  defp enable_unsafe(document) do
    Document.put_render_options(document, unsafe: true)
  end

  defp inject_content(document) do
    node = %MDEx.HtmlBlock{literal: "<div>Injected</div>"}
    Document.put_node_in_document_root(document, node, :top)
  end

  defp transform_nodes(document) do
    selector = fn
      %MDEx.CodeBlock{info: "custom"} -> true
      _ -> false
    end

    Document.update_nodes(document, selector, fn node ->
      %MDEx.HtmlBlock{literal: "<pre>#{node.literal}</pre>"}
    end)
  end
end

# Usage
MDEx.to_html!(markdown, plugins: [MyPlugin])
# Or:
MDEx.new(markdown: "# Title")
|> MyPlugin.attach(my_option: "value")
|> MDEx.to_html!()
```

## Syntax Highlighting

MDEx includes built-in syntax highlighting via [lumis](https://crates.io/crates/lumis) and [lumis](https://hex.pm/packages/lumis):

````elixir
MDEx.to_html!("""
```elixir
def hello do
  :world
end
```
""", syntax_highlight: [formatter: {:html_inline, theme: "github_dark"}])
````

### Formatters and Themes

```elixir
# HTML inline (styles embedded)
syntax_highlight: [formatter: {:html_inline, theme: "onedark"}]

# HTML linked (CSS classes)
syntax_highlight: [formatter: {:html_linked, theme: "github_light"}]

# Disable syntax highlighting
syntax_highlight: nil

# Get available themes and languages
Lumis.available_themes()
#=> ["onedark", "github_dark", "github_light", ...]

Lumis.available_languages()
#=> ["elixir", "rust", "javascript", ...]
```

See [Lumis themes](https://docs.rs/lumis/latest/lumis/#themes-available) for theme details and [Lumis documentation](https://hexdocs.pm/lumis) for configuration.

## Code Block Decorators

Customize individual code blocks with decorators in the info string.

**Prerequisites**: Enable both render options:

```elixir
render: [github_pre_lang: true, full_info_string: true]
```

### Decorator Examples

````markdown
# Override theme
```elixir theme=github_dark
def hello, do: :world
```

# Add CSS classes
```javascript pre_class="my-class interactive"
console.log("Hello");
```

# Highlight specific lines
```python highlight_lines="1,3-5"
import math
x = 1
y = 2
z = 3
result = x + y + z
```

# Custom highlight styling (html_inline only)
```ruby highlight_lines="2" highlight_lines_style="background: yellow;"
def method
  # highlighted line
end
```

# Include syntax token data
```rust include_highlights
let x: i32 = 42;
```
````

See the [Code Block Decorators Guide](https://hexdocs.pm/mdex/code_block_decorators.html) for complete documentation.

## Streaming

MDEx supports streaming for real-time Markdown processing (e.g., AI chat applications). Streaming automatically completes incomplete fragments to ensure valid output at each render.

### Basic Streaming with put_markdown

```elixir
# Create a streaming document
doc = MDEx.new(streaming: true)

# Add initial chunk
doc = MDEx.Document.put_markdown(doc, "**Fol")
MDEx.to_html!(doc)
#=> "<p><strong>Fol</strong></p>"  (temporary completion)

# Add more content (overwrites previous markdown)
doc = MDEx.Document.put_markdown(doc, "**Follow**")
MDEx.to_html!(doc)
#=> "<p><strong>Follow</strong></p>"  (final output)
```

### Incremental Updates with Collectable Protocol

**Preferred for LiveView and incremental streaming** - Use the Collectable protocol to append chunks:

```elixir
# Initialize streaming document
document = MDEx.new(streaming: true)

# Collect chunks incrementally (accumulates content)
document = Enum.into(["**Hel"], document)
MDEx.to_html!(document)
#=> "<p><strong>Hel</strong></p>"

document = Enum.into(["lo**\n\n"], document)
MDEx.to_html!(document)
#=> "<p><strong>Hello</strong></p>"

document = Enum.into(["Next ", "paragraph"], document)
MDEx.to_html!(document)
#=> "<p><strong>Hello</strong></p>\n<p>Next paragraph</p>"
```

### LiveView Integration Pattern

```elixir
defmodule MyAppWeb.ChatLive do
  use MyAppWeb, :live_view
  use MDEx

  def mount(_params, _session, socket) do
    {:ok, assign(socket, document: MDEx.new(streaming: true), html: "")}
  end

  def handle_info({:chunk, chunk}, socket) do
    # Accumulate chunk using Collectable protocol
    document = Enum.into([chunk], socket.assigns.document)
    html = MDEx.to_html!(document)

    {:noreply, assign(socket, document: document, html: html)}
  end
end
```

**Use Cases**:
- AI/LLM chat responses arriving in chunks
- Real-time collaborative editing
- Progressive content loading
- Streaming API responses

See the [Streaming Example](https://github.com/leandrocp/mdex/blob/main/examples/streaming.exs) for a complete LiveView demo.

## Safety and Sanitization

By default, MDEx escapes HTML for safety. Use sanitization and unsafe rendering carefully:

```elixir
# Default: HTML is escaped
MDEx.to_html!("<script>alert('xss')</script>")
#=> (escaped output)

# Allow raw HTML (UNSAFE)
MDEx.to_html!("<div>Custom HTML</div>", render: [unsafe: true])
#=> "<p><div>Custom HTML</div></p>"

# Sanitize HTML after rendering
MDEx.to_html!("<script>bad</script><p>Good</p>",
  render: [unsafe: true],
  sanitize: MDEx.Document.default_sanitize_options()
)
#=> "<p>Good</p>"  (script removed)

# Custom sanitization
MDEx.to_html!(markdown,
  render: [unsafe: true],
  sanitize: [
    rm_tags: ["script", "iframe"],
    add_tags: ["custom-component"]
  ]
)

# Escape curly braces only in code (for LiveView compatibility)
MDEx.safe_html(html, escape: [curly_braces_in_code: true])
```

Sanitization uses [ammonia](https://crates.io/crates/ammonia) for HTML cleaning.

See [Safety Guide](https://hexdocs.pm/mdex/safety.html) for security best practices.

## Node Types

MDEx provides 55+ node types for complete Markdown representation:

### Block Nodes (can be document root)

| Node | Description |
|------|-------------|
| `MDEx.Document` | Document root container |
| `MDEx.Heading` | Headings (level 1-6) |
| `MDEx.Paragraph` | Paragraph container |
| `MDEx.BlockQuote` | Block quote |
| `MDEx.List` | Bullet or ordered list |
| `MDEx.ListItem` | List item |
| `MDEx.TaskItem` | Task list item with checkbox |
| `MDEx.CodeBlock` | Fenced or indented code |
| `MDEx.HtmlBlock` | Raw HTML block |
| `MDEx.ThematicBreak` | Horizontal rule |
| `MDEx.Table` | GFM table |
| `MDEx.TableRow` | Table row |
| `MDEx.TableCell` | Table cell |
| `MDEx.FootnoteDefinition` | Footnote definition |
| `MDEx.DescriptionList` | Definition list |
| `MDEx.DescriptionItem` | Definition item |
| `MDEx.DescriptionTerm` | Definition term |
| `MDEx.DescriptionDetails` | Definition details |
| `MDEx.Alert` | GitHub/GitLab alerts |
| `MDEx.MultilineBlockQuote` | Multiline block quote |
| `MDEx.FrontMatter` | YAML front matter |

### Inline Nodes (require block parent)

| Node | Description |
|------|-------------|
| `MDEx.Text` | Plain text |
| `MDEx.Code` | Inline code |
| `MDEx.Strong` | Bold text |
| `MDEx.Emph` | Italic text |
| `MDEx.Strikethrough` | Strikethrough text |
| `MDEx.Underline` | Underlined text |
| `MDEx.Subscript` | Subscript (H~2~O) |
| `MDEx.Superscript` | Superscript (E=mc^2^) |
| `MDEx.SpoileredText` | Spoiler text |
| `MDEx.Highlight` | Highlighted text |
| `MDEx.Link` | Hyperlink |
| `MDEx.WikiLink` | Wiki-style link |
| `MDEx.Image` | Image |
| `MDEx.Math` | Math expression |
| `MDEx.HtmlInline` | Inline raw HTML |
| `MDEx.SoftBreak` | Soft line break |
| `MDEx.LineBreak` | Hard line break |
| `MDEx.FootnoteReference` | Footnote reference |
| `MDEx.ShortCode` | Emoji shortcode |
| `MDEx.Escaped` | Escaped character |
| `MDEx.HeexBlock` | Phoenix HEEx block |
| `MDEx.HeexInline` | Phoenix HEEx inline |

## Common Patterns

### Table of Contents

```elixir
doc = MDEx.parse_document!(markdown)

Enum.reduce(doc, [], fn
  %MDEx.Heading{level: level, nodes: [%MDEx.Text{literal: text}]}, acc ->
    [{level, text, MDEx.anchorize(text)} | acc]
  _, acc -> acc
end)
|> Enum.reverse()
```

### Transform Code Blocks

```elixir
MDEx.parse_document!(markdown)
|> MDEx.traverse_and_update(fn
  %MDEx.CodeBlock{info: "mermaid"} = node ->
    %MDEx.HtmlBlock{literal: render_mermaid(node.literal)}
  node -> node
end)
|> MDEx.to_html!()
```

### Extract Front Matter

```elixir
doc = MDEx.parse_document!(markdown,
  extension: [front_matter_delimiter: "---"])

front_matter = doc[MDEx.FrontMatter] |> List.first()
YamlElixir.read_from_string!(front_matter.literal)
```

### Find All Links

```elixir
doc = MDEx.parse_document!(markdown)

links = Enum.filter(doc, fn
  %MDEx.Link{} -> true
  _ -> false
end)
```

### Custom Node Transformation

```elixir
# Convert all code blocks of a specific language
MDEx.Document.update_nodes(doc,
  fn %MDEx.CodeBlock{info: "diagram"} -> true; _ -> false end,
  fn node -> %MDEx.HtmlBlock{literal: render_diagram(node.literal)} end
)
```

## Options Reference

MDEx provides several option categories for controlling parsing and rendering behavior:

### Extension Options

Enable features like GFM, math, and more:

```elixir
extension: [
  # GFM features
  strikethrough: true,
  table: true,
  autolink: true,
  tasklist: true,
  tagfilter: true,

  # Math
  math_dollars: true,
  math_code: true,

  # Advanced
  superscript: true,
  subscript: true,
  footnotes: true,
  description_lists: true,
  wikilinks_title_after_pipe: true,

  # Text styling
  underline: true,
  spoiler: true,
  highlight: true,

  # Other
  header_ids: "prefix-",
  front_matter_delimiter: "---",
  alerts: true,
  shortcodes: true,
  phoenix_heex: true  # For HEEx support
]
```

### Parse Options

Control parsing behavior:

```elixir
parse: [
  smart: true,                    # Smart punctuation
  relaxed_tasklist_matching: true,
  relaxed_autolinks: true,
  default_info_string: "text"
]
```

### Render Options

Control output generation:

```elixir
render: [
  unsafe: true,              # Allow raw HTML
  escape: false,             # Escape special characters
  github_pre_lang: true,     # Use lang attr on pre tag
  full_info_string: true,    # Keep full info string
  hardbreaks: true,          # Convert newlines to <br>
  sourcepos: true,           # Add source positions
  figure_with_caption: true  # Wrap images in figure
]
```

### Syntax Highlight Options

```elixir
syntax_highlight: [
  formatter: {:html_inline, theme: "onedark"}
]
# Or disable:
syntax_highlight: nil
```

### Sanitize Options

```elixir
sanitize: [
  tags: ["p", "a", "code"],           # Allowed tags
  add_tags: ["custom-tag"],
  rm_tags: ["script"],
  tag_attributes: %{"a" => ["href"]},
  url_schemes: ["http", "https"],
  link_rel: "noopener noreferrer"
]
```

See [MDEx.Document typespecs](https://hexdocs.pm/mdex/MDEx.Document.html) for complete option documentation.

## Foundation Libraries

MDEx is built on top of these high-quality Rust libraries:

- **[comrak](https://crates.io/crates/comrak)** - Fast CommonMark parser (port of GitHub's cmark-gfm)
  - [Documentation](https://docs.rs/comrak/latest/comrak/)

- **[ammonia](https://crates.io/crates/ammonia)** - HTML sanitization
  - [Documentation](https://docs.rs/ammonia/latest/ammonia/)

- **[lumis](https://crates.io/crates/lumis)** - Syntax highlighting powered by Tree-sitter and Neovim themes
  - [Documentation](https://docs.rs/lumis/latest/lumis/)
  - [Available Themes](https://docs.rs/lumis/latest/lumis/#themes-available)

- **[lumis](https://hex.pm/packages/lumis)** - Elixir wrapper for lumis
  - [Documentation](https://hexdocs.pm/lumis/Lumis.html)

## Resources

### Official Documentation

- **[Hex Package](https://hex.pm/packages/mdex)** - Package on Hex.pm
- **[HexDocs](https://hexdocs.pm/mdex)** - Complete API documentation
- **[GitHub Repository](https://github.com/leandrocp/mdex)** - Source code and issues

### Guides

- [Plugins](https://hexdocs.pm/mdex/plugins.html) - How to use and create plugins
- [Code Block Decorators](https://hexdocs.pm/mdex/code_block_decorators.html) - Customize code blocks
- [Safety](https://hexdocs.pm/mdex/safety.html) - Security best practices
- [Compilation](https://hexdocs.pm/mdex/compilation.html) - Build and compilation info

### Examples (Livebooks)

- [GitHub Flavored Markdown](https://hexdocs.pm/mdex/gfm.html) - GFM features demo
- [Syntax Highlighting](https://hexdocs.pm/mdex/syntax_highlight.html) - Highlighting themes
- [Code Block Decorators](https://hexdocs.pm/mdex/code_block_decorators-1.html) - Decorator examples
- [Mermaid Diagrams](https://hexdocs.pm/mdex/mermaid.html) - Mermaid plugin demo
- [Custom Themes](https://hexdocs.pm/mdex/custom_theme.html) - Custom syntax themes
- [Liquid Templates](https://hexdocs.pm/mdex/liquid.html) - Liquid integration
- [Highlight Words](https://hexdocs.pm/mdex/highlight_words.html) - Word highlighting
- [Streaming Example](https://github.com/leandrocp/mdex/blob/main/examples/streaming.exs) - Real-time streaming

## Performance Tips

1. **Use ~MD sigil** for static content (compile-time parsing)
2. **Use `use MDEx`** to set up modules correctly
3. **Pass `:plugins` option** for one-off conversions instead of building pipelines
4. **Minimize document rebuilds** when using the pipeline API
5. **Cache rendered output** for frequently accessed content
6. **Disable unused extensions** to reduce parsing overhead
7. **Use `Enum.into/2`** for streaming instead of repeated `put_markdown/2`
8. **Prefer `~MD[...]HEEX`** over `to_heex!/2` for static content

## Common Gotchas

1. **Info String Order** - Language must come first: `elixir theme=dark` (not `theme=dark elixir`)

2. **Streaming Requires Flag** - Set `streaming: true` explicitly when creating documents

3. **Unsafe HTML** - Raw HTML requires `render: [unsafe: true]`
   ```elixir
   # Wrong: HTML is escaped by default
   MDEx.to_html!("<div>Custom</div>")
   #=> "&lt;div&gt;Custom&lt;/div&gt;"

   # Right: Enable unsafe mode
   MDEx.to_html!("<div>Custom</div>", render: [unsafe: true])
   #=> "<p><div>Custom</div></p>"
   ```

4. **Phoenix Components** - Use `to_heex!/2` or `~MD[...]HEEX`, not `to_html!/2`
   ```elixir
   # Wrong: to_html! doesn't support components
   MDEx.to_html!("<.link href=\"/\">Home</.link>")

   # Right: Use HEEX
   ~MD[<.link href="/">Home</.link>]HEEX
   ```

5. **Code Decorators** - Need both `github_pre_lang: true` and `full_info_string: true`

6. **Extension Conflicts** - Some extensions may interact unexpectedly, test combinations
   - `underline: true` requires specific parse options
   - Discord features (`greentext`, `multiline_block_quotes`) may conflict with standard Markdown

7. **Fragment Nodes** - Not all nodes can be used as document root
   ```elixir
   # Wrong: Inline nodes like Text can't be document root
   doc = %MDEx.Document{nodes: [%MDEx.Text{literal: "Hello"}]}

   # Right: Wrap inline nodes in a block container
   doc = MDEx.Document.wrap(%MDEx.Text{literal: "Hello"})
   #=> Document with Paragraph containing Text
   ```

8. **Streaming Position** - `put_markdown/2` replaces content, use `Enum.into/2` for accumulation
   ```elixir
   # Wrong for incremental updates
   doc = MDEx.Document.put_markdown(doc, "chunk1")
   doc = MDEx.Document.put_markdown(doc, "chunk2")  # Overwrites chunk1!

   # Right: Use Collectable protocol
   doc = Enum.into(["chunk1"], doc)
   doc = Enum.into(["chunk2"], doc)  # Accumulates
   ```

9. **Assigns Scope** - For `~MD[...]HEEX`, the `assigns` variable must be in scope
   ```elixir
   # Wrong: assigns not defined
   ~MD[Hello <%= @name %>]HEEX

   # Right: Define assigns first
   assigns = %{name: "World"}
   ~MD[Hello <%= @name %>]HEEX
   ```

10. **Plugin Application** - Plugins must be attached or passed via `:plugins` option
    ```elixir
    # Wrong: Plugin not applied
    MDEx.new(markdown: md)
    |> MDEx.to_html!()

    # Right: Attach plugin or use :plugins option
    MDEx.to_html!(md, plugins: [MDExGFM])
    ```
