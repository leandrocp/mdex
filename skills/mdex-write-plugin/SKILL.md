---
name: mdex-write-plugin
description: Build an MDEx plugin the way the MDEx plugins guide describes, covering module structure, registered options, attach/2 and pipeline steps, emitting HTML safely with MDEx.Raw, streaming rules, and tests. Use when writing, reviewing, or publishing an MDEx plugin (such as mdex_mermaid or mdex_katex) or contributing one to leandrocp/mdex.
---

# Write an MDEx plugin

A plugin is a module with an `attach/2` function. It takes an `MDEx.Document`
and returns one. It registers options, sets parser options, and appends
pipeline steps. The steps run later, at render time, and do the work.

This skill follows the [Plugins guide](https://hexdocs.pm/mdex/plugins.html)
(`guides/plugins.md` in the repository). Read it when a rule here is unclear.

## Structure

Start from this shape:

```elixir
defmodule MyPlugin do
  alias MDEx.Document

  def attach(document, options \\ []) do
    document
    |> Document.register_options([:my_plugin_option])
    |> Document.put_options(options)
    |> Document.append_steps(my_plugin_step: &my_plugin_step/1)
  end

  defp my_plugin_step(document) do
    # Transform the document
    document
  end
end
```

`attach/2` runs once, before the Markdown is parsed. Keep it to registering
options, setting parser options, and adding steps.

A published plugin is a Hex package named `mdex_<name>` that depends on
`:mdex`. Its README says how to attach it, which options it takes, and what it
needs from the caller (see [Emitting HTML](#emitting-html)).

## Options

- Call `Document.register_options/2` before `Document.put_options/2`.
  `put_options/2` raises `ArgumentError` with `unknown option :my_option` for
  an unregistered key.
- Start every key with the plugin name. All plugins share one options space, so
  two plugins using `:version` clash, while `:mermaid_version` and
  `:katex_version` do not.
- Read options back with a default:
  `Document.get_option(document, :mermaid_version, "11")`.

## Steps

- `Document.append_steps/2` adds steps to the end of the pipeline and
  `Document.prepend_steps/2` to the front. A step takes a document and returns
  one.
- Edit the tree with `Document.update_nodes/3` or `MDEx.traverse_and_update/2`.
  Do not edit rendered strings.
- A step can call `Document.halt/1` to skip the remaining steps. The document
  still renders.

```elixir
MDEx.Document.update_nodes(document, MDEx.Text, fn node ->
  %{node | literal: String.upcase(node.literal)}
end)
```

## Parser options belong in `attach/2`

When a step runs, the Markdown is already parsed. Setting a parser or extension
option in a step is too late:

```elixir
# the parser already ran, so ~b~ stays as plain text
MDEx.new(markdown: "a ~b~")
|> MDEx.Document.append_steps(late: &MDEx.Document.put_extension_options(&1, strikethrough: true))
|> MDEx.to_html!()
#=> "<p>a ~b~</p>"
```

Call `Document.put_extension_options/2` and `Document.put_parse_options/2` in
`attach/2`. Render options work from either place, since rendering happens
after the steps.

## State

- Store plugin-only data with `Document.put_private/3`, `get_private/3`, and
  `update_private/4`, for example a counter for generated ids. A later step can
  read what an earlier one wrote.
- Do not use assigns. They hold values the caller passes in and HEEx templates
  read.

## Emitting HTML

Pick the node that holds your HTML on purpose:

| Node | Default | `render: [escape: true]` | `render: [unsafe: true]` | `sanitize:` |
| --- | --- | --- | --- | --- |
| `MDEx.HtmlBlock`, `MDEx.HtmlInline` | `<!-- raw HTML omitted -->` | Escaped | Rendered | Cleaned |
| `MDEx.Raw` | Rendered | Rendered | Rendered | Cleaned |

- Prefer `MDEx.Raw`. It renders whatever the caller set for `:unsafe` and
  `:escape`, and it goes out as written.
- Escape every piece of text taken from the Markdown source before putting it in
  `MDEx.Raw`, with `MDEx.safe_html(text, sanitize: false)`. Without it, a code
  block holding `</code></pre><script>` becomes real HTML. Keep
  `sanitize: false`: with sanitizing on, `safe_html/2` treats the text as HTML
  and deletes anything that looks like a tag instead of escaping it.
- `MDEx.HtmlBlock` and `MDEx.HtmlInline` follow the caller's settings and are
  dropped unless `render: [unsafe: true]` is set. If you use them, say so in
  the README.
- Do not call `Document.put_render_options(document, unsafe: true)` to make
  your HTML show up. It turns on raw HTML for the whole document, the
  author's included. From a step the caller cannot turn it back off.
- `:sanitize` cleans `MDEx.Raw` too. Its default rules remove `<script>` and
  most attributes, such as `id` and `phx-update`. If your plugin needs certain
  tags or attributes, document them for callers who sanitize.

```elixir
defp enhance_code_blocks(document) do
  class = Document.get_option(document, :code_block_enhancer_class) || "highlight"

  MDEx.traverse_and_update(document, fn
    %MDEx.CodeBlock{} = node ->
      html = ~s(<pre class="#{escape(class)}"><code>#{escape(node.literal)}</code></pre>)
      %MDEx.Raw{literal: html}

    node ->
      node
  end)
end

defp escape(text), do: MDEx.safe_html(text, sanitize: false)
```

## Streaming

`MDEx.stream/2` calls `attach/2` once when enumeration starts, then runs the
steps on every emitted document. Each document holds one keyed chunk, not the
full response.

- Do not read or rewrite `document.buffer` in `attach/2`. It is empty because
  the source Stream has not been read yet.
- Make each step work on one keyed document. Expect it to run again when the
  same id is replaced.
- Do not rely on `document.private`, assigns, counters, or transformed nodes
  from an earlier update.
- Do not assume generated ids are unique across keyed chunks. Include external
  context in an id when it must be unique across the response.
- Prefer loading CSS and JavaScript in the surrounding page. Assets inserted
  into the document root can repeat across chunks.
- Keep document-wide transforms (table of contents, global numbering, collected
  footnotes, source preprocessing) on the one-document API, and say so in the
  README.

## Tests

Test the plugin the way users call it:

```elixir
test "wraps code blocks" do
  html = MDEx.to_html!("```elixir\n:ok\n```", plugins: [MyPlugin])
  assert html =~ ~s(<pre class="highlight"><code>:ok\n</code></pre>)
end
```

- Cover each documented attach style: `plugins: [MyPlugin]`,
  `plugins: [{MyPlugin, my_plugin_option: value}]`, and `MyPlugin.attach/2`.
- If the plugin changes the tree rather than the output, call
  `MyPlugin.attach/2`, then `MDEx.Document.run/1`, and match on the nodes.
- Test source text containing `<`, `&`, and `</code></pre><script>` to prove it
  is escaped.
- If the plugin supports streaming, test it through `MDEx.stream/2` with a
  repeated id.

## Contributing to leandrocp/mdex

To list a published plugin, or to change the plugin docs, open a PR against
`main` in [leandrocp/mdex](https://github.com/leandrocp/mdex):

- List the plugin in the README `## Plugins` section and in the
  `## Plugin Ecosystem` section of `skills/mdex/SKILL.md`.
- After editing `skills/mdex/SKILL.md`, run `just sync-usage-rules` to
  regenerate `usage-rules.md`.

Install this skill with `npx skills add leandrocp/mdex --skill mdex-write-plugin`.

### PR checklist

The repository has no PR template. CI runs these checks on every pull request,
so run them locally first:

- [ ] `mix compile --warnings-as-errors`
- [ ] `mix deps.unlock --check-unused`
- [ ] `mix format --check-formatted`
- [ ] `mix credo --strict`
- [ ] `mix test`
- [ ] Add an entry under `## Unreleased` in `CHANGELOG.md` for user-facing changes, following the existing format.
