# Plugins

Plugins are reusable modules that extend MDEx's functionality by registering options, appending processing steps, and transforming the document tree. They provide a clean way to package and share custom behavior.

## Using Existing Plugins

There are three ways to attach plugins to a document:

### Via `MDEx.new/1`

The most common approach is passing plugins when creating a new document:

```elixir
MDEx.new(markdown: "# Hello", plugins: [MyPlugin])
|> MDEx.to_html!()
```

You can pass options to plugins using a tuple:

```elixir
MDEx.new(markdown: "# Hello", plugins: [{MyPlugin, custom_option: "value"}])
|> MDEx.to_html!()
```

### Via `:plugins` option in `MDEx.to_html/2`

For convenience, you can pass plugins directly to rendering functions:

```elixir
MDEx.to_html!("# Hello", plugins: [MyPlugin])
```

### Via `MDEx.Document.put_plugins/2`

For more control, attach plugins manually to a document:

```elixir
MDEx.new(markdown: "# Hello")
|> MDEx.Document.put_plugins([MyPlugin])
|> MDEx.to_html!()
```

You can also call the plugin's `attach/2` function directly:

```elixir
MDEx.new(markdown: "# Hello")
|> MyPlugin.attach(custom_option: "value")
|> MDEx.to_html!()
```

## Streaming Plugins

Pass plugins to `MDEx.stream/2` with the same `:plugins` option:

```elixir
chunks
|> MDEx.stream(plugins: [{MyPlugin, custom_option: "value"}])
|> Stream.map(fn {id, document} ->
  {id, MDEx.to_html!(document)}
end)
```

The streaming lifecycle differs from the one-document lifecycle:

1. Stream enumeration starts.
2. MDEx creates an empty document and calls each plugin's `attach/2` once.
3. MDEx uses the resulting parser options for every source parse.
4. MDEx runs the configured pipeline steps on every emitted document.
5. A repeated id receives a new document built from the latest source. State
   from the earlier document is not reused.

An emitted document contains one keyed chunk, not the full Markdown response.
A plugin step must therefore treat the document as independent.

### Plugin author rules

- Use `attach/2` to register options, configure MDEx, and append pipeline steps.
- Do not read or rewrite `document.buffer` in `attach/2`. The buffer is empty
  because the source Stream has not been read yet.
- Make each pipeline step work with one keyed document.
- Do not rely on `document.private`, assigns, counters, or transformed nodes
  from an earlier update. Each update starts from the plugin configuration.
- Expect a pipeline step to run again when the same id is replaced.
- Parser options set during `attach/2` apply before both normal and partial
  parsing. Parser options set inside a pipeline step are too late to change the
  AST that the step receives.
- Do not assume generated IDs are unique across keyed chunks. Include external
  context in an ID when response-wide uniqueness is required.
- Prefer loading CSS and JavaScript in the surrounding page. Assets inserted
  into the document root may be repeated in several keyed chunks.
- Keep document-wide transforms on the one-document API. Examples include a
  table of contents, global numbering, collected footnotes, and source
  preprocessing.

Plugin attachment is lazy. Enumerating a repeatable Stream again attaches the
plugins again and creates a new pipeline.

