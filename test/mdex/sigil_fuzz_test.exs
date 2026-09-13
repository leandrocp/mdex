defmodule MDEx.SigilFuzzTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import MDEx.Sigil

  @max_runs 500

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
    check all(markdown <- markdown(), property_options()) do
      assert eval_sigil(markdown, []) == MDEx.parse_document!(markdown, @sigil_options)
    end
  end

  property "~MD HTML output matches to_html" do
    check all(markdown <- markdown(), property_options()) do
      assert eval_sigil(markdown, ~c"HTML") == MDEx.to_html!(markdown, @sigil_options)
    end
  end

  property "~MD Markdown output preserves literal Markdown" do
    check all(markdown <- markdown(), property_options()) do
      assert eval_sigil(markdown, ~c"MD") == markdown
    end
  end

  property "~MD JSON output matches to_json" do
    check all(markdown <- markdown(), property_options()) do
      assert eval_sigil(markdown, ~c"JSON") == MDEx.to_json!(markdown, @sigil_options)
    end
  end

  property "~MD XML output matches to_xml" do
    check all(markdown <- markdown(), property_options()) do
      assert eval_sigil(markdown, ~c"XML") == MDEx.to_xml!(markdown, @sigil_options)
    end
  end

  property "~MD Delta output matches to_delta" do
    check all(markdown <- markdown(), property_options()) do
      assert eval_sigil(markdown, ~c"DELTA") == MDEx.to_delta!(markdown, @sigil_options)
    end
  end

  property "~MD HEEX output evaluates generated assigns" do
    check all(value <- heex_value(), property_options()) do
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
    {value, []} = Code.eval_quoted(ast, [], env)
    value
  end

  defp render_heex_sigil(assigns) do
    ~MD|Hello {@value}|HEEX
    |> MDEx.to_html!()
  end

  defp markdown do
    gen all(text <- nonempty_text()) do
      """
      # #{text}

      ~~strike~~ __underline__ X^2^ ||spoiler|| :rocket:

      - [x] task
      - [?] relaxed task

      | feature | value |
      | ------- | ----- |
      | table   | #{text} |

      A reference.[^note]

      [^note]: footnote

      Term
      : Description

      > [!NOTE]
      > alert

      >>>
      multiline block quote
      >>>

      Inline math $x + y$ and math code `$x + y$`.

      {https://example.com/#{text}}

      <span data-kind="raw">raw HTML</span>
      """
    end
  end

  defp heex_value do
    one_of([
      string(:alphanumeric, max_length: 48),
      member_of(["<MDEx>", "Elixir & Rust", ~s("quoted"), "{value}"])
    ])
  end

  defp nonempty_text, do: string(:alphanumeric, min_length: 1, max_length: 48)

  defp property_options do
    [max_runs: @max_runs, max_generation_size: 30]
  end
end
