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

The snippets below are written against `alias MDEx.Document`, like the module
above.

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

Plugins often replace nodes with their own HTML. Three node types can carry it,
and the one you pick decides how much of the caller's configuration your plugin
depends on. That part is up to you:

| Node | Default | `render: [escape: true]` | `render: [unsafe: true]` | `sanitize:` |
| --- | --- | --- | --- | --- |
| `MDEx.HtmlBlock`, `MDEx.HtmlInline` | `<!-- raw HTML omitted -->` | Escaped | Rendered | Cleaned |
| `MDEx.Raw` | Rendered | Rendered | Rendered | Cleaned |

### `MDEx.Raw` ignores the caller's `:unsafe` and `:escape`

`MDEx.Raw` never comes from the parser. You can only build one in code, and it
goes into HTML and CommonMark output as written no matter what the caller set
for `:unsafe` or `:escape`. Your markup renders the same for everyone, which is
usually what you want for markup the plugin itself generated.

That guarantee is also the cost. You've taken one node out of the caller's
safety settings, so anything you interpolate into it from the Markdown source is
yours to escape. Skip that and a code block containing `</code></pre><script>`
lands in the page intact, under default options, in an app that never asked for
raw HTML.

`:sanitize` is the exception. It runs over the rendered HTML, `MDEx.Raw`
included, so a caller who turns it on can still strip what your plugin emitted:

```elixir
document = %MDEx.Document{nodes: [%MDEx.Raw{literal: "<script>init()</script><b>ok</b>"}]}

MDEx.to_html!(document)
#=> "<script>init()</script><b>ok</b>"

MDEx.to_html!(document, sanitize: MDEx.Document.default_sanitize_options())
#=> "<b>ok</b>"
```

Scripts go first, and so do most attributes. A diagram wrapper comes back
stripped down to the one attribute the default rules allow:

```elixir
wrapper = ~s(<pre id="m-1" class="mermaid" phx-update="ignore">graph TD;</pre>)

%MDEx.Document{nodes: [%MDEx.Raw{literal: wrapper}]}
|> MDEx.to_html!(sanitize: MDEx.Document.default_sanitize_options())
#=> "<pre class=\"mermaid\">graph TD;</pre>"
```

The `id` and `phx-update` are gone, and with them any chance of that diagram
initializing. So if your plugin needs particular tags or attributes to survive,
that's the second thing worth telling callers who sanitize.

### `MDEx.HtmlBlock` and `MDEx.HtmlInline` follow the caller

These are the nodes the parser builds for raw HTML in the Markdown source, so a
plugin that emits them gets whatever treatment the author's own HTML gets. They
disappear by default and need `render: [unsafe: true]`.

Depending on that is a reasonable choice. It keeps your plugin inside the policy
the caller picked instead of carving out an exception, and a document rendered
with `escape: true` shows your markup as text along with everything else. The
catch is that your plugin does nothing at all until the caller opts in, so say
so in your README. "Requires `render: [unsafe: true]`" is a fine thing for a
plugin to ask for when it's written down.

A third path is to call `Document.put_render_options(document, unsafe: true)`
yourself. It flips the option for the whole document, so the Markdown author's
raw HTML renders too. Where you call it decides whether the caller can say no,
because render options are last write wins:

```elixir
# from attach/2, so the caller's options are applied after yours and win
MDEx.to_html!("<i>author</i>", plugins: [SetsUnsafeInAttach], render: [unsafe: false])
#=> "<p><!-- raw HTML omitted -->author<!-- raw HTML omitted --></p>"

# from a step, which runs during rendering, after every option the caller set
MDEx.to_html!("<i>author</i>", plugins: [SetsUnsafeInAStep], render: [unsafe: false])
#=> "<p><i>author</i></p>"
```

Setting it from a step takes the decision away from the caller for good, which
is rarely yours to take. Prefer `MDEx.Raw` unless you really mean "this document
renders raw HTML."

### Escaping what you interpolate

Whichever node you emit, escape text that came from the Markdown source before
it goes into a literal. `MDEx.safe_html/2` does it with sanitizing off:

```elixir
MDEx.safe_html(~s(if a < b, do: "x"), sanitize: false)
#=> "if a &lt; b, do: &quot;x&quot;"
```

Leave `:sanitize` at its default and it cleans the text as HTML first, which is
the wrong job here: it drops whatever parses as a tag instead of escaping it.
`:escape` also covers `{` and `}` inside `<code>` tags by default, which you
want when the output is headed for LiveView. Pass
`escape: [curly_braces_in_code: false]` when it isn't.

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

  defp escape(text), do: MDEx.safe_html(text, sanitize: false)
end
```

Usage:

```elixir
MDEx.to_html!("```elixir\n:ok\n```", plugins: [{CodeBlockEnhancer, code_class: "syntax-highlight"}])
#=> "<pre class=\"syntax-highlight\"><code>:ok\n</code></pre>"
```
