defmodule MDExMermaidSample do
  alias MDEx.Document

  @latest_version "11"

  def attach(document, options \\ []) do
    document
    |> Document.register_options([:mermaid_version])
    |> Document.put_options(options)
    |> Document.append_steps(enable_unsafe: &enable_unsafe/1)
    |> Document.append_steps(inject_script: &inject_script/1)
    |> Document.append_steps(update_code_blocks: &update_code_blocks/1)
  end

  defp enable_unsafe(document) do
    Document.put_render_options(document, unsafe: true)
  end

  defp inject_script(document) do
    version = Document.get_option(document, :mermaid_version, @latest_version)

    script_node =
      %MDEx.HtmlBlock{
        literal: """
        <script type="module">
          import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@#{version}/dist/mermaid.esm.min.mjs';
          mermaid.initialize({ startOnLoad: true });
        </script>
        """
      }

    Document.put_node_in_document_root(document, script_node)
  end

  defp update_code_blocks(document) do
    selector = fn
      %MDEx.CodeBlock{info: "mermaid"} -> true
      _ -> false
    end

    Document.update_nodes(
      document,
      selector,
      &%MDEx.HtmlBlock{literal: "<pre class=\"mermaid\">#{&1.literal}</pre>", nodes: &1.nodes}
    )
  end
end

defmodule MDEx.PipelineTest do
  use ExUnit.Case, async: true

  alias MDEx.Document

  setup do
    [document: MDEx.new()]
  end

  describe "plugin" do
    setup do
      markdown = """
      # Project Diagram

      ```mermaid
      graph TD
          A[Enter Chart Definition] --> B(Preview)
          B --> C{decide}
          C --> D[Keep]
          C --> E[Edit Definition]
          E --> B
          D --> F[Save Image and Code]
          F --> B
      ```
      """

      [markdown: markdown]
    end

    test ":markdown in new/1", %{markdown: markdown} do
      assert {:ok, html} =
               MDEx.new(markdown: markdown)
               |> MDExMermaidSample.attach(mermaid_version: "10")
               |> MDEx.to_html()

      assert html =~ "import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs'"
      assert html =~ "<pre class=\"mermaid\">graph TD"
    end
  end
end
