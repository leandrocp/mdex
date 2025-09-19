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
  defparsecp(:leading_ws_parser, ascii_string(@ws_chars, min: 0))

  def complete(fragment, options \\ []) do
    prefix = options[:prefix] || ""

    if list_marker_line?(fragment) do
      {trailing_ws, core_with_leading} = split_trailing_ws(fragment)
      {completed, used_delim, flag} = complete_core(core_with_leading, prefix, trailing_ws)
      {completed, used_delim, adjust_trailing(trailing_ws, flag)}
    else
      {_leading, core, trailing} = split_ws(fragment)
      {completed, used_delim, flag} = complete_core(core, prefix, trailing)
      {completed, used_delim, adjust_trailing(trailing, flag)}
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
    {:ok, [leading], rest, _context, _line, _column} = leading_ws_parser(binary)
    {leading, rest}
  end

  defp take_trailing_ws(binary) do
    reversed = String.reverse(binary)
    {:ok, [rev_trailing], rest_rev, _context, _line, _column} = leading_ws_parser(reversed)
    core = String.reverse(rest_rev)
    trailing = String.reverse(rev_trailing)
    {core, trailing}
  end

  defp adjust_trailing(trailing, {:consume_trailing, consumed}) when consumed != "" do
    if String.starts_with?(trailing, consumed) do
      drop_prefix(trailing, consumed)
    else
      trailing
    end
  end

  defp adjust_trailing(trailing, _flag), do: trailing

  defp complete_core("", _prefix, _trailing), do: {"", "", :none}

  defp complete_core(core, prefix, trailing) do
    case maybe_complete_fence(core, trailing) do
      {completed, used, flag} ->
        {completed, used, flag}

      nil ->
        line = last_line(core)
        opening_append = opening_completion_append(core)

        cond do
          skip_completion?(core, line) ->
            {core, "", :none}

          unmatched_backtick?(core) ->
            cond do
              prefix_has_open_backtick?(prefix) and String.ends_with?(core, "`") ->
                {prefix <> core, "", :none}

              true ->
                {core <> "`", "`", :backtick_appended}
            end

          opening_append != "" ->
            {core <> opening_append, opening_append, :none}

          closer = closing_token(core) ->
            if prefix != "" and prefix == closer do
              {prefix <> core, "", :none}
            else
              {core, "", :none}
            end

          list_marker_line?(line) ->
            case complete_list_line(core, line) do
              {^core, ""} -> {core, "", :none}
              {updated, used} -> {updated, used, :none}
            end

          true ->
            case incomplete_link_completion(core) do
              {completion, delimiter} ->
                {completion, delimiter, :none}

              nil ->
                case unmatched_suffix(line) do
                  {suffix, used} when suffix != "" -> {core <> suffix, used, :none}
                  _ -> {core, "", :none}
                end
            end
        end
    end
  end

  defp maybe_complete_fence(core, trailing) do
    case unclosed_fence_info(core) do
      nil ->
        nil

      %{indent: indent, char: char, run: run} = info ->
        case fence_partial_closing_gap(core, info) do
          {:append, append} ->
            {core <> append, append, :none}

          :none ->
            # reuse a trailing newline when available so the appended delimiter matches expectations
            {consumed, _remaining?} = consume_trailing_for_fence(trailing)

            closing_line = indent <> String.duplicate(char, run)

            leading_segment =
              cond do
                consumed != "" ->
                  consumed

                String.ends_with?(core, "\n") ->
                  ""

                true ->
                  "\n"
              end

            append = leading_segment <> closing_line

            used_delim =
              if consumed != "" and String.starts_with?(append, consumed) do
                drop_prefix(append, consumed)
              else
                append
              end

            flag = if consumed == "", do: :none, else: {:consume_trailing, consumed}

            {core <> append, used_delim, flag}
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
    case String.split(core, "\n", trim: false) do
      [] ->
        nil

      [first_line | rest] ->
        case parse_fence_line(first_line) do
          %{run: run} = info when run >= 3 ->
            cond do
              rest == [] ->
                nil

              fence_closed_in_lines?(rest, info) ->
                nil

              true ->
                info
            end

          _ ->
            nil
        end
    end
  end

  defp parse_fence_line(line) do
    {indent, rest} = take_fence_indent(line)

    case rest do
      <<char_code, _::binary>> ->
        char = <<char_code>>

        if char in @fence_chars do
          run = count_fence_run(rest, char_code, 0)
          remainder = binary_part(rest, run, byte_size(rest) - run)
          %{indent: indent, char: char, run: run, rest: remainder}
        else
          nil
        end

      _ ->
        nil
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

  defp fence_closed_in_lines?(lines, %{indent: indent, char: char, run: run}) do
    Enum.any?(lines, fn line ->
      case parse_fence_line(line) do
        %{indent: ^indent, char: ^char, run: closing_run, rest: rest} ->
          closing_run >= run and only_spaces?(rest)

        _ ->
          false
      end
    end)
  end

  defp only_spaces?(""), do: true

  defp only_spaces?(<<char, rest::binary>>) when char in [32, 9] do
    only_spaces?(rest)
  end

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

  defp complete_list_line(core, line) do
    case extract_list_content(line) do
      {prefix, content} when content != "" ->
        case unmatched_suffix(content) do
          {suffix, used} when suffix != "" ->
            new_line = prefix <> content <> suffix
            {replace_last_line(core, new_line), used}

          _ ->
            {core, ""}
        end

      _ ->
        {core, ""}
    end
  end

  defp skip_completion?(core, line) do
    fence_candidate?(core) or fence_line_start?(line)
  end

  defp unmatched_suffix(text) do
    Enum.find_value([{"*", "**"}, {"_", "__"}, {"~", "~~"}], {"", ""}, fn {single, double} ->
      case unmatched_emph_suffix(text, single, double) do
        {suffix, used} when suffix != "" -> {suffix, used}
        _ -> nil
      end
    end)
  end

  defp opening_completion_append(core) do
    case opening_token(core) do
      nil ->
        ""

      token ->
        append = missing_trailing_for(core, token)

        if append != "" and rem(count_occurrences(core, token), 2) == 1 do
          append
        else
          ""
        end
    end
  end

  defp opening_token(bin) do
    Enum.find_value(@tokens, fn token ->
      if String.starts_with?(bin, token), do: token, else: nil
    end)
  end

  defp closing_token(bin) do
    Enum.find_value(@tokens, fn token ->
      if String.ends_with?(bin, token), do: token, else: nil
    end)
  end

  defp missing_trailing_for(bin, token) do
    case String.first(token) do
      nil ->
        ""

      char ->
        needed = div(String.length(token), String.length(char))
        present = trailing_run_len(bin, char)

        if present >= needed do
          ""
        else
          String.duplicate(char, needed - present)
        end
    end
  end

  defp trailing_run_len(bin, char) do
    trimmed = String.trim_trailing(bin, char)
    consumed = String.length(bin) - String.length(trimmed)
    char_len = String.length(char)

    if char_len == 0 do
      0
    else
      div(consumed, char_len)
    end
  end

  defp unmatched_backtick?(bin), do: rem(count_char(bin, ?`), 2) == 1

  defp prefix_has_open_backtick?(prefix) do
    prefix != "" and unmatched_backtick?(prefix)
  end

  defp unmatched_emph_suffix(core, single, double) do
    single_code = single |> String.to_charlist() |> List.first()
    total = count_char(core, single_code)
    double_count = count_occurrences(core, double)
    unmatched_double = rem(double_count, 2)
    unmatched_single = rem(max(total - double_count * 2, 0), 2)

    cond do
      unmatched_double == 1 and unmatched_single == 1 ->
        cond do
          String.ends_with?(core, single) and not String.ends_with?(core, double) ->
            {single, single}

          true ->
            {double <> single, double <> single}
        end

      unmatched_double == 1 ->
        {double, double}

      unmatched_single == 1 ->
        {single, single}

      true ->
        {"", ""}
    end
  end

  defp count_char(bin, char) when is_integer(char) do
    case :binary.matches(bin, <<char>>) do
      :nomatch -> 0
      matches -> length(matches)
    end
  end

  defp count_occurrences(bin, token) do
    case :binary.matches(bin, token) do
      :nomatch -> 0
      matches -> length(matches)
    end
  end

  defp incomplete_link_completion(core) do
    cond do
      incomplete_link_brackets?(core) ->
        completion = ensure_placeholder_prefix(core, "](mdex:incomplete-link)")
        {completion, "](mdex:incomplete-link)"}

      incomplete_link_destination?(core) ->
        completion = ensure_placeholder_prefix(core, "(mdex:incomplete-link)")
        {completion, "(mdex:incomplete-link)"}

      true ->
        nil
    end
  end

  defp ensure_placeholder_prefix(core, placeholder) do
    if String.ends_with?(core, placeholder) do
      core
    else
      core <> placeholder
    end
  end

  defp incomplete_link_brackets?(core) do
    count_occurrences(core, "[") > count_occurrences(core, "]")
  end

  defp incomplete_link_destination?(core) do
    Regex.match?(~r/\[[^\]]*\]$/, core) and not Regex.match?(~r/\[[^\]]*\]\([^)]*\)$/, core)
  end

  defp fence_candidate?(""), do: false

  defp fence_candidate?(bin) do
    not String.contains?(bin, "\n") and Enum.any?(@fence_chars, fn char -> leading_run_len(bin, char) >= 3 end)
  end

  defp fence_line_start?(line) do
    Enum.any?(@fence_chars, fn char -> leading_run_len(line, char) >= 3 end)
  end

  defp leading_run_len("", _char), do: 0

  defp leading_run_len(bin, char) do
    trimmed = String.trim_leading(bin, char)
    consumed = String.length(bin) - String.length(trimmed)
    char_len = String.length(char)

    if char_len == 0 do
      0
    else
      div(consumed, char_len)
    end
  end

  defp last_line(""), do: ""

  defp last_line(bin) do
    case String.split(bin, "\n", trim: false) do
      [] -> ""
      parts -> List.last(parts)
    end
  end

  defp replace_last_line(bin, new_line) do
    case String.split(bin, "\n", trim: false) do
      [] ->
        new_line

      [_line] ->
        new_line

      parts ->
        parts
        |> List.replace_at(length(parts) - 1, new_line)
        |> Enum.join("\n")
    end
  end

  defp list_marker_line?(line) do
    case list_prefix_parser(line) do
      {:ok, _parts, _rest, _context, _line, _column} -> true
      _ -> false
    end
  end

  defp extract_list_content(line) do
    case list_prefix_parser(line) do
      {:ok, parts, rest, _context, _line, _column} ->
        {Enum.join(parts), rest}

      _ ->
        {"", line}
    end
  end
end
