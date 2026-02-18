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

## Available Plugins

- [mdex_gfm](https://hex.pm/packages/mdex_gfm) - Enable [GitHub Flavored Markdown](https://github.github.com/gfm) (GFM)
- [mdex_mermaid](https://hex.pm/packages/mdex_mermaid) - Render [Mermaid](https://mermaid.js.org) diagrams in code blocks
- [mdex_katex](https://hex.pm/packages/mdex_katex) - Render math formulas using [KaTeX](https://katex.org)
- [mdex_video_embed](https://hex.pm/packages/mdex_video_embed) - Privacy-respecting video embeds from code blocks
- [mdex_custom_heading_id](https://hex.pm/packages/mdex_custom_heading_id) - Custom heading IDs for markdown headings
