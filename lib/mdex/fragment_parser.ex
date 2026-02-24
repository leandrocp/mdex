defmodule MDEx.FragmentParser do
  @moduledoc false

  import NimbleParsec

  @ws_chars [9, 10, 11, 12, 13, 32]
  @bullet_markers ["* ", "*\t", "+ ", "+\t", "- ", "-\t"]
  @task_markers ["- [ ] ", "- [ ]\t", "- [x] ", "- [x]\t", "- [X] ", "- [X]\t"]
  @ordered_delims [". ", ".\t", ") ", ")\t"]
  @tokens ["**", "__", "~~", "*", "_", "~"]
  @fence_chars ["`", "~"]

  defcombinatorp(:space_prefix, ascii_string([32], min: 0, max: 3))
  defcombinatorp(:bullet_marker, choice(Enum.map(@bullet_markers, &string/1)))
  defcombinatorp(:task_marker, choice(Enum.map(@task_markers, &string/1)))

  defcombinatorp(
    :ordered_marker,
    ascii_string([?0..?9], min: 1)
    |> concat(choice(Enum.map(@ordered_delims, &string/1)))
  )

  defcombinatorp(
    :list_marker_prefix,
    parsec(:space_prefix)
    |> concat(choice([parsec(:task_marker), parsec(:bullet_marker), parsec(:ordered_marker)]))
  )

  defparsecp(:list_prefix_parser, parsec(:list_marker_prefix))

  defmodule State do
    @moduledoc false
    defstruct last_unclosed_token: nil
  end

  @spec complete_with_state(String.t(), %State{} | nil) :: {String.t(), %State{}}
  def complete_with_state(fragment, state) do
    state = state || %State{}
    prefix = state.last_unclosed_token || ""
    completed = complete(fragment, prefix: prefix)

    # Detect what token we closed (if any) to pass as prefix next time
    new_unclosed = extract_unclosed_token(fragment, prefix)
    {completed, %State{last_unclosed_token: new_unclosed}}
  end

  defp extract_unclosed_token(fragment, prefix) do
    full = if prefix != "", do: prefix <> fragment, else: fragment
    suffix = unmatched_suffix(full)
    if suffix != "", do: suffix, else: nil
  end

  @spec complete(String.t(), keyword()) :: String.t()
  def complete(fragment, options \\ []) do
    prefix = options[:prefix] || ""

    if list_marker_line?(fragment) do
      {trailing_ws, core_with_leading} = split_trailing_ws(fragment)
      {completed, flag} = complete_core(core_with_leading, prefix, trailing_ws, options)
      completed <> adjust_trailing(trailing_ws, flag)
    else
      {leading, core, trailing} = split_ws(fragment)
      leading = maybe_preserve_leading(leading)
      {completed, flag} = complete_core(core, prefix, trailing, options)
      leading <> completed <> adjust_trailing(trailing, flag)
    end
  end

  defp split_trailing_ws(binary) do
    {core, trailing} = take_trailing_ws(binary)
    {trailing, core}
  end

  defp split_ws(binary) do
    {leading, rest} = take_leading_ws(binary)
    {core, trailing} = take_trailing_ws(rest)
    {leading, core, trailing}
  end

  defp take_leading_ws(binary) do
    size = byte_size(binary)
    leading_size = leading_ws_size(binary, size, 0)

    {
      binary_part(binary, 0, leading_size),
      binary_part(binary, leading_size, size - leading_size)
    }
  end

  defp take_trailing_ws(binary) do
    size = byte_size(binary)
    trailing_size = trailing_ws_size(binary, size - 1, 0)
    core_size = size - trailing_size

    {
      binary_part(binary, 0, core_size),
      binary_part(binary, core_size, trailing_size)
    }
  end

  defp adjust_trailing(trailing, {:consume_trailing, consumed}) when consumed != "" do
    if String.starts_with?(trailing, consumed) do
      drop_prefix(trailing, consumed)
    else
      trailing
    end
  end

  defp adjust_trailing(trailing, _flag), do: trailing

  defp complete_core("", _prefix, _trailing, _options), do: {"", :none}

  defp complete_core(core, prefix, trailing, options) do
    with nil <- maybe_complete_fence(core, trailing, options),
         nil <- maybe_complete_table(core, trailing),
         nil <- maybe_complete_math(core, trailing) do
      line = last_line(core)
      opening_append = opening_completion_append(core)

      cond do
        skip_completion?(core, line) ->
          {core, :none}

        unmatched_backtick?(core) ->
          if prefix_has_open_backtick?(prefix) and String.ends_with?(core, "`") do
            {prefix <> core, :none}
          else
            {core <> "`", :backtick_appended}
          end

        opening_append != "" ->
          {core <> opening_append, :none}

        closer = closing_token(core) ->
          if prefix != "" and prefix == closer do
            {prefix <> core, :none}
          else
            {core, :none}
          end

        list_marker_line?(line) ->
          {complete_list_line(core, line), :none}

        true ->
          case incomplete_link_completion(core) do
            nil ->
              case unmatched_suffix(line) do
                suffix when suffix != "" -> {core <> suffix, :none}
                _ -> {core, :none}
              end

            completion ->
              {completion, :none}
          end
      end
    end
  end

  defp maybe_complete_fence(core, trailing, _options) do
    case unclosed_fence_info(core) do
      nil ->
        nil

      %{indent: indent, char: char, run: run} = info ->
        case fence_partial_closing_gap(core, info) do
          {:append, append} ->
            {core <> append, :none}

          :none ->
            # reuse a trailing newline when available so the appended delimiter matches expectations
            {consumed, _remaining?} = consume_trailing_for_fence(trailing)

            closing_line = indent <> String.duplicate(char, run)

            leading_segment =
              cond do
                consumed != "" -> consumed
                String.ends_with?(core, "\n") -> ""
                true -> "\n"
              end

            append = leading_segment <> closing_line
            flag = if consumed == "", do: :none, else: {:consume_trailing, consumed}

            {core <> append, flag}
        end
    end
  end

  defp fence_partial_closing_gap(core, %{indent: indent, char: char, run: run}) do
    case parse_fence_line(last_line(core)) do
      %{indent: ^indent, char: ^char, run: partial_run, rest: rest}
      when partial_run > 0 and partial_run < run ->
        if only_spaces?(rest) do
          missing = run - partial_run
          {:append, String.duplicate(char, missing)}
        else
          :none
        end

      _ ->
        :none
    end
  end

  defp unclosed_fence_info(core) do
    core
    |> String.split("\n", trim: false)
    |> find_unclosed_fence(0, nil)
    |> normalize_fence_info()
  end

  defp find_unclosed_fence([], _index, open_fence), do: open_fence

  defp find_unclosed_fence([line | rest], index, open_fence) do
    case parse_fence_line(line) do
      %{run: run} = info when run >= 3 ->
        updated_info = Map.merge(info, %{line_index: index, has_body: false})

        cond do
          open_fence == nil ->
            find_unclosed_fence(rest, index + 1, updated_info)

          closes_open_fence?(updated_info, open_fence) ->
            find_unclosed_fence(rest, index + 1, nil)

          true ->
            find_unclosed_fence(rest, index + 1, updated_info)
        end

      _ ->
        open_fence = maybe_mark_body(open_fence, index)
        find_unclosed_fence(rest, index + 1, open_fence)
    end
  end

  defp maybe_mark_body(nil, _index), do: nil

  defp maybe_mark_body(%{line_index: line_index} = info, index) when index > line_index do
    Map.put(info, :has_body, true)
  end

  defp maybe_mark_body(info, _index), do: info

  defp normalize_fence_info(nil), do: nil

  defp normalize_fence_info(%{has_body: false}), do: nil

  defp normalize_fence_info(info), do: Map.drop(info, [:has_body])

  defp closes_open_fence?(%{indent: indent, char: char, run: run, rest: rest}, %{indent: indent, char: char, run: open_run}) do
    run >= open_run and only_spaces?(rest)
  end

  defp parse_fence_line(line) do
    {indent, rest} = take_fence_indent(line)

    with <<char_code, _::binary>> <- rest,
         char = <<char_code>>,
         true <- char in @fence_chars do
      run = count_fence_run(rest, char_code, 0)
      remainder = binary_part(rest, run, byte_size(rest) - run)
      %{indent: indent, char: char, run: run, rest: remainder}
    else
      _ -> nil
    end
  end

  defp take_fence_indent(line), do: take_fence_indent(line, 0)

  defp take_fence_indent(<<" "::utf8, rest::binary>>, count) when count < 3 do
    take_fence_indent(rest, count + 1)
  end

  defp take_fence_indent(rest, count) do
    {String.duplicate(" ", count), rest}
  end

  defp count_fence_run(<<char_code, rest::binary>>, char_code, acc) do
    count_fence_run(rest, char_code, acc + 1)
  end

  defp count_fence_run(_rest, _char_code, acc), do: acc

  defp only_spaces?(""), do: true
  defp only_spaces?(<<char, rest::binary>>) when char in [32, 9], do: only_spaces?(rest)
  defp only_spaces?(_), do: false

  defp consume_trailing_for_fence(trailing) do
    if String.starts_with?(trailing, "\n") do
      {"\n", drop_prefix(trailing, "\n")}
    else
      {"", trailing}
    end
  end

  defp drop_prefix(binary, prefix) do
    prefix_size = byte_size(prefix)
    binary_part(binary, prefix_size, byte_size(binary) - prefix_size)
  end

  @doc false
  def merge_stream_buffer(existing_markdown, buffer, last_node) do
    existing_markdown
    |> maybe_strip_trailing_fence(last_node)
    |> ensure_trailing_newline()
    |> append_buffer(buffer)
  end

  defp maybe_strip_trailing_fence(markdown, %{__struct__: MDEx.CodeBlock, fenced: true} = block) do
    closing_line = closing_fence_line(block)
    trim_trailing_line(markdown, closing_line)
  end

  defp maybe_strip_trailing_fence(markdown, _), do: markdown

  defp ensure_trailing_newline(<<>>), do: ""

  defp ensure_trailing_newline(binary) do
    case :binary.last(binary) do
      ?\n -> binary
      _ -> binary <> "\n"
    end
  end

  defp append_buffer(existing, buffer) do
    IO.iodata_to_binary([existing | Enum.reverse(buffer)])
  end

  defp closing_fence_line(%{fence_char: char, fence_length: length, fence_offset: offset}) do
    indent = if offset > 0, do: String.duplicate(" ", offset), else: ""
    indent <> String.duplicate(char, length)
  end

  defp trim_trailing_line(markdown, closing_line) do
    newline_closing = "\n" <> closing_line

    cond do
      String.ends_with?(markdown, newline_closing <> "\n") ->
        drop_suffix(markdown, byte_size(newline_closing <> "\n"))

      String.ends_with?(markdown, newline_closing) ->
        drop_suffix(markdown, byte_size(newline_closing))

      true ->
        markdown
    end
  end

  defp drop_suffix(markdown, size_to_drop) do
    length = byte_size(markdown)
    binary_part(markdown, 0, length - size_to_drop)
  end

  defp whitespace_char?(char), do: char in @ws_chars

  defp leading_ws_size(_binary, size, size), do: size

  defp leading_ws_size(binary, size, index) do
    char = :binary.at(binary, index)

    if whitespace_char?(char) do
      leading_ws_size(binary, size, index + 1)
    else
      index
    end
  end

  defp trailing_ws_size(_binary, index, count) when index < 0, do: count

  defp trailing_ws_size(binary, index, count) do
    char = :binary.at(binary, index)

    if whitespace_char?(char) do
      trailing_ws_size(binary, index - 1, count + 1)
    else
      count
    end
  end

  defp maybe_preserve_leading(""), do: ""

  defp maybe_preserve_leading(leading) do
    if preserve_leading?(leading) do
      leading
    else
      ""
    end
  end

  defp preserve_leading?(leading) do
    contains_line_break?(leading) or code_block_indented?(leading)
  end

  defp contains_line_break?(leading) do
    :binary.match(leading, <<10>>) != :nomatch or :binary.match(leading, <<13>>) != :nomatch
  end

  defp code_block_indented?(leading) do
    :binary.match(leading, <<9>>) != :nomatch or final_space_run(leading) >= 4
  end

  defp final_space_run(binary), do: final_space_run(binary, 0)

  defp final_space_run(<<>>, count), do: count
  defp final_space_run(<<10, rest::binary>>, _count), do: final_space_run(rest, 0)
  defp final_space_run(<<13, rest::binary>>, _count), do: final_space_run(rest, 0)
  defp final_space_run(<<32, rest::binary>>, count), do: final_space_run(rest, count + 1)
  defp final_space_run(<<_char, rest::binary>>, count), do: final_space_run(rest, count)

  defp maybe_complete_table(core, trailing) do
    if String.starts_with?(trailing, "\n") do
      line = last_line(core)

      if table_header_line?(line) do
        separator = generate_table_separator(line)
        {core <> "\n" <> separator, {:consume_trailing, "\n"}}
      else
        nil
      end
    else
      nil
    end
  end

  defp table_header_line?(line) do
    trimmed = String.trim(line)
    String.starts_with?(trimmed, "|") and String.ends_with?(trimmed, "|")
  end

  defp generate_table_separator(line) do
    pipe_count = count_char(line, ?|)

    cond do
      pipe_count > 1 ->
        columns = pipe_count - 1

        columns
        |> build_table_separator(["|"])
        |> IO.iodata_to_binary()

      true ->
        ""
    end
  end

  defp build_table_separator(0, acc), do: acc

  defp build_table_separator(columns, acc) do
    build_table_separator(columns - 1, [acc, " - |"])
  end

  defp maybe_complete_math(core, trailing) do
    cond do
      has_unclosed_delimiter?(core, "$$") ->
        if String.starts_with?(trailing, "\n") do
          {core <> "\n$$", {:consume_trailing, "\n"}}
        else
          {core <> "$$", :none}
        end

      has_unclosed_delimiter?(core, "$") ->
        {core <> "$", :none}

      true ->
        nil
    end
  end

  defp has_unclosed_delimiter?(text, "$") do
    count = count_math_dollars(text, 0)
    rem(count, 2) == 1
  end

  defp has_unclosed_delimiter?(text, delimiter) do
    count = count_occurrences(text, delimiter)
    rem(count, 2) == 1
  end

  defp count_math_dollars(<<>>, acc), do: acc
  defp count_math_dollars(<<"\\$", rest::binary>>, acc), do: count_math_dollars(rest, acc)

  defp count_math_dollars(<<"$", digit, rest::binary>>, acc) when digit in ?0..?9 do
    count_math_dollars(rest, acc)
  end

  defp count_math_dollars(<<"$", rest::binary>>, acc), do: count_math_dollars(rest, acc + 1)
  defp count_math_dollars(<<_char, rest::binary>>, acc), do: count_math_dollars(rest, acc)

  defp complete_list_line(core, line) do
    case extract_list_content(line) do
      {prefix, content} when content != "" ->
        case unmatched_suffix(content) do
          suffix when suffix != "" ->
            new_line = prefix <> content <> suffix
            replace_last_line(core, new_line)

          "" ->
            case incomplete_link_completion(content) do
              nil -> core
              completion -> replace_last_line(core, prefix <> completion)
            end
        end

      _ ->
        core
    end
  end

  defp skip_completion?(core, line) do
    fence_candidate?(core) or fence_line_start?(line)
  end

  defp unmatched_suffix(text) do
    Enum.find_value([{"*", "**"}, {"_", "__"}, {"~", "~~"}, {"+", "++"}, {"=", "=="}], "", fn {single, double} ->
      case unmatched_emph_suffix(text, single, double) do
        suffix when suffix != "" -> suffix
        _ -> nil
      end
    end)
  end

  defp opening_completion_append(core) do
    with token when token != nil <- opening_token(core),
         append when append != "" <- missing_trailing_for(core, token),
         true <- rem(count_occurrences(core, token), 2) == 1 do
      append
    else
      _ -> ""
    end
  end

  defp opening_token(bin) do
    Enum.find(@tokens, &String.starts_with?(bin, &1))
  end

  defp closing_token(bin) do
    Enum.find(@tokens, &String.ends_with?(bin, &1))
  end

  defp missing_trailing_for(bin, token) do
    with char when char != nil <- String.first(token),
         needed = div(String.length(token), String.length(char)),
         present = trailing_run_len(bin, char),
         true <- present < needed do
      String.duplicate(char, needed - present)
    else
      _ -> ""
    end
  end

  defp trailing_run_len(bin, char) do
    char_len = String.length(char)

    if char_len == 0 do
      0
    else
      consumed = String.length(bin) - String.length(String.trim_trailing(bin, char))
      div(consumed, char_len)
    end
  end

  defp unmatched_backtick?(bin), do: rem(count_char(bin, ?`), 2) == 1

  defp prefix_has_open_backtick?(""), do: false
  defp prefix_has_open_backtick?(prefix), do: unmatched_backtick?(prefix)

  @double_only_delimiters ["+", "="]

  defp unmatched_emph_suffix(core, single, double) do
    double_count = count_occurrences(core, double)
    unmatched_double = rem(double_count, 2)

    if single in @double_only_delimiters do
      flanking = count_flanking_delimiters(core, double)

      if rem(flanking, 2) == 1, do: double, else: ""
    else
      single_code = single |> String.to_charlist() |> List.first()
      total = count_emphasis_char(core, single_code)
      unmatched_single = rem(max(total - double_count * 2, 0), 2)

      cond do
        unmatched_double == 1 and unmatched_single == 1 ->
          if String.ends_with?(core, single) and not String.ends_with?(core, double) do
            single
          else
            double <> single
          end

        unmatched_double == 1 ->
          double

        unmatched_single == 1 ->
          single

        true ->
          ""
      end
    end
  end

  # Count occurrences of a double delimiter (like ++ or ==) that appear in
  # flanking position — preceded by whitespace/SOL or followed by whitespace/EOL.
  # This prevents false positives like "C++17" or "x==1".
  defp count_flanking_delimiters(bin, delim) do
    delim_size = byte_size(delim)
    do_count_flanking(bin, delim, delim_size, 0)
  end

  defp do_count_flanking(bin, delim, delim_size, acc) do
    case :binary.match(bin, delim) do
      :nomatch ->
        acc

      {pos, _len} ->
        before_ok = pos == 0 or non_alnum_at?(bin, pos - 1)
        after_pos = pos + delim_size
        after_ok = after_pos >= byte_size(bin) or non_alnum_at?(bin, after_pos)

        new_acc = if before_ok or after_ok, do: acc + 1, else: acc
        rest_start = pos + delim_size
        rest = binary_part(bin, rest_start, byte_size(bin) - rest_start)
        do_count_flanking(rest, delim, delim_size, new_acc)
    end
  end

  defp non_alnum_at?(bin, pos) do
    char = :binary.at(bin, pos)
    not (char in ?0..?9 or char in ?A..?Z or char in ?a..?z)
  end

  defp count_emphasis_char(bin, ?_), do: count_emphasis_underscore(bin)
  defp count_emphasis_char(bin, char), do: count_char(bin, char)

  defp count_char(bin, char) when is_integer(char) do
    bin |> :binary.matches(<<char>>) |> count_matches()
  end

  defp count_occurrences(bin, token) do
    bin |> :binary.matches(token) |> count_matches()
  end

  defp count_matches(:nomatch), do: 0
  defp count_matches(matches), do: length(matches)

  defp count_emphasis_underscore(bin) do
    count_emphasis_underscore(bin, :boundary, 0)
  end

  defp count_emphasis_underscore(<<>>, _prev_type, acc), do: acc

  defp count_emphasis_underscore(<<char::utf8, rest::binary>>, prev_type, acc) do
    cond do
      char == ?_ ->
        next_type = next_char_type(rest)
        eligible? = not (prev_type == :word and next_type == :word)
        new_acc = if eligible?, do: acc + 1, else: acc
        count_emphasis_underscore(rest, :underscore, new_acc)

      true ->
        count_emphasis_underscore(rest, char_type(char), acc)
    end
  end

  defp next_char_type(<<>>), do: :boundary
  defp next_char_type(<<char::utf8, _rest::binary>>), do: char_type(char)

  defp char_type(char) when char in ?0..?9, do: :word
  defp char_type(char) when char in ?A..?Z, do: :word
  defp char_type(char) when char in ?a..?z, do: :word
  defp char_type(_char), do: :boundary

  defp incomplete_link_completion(core) do
    cond do
      has_incomplete_link_url?(core) ->
        core <> ")"

      incomplete_link_brackets?(core) ->
        ensure_placeholder_prefix(core, "](mdex:incomplete-link)")

      incomplete_link_destination?(core) ->
        ensure_placeholder_prefix(core, "(mdex:incomplete-link)")

      true ->
        nil
    end
  end

  defp has_incomplete_link_url?(core) do
    matches = :binary.matches(core, "](")

    case matches do
      [] ->
        false

      list ->
        {pos, _len} = List.last(list)
        has_open_bracket_before?(core, pos) and no_closing_paren_after?(core, pos)
    end
  end

  defp has_open_bracket_before?(core, bracket_close_pos) do
    # Scan backwards from the ] position to find a matching [
    prefix = binary_part(core, 0, bracket_close_pos)
    # Check for [ or ![ — the [ must not be escaped
    find_label_start(prefix, byte_size(prefix) - 1) != nil
  end

  defp no_closing_paren_after?(core, pos) do
    # pos is the position of "](" — check after the "("
    after_start = pos + 2
    remaining = binary_part(core, after_start, byte_size(core) - after_start)
    not has_unmatched_close_paren?(remaining, 0)
  end

  # Walk the string tracking paren depth. A ) at depth 0 means
  # the link destination is closed.
  defp has_unmatched_close_paren?(<<>>, _depth), do: false
  defp has_unmatched_close_paren?(<<"(", rest::binary>>, depth), do: has_unmatched_close_paren?(rest, depth + 1)
  defp has_unmatched_close_paren?(<<")", _rest::binary>>, 0), do: true
  defp has_unmatched_close_paren?(<<")", rest::binary>>, depth), do: has_unmatched_close_paren?(rest, depth - 1)
  defp has_unmatched_close_paren?(<<_char, rest::binary>>, depth), do: has_unmatched_close_paren?(rest, depth)

  defp ensure_placeholder_prefix(core, placeholder) do
    if String.ends_with?(core, placeholder), do: core, else: core <> placeholder
  end

  defp incomplete_link_brackets?(core) do
    count_occurrences(core, "[") > count_occurrences(core, "]")
  end

  defp incomplete_link_destination?(core) do
    case trailing_link_label(core) do
      nil -> false
      _span -> true
    end
  end

  defp fence_candidate?(""), do: false

  defp fence_candidate?(bin) do
    not String.contains?(bin, "\n") and Enum.any?(@fence_chars, &(leading_run_len(bin, &1) >= 3))
  end

  defp fence_line_start?(line) do
    Enum.any?(@fence_chars, &(leading_run_len(line, &1) >= 3))
  end

  defp leading_run_len("", _char), do: 0

  defp leading_run_len(bin, char) do
    char_len = String.length(char)

    if char_len == 0 do
      0
    else
      consumed = String.length(bin) - String.length(String.trim_leading(bin, char))
      div(consumed, char_len)
    end
  end

  defp last_line(""), do: ""

  defp last_line(bin) do
    case find_last_newline(bin, byte_size(bin) - 1) do
      nil ->
        bin

      index ->
        start = index + 1
        binary_part(bin, start, byte_size(bin) - start)
    end
  end

  defp replace_last_line("", new_line), do: new_line

  defp replace_last_line(bin, new_line) do
    case find_last_newline(bin, byte_size(bin) - 1) do
      nil ->
        new_line

      index ->
        binary_part(bin, 0, index + 1) <> new_line
    end
  end

  defp find_last_newline(_binary, index) when index < 0, do: nil

  defp find_last_newline(binary, index) do
    case :binary.at(binary, index) do
      ?\n -> index
      _ -> find_last_newline(binary, index - 1)
    end
  end

  defp list_marker_line?(line) do
    match?({:ok, _, _, _, _, _}, list_prefix_parser(line))
  end

  defp extract_list_content(line) do
    case list_prefix_parser(line) do
      {:ok, parts, rest, _, _, _} -> {Enum.join(parts), rest}
      _ -> {"", line}
    end
  end

  defp trailing_link_label(<<>>), do: nil

  defp trailing_link_label(core) do
    size = byte_size(core)

    if size == 0 do
      nil
    else
      last_index = size - 1

      case :binary.at(core, last_index) do
        ?] ->
          with start when not is_nil(start) <- find_label_start(core, last_index - 1) do
            {start, last_index - start + 1}
          else
            _ -> nil
          end

        _ ->
          nil
      end
    end
  end

  defp find_label_start(_binary, index) when index < 0, do: nil

  defp find_label_start(binary, index) do
    case :binary.at(binary, index) do
      ?[ -> index
      ?] -> nil
      _ -> find_label_start(binary, index - 1)
    end
  end
end
