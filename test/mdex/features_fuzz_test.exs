defmodule MDEx.FeaturesFuzzTest do
  use MDEx.Fuzz

  import ExUnit.CaptureIO

  require MDEx

  alias MDEx.Document
  alias MDEx.FragmentParser
  alias MDEx.Fuzz.Markdown
  alias MDEx.Fuzz.Options

  @document_option_names [
    :extension,
    :parse,
    :render,
    :syntax_highlight,
    :sanitize,
    :assigns,
    :plugins,
    :codefence_renderers
  ]

  @registered_option_names @document_option_names ++ [:auto_close, :streaming]

  @unsafe_html ~S"""
  <div id="root" class="allowed blocked" data-kind="feature" onclick="attack()">
    <a href="javascript:alert(1)" title="link">link</a>
    <img src="https://example.com/image.png" alt="image">
    <custom-element aria-label="custom">custom</custom-element>
    <code>{:ok, "MDEx"}</code>
    <!-- comment -->
    <script>attack()</script>
    <style>body { display: none; }</style>
  </div>
  """

  test "feature coverage stays in parity with every MDEx option" do
    assert MapSet.new(Keyword.keys(Document.default_options())) ==
             MapSet.new(@document_option_names)

    assert MDEx.new().registered_options == MapSet.new(@registered_option_names)

    assert MapSet.new(Keyword.keys(Document.default_sanitize_options())) ==
             MapSet.new(Options.sanitize_option_names())
  end

  property "sanitization has Markdown and Document input parity" do
    check all(sanitize <- Options.sanitize_options(), suffix <- nonempty_text()) do
      markdown = @unsafe_html <> "\n<p>#{suffix}</p>"
      options = [render: [unsafe: true], sanitize: sanitize]
      expected = MDEx.to_html!(markdown, options)
      document = MDEx.parse_document!(markdown, options)
      actual = MDEx.to_html!(document)

      assert html_tree(actual) == html_tree(expected)
      assert_sanitized(actual, suffix, sanitize)
    end
  end

  property "safe_html uses the same sanitizer as document rendering" do
    check all(sanitize <- Options.sanitize_options(), suffix <- nonempty_text()) do
      unsafe_html = @unsafe_html <> "<p>#{suffix}</p>"

      expected =
        MDEx.safe_html(unsafe_html,
          sanitize: sanitize,
          escape: [content: false, curly_braces_in_code: false]
        )

      document = %Document{nodes: [%MDEx.Raw{literal: unsafe_html}]}
      actual = MDEx.to_html!(document, render: [unsafe: true], sanitize: sanitize)

      assert html_tree(actual) == html_tree(expected)
      assert_sanitized(actual, suffix, sanitize)
    end
  end

  property "syntax highlighting has Markdown and Document input parity" do
    check all(
            code <- code(),
            language <- member_of(~w(elixir javascript plaintext rust)),
            syntax_highlight <- Options.syntax_highlight_options()
          ) do
      markdown = "```#{language}\n#{code}\n```"
      options = [syntax_highlight: syntax_highlight]
      expected = MDEx.to_html!(markdown, options)
      document = MDEx.parse_document!(markdown, options)
      actual = MDEx.to_html!(document)

      assert html_tree(actual) == html_tree(expected)

      [code_node] = Floki.find(html_tree(actual), "pre code")
      assert String.trim(rendered_code_text(code_node)) == String.trim(code)
    end
  end

  property "HEEx assigns have options and Document parity" do
    check all(value <- heex_value()) do
      from_options =
        MDEx.to_heex!("Hello {@value}", assigns: %{value: value})
        |> MDEx.to_html!()

      from_document =
        MDEx.new(markdown: "Hello {@value}")
        |> Document.assign(:value, value)
        |> MDEx.to_heex!()
        |> MDEx.to_html!()

      assert html_tree(from_document) == html_tree(from_options)
      assert Floki.text(html_tree(from_options)) == "Hello #{value}"
    end
  end

  property "plugins run generated AST transformations before rendering" do
    check all(prefix <- option_string(), text <- nonempty_text()) do
      markdown = "Hello #{text}"

      transform = fn document ->
        Document.update_nodes(document, MDEx.Text, fn node ->
          %{node | literal: prefix <> node.literal}
        end)
      end

      plugin = fn document -> Document.append_steps(document, fuzz_transform: transform) end

      expected =
        markdown
        |> MDEx.parse_document!()
        |> transform.()
        |> MDEx.to_html!()

      actual = MDEx.to_html!(markdown, plugins: [plugin])

      assert actual == expected
      assert Floki.text(html_tree(actual)) == prefix <> "Hello #{text}"
    end
  end

  property "code-fence renderers receive the generated language, metadata, and code" do
    check all(code <- code(), metadata <- option_string()) do
      info = "custom key=#{metadata}"
      markdown = "```#{info}\n#{code}\n```"
      parent = self()
      reference = make_ref()

      renderer = fn language, actual_metadata, actual_code ->
        send(parent, {reference, language, actual_metadata, actual_code})
        ~s(<output data-custom="true">#{Base.encode64(actual_code)}</output>)
      end

      options = [
        render: [unsafe: true],
        syntax_highlight: nil,
        codefence_renderers: %{"custom" => renderer}
      ]

      expected_info = MDExNative.Comrak.parse_code_fence_info(info)
      expected_metadata = expected_info.metadata
      expected_code = code <> "\n"
      expected_html = ~s(<output data-custom="true">#{Base.encode64(expected_code)}</output>)

      assert MDEx.to_html!(markdown, options) == expected_html
      assert_receive {^reference, "custom", ^expected_metadata, ^expected_code}

      document = MDEx.parse_document!(markdown, options)
      assert MDEx.to_html!(document) == expected_html
      assert_receive {^reference, "custom", ^expected_metadata, ^expected_code}
    end
  end

  property "auto_close parsing matches explicit fragment completion" do
    check all(source <- incomplete_markdown()) do
      expected = source |> FragmentParser.complete() |> MDEx.parse_document!()
      actual = MDEx.parse_document!(source, auto_close: true)

      assert actual.nodes == expected.nodes
    end
  end

  property "auto_close HTML matches explicit fragment completion" do
    check all(source <- incomplete_markdown()) do
      assert MDEx.to_html!(source, auto_close: true) ==
               source |> FragmentParser.complete() |> MDEx.to_html!()
    end
  end

  property "auto_close XML matches explicit fragment completion" do
    check all(source <- incomplete_markdown()) do
      assert MDEx.to_xml!(source, auto_close: true) ==
               source |> FragmentParser.complete() |> MDEx.to_xml!()
    end
  end

  property "auto_close JSON matches explicit fragment completion" do
    check all(source <- incomplete_markdown()) do
      assert MDEx.to_json!(source, auto_close: true) ==
               source |> FragmentParser.complete() |> MDEx.to_json!()
    end
  end

  property "auto_close Delta matches explicit fragment completion" do
    check all(source <- incomplete_markdown()) do
      assert MDEx.to_delta!(source, auto_close: true) ==
               source |> FragmentParser.complete() |> MDEx.to_delta!()
    end
  end

  property "auto_close Slack matches explicit fragment completion" do
    check all(source <- incomplete_markdown()) do
      assert MDEx.to_slack!(source, auto_close: true) ==
               source |> FragmentParser.complete() |> MDEx.to_slack!()
    end
  end

  property "deprecated streaming matches auto_close" do
    check all(source <- incomplete_markdown(), enabled? <- boolean()) do
      legacy =
        capture_io(:stderr, fn ->
          send(self(), {:legacy_html, MDEx.to_html!(source, streaming: enabled?)})
        end)

      assert_receive {:legacy_html, legacy_html}
      assert legacy =~ "the :streaming option is deprecated"
      assert legacy_html == MDEx.to_html!(source, auto_close: enabled?)
    end
  end

  property "streaming converges to the one-shot AST across byte boundaries" do
    check all(markdown <- Markdown.document(max_blocks: 4), chunk_size <- integer(1..24)) do
      expected = MDEx.parse_document!(markdown).nodes

      actual =
        markdown
        |> binary_chunks(chunk_size)
        |> MDEx.stream()
        |> Enum.reduce(%{}, fn {id, document}, latest -> Map.put(latest, id, document) end)
        |> Enum.sort_by(&elem(&1, 0))
        |> Enum.flat_map(fn {_id, document} -> document.nodes end)

      assert actual == expected
    end
  end

  property "fragment parsing preserves the single generated node" do
    check all(markdown <- fragment_markdown()) do
      document = MDEx.parse_document!(markdown)

      {expected, rewrap} =
        case document.nodes do
          [%MDEx.Paragraph{nodes: [node]} = paragraph] ->
            {node, fn fragment -> %Document{nodes: [%{paragraph | nodes: [fragment]}]} end}

          [node] ->
            {node, fn fragment -> %Document{nodes: [fragment]} end}
        end

      fragment = MDEx.parse_fragment!(markdown)

      assert fragment == expected
      assert html_tree(MDEx.to_html!(rewrap.(fragment))) == html_tree(MDEx.to_html!(markdown))
    end
  end

  property "custom Delta converters preserve their generated operation" do
    check all(text <- nonempty_text()) do
      converter = fn %MDEx.Strong{}, _options ->
        [%{"insert" => text, "attributes" => %{"mdex_custom" => true}}]
      end

      assert [
               %{"insert" => ^text, "attributes" => %{"mdex_custom" => true}},
               %{"insert" => "\n"}
             ] = MDEx.to_delta!("**#{text}**", custom_converters: %{MDEx.Strong => converter})
    end
  end

  defp incomplete_markdown do
    gen all(text <- nonempty_text(), kind <- member_of([:code, :emphasis, :fence, :link, :strong])) do
      case kind do
        :code -> "`#{text}"
        :emphasis -> "*#{text}"
        :fence -> "```elixir\n#{text}"
        :link -> "[#{text}](https://example.com"
        :strong -> "**#{text}"
      end
    end
  end

  defp fragment_markdown do
    gen all(text <- nonempty_text(), kind <- member_of([:code, :heading, :link, :strong, :text])) do
      case kind do
        :code -> "`#{text}`"
        :heading -> "# #{text}"
        :link -> "[#{text}](https://example.com)"
        :strong -> "**#{text}**"
        :text -> text
      end
    end
  end

  defp code do
    list_of(string(:alphanumeric, min_length: 1, max_length: 24), min_length: 1, max_length: 4)
    |> map(&Enum.join(&1, "\n"))
  end

  defp rendered_code_text(code_node) do
    case Floki.find(code_node, ".l-line") do
      [] -> Floki.text(code_node)
      lines -> Enum.map_join(lines, "\n", &(Floki.text(&1) |> String.trim_trailing("\n")))
    end
  end

  defp assert_sanitized(html, suffix, sanitize) do
    refute html =~ "onclick"
    refute html =~ "<script"
    refute html =~ "<style"
    assert Floki.text(html_tree(html)) =~ suffix

    if Keyword.get(sanitize, :strip_comments, true) do
      refute html =~ "<!--"
    end
  end
end
