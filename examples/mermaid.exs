Mix.install([
  {:mdex, path: ".."}
])

opts = [
  render: [unsafe_: true]
]

markdown = """
# Mermaid Example

In this example we'll inject the script code to initialize and render mermaid blocks.

```mermaid
sequenceDiagram
    participant Alice
    participant Bob
    Alice->>John: Hello John, how are you?
    loop HealthCheck
        John->>John: Fight against hypochondria
    end
    Note right of John: Rational thoughts <br/>prevail!
    John-->>Alice: Great!
    John->>Bob: How about you?
    Bob-->>John: Jolly good!
```

The following script is used to load the mermaid library and initialize it:

```js
import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
mermaid.initialize({ startOnLoad: true });
```
"""

mermaid = """
<script type="module">
  import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
  mermaid.initialize({ startOnLoad: true });
</script>
"""

html =
  markdown
  |> MDEx.parse_document!(opts)
  |> MDEx.traverse_and_update(fn
    # inject the script at the end of the document
    {"document", attrs, children} ->
      mermaid = MDEx.parse_document!(mermaid)
      {"document", attrs, children ++ mermaid}

    # inject the mermaid <pre> block without escaping the content
    {"code_block", %{"info" => "mermaid", "literal" => code}, children} ->
      code = """
      <pre class="mermaid">#{code}</pre>
      """

      {"html_block", %{"literal" => code}, children}

    node ->
      node
  end)
  |> MDEx.to_html!(opts)

File.write!("mermaid.html", html)

IO.puts(html)
