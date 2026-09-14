defmodule MDEx.OptionsFuzzTest do
  use MDEx.Fuzz

  import ExUnit.CaptureIO

  alias MDEx.ComrakConverter
  alias MDEx.Document
  alias MDEx.Fuzz.Markdown
  alias MDEx.Fuzz.Options
  alias MDExNative.Comrak, as: NativeComrak

  require MDEx

  test "fuzz option definitions stay in parity with MDEx defaults" do
    assert MapSet.new(Options.extension_option_names()) ==
             MapSet.new(Keyword.keys(Document.default_extension_options()))

    assert MapSet.new(Options.parse_option_names()) ==
             MapSet.new(Keyword.keys(Document.default_parse_options()))

    assert MapSet.new(Options.render_option_names()) ==
             MapSet.new(Keyword.keys(Document.default_render_options()))
  end

  property "parsing stays in parity with mdex_native" do
    check all({markdown, options} <- fuzz_case()) do
      native_nodes = NativeComrak.parse_document(markdown, native_options(options)).nodes

      mdex_nodes =
        markdown
        |> MDEx.parse_document!(options)
        |> ComrakConverter.from_mdex()
        |> Map.fetch!(:nodes)

      assert mdex_nodes == native_nodes
    end
  end

  property "HTML rendering has Markdown and Document input parity" do
    check all({markdown, options} <- fuzz_case()) do
      expected = NativeComrak.markdown_to_html(markdown, native_options(options))
      document = MDEx.parse_document!(markdown, options)

      assert html_tree(MDEx.to_html!(document)) == html_tree(expected)
    end
  end

  property "XML rendering has Markdown and Document input parity" do
    check all({markdown, options} <- fuzz_case()) do
      expected = MDEx.to_xml!(markdown, options)
      document = MDEx.parse_document!(markdown, options)
      actual = MDEx.to_xml!(document)

      assert normalize_document_sourcepos(actual) == normalize_document_sourcepos(expected)
      assert actual =~ "<document"
      assert String.ends_with?(actual, "</document>") or String.ends_with?(actual, "/>")
    end
  end

  property "CommonMark rendering stays in parity with mdex_native" do
    check all({markdown, options} <- fuzz_case()) do
      native_options = native_options(options)

      # MDEx only strips the trailing newline comrak appends; leading whitespace
      # is significant, an indented code block at the top of the document loses
      # its indent without it.
      expected =
        markdown
        |> NativeComrak.parse_document(native_options)
        |> NativeComrak.document_to_commonmark(native_options)
        |> String.trim_trailing()

      document = MDEx.parse_document!(markdown, options)

      assert MDEx.to_markdown!(document) == expected
    end
  end

  property "JSON rendering round-trips the parsed document" do
    check all({markdown, options} <- fuzz_case()) do
      document = MDEx.parse_document!(markdown, options)
      json = MDEx.to_json!(markdown, options)

      assert MDEx.to_json!(document) == json
      assert %{"node_type" => "MDEx.Document", "nodes" => nodes} = Jason.decode!(json)
      assert is_list(nodes)

      assert MDEx.parse_document!({:json, json}, options).nodes == document.nodes
    end
  end

  property "Delta rendering has Markdown and Document input parity" do
    check all({markdown, options} <- fuzz_case()) do
      document = MDEx.parse_document!(markdown, options)
      delta = MDEx.to_delta!(markdown, options)

      assert MDEx.to_delta!(document) == delta
      assert_valid_delta(delta)
    end
  end

  property "Slack rendering has Markdown and Document input parity" do
    check all({markdown, options} <- fuzz_case()) do
      document = MDEx.parse_document!(markdown, options)
      slack = MDEx.to_slack!(markdown, options)

      assert MDEx.to_slack!(document) == slack
      assert String.valid?(slack)
    end
  end

  property "HEEx rendering has Markdown and Document input parity" do
    check all({markdown, options} <- fuzz_case(heex_safe: true)) do
      options = heex_options(options)
      document = MDEx.parse_document!(markdown, options)

      from_markdown = markdown |> MDEx.to_heex!(options) |> MDEx.to_html!()
      from_document = document |> MDEx.to_heex!() |> MDEx.to_html!()

      assert html_tree(from_document) == html_tree(from_markdown)
    end
  end

  property "deprecated header_ids matches header_id_prefix" do
    check all({markdown, options} <- fuzz_case(), prefix <- option_string()) do
      extension = Keyword.fetch!(options, :extension)

      legacy_options =
        Keyword.put(
          options,
          :extension,
          extension
          |> Keyword.delete(:header_id_prefix)
          |> Keyword.put(:header_ids, prefix)
        )

      current_options =
        Keyword.put(
          options,
          :extension,
          extension
          |> Keyword.put(:header_ids, nil)
          |> Keyword.put(:header_id_prefix, prefix)
        )

      warning =
        capture_io(:stderr, fn ->
          assert html_tree(MDEx.to_html!(markdown, legacy_options)) ==
                   html_tree(MDEx.to_html!(markdown, current_options))
        end)

      assert warning =~ "extension :header_ids is deprecated"
    end
  end

  # Options and Markdown are generated together because the front matter
  # delimiter has to match the option that enables it, and because a document
  # built from random blocks exercises a different shape on every run.
  defp fuzz_case(opts \\ []) do
    gen all(
          options <- Options.options(),
          markdown <- source(options, opts)
        ) do
      {markdown, options}
    end
  end

  defp source(options, opts) do
    document_opts =
      Keyword.put(opts, :front_matter_delimiter, get_in(options, [:extension, :front_matter_delimiter]))

    document = Markdown.document(document_opts)

    # Unstructured noise is worth a slice of the runs, but it can contain curly
    # braces, which the HEEx tag engine refuses to compile.
    if Keyword.get(opts, :heex_safe, false) do
      document
    else
      frequency([{9, document}, {1, string(:utf8, max_length: 128)}])
    end
  end

  defp native_options(options), do: Document.rust_options!(options)

  defp heex_options(options) do
    options
    |> Keyword.update!(:extension, &Keyword.put(&1, :phoenix_heex, true))
    |> Keyword.update!(:render, &Keyword.put(&1, :unsafe, true))
  end

  defp normalize_document_sourcepos(xml) do
    String.replace(xml, ~r/<document sourcepos="[^"]*"/, "<document")
  end

  defp assert_valid_delta(delta) do
    assert is_list(delta)

    Enum.each(delta, fn operation ->
      assert %{"insert" => insert} = operation
      assert is_binary(insert) or is_map(insert)

      if Map.has_key?(operation, "attributes") do
        assert is_map(operation["attributes"])
      end
    end)
  end
end
