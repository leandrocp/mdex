defmodule MDExMermaidTest do
  alias MDEx.Pipe

  @latest_version "11"

  def attach(pipe, options \\ []) do
    pipe
    |> Pipe.register_options([:mermaid_version])
    |> Pipe.merge_options(mermaid_version: options[:version])
    |> Pipe.prepend_steps(options: &options/1)
    |> Pipe.prepend_steps(transform: &transform/1)
  end

  defp options(pipe) do
    options = put_in(pipe.options, [:render, :unsafe_], true)
    %{pipe | options: options}
  end

  defp transform(pipe) do
    script_node = script_node(pipe)

    document =
      MDEx.traverse_and_update(pipe.document, fn
        %MDEx.Document{nodes: nodes} = document ->
          nodes = [script_node | nodes]
          %{document | nodes: nodes}

        %MDEx.CodeBlock{info: "mermaid", literal: code, nodes: nodes} ->
          %MDEx.HtmlBlock{
            literal: "<pre class=\"mermaid\">#{code}</pre>",
            nodes: nodes
          }

        node ->
          node
      end)

    %{pipe | document: document}
  end

  defp script_node(pipe) do
    version = Pipe.get_option(pipe, :mermaid_version, @latest_version)

    %MDEx.HtmlBlock{
      literal: """
      <script type="module">
        import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@#{version}/dist/mermaid.esm.min.mjs';
        mermaid.initialize({ startOnLoad: true });
      </script>
      """
    }
  end
end

defmodule MDEx.PipeTest do
  use ExUnit.Case, async: true

  alias MDEx.Pipe

  setup do
    [pipe: MDEx.new()]
  end

  test "plugin" do
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

    assert {:ok, html} =
             MDEx.new()
             |> MDExMermaidTest.attach(version: "10")
             |> MDEx.to_html(document: document)

    assert html =~ "import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs'"
    assert html =~ "<pre class=\"mermaid\">graph TD"
  end

  test "register_options", %{pipe: pipe} do
    assert %{registered_options: opts} = Pipe.register_options(pipe, [])
    assert MapSet.to_list(opts) == []

    assert %{registered_options: opts} = Pipe.register_options(pipe, [:foo])
    assert MapSet.to_list(opts) == [:foo]

    assert %{registered_options: opts} = Pipe.register_options(pipe, [:foo, :foo])
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
