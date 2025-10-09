# MDEx Usage Rules

MDEx is a fast and extensible Markdown parser for Elixir. It provides multiple output formats, syntax highlighting, plugins, and a powerful Document API for programmatic manipulation.

## Core Principles

1. **Prefer the ~MD Sigil** - It's the most idiomatic and performant approach (compile-time parsing)
2. **Use Document API for Manipulation** - Leverage the Req-like pipeline for transformations
3. **Enable Extensions as Needed** - Start minimal, add features progressively
4. **Chain Operations** - Compose transformations instead of nesting
5. **Leverage Protocols** - Use Access, Enumerable, and Collectable for tree operations

## Basic Usage

### Simple Conversions

The most common use case is converting Markdown to HTML:

```elixir
# Using to_html! (runtime parsing)
MDEx.to_html!("# Hello World")
#=> "<h1>Hello World</h1>"

# With options
MDEx.to_html!("Hello ~world~", extension: [strikethrough: true])
#=> "<p>Hello <del>world</del></p>"
```

### Using the ~MD Sigil (PREFERRED)

**Always prefer the ~MD sigil when possible** - it compiles Markdown at compile-time, making it significantly faster and more idiomatic:

```elixir
import MDEx.Sigil

# Compile to HTML at compile-time
~MD[# Hello World]HTML
#=> "<h1>Hello World</h1>"

# Get Document AST
~MD[# Hello World]
#=> %MDEx.Document{nodes: [...]}

# Works with assigns
assigns = %{name: "Elixir"}
~MD[# Hello <%= @name %>]HTML
#=> "<h1>Hello Elixir</h1>"
```

## Output Formats

MDEx supports multiple output formats from the same Markdown source:

```elixir
markdown = "# Hello **World**"

# HTML
MDEx.to_html!(markdown)
#=> "<h1>Hello <strong>World</strong></h1>"

# JSON
MDEx.to_json!(markdown)
#=> "{\"nodes\":[{\"nodes\":[{\"literal\":\"Hello \",\"node_type\":\"MDEx.Text\"}..."

# XML
MDEx.to_xml!(markdown)
#=> "<?xml version=\"1.0\" encoding=\"UTF-8\"?>..."

# Markdown
doc = MDEx.parse_document!(markdown)
MDEx.to_markdown!(doc)
#=> "# Hello **World**"

# Quill Delta (for rich text editors)
MDEx.to_delta!(markdown)
#=> [%{"insert" => "Hello "}, %{"insert" => "World", "attributes" => %{"bold" => true}}, ...]
```

## Document API and AST Manipulation

MDEx provides a powerful Document API for programmatic manipulation of Markdown:

```elixir
# Create a document with options
document = MDEx.new(
  markdown: "# Hello",
  extension: [table: true, strikethrough: true],
  render: [unsafe: false]
)

# Parse and get AST
doc = MDEx.parse_document!("# Hello **World**")
#=> %MDEx.Document{nodes: [%MDEx.Heading{...}]}

# Access nodes using protocols
doc[MDEx.Heading]  # Get all headings
doc[:text]         # Get all text nodes
doc[0]             # Get first node (depth-first traversal)

# Enumerate over all nodes
Enum.count(doc)
Enum.map(doc, fn %node{} -> inspect(node) end)

# Update nodes
update_in(doc, [:document, Access.key!(:nodes), Access.all(), :code], fn code_node ->
  %{code_node | literal: String.upcase(code_node.literal)}
end)

# Traverse and update
MDEx.traverse_and_update(doc, fn
  %MDEx.Text{literal: text} = node -> %{node | literal: String.upcase(text)}
  node -> node
end)
```

### Document Pipeline (Req-like API)

Chain operations using the pipeline API:

```elixir
MDEx.new(markdown: "# Title")
|> MDEx.Document.put_options(extension: [table: true])
|> MDEx.Document.append_steps(custom_step: &my_transform/1)
|> MDEx.to_html!()
```

### Protocols

MDEx.Document implements several protocols for flexible manipulation:

- **Access** - Get/update nodes by index, type, or function
- **Enumerable** - Use Enum functions (map, filter, reduce, etc.)
- **Collectable** - Build documents by collecting nodes
- **String.Chars** - Convert to CommonMark with `to_string/1`
- **Inspect** - Pretty-print document tree

## Plugins

MDEx supports a plugin system via the Document pipeline API. Plugins use `append_steps/2` to inject transformation steps.

### Using Existing Plugins

```elixir
# GitHub Flavored Markdown plugin
MDEx.new(markdown: "# Title")
|> MDExGFM.attach()
|> MDEx.to_html!()

# Mermaid diagrams plugin
MDEx.new(markdown: "```mermaid\ngraph TD\nA-->B\n```")
|> MDExMermaid.attach(mermaid_version: "11")
|> MDEx.to_html!()
```