See the [Streaming guide](streaming.html#plugins) for the user-facing behavior
and notes about existing MDEx plugins.

## Creating Custom Plugins

A plugin is any module with an `attach/2` function. It takes a document and returns one:

```elixir
defmodule MyPlugin do
  alias MDEx.Document

  def attach(document, options \\ []) do
    document
    |> Document.register_options([:my_option])
    |> Document.put_options(options)
    |> Document.append_steps(my_step: &my_step/1)
  end

  defp my_step(document) do
    # Transform the document
    document
  end
end
```

`attach/2` runs once, before any Markdown is parsed. It registers options and
queues up steps, and that's all it should do. The steps run later, when the
document is rendered, and they're where the work happens.

### Registering options

`put_options/2` rejects a key nobody registered:

```elixir
MDEx.new() |> MDEx.Document.put_options(my_option: 1)
** (ArgumentError) unknown option :my_option
```

Hence `register_options/2`. Prefix your keys with the plugin name while you're
there: every plugin on a document shares one namespace, so a plain `:version`
from two plugins collides where `:mermaid_version` and `:katex_version` don't.

Read one back with `get_option/3`:

```elixir
Document.get_option(document, :mermaid_version, "11")
```

### Steps

`append_steps/2` puts steps at the end of the pipeline, `prepend_steps/2` at
the front. A step takes a document and returns one:

```elixir
Document.append_steps(document,
  validate: &validate/1,
  transform: &transform/1
)
```

To edit the tree, use `update_nodes/3` or `MDEx.traverse_and_update/2`:

```elixir
Document.update_nodes(document, MDEx.Text, fn node ->
  %{node | literal: String.upcase(node.literal)}
end)
```

A step can call `halt/1` to skip every step after it. The document still
renders:

```elixir
MDEx.new(markdown: "# Title")
|> Document.append_steps(stop: &Document.halt/1)
|> Document.append_steps(never_runs: &explode/1)
|> MDEx.to_html!()
#=> "<h1>Title</h1>"
```

### Parser options have to be set in `attach/2`

By the time a step runs, the AST is already parsed. A parser or extension
option set inside one arrives too late to change it:

```elixir
# the AST was built before the step ran, so ~b~ stays literal
MDEx.new(markdown: "a ~b~")
|> Document.append_steps(late: &Document.put_extension_options(&1, strikethrough: true))
|> MDEx.to_html!()
#=> "<p>a ~b~</p>"

# set it in attach/2 and the parser sees it
MDEx.new(markdown: "a ~b~")
|> Document.put_extension_options(strikethrough: true)
|> MDEx.to_html!()
#=> "<p>a <del>b</del></p>"
```

Render options are fine either way, since rendering happens after the steps.
`put_render_options/2` works from a step or from `attach/2`.

### Keeping state

`put_private/3` and `get_private/3` hold anything only the plugin cares about,
like the counter behind generated element ids. Private values survive the
pipeline, so a later step reads what an earlier one wrote:

```elixir
document
|> Document.put_private(:seen, 0)
|> Document.update_private(:seen, 0, &(&1 + 1))
|> Document.get_private(:seen)
#=> 1
```

Assigns look tempting for this, but they hold values the caller passes in and
HEEx templates read. Leave those to the caller and keep plugin bookkeeping in
`private`.

### Testing a plugin

Test through the same entry point users call. No pipeline setup needed:

```elixir
test "wraps code blocks" do
  html = MDEx.to_html!("```elixir\n:ok\n```", plugins: [MyPlugin])
  assert html =~ ~s(<pre class="highlight">)
end
```

Assert on the rendered string when the plugin emits markup. When it rewrites
the tree instead, `MyPlugin.attach/2` followed by `MDEx.Document.run/1` hands
you the nodes to match on.

## Emitting HTML

Plugins often replace nodes with their own HTML. Three nodes can hold HTML, and
the render options treat them differently:

| Node | Default | `render: [escape: true]` | `render: [unsafe: true]` |
| --- | --- | --- | --- |
| `MDEx.HtmlBlock`, `MDEx.HtmlInline` | `<!-- raw HTML omitted -->` | Escaped | Rendered |
| `MDEx.Raw` | Rendered | Rendered | Rendered |

The parser creates `MDEx.HtmlBlock` and `MDEx.HtmlInline` for raw HTML written
in the Markdown source, so nodes a plugin inserts get the same treatment as the
author's HTML. `MDEx.Raw` is never parsed from input and is inserted verbatim
into HTML and CommonMark output.

Use `MDEx.Raw` for the HTML a plugin generates. Calling
`Document.put_render_options(document, unsafe: true)` from a plugin also works,
but it renders all raw HTML written by the Markdown author across the whole
document.

`MDEx.Raw` is never escaped, so escape any text taken from the Markdown source
yourself, like the code in a code block. Otherwise a code block containing
`</code></pre><script>` injects a script under the default options. The
`:sanitize` option still applies to `MDEx.Raw` output.

## Example Plugin

Here's a complete example that renders code blocks with a custom class,
following the rules in [Emitting HTML](#emitting-html):

```elixir
defmodule CodeBlockEnhancer do
  alias MDEx.Document

  def attach(document, options \\ []) do
    document
    |> Document.register_options([:code_class])
    |> Document.put_options(options)
    |> Document.append_steps(enhance_code_blocks: &enhance_code_blocks/1)
  end

  defp enhance_code_blocks(document) do
    class = Document.get_option(document, :code_class) || "highlight"

    MDEx.traverse_and_update(document, fn
      %MDEx.CodeBlock{} = node ->
        html = ~s(<pre class="#{escape(class)}"><code>#{escape(node.literal)}</code></pre>)
        %MDEx.Raw{literal: html}

      node ->
        node
    end)
  end

  defp escape(text) do
    String.replace(text, ["&", "<", ">", "\"", "'"], fn
      "&" -> "&amp;"
      "<" -> "&lt;"
      ">" -> "&gt;"
      "\"" -> "&quot;"
      "'" -> "&#39;"
    end)
  end
end
```

Usage:

```elixir
MDEx.to_html!("```elixir\n:ok\n```", plugins: [{CodeBlockEnhancer, code_class: "syntax-highlight"}])
#=> "<pre class=\"syntax-highlight\"><code>:ok\n</code></pre>"
```
