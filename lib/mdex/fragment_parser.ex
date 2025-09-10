defmodule MDEx.FragmentParser do
  @moduledoc false

  @doc """
  Completes a markdown fragment by ensuring all opened structures are properly closed.

  Returns the completed markdown string along with metadata:

  - delimiter: The delimiter used for completion (e.g., `*`, `**`, `_`, `__`, etc.)
  - leading: Any leading characters stripped from the original fragment
  - trailing: Any trailing characters added to complete the fragment

  ## Examples

      iex> complete("**text")
      {"**text**", "**", "", ""}

      iex> complete("**text*")
      {"**text**", "*", "", ""}

      iex> complete("**text**")
      {"**text**", "", "", ""}

      iex> complete(" text**", prefix: "**")
      {"**text**", "", " ", ""}

      iex> complete(" text** ", prefix: "**")
      {"**text**", "", " ", " "}

      iex> complete("# Hello `World", prefix: "")
      {"# Hello `World`", "`", " ", " "}

  """
  @spec complete(String.t(), keyword()) :: {markdown :: String.t(), delimiter :: String.t(), leading :: String.t(), trailing :: String.t()}
  def complete(fragment, options \\ []) do
    prefix = options[:prefix] || ""

    if list_marker_line?(fragment) do
      {trailing_ws, core_with_leading} = split_trailing_ws(fragment)
      {completed, used_delim, flag} = complete_core(core_with_leading, prefix)

      case flag do
        :backtick_appended -> {completed, used_delim, " ", " "}
        _ -> {completed, used_delim, "", trailing_ws}
      end
    else
      {leading, core, trailing} = split_ws(fragment)
      {completed, used_delim, flag} = complete_core(core, prefix)

      case flag do
        :backtick_appended -> {completed, used_delim, " ", " "}
        _ -> {completed, used_delim, leading, trailing}
      end
    end
  end

  defp split_trailing_ws(binary) when is_binary(binary) do
    trailing_len = count_trailing_ws(binary)
    total = byte_size(binary)
    core_len = total - trailing_len

    core = if core_len > 0, do: :binary.part(binary, 0, core_len), else: ""
    trailing = if trailing_len > 0, do: :binary.part(binary, total - trailing_len, trailing_len), else: ""

    {trailing, core}
  end

  defp split_ws(binary) when is_binary(binary) do
    {leading_len, total} = {count_leading_ws(binary), byte_size(binary)}
    trailing_len = count_trailing_ws(binary)

    middle_len = max(total - leading_len - trailing_len, 0)

    leading = if leading_len > 0, do: :binary.part(binary, 0, leading_len), else: ""
    core = if middle_len > 0, do: :binary.part(binary, leading_len, middle_len), else: ""
    trailing = if trailing_len > 0, do: :binary.part(binary, total - trailing_len, trailing_len), else: ""

    {leading, core, trailing}
  end

  # ASCII whitespace: space, tab, CR, LF, FF, VT
  @ws [9, 10, 11, 12, 13, 32]

  defp ws?(<<c>>) when is_integer(c), do: c in @ws
  defp ws?(_), do: false

  defp count_leading_ws(<<>>), do: 0

  defp count_leading_ws(<<c, rest::binary>>) when c in @ws do
    1 + count_leading_ws(rest)
  end

  defp count_leading_ws(_), do: 0

  defp count_trailing_ws(<<>>), do: 0

  defp count_trailing_ws(bin) do
    count_trailing_ws_rev(bin, byte_size(bin))
  end

  defp count_trailing_ws_rev(_bin, 0), do: 0

  defp count_trailing_ws_rev(bin, idx) do
    last = :binary.part(bin, idx - 1, 1)
    if ws?(last), do: 1 + count_trailing_ws_rev(bin, idx - 1), else: 0
  end

  defp complete_core(<<>>, _prefix), do: {"", "", :none}

  defp complete_core(core, prefix) when is_binary(core) and is_binary(prefix) do
    cond do
      fence_candidate?(core) or fence_line_start?(last_line(core)) or in_open_fence?(core) ->
        {core, "", :none}

      unmatched_backtick?(core) ->
        {core <> "`", "`", :backtick_appended}

      true ->
        opener = opening_token(core)

        if opener != "" do
          append = missing_trailing_for(core, opener)
          {core <> append, append, :none}
        else
          closer = closing_token(core)

          if closer != "" do
            if prefix != "" and prefix == closer, do: {prefix <> core, "", :none}, else: {core, "", :none}
          else
            line = last_line(core)

            if list_marker_line?(line) do
              case extract_list_content(line) do
                {prefix, content} when content != "" ->
                  case unmatched_emph_suffix(content, "*", "**") do
                    {sfx, used} when sfx != "" ->
                      new_line = prefix <> content <> sfx
                      new_core = replace_last_line(core, new_line)
                      {new_core, used, :none}

                    _ ->
                      case unmatched_emph_suffix(content, "_", "__") do
                        {sfx, used} when sfx != "" ->
                          new_line = prefix <> content <> sfx
                          new_core = replace_last_line(core, new_line)
                          {new_core, used, :none}

                        _ ->
                          case unmatched_emph_suffix(content, "~", "~~") do
                            {sfx, used} when sfx != "" ->
                              new_line = prefix <> content <> sfx
                              new_core = replace_last_line(core, new_line)
                              {new_core, used, :none}

                            _ ->
                              {core, "", :none}
                          end
                      end
                  end

                _ ->
                  {core, "", :none}
              end
            else
              case unmatched_emph_suffix(line, "*", "**") do
                {sfx, used} when sfx != "" ->
                  {core <> sfx, used, :none}

                _ ->
                  case unmatched_emph_suffix(line, "_", "__") do
                    {sfx, used} when sfx != "" ->
                      {core <> sfx, used, :none}

                    _ ->
                      case unmatched_emph_suffix(line, "~", "~~") do
                        {sfx, used} when sfx != "" -> {core <> sfx, used, :none}
                        _ -> {core, "", :none}
                      end
                  end
              end
            end
          end
        end
    end
  end

  defp opening_token(bin) do
    cond do
      starts_with?(bin, "**") -> "**"
      starts_with?(bin, "__") -> "__"
      starts_with?(bin, "~~") -> "~~"
      starts_with?(bin, "*") -> "*"
      starts_with?(bin, "_") -> "_"
      true -> ""
    end
  end

  defp closing_token(bin) do
    cond do
      ends_with?(bin, "**") -> "**"
      ends_with?(bin, "__") -> "__"
      ends_with?(bin, "~~") -> "~~"
      ends_with?(bin, "*") -> "*"
      ends_with?(bin, "_") -> "_"
      true -> ""
    end
  end

  defp missing_trailing_for(bin, token) when is_binary(token) and token != "" do
    token_len = byte_size(token)
    char = :binary.part(token, 0, 1)

    present = trailing_run_len(bin, char)

    cond do
      present >= token_len -> ""
      true -> dup(char, token_len - present)
    end
  end

  defp trailing_run_len(<<>>, _char), do: 0

  defp trailing_run_len(bin, char) do
    run_len_trailing(bin, char, byte_size(bin))
  end

  defp run_len_trailing(_bin, _char, 0), do: 0

  defp run_len_trailing(bin, char, idx) do
    last = :binary.part(bin, idx - 1, 1)
    if last == char, do: 1 + run_len_trailing(bin, char, idx - 1), else: 0
  end

  defp dup(_char, 0), do: ""
  defp dup(char, n) when is_integer(n) and n > 0, do: :binary.copy(char, n)

  defp unmatched_backtick?(bin) do
    rem(count_char(bin, ?`), 2) == 1
  end

  defp count_char(<<>>, _c), do: 0
  defp count_char(<<c, rest::binary>>, c), do: 1 + count_char(rest, c)
  defp count_char(<<_other, rest::binary>>, c), do: count_char(rest, c)

  defp starts_with?(bin, prefix) do
    bl = byte_size(bin)
    pl = byte_size(prefix)
    bl >= pl and :binary.part(bin, 0, pl) == prefix
  end

  defp ends_with?(bin, suffix) do
    bl = byte_size(bin)
    sl = byte_size(suffix)
    bl >= sl and :binary.part(bin, bl - sl, sl) == suffix
  end

  defp fence_candidate?(<<>>), do: false

  defp fence_candidate?(bin) do
    no_nl = :binary.match(bin, "\n") == :nomatch
    no_nl and (leading_run_len(bin, "`") >= 3 or leading_run_len(bin, "~") >= 3)
  end

  defp fence_line_start?(line), do: leading_run_len(line, "`") >= 3 or leading_run_len(line, "~") >= 3

  defp in_open_fence?(bin) do
    cond do
      leading_run_len(bin, "`") >= 3 -> open_fence_without_closer?(bin, "`", leading_run_len(bin, "`"))
      leading_run_len(bin, "~") >= 3 -> open_fence_without_closer?(bin, "~", leading_run_len(bin, "~"))
      true -> false
    end
  end

  defp open_fence_without_closer?(bin, char, run) do
    scan_lines_for_closer(skip_first_line(bin), char, run)
  end

  defp skip_first_line(bin) do
    case :binary.match(bin, "\n") do
      :nomatch -> <<>>
      {pos, _} -> :binary.part(bin, pos + 1, byte_size(bin) - pos - 1)
    end
  end

  defp scan_lines_for_closer(<<>>, _char, _run), do: true

  defp scan_lines_for_closer(bin, char, run) do
    if leading_run_len(bin, char) >= run do
      false
    else
      case :binary.match(bin, "\n") do
        :nomatch ->
          true

        {pos, _} ->
          rest = :binary.part(bin, pos + 1, byte_size(bin) - pos - 1)
          scan_lines_for_closer(rest, char, run)
      end
    end
  end

  defp leading_run_len(bin, char) do
    cl = byte_size(char)
    do_leading(bin, char, cl, 0)
  end

  defp do_leading(<<>>, _c, _cl, acc), do: acc

  defp do_leading(bin, char, cl, acc) do
    if :binary.part(bin, 0, cl) == char do
      do_leading(:binary.part(bin, cl, byte_size(bin) - cl), char, cl, acc + 1)
    else
      acc
    end
  end

  defp last_line(<<>>), do: ""

  defp last_line(bin) do
    len = byte_size(bin)
    start = find_last_nl(bin, len)
    :binary.part(bin, start, len - start)
  end

  defp find_last_nl(_bin, 0), do: 0

  defp find_last_nl(bin, i) do
    if :binary.part(bin, i - 1, 1) == "\n", do: i, else: find_last_nl(bin, i - 1)
  end

  defp list_marker_line?(line) do
    {spaces, rest} = take_leading_spaces(line, 0)
    spaces <= 3 and list_bullet?(rest)
  end

  defp take_leading_spaces(<<32, rest::binary>>, n) when n < 4, do: take_leading_spaces(rest, n + 1)
  defp take_leading_spaces(rest, n), do: {n, rest}

  defp list_bullet?(<<c, 32, _::binary>>) when c in [?*, ?+, ?-], do: true
  defp list_bullet?(_), do: false

  defp extract_list_content(line) do
    {spaces, rest} = take_leading_spaces(line, 0)
    space_prefix = :binary.copy(" ", spaces)

    case rest do
      <<marker, 32, content::binary>> when marker in [?*, ?+, ?-] ->
        prefix = space_prefix <> <<marker, 32>>
        {prefix, content}

      <<marker, 9, content::binary>> when marker in [?*, ?+, ?-] ->
        prefix = space_prefix <> <<marker, 9>>
        {prefix, content}

      <<"[", check, "]", 32, content::binary>> when check in [?x, ?X, 32] ->
        prefix = space_prefix <> "- [" <> <<check>> <> "] "
        {prefix, content}

      _ ->
        case :binary.match(rest, " ") do
          {pos, _} ->
            prefix = space_prefix <> :binary.part(rest, 0, pos + 1)
            content = :binary.part(rest, pos + 1, byte_size(rest) - pos - 1)
            {prefix, content}

          :nomatch ->
            {"", line}
        end
    end
  end

  defp replace_last_line(binary, new_line) do
    len = byte_size(binary)
    start = find_last_nl(binary, len)

    if start == 0 do
      new_line
    else
      prefix = :binary.part(binary, 0, start)
      prefix <> new_line
    end
  end

  defp unmatched_emph_suffix(core, single, double) do
    total = count_char(core, :binary.first(single))
    double_count = count_non_overlapping(core, double)
    unmatched_double = rem(double_count, 2)
    unmatched_single = rem(total - double_count * 2, 2)

    cond do
      unmatched_double == 1 and unmatched_single == 1 ->
        if ends_with?(core, single) and not ends_with?(core, double) do
          {single, single}
        else
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

  defp count_non_overlapping(<<>>, _token), do: 0

  defp count_non_overlapping(bin, token) do
    tl = byte_size(token)
    do_count_no(bin, token, tl, 0)
  end

  defp do_count_no(<<>>, _t, _tl, acc), do: acc

  defp do_count_no(bin, token, tl, acc) do
    case :binary.match(bin, token) do
      :nomatch ->
        acc

      {pos, _len} ->
        next_pos = pos + tl
        rest = :binary.part(bin, next_pos, byte_size(bin) - next_pos)
        do_count_no(rest, token, tl, acc + 1)
    end
  end
end
