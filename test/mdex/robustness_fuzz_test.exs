defmodule MDEx.RobustnessFuzzTest do
  use MDEx.Fuzz

  alias MDEx.Fuzz.Markdown
  alias MDEx.Fuzz.Options

  @known_errors [MDEx.InvalidInputError, MDEx.DecodeError, MDEx.InvalidSelector]

  property "every entry point survives adversarial input" do
    check all(source <- Markdown.adversarial(), options <- Options.options()) do
      document = assert_returns(fn -> MDEx.parse_document(source, options) end)

      assert_returns(fn -> MDEx.to_html(source, options) end)
      assert_returns(fn -> MDEx.to_xml(source, options) end)
      assert_returns(fn -> MDEx.to_json(source, options) end)
      assert_returns(fn -> MDEx.to_delta(source, options) end)
      assert_returns(fn -> MDEx.to_slack(source, options) end)
      assert_returns(fn -> MDEx.to_markdown(document, options) end)

      assert_returns(fn -> MDEx.to_html(document, options) end)
      assert_returns(fn -> MDEx.to_xml(document, options) end)
      assert_returns(fn -> MDEx.to_json(document, options) end)
      assert_returns(fn -> MDEx.to_delta(document, options) end)
      assert_returns(fn -> MDEx.to_slack(document, options) end)
    end
  end

  property "auto_close survives adversarial input" do
    check all(source <- Markdown.adversarial(), options <- Options.options()) do
      options = Keyword.put(options, :auto_close, true)

      assert_returns(fn -> MDEx.parse_document(source, options) end)
      assert_returns(fn -> MDEx.to_html(source, options) end)
    end
  end

  property "streaming survives adversarial input at any chunk size" do
    check all(source <- Markdown.adversarial(), chunk_size <- integer(1..16)) do
      documents =
        source
        |> binary_chunks(chunk_size)
        |> MDEx.stream()
        |> Enum.to_list()

      assert Enum.all?(documents, &match?({_id, %MDEx.Document{}}, &1))
    end
  end

  property "the AST reached through JSON is the AST reached directly" do
    check all({markdown, options} <- round_trip_case()) do
      document = MDEx.parse_document!(markdown, options)

      through_json =
        document
        |> MDEx.to_json!(options)
        |> then(&MDEx.parse_document!({:json, &1}, options))

      assert through_json.nodes == document.nodes
    end
  end

  # Round trips are only meaningful when the same options drive both the parse
  # and the render, so they are generated once and reused on both sides.
  defp round_trip_case do
    gen all(
          options <- Options.options(),
          markdown <- Markdown.document(front_matter_delimiter: get_in(options, [:extension, :front_matter_delimiter]))
        ) do
      {markdown, options}
    end
  end

  # MDEx is a NIF wrapper, so the property worth asserting over hostile input is
  # that a call returns at all: either a result or one of the errors MDEx
  # declares. A Rust panic or an undeclared exception fails here.
  defp assert_returns(call) do
    case call.() do
      {:ok, result} ->
        result

      {:error, %struct{}} when struct in @known_errors ->
        nil

      other ->
        flunk("expected {:ok, result} or a declared MDEx error, got: #{inspect(other)}")
    end
  end
end
