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

`attach/2` runs once, before the Markdown is parsed, and should only register
options and add steps. The steps run later, at render time, and do the work.

### Registering options

`put_options/2` fails if you did not register the key first:

```elixir
MDEx.new() |> MDEx.Document.put_options(my_option: 1)
** (ArgumentError) unknown option :my_option
```

So call `register_options/2` first, and start your keys with the plugin name.
All plugins share the same options, so two that use `:version` will clash where
`:mermaid_version` and `:katex_version` will not. Read one back with
`MDEx.Document.get_option(document, :mermaid_version, "11")`.

### Steps

`append_steps/2` adds steps to the end of the pipeline, `prepend_steps/2` to
the front. A step takes a document and returns one:

```elixir
MDEx.Document.append_steps(document,
  validate: &validate/1,
  transform: &transform/1
)
```

Edit the tree with `update_nodes/3` or `MDEx.traverse_and_update/2`:

```elixir
MDEx.Document.update_nodes(document, MDEx.Text, fn node ->
  %{node | literal: String.upcase(node.literal)}
end)
```

A step can call `halt/1` to skip the rest. The document still renders:

```elixir
MDEx.new(markdown: "# Title")
|> MDEx.Document.append_steps(stop: &MDEx.Document.halt/1)
|> MDEx.Document.append_steps(never_runs: &explode/1)
|> MDEx.to_html!()
#=> "<h1>Title</h1>"
```

### Parser options have to be set in `attach/2`

When a step runs the Markdown is already parsed, so setting a parser or
extension option there is too late:

```elixir
# the parser already ran, so ~b~ stays as plain text
MDEx.new(markdown: "a ~b~")
|> MDEx.Document.append_steps(late: &MDEx.Document.put_extension_options(&1, strikethrough: true))
|> MDEx.to_html!()
#=> "<p>a ~b~</p>"

# set it in attach/2 and the parser sees it
MDEx.new(markdown: "a ~b~")
|> MDEx.Document.put_extension_options(strikethrough: true)
|> MDEx.to_html!()
#=> "<p>a <del>b</del></p>"
```

Render options work from either place, since rendering happens after the steps.

### Keeping state

Use `put_private/3` and `get_private/3` for data only your plugin needs, like a
counter for generated ids. A later step can read what an earlier one wrote:

```elixir
document
|> MDEx.Document.put_private(:seen, 0)
|> MDEx.Document.update_private(:seen, 0, &(&1 + 1))
|> MDEx.Document.get_private(:seen)
#=> 1
```

Do not use assigns for this. Those hold values the caller passes in and HEEx
templates read, so leave them to the caller.

### Testing a plugin

Test it the same way users call it:

```elixir
test "wraps code blocks" do
  html = MDEx.to_html!("```elixir\n:ok\n```", plugins: [MyPlugin])
  assert html =~ ~s(<pre class="highlight">)
end
```

If your plugin changes the tree rather than the output, call `MyPlugin.attach/2`
then `MDEx.Document.run/1` and match on the nodes.

## Emitting HTML

Plugins often replace nodes with their own HTML. Three node types can hold it.
The one you pick decides how much your plugin depends on the caller's settings,
and that choice is yours:

| Node | Default | `render: [escape: true]` | `render: [unsafe: true]` | `sanitize:` |
| --- | --- | --- | --- | --- |
| `MDEx.HtmlBlock`, `MDEx.HtmlInline` | `<!-- raw HTML omitted -->` | Escaped | Rendered | Cleaned |
| `MDEx.Raw` | Rendered | Rendered | Rendered | Cleaned |

`MDEx.Raw` never comes from the parser, and it goes out as written whatever the
caller set for `:unsafe` and `:escape`. Your HTML works everywhere, but it skips
those settings, so you have to escape any text you take from the Markdown
source. Miss that and a code block holding `</code></pre><script>` ends up in
the page as real HTML.

`MDEx.HtmlBlock` and `MDEx.HtmlInline` are what the parser builds for raw HTML
in the source, so they follow the caller: dropped by default, shown with
`render: [unsafe: true]`. Your plugin then does nothing until the caller turns
that on, which is fine as long as your README says so.

`:sanitize` applies to both. Its default rules remove scripts and most
attributes:

```elixir
wrapper = ~s(<pre id="m-1" class="mermaid" phx-update="ignore">graph TD;</pre>)

%MDEx.Document{nodes: [%MDEx.Raw{literal: wrapper}]}
|> MDEx.to_html!(sanitize: MDEx.Document.default_sanitize_options())
#=> "<pre class=\"mermaid\">graph TD;</pre>"
```

The `id` and `phx-update` are gone, so that diagram never starts. If your plugin
needs certain tags or attributes, tell callers who sanitize.

You can also call `MDEx.Document.put_render_options/2` with `unsafe: true`, but
that turns raw HTML on for the whole document, the author's included. The last
call wins, so from `attach/2` the caller can still turn it back off, and from a
step they cannot. Prefer `MDEx.Raw`.

### Escaping text you insert

Use `MDEx.safe_html/2` with sanitizing off:

```elixir
MDEx.safe_html(~s(if a < b, do: "x"), sanitize: false)
#=> "if a &lt; b, do: &quot;x&quot;"
```

`sanitize: false` matters: left on, it treats your text as HTML and deletes
anything that looks like a tag instead of escaping it. It also escapes `{` and
`}` inside `<code>`, which helps in LiveView. Turn that off with
`escape: [curly_braces_in_code: false]`.

## Example Plugin

Here is a full example that wraps code blocks in a custom class, using the rules
from [Emitting HTML](#emitting-html):

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

  defp escape(text), do: MDEx.safe_html(text, sanitize: false)
end
```

Usage:

```elixir
MDEx.to_html!("```elixir\n:ok\n```", plugins: [{CodeBlockEnhancer, code_class: "syntax-highlight"}])
#=> "<pre class=\"syntax-highlight\"><code>:ok\n</code></pre>"
```
