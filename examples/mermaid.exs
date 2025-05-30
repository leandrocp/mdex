Mix.install([
  {:mdex, path: ".."}
])

defmodule MermaidExample do
  import MDEx.Sigil

  def run do
    opts = [
      render: [unsafe: true]
    ]

    markdown = ~MD"""
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

    mermaid_node =
      MDEx.parse_fragment!("""
      <script type="module">
        import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
        mermaid.initialize({ startOnLoad: true });
      </script>
      """)

    html =
      markdown
      |> MDEx.traverse_and_update(fn
        # inject the mermaid script
        %MDEx.Document{nodes: nodes} = document ->
          nodes = [mermaid_node | nodes]
          %{document | nodes: nodes}

        # inject the mermaid <pre> block without escaping the content
        %MDEx.CodeBlock{info: "mermaid", literal: code, nodes: nodes} ->
          code = """
          <pre class="mermaid">#{code}</pre>
          """

          %MDEx.HtmlBlock{literal: code, nodes: nodes}

        node ->
          node
      end)
      |> MDEx.to_html!(opts)

    File.write!("mermaid.html", html)

    IO.puts(html)
  end
end

MermaidExample.run()
