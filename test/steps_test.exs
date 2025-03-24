defmodule MDEx.StepsTest do
  use ExUnit.Case, async: true

  alias MDEx.Pipe
  alias MDEx.Steps

  describe "put_options" do
    setup do
      [pipe: %Pipe{options: [render: [escape: true]]}]
    end

    test "update existing nested values", %{pipe: pipe} do
      pipe = Pipe.register_options(pipe, [:test])
      pipe = Steps.put_options(pipe, test: 1, document: "new", render: [escape: false, unsafe_: true], extension: [table: true])

      assert get_in(pipe.options, [:test]) == 1
      assert get_in(pipe.options, [:document]) == "new"
      refute get_in(pipe.options, [:render, :escape])
      assert get_in(pipe.options, [:render, :unsafe_])
      assert get_in(pipe.options, [:extension, :table])
    end

    test "validate registered options", %{pipe: pipe} do
      pipe = Pipe.register_options(pipe, [:test])

      assert_raise ArgumentError, "unknown option :testt. Did you mean :test?", fn ->
        pipe = Steps.put_options(pipe, testt: 1)
      end
    end

    test "validate built-in options", %{pipe: pipe} do
      assert_raise NimbleOptions.ValidationError, fn ->
        pipe = Steps.put_options(pipe, document: 1)
      end

      assert_raise NimbleOptions.ValidationError, fn ->
        pipe = Steps.put_options(pipe, render: [foo: 1])
      end
    end
  end

  test "put_built_in_options" do
    pipe = %Pipe{options: [render: [escape: true]]}
    pipe = Pipe.register_options(pipe, [:test])

    assert Steps.put_built_in_options(pipe, document: "new").options[:document] == "new"
    refute Steps.put_built_in_options(pipe, render: [escape: false]).options[:render][:escape]
    refute Steps.put_built_in_options(pipe, test: 1).options[:test]
  end

  test "put_user_options" do
    pipe = %Pipe{options: [render: [escape: true]]}
    pipe = Pipe.register_options(pipe, [:test])

    refute Steps.put_user_options(pipe, document: "new").options[:document]
    assert Steps.put_user_options(pipe, render: [escape: false]).options[:render][:escape]
    assert Steps.put_user_options(pipe, test: 1).options[:test] == 1
  end

  describe "put_extension_options" do
    setup do
      [pipe: %Pipe{options: [extension: [table: true]]}]
    end

    test "update existing value", %{pipe: pipe} do
      pipe = Steps.put_extension_options(pipe, table: false)
      refute get_in(pipe.options, [:extension, :table])
    end

    test "validate schema", %{pipe: pipe} do
      assert_raise NimbleOptions.ValidationError, fn ->
        pipe = Steps.put_extension_options(pipe, foo: 1)
      end
    end

    test "keep other options groups" do
      pipe = %Pipe{options: [extension: [table: true], render: [escape: true]]}
      pipe = Steps.put_extension_options(pipe, table: false)
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
               Steps.put_node_in_document_root(pipe, %MDEx.HtmlBlock{literal: "<p>top</p>"}, :top)
    end

    test "bottom", %{pipe: pipe} do
      assert %Pipe{document: %MDEx.Document{nodes: [%MDEx.Heading{level: 1}, %MDEx.HtmlBlock{literal: "<p>bottom</p>"}]}} =
               Steps.put_node_in_document_root(pipe, %MDEx.HtmlBlock{literal: "<p>bottom</p>"}, :bottom)
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
             Steps.update_nodes(pipe, selector, fn node ->
               %MDEx.HtmlBlock{
                 literal: "<pre>#{String.trim(node.literal)}</pre>",
                 nodes: []
               }
             end)
  end
end