Available plugins listed at [Plugins](https://hexdocs.pm/mdex/plugins.html)

### Writing Custom Plugins

Plugins are modules that manipulate the Document through pipeline steps:

```elixir
defmodule MyPlugin do
  alias MDEx.Document

  def attach(document, options \\\\ []) do
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
MDEx.new(markdown: "# Title")
|> MyPlugin.attach(my_option: "value")
|> MDEx.to_html!()
```

## Syntax Highlighting

MDEx includes built-in syntax highlighting via [autumnus](https://crates.io/crates/autumnus) and [autumn](https://hex.pm/packages/autumn):

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
Autumn.available_themes()
#=> ["onedark", "github_dark", "github_light", ...]

Autumn.available_languages()
#=> ["elixir", "rust", "javascript", ...]
```

See [Autumnus themes](https://docs.rs/autumnus/latest/autumnus/#themes-available) for theme details and [Autumn documentation](https://hexdocs.pm/autumn) for configuration.

## Code Block Decorators

Customize individual code blocks with decorators in the info string.

See the [Code Block Decorators Guide](https://hexdocs.pm/mdex/code_block_decorators-2.html) and [Livebook Example](https://hexdocs.pm/mdex/code_block_decorators-1.html) for complete documentation.

**Prerequisites**: Enable both render options:

```elixir
render: [github_pre_lang: true, full_info_string: true]
```

### Decorators Examples

````elixir
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

## Streaming

MDEx supports streaming for real-time Markdown processing (e.g., AI chat applications):

```elixir
# Enable streaming
doc = MDEx.new(streaming: true)
|> MDEx.Document.put_markdown("**Fol")
|> MDEx.to_html!()
#=> "<p><strong>Fol</strong></p>"  (temporary completion)

# Add more content
doc
|> MDEx.Document.put_markdown("low**")
|> MDEx.to_html!()
#=> "<p><strong>Follow</strong></p>"  (final output)
```

Streaming automatically completes incomplete fragments to ensure valid output at each render.

**Use Cases**:
- AI/LLM chat responses arriving in chunks
- Real-time collaborative editing
- Progressive content loading

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
```

Sanitization uses [ammonia](https://crates.io/crates/ammonia) for HTML cleaning.

See [Safety Guide](https://hexdocs.pm/mdex/safety.html) for security best practices.

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

## Options Reference

MDEx provides several option categories for controlling parsing and rendering behavior:

- **[extension](https://hexdocs.pm/mdex/MDEx.Document.html#t:extension_options/0)** - Enable GFM features (tables, strikethrough, tasklists), math, emoji, WikiLinks, etc.
- **[parse](https://hexdocs.pm/mdex/MDEx.Document.html#t:parse_options/0)** - Control parsing behavior (smart punctuation, autolinks, etc.)
- **[render](https://hexdocs.pm/mdex/MDEx.Document.html#t:render_options/0)** - Control output (unsafe mode, code block formatting, etc.)
- **[syntax_highlight](https://hexdocs.pm/mdex/MDEx.Document.html#t:syntax_highlight_options/0)** - Configure syntax highlighting formatter and theme
- **[sanitize](https://hexdocs.pm/mdex/MDEx.Document.html#t:sanitize_options/0)** - HTML sanitization rules (tags, attributes, URL schemes, etc.)

Also see [comrak's documentation](https://docs.rs/comrak/latest/comrak/) for the underlying Rust library options.

## Foundation Libraries

MDEx is built on top of these high-quality Rust libraries:

- **[comrak](https://crates.io/crates/comrak)** - Fast CommonMark parser (port of GitHub's cmark-gfm)
  - [Documentation](https://docs.rs/comrak/latest/comrak/)
  - Provides the core Markdown parsing and rendering

- **[ammonia](https://crates.io/crates/ammonia)** - HTML sanitization
  - [Documentation](https://docs.rs/ammonia/latest/ammonia/)
  - Cleans untrusted HTML to prevent XSS attacks

- **[autumnus](https://crates.io/crates/autumnus)** - Syntax highlighting powered by Tree-sitter and Neovim themes
  - [Documentation](https://docs.rs/ammonia/latest/autumnus/)
  - [Available Themes](https://docs.rs/autumnus/latest/autumnus/#themes-available)
  - High-quality code highlighting for 100+ languages

- **[autumn](https://hex.pm/packages/autumn)** - Elixir wrapper for autumnus
  - [Documentation](https://hexdocs.pm/autumn/Autumn.html)

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

### Official Plugins

- [mdex_gfm](https://hex.pm/packages/mdex_gfm) - GitHub Flavored Markdown preset
- [mdex_mermaid](https://hex.pm/packages/mdex_mermaid) - Mermaid diagram rendering

## Performance Tips

1. **Use ~MD sigil** for static content (compile-time parsing)
2. **Minimize document rebuilds** when using the pipeline API
3. **Cache rendered output** for frequently accessed content
4. **Disable unused extensions** to reduce parsing overhead
5. **Use fragments** for partial updates in streaming scenarios
6. **Profile your usage** with benchmarking tools

## Common Gotchas

1. **Info String Order** - Language must come first: `elixir theme=dark` (not `theme=dark elixir`)
2. **Streaming Requires Flag** - Set `streaming: true` explicitly
3. **Unsafe HTML** - Raw HTML requires both `render: [unsafe: true]` and optionally sanitization
4. **Code Decorators** - Need both `github_pre_lang: true` and `full_info_string: true`
5. **Extension Conflicts** - Some extensions may interact unexpectedly, test combinations
6. **Fragment Nodes** - Not all nodes can be used as document root (use `wrap/1`)
