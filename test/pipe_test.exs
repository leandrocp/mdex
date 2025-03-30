defmodule MDExMermaidSample do
  alias MDEx.Pipe

  @latest_version "11"

  def attach(pipe, options \\ []) do
    pipe
    |> Pipe.register_options([:mermaid_version])
    |> Pipe.put_options(mermaid_version: options[:version])
    |> Pipe.append_steps(enable_unsafe: &enable_unsafe/1)
    |> Pipe.append_steps(inject_script: &inject_script/1)
    |> Pipe.append_steps(update_code_blocks: &update_code_blocks/1)
  end

  defp enable_unsafe(pipe) do
    Pipe.put_render_options(pipe, unsafe_: true)
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

    Pipe.put_node_in_document_root(pipe, script_node)
  end

  defp update_code_blocks(pipe) do
    selector = fn
      %MDEx.CodeBlock{info: "mermaid"} -> true
      _ -> false
    end

    Pipe.update_nodes(
      pipe,
      selector,
      &%MDEx.HtmlBlock{literal: "<pre class=\"mermaid\">#{&1.literal}</pre>", nodes: &1.nodes}
    )
  end
end

defmodule MDEx.PipeTest do
  use ExUnit.Case, async: true
  doctest MDEx.Pipe

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
               |> MDExMermaidSample.attach(version: "10")
               |> MDEx.to_html()

      assert html =~ "import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs'"
      assert html =~ "<pre class=\"mermaid\">graph TD"
    end

    test ":document in to_html/2", %{document: document} do
      assert {:ok, html} =
               MDEx.new()
               |> MDExMermaidSample.attach(version: "10")
               |> MDEx.to_html(document: document)

      assert html =~ "import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs'"
      assert html =~ "<pre class=\"mermaid\">graph TD"
    end
  end

  describe "put_options" do
    setup do
      [pipe: MDEx.new()]
    end

    test "update existing nested values", %{pipe: pipe} do
      pipe = Pipe.register_options(pipe, [:test])
      pipe = Pipe.put_options(pipe, test: 1, render: [escape: false, unsafe_: true], extension: [table: true])

      assert get_in(pipe.options, [:test]) == 1
      refute get_in(pipe.options, [:render, :escape])
      assert get_in(pipe.options, [:render, :unsafe_])
      assert get_in(pipe.options, [:extension, :table])
    end

    test "validate registered options", %{pipe: pipe} do
      pipe = Pipe.register_options(pipe, [:test])

      assert_raise ArgumentError, "unknown option :testt. Did you mean :test?", fn ->
        Pipe.put_options(pipe, testt: 1)
      end
    end

    test "validate built-in options", %{pipe: pipe} do
      assert_raise ArgumentError, fn ->
        Pipe.put_options(pipe, invalid: 1)
      end

      assert_raise NimbleOptions.ValidationError, fn ->
        Pipe.put_options(pipe, render: [foo: 1])
      end
    end

    test "put_built_in_options" do
      pipe = %Pipe{options: [render: [escape: true]]}
      pipe = Pipe.register_options(pipe, [:test])

      assert Pipe.put_built_in_options(pipe, document: "new").options[:document] == "new"
      refute Pipe.put_built_in_options(pipe, render: [escape: false]).options[:render][:escape]
      refute Pipe.put_built_in_options(pipe, test: 1).options[:test]
    end

    test "put_user_options" do
      pipe = %Pipe{options: [render: [escape: true]]}
      pipe = Pipe.register_options(pipe, [:test])

      refute Pipe.put_user_options(pipe, document: "new").options[:document]
      assert Pipe.put_user_options(pipe, render: [escape: false]).options[:render][:escape]
      assert Pipe.put_user_options(pipe, test: 1).options[:test] == 1
    end
  end

  describe "put_extension_options" do
    setup do
      [pipe: %Pipe{options: [extension: [table: true]]}]
    end

    test "update existing value", %{pipe: pipe} do
      pipe = Pipe.put_extension_options(pipe, table: false)
      refute get_in(pipe.options, [:extension, :table])
    end

    test "validate schema", %{pipe: pipe} do
      assert_raise NimbleOptions.ValidationError, fn ->
        Pipe.put_extension_options(pipe, foo: 1)
      end
    end

    test "keep other options groups" do
      pipe = %Pipe{options: [extension: [table: true], render: [escape: true]]}
      pipe = Pipe.put_extension_options(pipe, table: false)
      refute get_in(pipe.options, [:extension, :table])
      assert get_in(pipe.options, [:render, :escape])
    end
  end

  describe "put_node_in_document_root" do
    setup do
      pipe =
        MDEx.new(document: "# Test")
        |> Pipe.resolve_document()

      [pipe: pipe]
    end

    test "top", %{pipe: pipe} do
      assert %Pipe{document: %MDEx.Document{nodes: [%MDEx.HtmlBlock{literal: "<p>top</p>"}, %MDEx.Heading{level: 1}]}} =
               Pipe.put_node_in_document_root(pipe, %MDEx.HtmlBlock{literal: "<p>top</p>"}, :top)
    end

    test "bottom", %{pipe: pipe} do
      assert %Pipe{document: %MDEx.Document{nodes: [%MDEx.Heading{level: 1}, %MDEx.HtmlBlock{literal: "<p>bottom</p>"}]}} =
               Pipe.put_node_in_document_root(pipe, %MDEx.HtmlBlock{literal: "<p>bottom</p>"}, :bottom)
    end
  end

  test "update_nodes" do
    pipe =
      MDEx.new(
        document: """
        # Test

        ```mermaid
        1
        ```

        ```elixir
        foo = :bar
        ```

        ```mermaid
        2
        ```

        ## Done
        """
      )
      |> Pipe.resolve_document()

    selector = fn
      %MDEx.CodeBlock{info: "mermaid"} -> true
      _ -> false
    end

    assert %Pipe{
             document: %MDEx.Document{
               nodes: [
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "Test"}], level: 1, setext: false},
                 %MDEx.HtmlBlock{nodes: [], literal: "<pre>1</pre>", block_type: 0},
                 %MDEx.CodeBlock{info: "elixir"},
                 %MDEx.HtmlBlock{nodes: [], literal: "<pre>2</pre>", block_type: 0},
                 %MDEx.Heading{nodes: [%MDEx.Text{literal: "Done"}], level: 2, setext: false}
               ]
             }
           } =
             Pipe.update_nodes(pipe, selector, fn node ->
               %MDEx.HtmlBlock{
                 literal: "<pre>#{String.trim(node.literal)}</pre>",
                 nodes: []
               }
             end)
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
        |> Pipe.put_options(foo: 1)

      assert Pipe.get_option(pipe, :foo) == 1
    end

    test "returns default when not registered", %{pipe: pipe} do
      refute Pipe.get_option(pipe, :foo)
    end
  end
end
