defmodule MDEx.Fuzz.Markdown do
  @moduledoc """
  Generators that build Markdown documents out of random parts.

  Documents are composed from blocks and inline spans rather than drawn from a
  fixture, so nesting, ordering, and adjacency differ on every run - which is
  where Markdown parsers break.

  Two flavours are provided:

    * `document/1` builds well-formed Markdown covering the feature surface the
      extension options switch on. Leaf text is alphanumeric, so a generated
      document contains only the markup the generator chose.

    * `adversarial/0` builds hostile input - unbalanced delimiters, deep
      nesting, control bytes, lone carriage returns, long runs. Use it for
      properties that assert MDEx never crashes rather than properties that
      assert a specific rendering.

  """

  use ExUnitProperties

  @shortcodes ~w(:rocket: :smile: :tada:)
  @languages ~w(elixir rust javascript plaintext)
  @alert_kinds ~w(NOTE TIP IMPORTANT WARNING CAUTION)
  @url_paths ~w(a b/c d?e=1&f=2)

  @doc """
  A Markdown document made of `:max_blocks` randomly chosen blocks.

  Options:

    * `:max_blocks` - how many blocks the document may contain, default `8`
    * `:front_matter_delimiter` - when set, the document opens with front matter
    * `:heex_safe` - drop every construct that can render a curly brace, default
      `false`. `MDEx.to_heex/2` compiles its HTML through the LiveView tag
      engine, which reads `{...}` as an interpolation and raises on anything
      that is not a valid Elixir expression.

  """
  def document(opts \\ []) do
    max_blocks = Keyword.get(opts, :max_blocks, 8)
    delimiter = Keyword.get(opts, :front_matter_delimiter)

    gen all(blocks <- list_of(block(opts), min_length: 1, max_length: max_blocks)) do
      front_matter(delimiter) <> Enum.join(blocks, "\n\n") <> "\n"
    end
  end

  @doc """
  Front matter fenced by `delimiter`, or an empty string when it is `nil`.
  """
  def front_matter(nil), do: ""
  def front_matter(delimiter), do: "#{delimiter}\ntitle: Fuzz\n#{delimiter}\n\n"

  @doc """
  A single Markdown block. Accepts the same options as `document/1`.
  """
  def block(opts \\ []) do
    blocks = [
      heading(opts),
      setext_heading(),
      paragraph(opts),
      fenced_code(opts),
      indented_code(),
      block_quote(opts),
      alert(opts),
      multiline_block_quote(opts),
      bullet_list(opts),
      ordered_list(opts),
      task_list(),
      table(),
      definition_list(),
      block_directive(opts),
      footnote_definition(opts),
      html_block(),
      math_block(),
      thematic_break()
    ]

    one_of(blocks)
  end

  @doc """
  A line of inline spans joined by spaces.

  Accepts the options of `document/1` plus `:max_length`, the number of spans.
  """
  def inlines(opts \\ []) do
    max_length = Keyword.get(opts, :max_length, 6)

    opts
    |> inline()
    |> list_of(min_length: 1, max_length: max_length)
    |> map(&Enum.join(&1, " "))
  end

  @doc """
  A single inline span. Accepts the same options as `document/1`.
  """
  def inline(opts \\ []) do
    inlines = [
      text(),
      wrapped("**", "**"),
      wrapped("*", "*"),
      wrapped("__", "__"),
      wrapped("~~", "~~"),
      wrapped("~", "~"),
      wrapped("^", "^"),
      wrapped("==", "=="),
      wrapped("++", "++"),
      wrapped("||", "||"),
      wrapped("`", "`"),
      wrapped("$", "$"),
      wrapped("$`", "`$"),
      wrapped("\\(", "\\)"),
      link(opts),
      reference_link(),
      image(),
      autolink(),
      bare_url(),
      wikilink(),
      footnote_reference(),
      inline_footnote(),
      raw_html_span(),
      escaped(),
      member_of(@shortcodes),
      constant("中文*emphasis*文本")
    ]

    one_of(inlines ++ if(heex_safe?(opts), do: [], else: curly_inlines()))
  end

  # Every generator here can put a literal `{` in the rendered HTML.
  defp curly_inlines do
    [
      wrapped("{-", "-}"),
      braced_url(),
      heex_interpolation()
    ]
  end

  defp heex_safe?(opts), do: Keyword.get(opts, :heex_safe, false)

  ## Blocks

  defp heading(opts) do
    gen all(
          level <- integer(1..6),
          content <- inlines(Keyword.put(opts, :max_length, 3)),
          attributes <- heading_attributes(opts)
        ) do
      String.duplicate("#", level) <> " " <> content <> attributes
    end
  end

  defp heading_attributes(opts) do
    if heex_safe?(opts) do
      constant("")
    else
      one_of([constant(""), constant(" {#custom .wide data-kind=fuzz}"), constant(" {#dup}")])
    end
  end

  defp setext_heading do
    gen all(content <- text(), underline <- member_of(["=", "-"])) do
      content <> "\n" <> String.duplicate(underline, max(3, String.length(content)))
    end
  end

  defp paragraph(opts), do: inlines(opts)

  defp fenced_code(opts) do
    gen all(
          info <- code_info_string(opts),
          lines <- list_of(text(), min_length: 1, max_length: 4),
          fence <- member_of(["```", "~~~"])
        ) do
      fence <> info <> "\n" <> Enum.join(lines, "\n") <> "\n" <> fence
    end
  end

  defp code_info_string(opts) do
    safe = [constant(""), member_of(@languages), constant("custom key=value")]
    curly = [map(member_of(@languages), &(&1 <> " {.example key=value}"))]

    one_of(safe ++ if(heex_safe?(opts), do: [], else: curly))
  end

  defp indented_code do
    gen all(lines <- list_of(text(), min_length: 1, max_length: 3)) do
      Enum.map_join(lines, "\n", &("    " <> &1))
    end
  end

  defp block_quote(opts) do
    gen all(content <- inlines(Keyword.put(opts, :max_length, 3)), depth <- integer(1..3)) do
      String.duplicate("> ", depth) <> content
    end
  end

  defp alert(opts) do
    gen all(kind <- member_of(@alert_kinds), content <- inlines(Keyword.put(opts, :max_length, 2))) do
      "> [!#{kind}]\n> #{content}"
    end
  end

  defp multiline_block_quote(opts) do
    gen all(content <- inlines(Keyword.put(opts, :max_length, 3))) do
      ">>>\n#{content}\n>>>"
    end
  end

  defp bullet_list(opts) do
    gen all(
          items <- list_of(inlines(Keyword.put(opts, :max_length, 2)), min_length: 1, max_length: 4),
          marker <- member_of(["-", "*", "+"])
        ) do
      Enum.map_join(items, "\n", &"#{marker} #{&1}")
    end
  end

  defp ordered_list(opts) do
    gen all(
          items <- list_of(inlines(Keyword.put(opts, :max_length, 2)), min_length: 1, max_length: 4),
          start <- integer(0..9)
        ) do
      items
      |> Enum.with_index(start)
      |> Enum.map_join("\n", fn {item, index} -> "#{index}. #{item}" end)
    end
  end

  defp task_list do
    gen all(items <- list_of(tuple({member_of(["x", " ", "?"]), text()}), min_length: 1, max_length: 4)) do
      Enum.map_join(items, "\n", fn {state, item} -> "- [#{state}] #{item}" end)
    end
  end

  defp table do
    gen all(
          headers <- list_of(text(), min_length: 1, max_length: 3),
          rows <- list_of(list_of(text(), min_length: 1, max_length: 3), min_length: 1, max_length: 3),
          alignments <- list_of(member_of([":---", "---:", ":---:", "---"]), min_length: 1, max_length: 3)
        ) do
      width = length(headers)
      delimiter = alignments |> pad_to(width, "---") |> table_row()

      rows = Enum.map_join(rows, "\n", &(&1 |> pad_to(width, "") |> table_row()))

      table_row(headers) <> "\n" <> delimiter <> "\n" <> rows
    end
  end

  defp pad_to(cells, width, filler) do
    cells
    |> Enum.take(width)
    |> Kernel.++(List.duplicate(filler, max(0, width - length(cells))))
  end

  defp table_row(cells), do: "| " <> Enum.join(cells, " | ") <> " |"

  defp definition_list do
    gen all(term <- text(), definitions <- list_of(text(), min_length: 1, max_length: 3)) do
      term <> "\n" <> Enum.map_join(definitions, "\n", &": #{&1}")
    end
  end

  defp block_directive(opts) do
    gen all(name <- member_of(~w(details note warning)), content <- inlines(Keyword.put(opts, :max_length, 2))) do
      "::: #{name}\n#{content}\n:::"
    end
  end

  defp footnote_definition(opts) do
    gen all(label <- footnote_label(), content <- inlines(Keyword.put(opts, :max_length, 2))) do
      "A reference.[^#{label}]\n\n[^#{label}]: #{content}"
    end
  end

  defp html_block do
    gen all(content <- text(), tag <- member_of(~w(div p section))) do
      ~s(<#{tag} data-kind="raw">#{content}</#{tag}>)
    end
  end

  defp math_block do
    gen all(content <- text()) do
      "$$\n#{content}\n$$"
    end
  end

  defp thematic_break, do: member_of(["---", "***", "___"])

  ## Inlines

  defp wrapped(open, close) do
    map(text(), &(open <> &1 <> close))
  end

  defp link(opts) do
    gen all(label <- text(), url <- url(), title <- link_title(), attributes <- link_attributes(opts)) do
      "[#{label}](#{url}#{title})#{attributes}"
    end
  end

  defp reference_link do
    gen all(label <- text(), reference <- text(), url <- url()) do
      "[#{label}][#{reference}]\n\n[#{reference}]: #{url}"
    end
  end

  defp image do
    gen all(alt <- text(), url <- url(), title <- link_title()) do
      "![#{alt}](#{url}#{title})"
    end
  end

  defp autolink, do: map(url(), &"<#{&1}>")
  defp bare_url, do: url()
  defp braced_url, do: map(url(), &"{#{&1}}")

  defp wikilink do
    gen all(page <- text(), title <- text(), order <- boolean()) do
      if order, do: "[[#{page}|#{title}]]", else: "[[#{title}|#{page}]]"
    end
  end

  defp footnote_reference, do: map(footnote_label(), &"[^#{&1}]")
  defp inline_footnote, do: map(text(), &"^[#{&1}]")
  defp raw_html_span, do: map(text(), &~s(<span data-kind="raw">#{&1}</span>))
  defp escaped, do: map(text(), &"\\*#{&1}\\*")
  defp heex_interpolation, do: constant("{@assign}")

  defp link_title, do: one_of([constant(""), map(text(), &~s( "#{&1}"))])

  defp link_attributes(opts) do
    if heex_safe?(opts) do
      constant("")
    else
      one_of([constant(""), constant("{target=_blank}"), constant("{width=10}")])
    end
  end

  defp url do
    gen all(path <- member_of(@url_paths), scheme <- member_of(["https://example.com/", "/relative/", "mailto:user@"])) do
      scheme <> path
    end
  end

  defp footnote_label, do: map(integer(1..4), &"note#{&1}")

  defp text do
    one_of([
      string(:alphanumeric, min_length: 1, max_length: 16),
      map(list_of(string(:alphanumeric, min_length: 1, max_length: 8), min_length: 2, max_length: 4), &Enum.join(&1, " "))
    ])
  end

  ## Adversarial input

  @control_bytes ["\0", "\r", "\r\n", "\v", "\f", " ", "﻿", "​"]
  @delimiters ["*", "_", "~", "`", "^", "=", "+", "|", "[", "]", "(", ")", "{", "}", "<", ">", "#", "-", "$", "\\", ":", "!"]

  @doc """
  Hostile Markdown for properties that assert MDEx survives its input.

  Covers unbalanced delimiters, deep nesting, control bytes, lone carriage
  returns, and long runs of a single character. Do not use it for parity
  properties: the point is that it has no well-defined rendering, only that
  every entry point has to return instead of crashing the NIF.
  """
  def adversarial do
    one_of([
      delimiter_soup(),
      deep_nesting(),
      control_bytes(),
      long_run(),
      truncated(),
      string(:utf8, max_length: 256)
    ])
  end

  defp delimiter_soup do
    list_of(one_of([member_of(@delimiters), string(:alphanumeric, min_length: 1, max_length: 4)]), min_length: 1, max_length: 64)
    |> map(&Enum.join/1)
  end

  defp deep_nesting do
    gen all(
          depth <- integer(1..48),
          marker <- member_of(["> ", "- ", "  - ", ">>>", "#", "*", "`", "((", "[["]),
          content <- string(:alphanumeric, max_length: 8)
        ) do
      String.duplicate(marker, depth) <> content
    end
  end

  defp control_bytes do
    part = one_of([member_of(@control_bytes), string(:alphanumeric, min_length: 1, max_length: 6)])

    gen all(parts <- list_of(part, min_length: 1, max_length: 32)) do
      Enum.join(parts)
    end
  end

  defp long_run do
    gen all(char <- member_of(@delimiters ++ ["a", " ", "\n"]), count <- integer(1..512)) do
      String.duplicate(char, count)
    end
  end

  defp truncated do
    gen all(source <- document(max_blocks: 3), take <- integer(0..100)) do
      # Byte-level truncation can split a grapheme, so cut on graphemes and let
      # the invalid-UTF8 case come from the :utf8 branch of `adversarial/0`.
      source |> String.graphemes() |> Enum.take(take) |> Enum.join()
    end
  end
end
