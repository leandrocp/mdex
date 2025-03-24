defmodule MDExMermaidTest do
  alias MDEx.Pipe
  alias MDEx.Steps

  @latest_version "11"

  def attach(pipe, options \\ []) do
    pipe
    |> Pipe.register_options([:mermaid_version])
    |> Pipe.merge_options(mermaid_version: options[:version])
    |> Pipe.append_steps(enable_unsafe: &enable_unsafe/1)
    |> Pipe.append_steps(inject_script: &inject_script/1)
    |> Pipe.append_steps(update_code_blocks: &update_code_blocks/1)
  end

  defp enable_unsafe(pipe) do
    Steps.put_render_options(pipe, unsafe_: true)
  end

  defp inject_script(pipe) do
    version = Pipe.get_option(pipe, :mermaid_version, @latest_version)

    script_node =
      %MDEx.HtmlBlock{
        literal: """
        <script type="module">
          import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@#{version}/dist/mermaid.esm.min.mjs';
          mermaid.initialize({ startOnLoad: true });
        </script>
        """
      }

    Steps.put_node_in_document_root(pipe, script_node)
  end

  defp update_code_blocks(pipe) do
    selector = fn
      %MDEx.CodeBlock{info: "mermaid"} -> true
      _ -> false
    end

    Steps.update_nodes(
      pipe,
      selector,
      &%MDEx.HtmlBlock{literal: "<pre class=\"mermaid\">#{&1.literal}</pre>", nodes: &1.nodes}
    )
  end
end

defmodule MDEx.PipeTest do
  use ExUnit.Case, async: true

  alias MDEx.Pipe

  setup do
    [pipe: MDEx.new()]
  end

  describe "plugin" do
    setup do
      document = """
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

      [document: document]
    end

    test ":document in new/1", %{document: document} do
      assert {:ok, html} =
               MDEx.new(document: document)
               |> MDExMermaidTest.attach(version: "10")
               |> MDEx.to_html()

      assert html =~ "import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs'"
      assert html =~ "<pre class=\"mermaid\">graph TD"
    end

    test ":document in to_html/2", %{document: document} do
      assert {:ok, html} =
               MDEx.new()
               |> MDExMermaidTest.attach(version: "10")
               |> MDEx.to_html(document: document)

      assert html =~ "import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs'"
      assert html =~ "<pre class=\"mermaid\">graph TD"
    end
  end

  test "register_options" do
    assert %{registered_options: opts} = Pipe.register_options(%MDEx.Pipe{}, [])
    assert MapSet.to_list(opts) == []

    assert %{registered_options: opts} = Pipe.register_options(%MDEx.Pipe{}, [:foo])
    assert MapSet.to_list(opts) == [:foo]

    assert %{registered_options: opts} = Pipe.register_options(%MDEx.Pipe{}, [:foo, :foo])
    assert MapSet.to_list(opts) == [:foo]
  end

  describe "get_option" do
    test "get registered option", %{pipe: pipe} do
      pipe =
        pipe
        |> Pipe.register_options([:foo])
        |> Pipe.merge_options(foo: 1)

      assert Pipe.get_option(pipe, :foo) == 1
    end

    test "returns default when not registered", %{pipe: pipe} do
      refute Pipe.get_option(pipe, :foo)
    end
  end
end
