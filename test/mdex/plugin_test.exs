defmodule MDExMermaidPluginTest do
  alias MDEx.Document

  @default_init """
  <script type="module">
    import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
    const theme = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'default';
    mermaid.initialize({securityLevel: 'loose', theme: theme});
  </script>
  """

  def attach(document, options \\ []) do
    document
    |> Document.register_options([:mermaid_init])
    |> Document.put_options(options)
    |> Document.append_steps(enable_unsafe: &enable_unsafe/1)
    |> Document.append_steps(inject_init: &inject_init/1)
    |> Document.append_steps(update_code_blocks: &update_code_blocks/1)
  end

  defp enable_unsafe(document) do
    Document.put_render_options(document, unsafe: true)
  end

  defp inject_init(document) do
    init = Document.get_option(document, :mermaid_init) || @default_init
    Document.put_node_in_document_root(document, %MDEx.HtmlBlock{literal: init}, :top)
  end

  defp update_code_blocks(document) do
    pre_attrs = fn seq ->
      ~s(id="mermaid-#{seq}" class="mermaid" phx-update="ignore")
    end

    {document, _} =
      MDEx.traverse_and_update(document, 1, fn
        %MDEx.CodeBlock{info: "mermaid"} = node, acc ->
          pre = "<pre #{pre_attrs.(acc)}>#{node.literal}</pre>"
          node = %MDEx.HtmlBlock{literal: pre, nodes: node.nodes}
          {node, acc + 1}

        node, acc ->
          {node, acc}
      end)

    document
  end
end

defmodule MDEx.PluginTest do
  use ExUnit.Case, async: true

  alias MDEx.Document

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

  @init12 """
  <script type="module">
    import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@12/dist/mermaid.esm.min.mjs';
    const theme = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'default';
    mermaid.initialize({securityLevel: 'loose', theme: theme});
  </script>
  """

  @init22 """
  <script type="module">
    import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@22/dist/mermaid.esm.min.mjs';
    const theme = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'default';
    mermaid.initialize({securityLevel: 'loose', theme: theme});
  </script>
  """

  describe "plugin" do
    test "default options", %{markdown: markdown} do
      assert {:ok, html} =
               MDEx.new(markdown: markdown)
               |> MDExMermaidPluginTest.attach()
               |> MDEx.to_html()

      assert html =~ "import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs'"
      assert html =~ ~s|<pre id="mermaid-1" class="mermaid" phx-update="ignore">|
    end

    test "custom options", %{markdown: markdown} do
      assert {:ok, html} =
               MDEx.new(markdown: markdown)
               |> MDExMermaidPluginTest.attach(mermaid_init: @init12)
               |> MDEx.to_html()

      assert html =~ "import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@12/dist/mermaid.esm.min.mjs'"
      assert html =~ ~s|<pre id="mermaid-1" class="mermaid" phx-update="ignore">|
    end
  end

  describe "plugin (via MDEx.new/1)" do
    test "default options via module", %{markdown: markdown} do
      assert {:ok, html} =
               MDEx.new(markdown: markdown, plugins: [MDExMermaidPluginTest])
               |> MDEx.to_html()

      assert html =~ "import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs'"
      assert html =~ ~s|<pre id="mermaid-1" class="mermaid" phx-update="ignore">|
    end

    test "custom options via {module, options}", %{markdown: markdown} do
      assert {:ok, html} =
               MDEx.new(markdown: markdown, plugins: [{MDExMermaidPluginTest, mermaid_init: @init12}])
               |> MDEx.to_html()

      assert html =~ "import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@12/dist/mermaid.esm.min.mjs'"
      assert html =~ ~s|<pre id="mermaid-1" class="mermaid" phx-update="ignore">|
    end

    test "custom options via fn/1", %{markdown: markdown} do
      attach = fn document -> MDExMermaidPluginTest.attach(document, mermaid_init: @init22) end

      assert {:ok, html} =
               MDEx.new(markdown: markdown, plugins: [attach])
               |> MDEx.to_html()

      assert html =~ "import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@22/dist/mermaid.esm.min.mjs'"
      assert html =~ ~s|<pre id="mermaid-1" class="mermaid" phx-update="ignore">|
    end
  end
end
