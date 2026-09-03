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

A plugin is any module that implements an `attach/2` function. This function receives a document and options, and returns a modified document:

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

## Document Pipeline Functions

These `MDEx.Document` functions are commonly used when building plugins:

### `register_options/2`

Registers custom option keys so they can be stored in the document:

```elixir
Document.register_options(document, [:theme_color, :enable_feature])
```

### `put_options/2`

Sets values for registered options:

```elixir
Document.put_options(document, theme_color: "blue", enable_feature: true)
```

### `append_steps/2`

Adds processing steps that run when the document is rendered. Steps are functions that receive and return a document:

```elixir
Document.append_steps(document,
  validate: &validate/1,
  transform: &transform/1
)
```

### `update_nodes/3`

Updates nodes matching a selector with a transformation function:

```elixir
Document.update_nodes(document, MDEx.Text, fn node ->
  %{node | literal: String.upcase(node.literal)}
end)
```

## Example Plugin

Here's a complete example that adds custom attributes to code blocks:

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
        %MDEx.HtmlBlock{literal: ~s(<pre class="#{class}"><code>#{node.literal}</code></pre>)}

      node ->
        node
    end)
  end
end
```

Usage:

```elixir
MDEx.to_html!(markdown, plugins: [{CodeBlockEnhancer, code_class: "syntax-highlight"}])
```
