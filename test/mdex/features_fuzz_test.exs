defmodule MDEx.FeaturesFuzzTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import ExUnit.CaptureIO

  require MDEx

  alias MDEx.Document
  alias MDEx.FragmentParser

  @max_runs 500

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

  @sanitize_option_kinds %{
    add_allowed_classes: :allowed_classes,
    add_clean_content_tags: :clean_content_tags,
    add_generic_attribute_prefixes: :attribute_prefixes,
    add_generic_attributes: :attributes,
    add_tag_attribute_values: :tag_attribute_value_lists,
    add_tag_attributes: :tag_attributes,
    add_tags: :tags,
    add_url_schemes: :url_schemes,
    allowed_classes: :allowed_classes,
    clean_content_tags: :clean_content_tags,
    generic_attribute_prefixes: :attribute_prefixes,
    generic_attributes: :attributes,
    id_prefix: :optional_string,
    link_rel: :optional_string,
    rm_allowed_classes: :allowed_classes,
    rm_clean_content_tags: :clean_content_tags,
    rm_generic_attribute_prefixes: :attribute_prefixes,
    rm_generic_attributes: :attributes,
    rm_set_tag_attribute_value: :tag_values,
    rm_tag_attribute_values: :tag_attribute_value_lists,
    rm_tag_attributes: :tag_attributes,
    rm_tags: :tags,
    rm_url_schemes: :url_schemes,
    set_tag_attribute_value: :tag_attribute_values,
    set_tag_attribute_values: :tag_attribute_values,
    strip_comments: :boolean,
    tag_attribute_values: :tag_attribute_value_lists,
    tag_attributes: :tag_attributes,
    tags: :tags,
    url_relative: :url_relative,
    url_schemes: :url_schemes
  }

  @sanitize_tags ~w(a code custom-element div h1 img p span)
  @clean_content_tags ~w(script style)
  @sanitize_attributes ~w(data-kind href id src title)
  @sanitize_generic_attributes ~w(data-kind id title)
  @sanitize_values ~w(allowed blocked first second)
  @sanitize_schemes ~w(data http https javascript mailto)
  @attribute_prefixes ["aria-", "data-", "phx-"]

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
             MapSet.new(Map.keys(@sanitize_option_kinds))
  end

  property "sanitization has Markdown and Document input parity" do
    check all(sanitize <- sanitize_options(), suffix <- nonempty_text(), property_options()) do
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
    check all(sanitize <- sanitize_options(), suffix <- nonempty_text(), property_options()) do
      unsafe_html = @unsafe_html <> "<p>#{suffix}</p>"

      expected =
        MDEx.safe_html(unsafe_html,
          sanitize: sanitize,
          escape: [content: false, curly_braces_in_code: false]
        )
        |> String.trim()

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
            syntax_highlight <- syntax_highlight_options(),
            property_options()
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
    check all(value <- heex_value(), property_options()) do
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
    check all(prefix <- option_string(), text <- nonempty_text(), property_options()) do
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
    check all(code <- code(), metadata <- option_string(), property_options()) do
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
    check all(source <- incomplete_markdown(), property_options()) do
      expected = source |> FragmentParser.complete() |> MDEx.parse_document!()
      actual = MDEx.parse_document!(source, auto_close: true)

      assert actual.nodes == expected.nodes
    end
  end

  property "auto_close HTML matches explicit fragment completion" do
    check all(source <- incomplete_markdown(), property_options()) do
      assert MDEx.to_html!(source, auto_close: true) ==
               source |> FragmentParser.complete() |> MDEx.to_html!()
    end
  end

  property "auto_close XML matches explicit fragment completion" do
    check all(source <- incomplete_markdown(), property_options()) do
      assert MDEx.to_xml!(source, auto_close: true) ==
               source |> FragmentParser.complete() |> MDEx.to_xml!()
    end
  end

  property "auto_close JSON matches explicit fragment completion" do
    check all(source <- incomplete_markdown(), property_options()) do
      assert MDEx.to_json!(source, auto_close: true) ==
               source |> FragmentParser.complete() |> MDEx.to_json!()
    end
  end

  property "auto_close Delta matches explicit fragment completion" do
    check all(source <- incomplete_markdown(), property_options()) do
      assert MDEx.to_delta!(source, auto_close: true) ==
               source |> FragmentParser.complete() |> MDEx.to_delta!()
    end
  end

  property "auto_close Slack matches explicit fragment completion" do
    check all(source <- incomplete_markdown(), property_options()) do
      assert MDEx.to_slack!(source, auto_close: true) ==
               source |> FragmentParser.complete() |> MDEx.to_slack!()
    end
  end

  property "deprecated streaming matches auto_close" do
    check all(source <- incomplete_markdown(), enabled? <- boolean(), property_options()) do
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
    check all(markdown <- stream_markdown(), chunk_size <- integer(1..24), property_options()) do
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
    check all(markdown <- fragment_markdown(), property_options()) do
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
    check all(text <- nonempty_text(), property_options()) do
      converter = fn %MDEx.Strong{}, _options ->
        [%{"insert" => text, "attributes" => %{"mdex_custom" => true}}]
      end

      assert [
               %{"insert" => ^text, "attributes" => %{"mdex_custom" => true}},
               %{"insert" => "\n"}
             ] = MDEx.to_delta!("**#{text}**", custom_converters: %{MDEx.Strong => converter})
    end
  end

  defp sanitize_options do
    @sanitize_option_kinds
    |> Map.new(fn {name, kind} -> {name, sanitize_value(kind)} end)
    |> fixed_map()
    |> map(&Map.to_list/1)
  end

  defp sanitize_value(:tags), do: list_of(member_of(@sanitize_tags), max_length: 5)

  defp sanitize_value(:clean_content_tags) do
    list_of(member_of(@clean_content_tags), max_length: 2)
  end

  defp sanitize_value(:attributes), do: list_of(member_of(@sanitize_generic_attributes), max_length: 3)
  defp sanitize_value(:attribute_prefixes), do: list_of(member_of(@attribute_prefixes), max_length: 3)
  defp sanitize_value(:url_schemes), do: list_of(member_of(@sanitize_schemes), max_length: 4)
  defp sanitize_value(:optional_string), do: one_of([constant(nil), option_string()])
  defp sanitize_value(:boolean), do: boolean()

  defp sanitize_value(:tag_attributes) do
    map_of(
      member_of(@sanitize_tags),
      list_of(member_of(@sanitize_attributes), max_length: 4),
      max_length: 4
    )
  end

  defp sanitize_value(:allowed_classes) do
    map_of(
      member_of(@sanitize_tags),
      list_of(member_of(@sanitize_values), max_length: 4),
      max_length: 4
    )
  end

  defp sanitize_value(:tag_attribute_value_lists) do
    map_of(
      member_of(@sanitize_tags),
      map_of(
        member_of(@sanitize_attributes),
        list_of(member_of(@sanitize_values), max_length: 4),
        max_length: 3
      ),
      max_length: 3
    )
  end

  defp sanitize_value(:tag_attribute_values) do
    map_of(
      member_of(@sanitize_tags),
      map_of(member_of(@sanitize_attributes), member_of(@sanitize_values), max_length: 3),
      max_length: 3
    )
  end

  defp sanitize_value(:tag_values) do
    map_of(member_of(@sanitize_tags), member_of(@sanitize_attributes), max_length: 4)
  end

  defp sanitize_value(:url_relative) do
    member_of([
      :deny,
      :passthrough,
      {:rewrite_with_base, "https://example.com/base/"},
      {:rewrite_with_root, {"https://example.com/root/", "index.html"}}
    ])
  end

  defp syntax_highlight_options do
    member_of([
      nil,
      false,
      [formatter: :html_linked],
      [formatter: {:html_inline, theme: "onedark"}],
      [engine: :lumis, opts: [formatter: :html_linked]]
    ])
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

  defp stream_markdown do
    gen all(heading <- nonempty_text(), body <- nonempty_text(), slug <- nonempty_text()) do
      "# #{heading}\n\n#{body} **strong**\n\n[link][ref]\n\n[ref]: https://example.com/#{slug}\n"
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

  defp heex_value do
    one_of([
      string(:alphanumeric, max_length: 48),
      member_of(["<MDEx>", "Elixir & Rust", ~s("quoted"), "{value}"])
    ])
  end

  defp nonempty_text, do: string(:alphanumeric, min_length: 1, max_length: 48)
  defp option_string, do: string(:alphanumeric, max_length: 24)

  defp property_options do
    [max_runs: @max_runs, max_generation_size: 30]
  end

  defp rendered_code_text(code_node) do
    case Floki.find(code_node, ".l-line") do
      [] -> Floki.text(code_node)
      lines -> Enum.map_join(lines, "\n", &(Floki.text(&1) |> String.trim_trailing("\n")))
    end
  end

  defp html_tree(html) do
    html
    |> Floki.parse_fragment!()
    |> normalize_html_tree()
  end

  defp normalize_html_tree(nodes) when is_list(nodes), do: Enum.map(nodes, &normalize_html_tree/1)

  defp normalize_html_tree({tag, attributes, children}) do
    {tag, Enum.sort(attributes), normalize_html_tree(children)}
  end

  defp normalize_html_tree(node), do: node

  defp assert_sanitized(html, suffix, sanitize) do
    refute html =~ "onclick"
    refute html =~ "<script"
    refute html =~ "<style"
    assert Floki.text(html_tree(html)) =~ suffix

    if sanitize[:strip_comments] do
      refute html =~ "<!--"
    end
  end

  defp binary_chunks(binary, size), do: binary_chunks(binary, size, [])

  defp binary_chunks("", _size, chunks), do: Enum.reverse(chunks)

  defp binary_chunks(binary, size, chunks) when byte_size(binary) <= size do
    Enum.reverse([binary | chunks])
  end

  defp binary_chunks(binary, size, chunks) do
    <<chunk::binary-size(^size), rest::binary>> = binary
    binary_chunks(rest, size, [chunk | chunks])
  end
end
