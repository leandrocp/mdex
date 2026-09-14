defmodule MDEx.SigilFuzzTest do
  use MDEx.Fuzz

  import ExUnit.CaptureIO
  import MDEx.Sigil

  alias MDEx.Fuzz.Markdown

  @sigil_options MDEx.merge_options(
                   MDEx.Document.default_options(),
                   extension: [
                     strikethrough: true,
                     table: true,
                     autolink: false,
                     tasklist: true,
                     superscript: true,
                     footnotes: true,
                     description_lists: true,
                     multiline_block_quotes: true,
                     alerts: true,
                     math_dollars: true,
                     math_code: true,
                     shortcodes: true,
                     underline: true,
                     spoiler: true,
                     phoenix_heex: true
                   ],
                   parse: [relaxed_tasklist_matching: true, relaxed_autolinks: true],
                   render: [unsafe: true, escape: false, github_pre_lang: true, full_info_string: true]
                 )

  defmodule ConfiguredSigil do
    use MDEx,
      extension: [strikethrough: true],
      render: [unsafe: true],
      sanitize: MDEx.Document.default_sanitize_options()

    def to_html do
      ~MD|~~enabled~~ <script>attack()</script>|HTML
    end
  end

  property "~MD document output matches parse_document" do
    check all(markdown <- markdown()) do
      assert eval_sigil(markdown, []) == MDEx.parse_document!(markdown, @sigil_options)
    end
  end

  property "~MD HTML output matches to_html" do
    check all(markdown <- markdown()) do
      assert html_tree(eval_sigil(markdown, ~c"HTML")) ==
               html_tree(MDEx.to_html!(markdown, @sigil_options))
    end
  end

  property "~MD Markdown output preserves literal Markdown" do
    check all(markdown <- markdown()) do
      assert eval_sigil(markdown, ~c"MD") == markdown
    end
  end

  property "~MD JSON output matches to_json" do
    check all(markdown <- markdown()) do
      assert eval_sigil(markdown, ~c"JSON") == MDEx.to_json!(markdown, @sigil_options)
    end
  end

  property "~MD XML output matches to_xml" do
    check all(markdown <- markdown()) do
      assert eval_sigil(markdown, ~c"XML") == MDEx.to_xml!(markdown, @sigil_options)
    end
  end

  property "~MD Delta output matches to_delta" do
    check all(markdown <- markdown()) do
      assert eval_sigil(markdown, ~c"DELTA") == MDEx.to_delta!(markdown, @sigil_options)
    end
  end

  property "~MD HEEX output evaluates generated assigns" do
    check all(value <- heex_value()) do
      html = render_heex_sigil(%{value: value})

      assert Floki.text(Floki.parse_fragment!(html)) == "Hello #{value}"
    end
  end

  test "use MDEx options apply to the ~MD sigil" do
    html = ConfiguredSigil.to_html()

    assert html =~ "<del>enabled</del>"
    refute html =~ "attack()"
    refute html =~ "<script"
  end

  defp eval_sigil(markdown, modifier) do
    ast = {:sigil_MD, [], [{:<<>>, [], [markdown]}, modifier]}
    env = %{__ENV__ | module: nil}

    # `MDEx.Sigil.expr/2` speculatively parses the sigil body as Elixir to detect
    # a `%MDEx.Document{}` literal. Markdown that happens to tokenize - `~~~`
    # fences, `---` breaks, `:::` directives - makes that probe print Elixir
    # deprecation warnings. They say nothing about the sigil result, so they are
    # swallowed here to keep a failing property readable.
    capture_io(:stderr, fn ->
      {value, []} = Code.eval_quoted(ast, [], env)
      send(self(), {:sigil_result, value})
    end)

    assert_received {:sigil_result, value}
    value
  end

  defp render_heex_sigil(assigns) do
    ~MD|Hello {@value}|HEEX
    |> MDEx.to_html!()
  end

  # The sigil interpolates its body at compile time, so the generated document
  # reaches every modifier verbatim and the parity assertions stay meaningful.
  defp markdown, do: Markdown.document(max_blocks: 6)
end
