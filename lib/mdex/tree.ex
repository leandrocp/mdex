defmodule MDEx.Tree do
  @moduledoc false

  alias MDEx.Alert
  alias MDEx.BlockQuote
  alias MDEx.Code
  alias MDEx.CodeBlock
  alias MDEx.DescriptionDetails
  alias MDEx.DescriptionItem
  alias MDEx.DescriptionList
  alias MDEx.DescriptionTerm
  alias MDEx.Document
  alias MDEx.Emph
  alias MDEx.EscapedTag
  alias MDEx.FootnoteDefinition
  alias MDEx.FootnoteReference
  alias MDEx.FrontMatter
  alias MDEx.Heading
  alias MDEx.HtmlBlock
  alias MDEx.HtmlInline
  alias MDEx.Image
  alias MDEx.Link
  alias MDEx.ListItem
  alias MDEx.Math
  alias MDEx.MultilineBlockQuote
  alias MDEx.Paragraph
  alias MDEx.SpoileredText
  alias MDEx.Strikethrough
  alias MDEx.Strong
  alias MDEx.Subscript
  alias MDEx.Superscript
  alias MDEx.Table
  alias MDEx.TableCell
  alias MDEx.TableRow
  alias MDEx.TaskItem
  alias MDEx.Text
  alias MDEx.ThematicBreak
  alias MDEx.Underline
  alias MDEx.WikiLink

  def append(%Document{} = document, chunk) when is_binary(chunk) do
    # IO.puts("------------------------------------------------------------------------")
    # dbg(chunk)
    original_chunk = chunk

    document =
      document
      |> Document.get_private(:mdex_stream_source, "")
      |> Kernel.<>(original_chunk)
      |> then(&Document.put_private(document, :mdex_stream_source, &1))

    buffer_state =
      document
      |> Document.get_private(:mdex_fragment_buffer, %{prefix: "", text: ""})
      |> normalize_buffer_state()

    {document, chunk, buffer_state, pending_break?} =
      consume_blank_line_chunk(document, chunk, buffer_state)

    {document, chunk, buffer_state, consumed_table?} =
      consume_table_acc(document, chunk, buffer_state)

    {document, chunk, buffer_state, consumed_list?} =
      consume_list_continuation(document, chunk, buffer_state)

    {document, chunk, buffer_state, consumed_code_block?} =
      consume_fenced_code_block(document, chunk, buffer_state)

    {document, chunk, buffer_state, consumed_escape?} =
      consume_escape_accumulator(document, chunk, buffer_state)

    {document, chunk, buffer_state, consumed_link?} =
      consume_link_accumulator(document, chunk, buffer_state)

    {document, chunk, buffer_state, consumed_emphasis?} =
      consume_emphasis_accumulator(document, chunk, buffer_state)

    {document, chunk, buffer_state, consumed_inline_code?} =
      consume_open_inline_code(document, chunk, buffer_state)

    consumed? =
      pending_break? or consumed_table? or consumed_list? or consumed_code_block? or consumed_escape? or
        consumed_link? or consumed_emphasis? or consumed_inline_code?

    cond do
      chunk == "" and consumed? ->
        Document.put_private(document, :mdex_fragment_buffer, buffer_state)

      true ->
        pending_break_flag = Document.get_private(document, :mdex_pending_break) || false
        document = Document.delete_private(document, :mdex_pending_break)

        options =
          document.options
          |> Keyword.put(:buffer, buffer_state.prefix)
          |> Keyword.put(:buffer_text, buffer_state.text)

        {nodes, delimiter, new_text_buffer} = MDEx.parse_fragments(chunk, options)
        nodes = maybe_strip_buffer_prefix(nodes, buffer_state.text, new_text_buffer)
        nodes = maybe_wrap_nodes_after_break(nodes, pending_break_flag)
        nodes = maybe_trim_auto_closed_code_blocks(nodes, delimiter, chunk)

        {normalized_buffer, pending_from_buffer?} = normalize_fragment_buffer(new_text_buffer)

        document =
          if pending_from_buffer? do
            Document.put_private(document, :mdex_pending_break, true)
          else
            document
          end

        # |> dbg

        document =
          if nodes == [] do
            document
          else
            last = Enum.at(document.nodes, -1)

            %{
              document
              | nodes: append(document.nodes, last, nodes, delimiter)
            }
          end

        document = maybe_update_fenced_state(document)
        document = maybe_store_table_acc(document, chunk)

        document =
          document
          |> maybe_store_link_acc(chunk, delimiter)
          |> maybe_store_emphasis_acc(chunk, delimiter)
          |> Document.put_private(:mdex_fragment_buffer, %{prefix: delimiter, text: normalized_buffer})
          |> maybe_reparse_with_source(original_chunk)

        maybe_store_list_acc(document, chunk)
    end
  end

  def append(%Document{} = document, chunk) when is_struct(chunk) do
    last = Enum.at(document.nodes, -1)
    %{document | nodes: append(document.nodes, last, [chunk], "")}
  end

  def append([] = _nodes, _last, [new_node | _] = new_nodes, _delimiter) do
    case block?(new_node) do
      true -> new_nodes
      false -> [%Paragraph{nodes: new_nodes}]
    end
  end

  def append(nodes, %CodeBlock{} = last, [%Text{literal: literal}], _delimiter) do
    replace_last(nodes, %{last | literal: last.literal <> literal})
  end

  def append(nodes, last, [new_node | _] = new_nodes, delimiter) do
    # dbg(binding())

    case {delimiter, block?(last), can_contain?(last, new_node)} do
      {_, true, true} ->
        trimmed_new_nodes = maybe_trim_leading_for_empty_container(last, new_nodes)
        updated_new_nodes = normalize_new_nodes_for_container(trimmed_new_nodes, last)

        merged_children =
          case {last, updated_new_nodes} do
            {%MDEx.List{nodes: existing}, [%MDEx.List{nodes: incoming} | _]} ->
              existing ++ incoming

            _ ->
              merge_inline_children(last.nodes ++ updated_new_nodes)
          end

        merged_children = maybe_compact_blockquote_children(last, merged_children)

        replace_last(nodes, %{last | nodes: merged_children})

      {_, false, true} ->
        replace_last(nodes, %{last | literal: last.literal <> new_node.literal})

      {_, true, false} ->
        if inline_nodes?(new_nodes) do
          nodes ++ [%Paragraph{nodes: Enum.map(new_nodes, &normalize_inline/1)}]
        else
          nodes ++ new_nodes
        end

      _ ->
        nodes ++ new_nodes
    end
  end

  def append(%Document{} = document, nodes, opts \\ []) when is_list(nodes) do
    prefix = opts[:prefix] || ""
    nodes = apply_fragment_whitespace(document, nodes, prefix)
    delimiter = Document.get_private(document, :mdex_fragment_delimiter, "")
    Enum.reduce(nodes, document, fn node, acc -> append_node(acc, node, delimiter) end)
  end

  def default_buffer_text(buffer) when is_binary(buffer), do: trailing_whitespace(buffer)
  def default_buffer_text(_), do: ""

  def build_fragment_prefix(buffer_text, starts_with_hard_line_break, leading_ws) do
    buffer_text
    |> remove_hard_line_break_prefix(starts_with_hard_line_break)
    |> Kernel.<>(leading_ws)
  end

  def prepend_text_prefix(nodes, ""), do: nodes
  def prepend_text_prefix(nil, prefix) when prefix == "", do: nil
  def prepend_text_prefix(nil, prefix), do: [%Text{literal: prefix}]
  def prepend_text_prefix([], ""), do: []
  def prepend_text_prefix([], prefix), do: [%Text{literal: prefix}]

  def prepend_text_prefix(nodes, prefix) when is_list(nodes) do
    if skip_prefix_for_nodes?(nodes, prefix) do
      nodes
    else
      {updated_nodes, remaining} = do_prepend_text_prefix(nodes, prefix)

      cond do
        remaining == "" ->
          updated_nodes

        true ->
          [%Text{literal: remaining} | updated_nodes]
      end
    end
  end

  defp normalize_buffer_state(%{prefix: prefix, text: text}) when is_binary(prefix) and is_binary(text) do
    %{prefix: prefix, text: text}
  end

  defp normalize_buffer_state(buffer) when is_binary(buffer) do
    %{prefix: "", text: buffer}
  end

  defp normalize_buffer_state(_), do: %{prefix: "", text: ""}

  defp consume_escape_accumulator(document, chunk, %{text: text} = buffer_state) do
    case Document.get_private(document, :mdex_escape_acc) do
      nil ->
        literal = text <> chunk

        if escaped_literal?(literal) do
          updated_document = append_literal_text(document, unescape_literal(literal))

          {
            updated_document,
            "",
            %{buffer_state | prefix: "", text: ""},
            true
          }
        else
          {document, chunk, buffer_state, false}
        end

      %{index: index, chunk: acc_chunk} = acc ->
        combined = acc_chunk <> chunk
        document = Document.delete_private(document, :mdex_escape_acc)

        case MDEx.parse_document(combined, document.options) do
          {:ok, %Document{nodes: parsed_nodes}} ->
            updated_nodes = replace_nodes_at(document.nodes, index, parsed_nodes)

            {
              %{document | nodes: updated_nodes},
              "",
              %{buffer_state | prefix: "", text: ""},
              true
            }

          _ ->
            updated_acc = %{acc | chunk: combined}

            {
              Document.put_private(document, :mdex_escape_acc, updated_acc),
              "",
              %{buffer_state | prefix: "", text: ""},
              true
            }
        end
    end
  end

  defp consume_link_accumulator(document, chunk, %{text: text} = buffer_state) do
    case Document.get_private(document, :mdex_link_acc) do
      nil ->
        {document, chunk, buffer_state, false}

      %{index: index, chunk: acc_chunk} = acc ->
        combined = acc_chunk <> text <> chunk

        if complete_link?(combined) do
          document = Document.delete_private(document, :mdex_link_acc)

          case MDEx.parse_document(combined, document.options) do
            {:ok, %Document{nodes: parsed_nodes}} ->
              {
                replace_link_nodes(document, index, acc_chunk, parsed_nodes),
                "",
                %{buffer_state | prefix: "", text: ""},
                true
              }

            _ ->
              {
                Document.put_private(document, :mdex_link_acc, %{acc | chunk: combined}),
                "",
                %{buffer_state | prefix: "", text: ""},
                true
              }
          end
        else
          updated_acc = %{acc | chunk: combined}

          updated_document =
            case MDEx.parse_document(combined <> ")", document.options) do
              {:ok, %Document{nodes: parsed_nodes}} ->
                replace_link_nodes(document, index, acc_chunk, parsed_nodes)

              _ ->
                document
            end

          {
            Document.put_private(updated_document, :mdex_link_acc, updated_acc),
            "",
            %{buffer_state | prefix: "", text: ""},
            true
          }
        end
    end
  end

  defp consume_fenced_code_block(document, chunk, %{text: text} = buffer_state) do
    case Document.get_private(document, :mdex_fenced_block) do
      %{index: index} ->
        case Enum.at(document.nodes, index) do
          %CodeBlock{fenced: true} = block ->
            payload = text <> chunk

            case split_fenced_payload(payload, block) do
              {:noop, _} ->
                {document, chunk, buffer_state, false}

              {:append, body, remainder} ->
                updated_document = append_to_fenced_code_block(document, block, body)
                new_buffer = %{buffer_state | text: ""}
                consumed_all? = remainder == ""
                {updated_document, remainder, new_buffer, consumed_all?}

              {:close, body, remainder} ->
                body_for_append = adjust_closing_body(body, chunk, block, remainder)

                updated_document =
                  append_to_fenced_code_block(document, block, body_for_append)
                  |> Document.delete_private(:mdex_fenced_block)
                  |> Document.put_private(:mdex_recent_closed_fence, index)

                new_buffer = %{buffer_state | text: ""}
                consumed_all? = remainder == ""
                {updated_document, remainder, new_buffer, consumed_all?}
            end

          _ ->
            {
              Document.delete_private(document, :mdex_fenced_block),
              chunk,
              buffer_state,
              false
            }
        end

      _ ->
        {document, chunk, buffer_state, false}
    end
  end

  defp consume_emphasis_accumulator(document, chunk, buffer_state) do
    case Document.get_private(document, :mdex_emphasis_acc) do
      nil ->
        {document, chunk, buffer_state, false}

      %{chunk: acc_chunk, index: index} = acc ->
        combined = acc_chunk <> chunk

        document = Document.delete_private(document, :mdex_emphasis_acc)

        case MDEx.parse_document(combined, document.options) do
          {:ok, %Document{nodes: parsed_nodes}} ->
            target_index = emphasis_replacement_index(document.nodes, acc_chunk, index)
            updated_nodes = replace_nodes_at(document.nodes, target_index, parsed_nodes)
            updated_document = %{document | nodes: updated_nodes}
            updated_document = store_emphasis_acc(updated_document, combined, parsed_nodes)

            {
              updated_document,
              "",
              %{buffer_state | prefix: "", text: ""},
              true
            }

          _ ->
            {
              Document.put_private(document, :mdex_emphasis_acc, acc),
              chunk,
              buffer_state,
              false
            }
        end
    end
  end

  defp consume_blank_line_chunk(document, chunk, %{text: _text} = buffer_state) do
    if blank_line_chunk?(chunk) do
      new_buffer = %{buffer_state | text: "", prefix: ""}
      updated_document = Document.put_private(document, :mdex_pending_break, true)
      {updated_document, "", new_buffer, true}
    else
      {document, chunk, buffer_state, false}
    end
  end

  defp consume_table_acc(document, chunk, buffer_state) do
    case Document.get_private(document, :mdex_table_acc) do
      nil ->
        {document, chunk, buffer_state, false}

      %{index: index, chunk: acc_chunk} = acc ->
        combined = acc_chunk <> chunk
        document = Document.delete_private(document, :mdex_table_acc)

        case MDEx.parse_document(combined, document.options) do
          {:ok, %Document{nodes: parsed_nodes}} ->
            if contains_table_node?(parsed_nodes) do
              updated_nodes = replace_nodes_at(document.nodes, index, parsed_nodes)

              updated_document =
                %{document | nodes: updated_nodes}
                |> Document.put_private(:mdex_table_acc, %{index: index, chunk: combined})

              {updated_document, "", %{buffer_state | prefix: "", text: ""}, true}
            else
              document = Document.put_private(document, :mdex_table_acc, acc)
              {document, chunk, buffer_state, false}
            end

          _ ->
            document = Document.put_private(document, :mdex_table_acc, acc)
            {document, chunk, buffer_state, false}
        end
    end
  end

  defp consume_list_continuation(document, chunk, %{text: text} = buffer_state) do
    case {Document.get_private(document, :mdex_list_acc), list_append_context(document)} do
      {%{index: index, chunk: acc_chunk, trailing: trailing}, {:ok, _info}} ->
        whitespace = if trailing == "", do: text, else: trailing
        combined = acc_chunk <> whitespace <> chunk
        document = Document.delete_private(document, :mdex_list_acc)

        case MDEx.parse_document(combined, document.options) do
          {:ok, %Document{nodes: parsed_nodes}} ->
            adjusted_nodes =
              preserve_rightmost_text_segments(parsed_nodes, Enum.at(document.nodes, index))

            updated_nodes =
              case Enum.split(document.nodes, index) do
                {left, [_old | _right]} -> left ++ adjusted_nodes
                _ -> replace_nodes_at(document.nodes, index, adjusted_nodes)
              end

            new_trimmed = String.trim_trailing(combined)
            trimmed_size = byte_size(new_trimmed)
            combined_size = byte_size(combined)

            new_trailing =
              if trimmed_size == combined_size do
                ""
              else
                :binary.part(combined, trimmed_size, combined_size - trimmed_size)
              end

            updated_document =
              %{document | nodes: updated_nodes}
              |> Document.put_private(:mdex_list_acc, %{index: index, chunk: new_trimmed, trailing: new_trailing})

            {updated_document, "", %{buffer_state | text: ""}, true}

          _ ->
            new_trimmed = String.trim_trailing(combined)
            trimmed_size = byte_size(new_trimmed)
            combined_size = byte_size(combined)

            new_trailing =
              if trimmed_size == combined_size do
                ""
              else
                :binary.part(combined, trimmed_size, combined_size - trimmed_size)
              end

            updated_document =
              Document.put_private(document, :mdex_list_acc, %{
                index: index,
                chunk: new_trimmed,
                trailing: new_trailing
              })

            {updated_document, "", %{buffer_state | text: ""}, true}
        end

      _ ->
        {document, chunk, buffer_state, false}
    end
  end

  defp consume_open_inline_code(document, chunk, %{prefix: prefix} = buffer_state) do
    case inline_code_backticks(prefix) do
      nil ->
        {document, chunk, buffer_state, false}

      backticks ->
        {document, buffer_state} =
          if buffer_state.text != "" do
            {append_to_inline_code(document, buffer_state.text), %{buffer_state | text: ""}}
          else
            {document, buffer_state}
          end

        closing = String.duplicate("`", backticks)

        case chunk do
          "" ->
            {document, chunk, buffer_state, true}

          _ ->
            case String.split(chunk, closing, parts: 2) do
              [before] ->
                updated_document = append_to_inline_code(document, before)
                {updated_document, "", %{buffer_state | text: ""}, true}

              [before, remainder] ->
                updated_document = append_to_inline_code(document, before)
                updated_buffer = %{buffer_state | prefix: "", text: ""}

                cond do
                  remainder == "" ->
                    {updated_document, "", updated_buffer, true}

                  blank_line_chunk?(remainder) ->
                    updated_document = Document.put_private(updated_document, :mdex_pending_break, true)
                    {updated_document, "", updated_buffer, true}

                  true ->
                    {updated_document, remainder, updated_buffer, false}
                end
            end
        end
    end
  end

  defp inline_code_backticks(prefix) when is_binary(prefix) and prefix != "" do
    if String.match?(prefix, ~r/^`+$/) do
      String.length(prefix)
    else
      nil
    end
  end

  defp inline_code_backticks(_), do: nil

  defp append_to_inline_code(document, text) do
    if text == "" do
      document
    else
      update_rightmost_code(document, fn %Code{literal: literal} = code ->
        %{code | literal: literal <> text}
      end)
    end
  end

  defp update_rightmost_code(document, fun) do
    case find_rightmost_node(document.nodes) do
      %Code{} = code ->
        %{document | nodes: replace_rightmost(document.nodes, fun.(code))}

      _ ->
        document
    end
  end

  defp rightmost_text_literal(nodes) do
    case find_rightmost_node(nodes) do
      %Text{literal: literal} -> literal
      _ -> nil
    end
  end

  defp append_literal_text(document, literal) do
    new_nodes = [%Text{literal: literal}]
    last = List.last(document.nodes)
    updated_nodes = append(document.nodes, last, new_nodes, "")
    %{document | nodes: updated_nodes}
  end

  defp preserve_rightmost_text_segments(parsed_nodes, nil), do: parsed_nodes

  defp preserve_rightmost_text_segments(parsed_nodes, old_node) do
    merge_segment_lists(parsed_nodes, [old_node])
  end

  defp merge_segment_lists(new_list, old_list) when is_list(new_list) and is_list(old_list) do
    old_list
    |> Enum.with_index()
    |> Enum.reverse()
    |> Enum.reduce(new_list, fn {old_node, idx}, acc ->
      case Enum.split(acc, idx) do
        {before, [new_node | tail]} ->
          replacements = merge_segment_node(new_node, old_node)
          before ++ replacements ++ tail

        _ ->
          acc
      end
    end)
  end

  defp merge_segment_node(%{__struct__: struct} = new_node, %{__struct__: struct, nodes: old_children})
       when is_list(old_children) do
    if Map.has_key?(new_node, :nodes) do
      new_children = Map.get(new_node, :nodes, [])
      updated_children = merge_segment_lists(new_children, old_children)
      [%{new_node | nodes: updated_children}]
    else
      [new_node]
    end
  end

  defp merge_segment_node(%Text{literal: new_literal} = new_text, %Text{literal: old_literal}) do
    cond do
      old_literal == "" ->
        [new_text]

      new_literal == old_literal ->
        [struct(new_text, literal: new_literal)]

      String.starts_with?(new_literal, old_literal) ->
        old_size = byte_size(old_literal)
        remainder_size = byte_size(new_literal) - old_size

        cond do
          remainder_size <= 0 ->
            [struct(new_text, literal: old_literal)]

          true ->
            remainder = :binary.part(new_literal, old_size, remainder_size)
            prefix_node = struct(new_text, literal: old_literal)

            case remainder do
              "" -> [prefix_node]
              _ -> [prefix_node, struct(new_text, literal: remainder)]
            end
        end

      true ->
        [new_text]
    end
  end

  defp merge_segment_node(new_node, _old_node), do: [new_node]

  defp append_trailing_ws_to_placeholder_link(document, ws) do
    case Enum.split(document.nodes, -1) do
      {prefix, [%Paragraph{} = paragraph]} ->
        updated_paragraph = %{paragraph | nodes: append_ws_to_link_nodes(paragraph.nodes, ws)}
        %{document | nodes: prefix ++ [updated_paragraph]}

      _ ->
        document
    end
  end

  defp append_ws_to_link_nodes(nodes, ws) do
    case Enum.split(nodes, -1) do
      {prefix, [%Link{} = link]} ->
        updated_link = %{link | nodes: append_ws_to_link_text(link.nodes, ws)}
        prefix ++ [updated_link]

      {prefix, [%Text{} = text]} ->
        prefix ++ [%{text | literal: text.literal <> ws}]

      _ ->
        nodes ++ [%Text{literal: ws}]
    end
  end

  defp append_ws_to_link_text(nodes, ws) do
    case Enum.split(nodes, -1) do
      {prefix, [%Text{} = text]} ->
        prefix ++ [%{text | literal: text.literal <> ws}]

      _ ->
        nodes ++ [%Text{literal: ws}]
    end
  end

  defp maybe_store_link_acc(document, chunk, delimiter) do
    if link_placeholder_delimiter?(delimiter) do
      existing = Document.get_private(document, :mdex_link_acc)

      trimmed_chunk = String.trim_trailing(chunk)
      trailing_ws_len = byte_size(chunk) - byte_size(trimmed_chunk)
      trailing_ws = if trailing_ws_len > 0, do: :binary.part(chunk, byte_size(chunk) - trailing_ws_len, trailing_ws_len), else: ""

      document =
        if existing == nil and trailing_ws != "" do
          append_trailing_ws_to_placeholder_link(document, trailing_ws)
        else
          document
        end

      combined_chunk =
        case existing do
          %{chunk: stored} -> stored <> trimmed_chunk
          _ -> trimmed_chunk
        end

      index =
        case existing do
          %{index: idx} -> idx
          _ -> max(length(document.nodes) - 1, 0)
        end

      Document.put_private(document, :mdex_link_acc, %{chunk: combined_chunk, index: index})
    else
      document
    end
  end

  defp maybe_store_emphasis_acc(document, chunk, delimiter) do
    if emphasis_delimiter?(delimiter) do
      if list_context?(document) do
        Document.delete_private(document, :mdex_emphasis_acc)
      else
        existing = Document.get_private(document, :mdex_emphasis_acc)

        combined_chunk =
          case existing do
            %{chunk: stored} -> stored <> chunk
            _ -> chunk
          end

        index =
          case existing do
            %{index: idx} -> idx
            _ -> max(length(document.nodes) - 1, 0)
          end

        Document.put_private(document, :mdex_emphasis_acc, %{chunk: combined_chunk, index: index})
      end
    else
      Document.delete_private(document, :mdex_emphasis_acc)
    end
  end

  defp store_emphasis_acc(document, chunk, parsed_nodes) do
    literal = rightmost_text_literal(parsed_nodes)

    needs_acc? =
      case literal do
        nil ->
          false

        lit ->
          case MDEx.FragmentParser.complete(lit) do
            {_completed, delimiter, _} -> emphasis_delimiter?(delimiter)
            _ -> false
          end
      end

    if needs_acc? do
      index = max(length(document.nodes) - 1, 0)
      Document.put_private(document, :mdex_emphasis_acc, %{chunk: chunk, index: index})
    else
      Document.delete_private(document, :mdex_emphasis_acc)
    end
  end

  defp list_append_context(%Document{nodes: []}), do: :error

  defp list_append_context(%Document{nodes: nodes}) do
    case Enum.split(nodes, -1) do
      {prefix, [%MDEx.List{} = list]} ->
        case list.nodes do
          [] -> :error
          _ -> {:ok, %{prefix: prefix, list: list}}
        end

      _ ->
        :error
    end
  end

  defp append_to_fenced_code_block(document, _block, ""), do: document

  defp append_to_fenced_code_block(document, %CodeBlock{} = block, body) do
    {updated_info, body_to_append} = extract_info_line(block, body)

    normalized_body =
      normalize_fenced_body(%{block | info: updated_info}, body_to_append)

    if normalized_body == "" and updated_info == block.info do
      document
    else
      case Enum.split(document.nodes, -1) do
        {prefix, [%CodeBlock{} = last]} ->
          updated_block = %{
            last
            | info: updated_info,
              literal: last.literal <> normalized_body
          }

          %{document | nodes: prefix ++ [updated_block]}

        _ ->
          document
      end
    end
  end

  defp extract_info_line(%CodeBlock{info: info, literal: literal}, body)
       when info == "" and literal == "" do
    case String.split(body, "\n", parts: 2) do
      [line, rest] ->
        {String.trim(line), strip_trailing_newline(rest)}

      [line] ->
        {String.trim(line), ""}
    end
  end

  defp extract_info_line(%CodeBlock{} = block, body), do: {block.info, body}

  defp normalize_fenced_body(%CodeBlock{literal: ""}, ""), do: ""

  defp normalize_fenced_body(%CodeBlock{literal: ""}, body) do
    String.replace_prefix(body, "\n", "")
  end

  defp normalize_fenced_body(_block, body), do: body

  defp split_fenced_payload("", _block), do: {:noop, ""}

  defp split_fenced_payload(payload, %CodeBlock{fence_char: char, fence_length: len} = block) do
    closing = String.duplicate(char, len)

    case :binary.match(payload, closing) do
      :nomatch ->
        {:append, payload, ""}

      {idx, match_len} ->
        if idx == 0 or :binary.at(payload, idx - 1) == ?\n do
          body = :binary.part(payload, 0, idx)

          remainder =
            payload
            |> :binary.part(idx + match_len, byte_size(payload) - idx - match_len)
            |> drop_closing_tail()

          closing_body =
            if body == "\n" and not String.ends_with?(block.literal, "\n") do
              ""
            else
              body
            end

          {:close, closing_body, remainder}
        else
          {:append, payload, ""}
        end
    end
  end

  defp drop_closing_tail(remainder) do
    remainder
    |> drop_leading_spaces()
    |> drop_leading_newline()
  end

  defp emphasis_replacement_index(nodes, chunk, default_index) do
    case Enum.find_index(nodes, &node_contains_chunk?(&1, chunk)) do
      nil -> default_index
      idx -> idx
    end
  end

  defp replace_link_nodes(document, index, chunk, parsed_nodes) do
    current_node = Enum.at(document.nodes, index)

    case {current_node, parsed_nodes} do
      {%Paragraph{nodes: paragraph_nodes} = paragraph, [%Paragraph{nodes: new_inlines}]} ->
        inner_index = Enum.find_index(paragraph_nodes, &node_contains_chunk?(&1, chunk))

        if inner_index do
          updated_paragraph_nodes = replace_nodes_at(paragraph_nodes, inner_index, new_inlines)
          updated_paragraph = %{paragraph | nodes: updated_paragraph_nodes}
          %{document | nodes: replace_nodes_at(document.nodes, index, [updated_paragraph])}
        else
          %{document | nodes: replace_nodes_at(document.nodes, index, parsed_nodes)}
        end

      _ ->
        %{document | nodes: replace_nodes_at(document.nodes, index, parsed_nodes)}
    end
  end

  defp node_contains_chunk?(%Paragraph{nodes: nodes}, chunk),
    do: Enum.any?(nodes, &node_contains_chunk?(&1, chunk))

  defp node_contains_chunk?(%Text{literal: literal}, chunk),
    do: String.ends_with?(literal, chunk)

  defp node_contains_chunk?(%Code{literal: literal}, chunk),
    do: String.ends_with?(literal, chunk)

  defp node_contains_chunk?(_, _), do: false

  defp maybe_trim_auto_closed_code_blocks(nodes, delimiter, chunk)
       when is_list(nodes) and nodes != [] do
    if auto_closed_delimiter?(delimiter) and not chunk_ends_with_newline?(chunk) do
      Enum.map(nodes, &trim_code_block_literal/1)
    else
      nodes
    end
  end

  defp maybe_trim_auto_closed_code_blocks(nodes, _delimiter, _chunk), do: nodes

  defp trim_code_block_literal(%CodeBlock{fenced: true, literal: literal} = block) do
    updated_literal =
      if ends_with_newline?(literal) do
        trim_trailing_newline(literal)
      else
        literal
      end

    %{block | literal: updated_literal}
  end

  defp trim_code_block_literal(node), do: node

  defp auto_closed_delimiter?(<<"\n"::utf8, rest::binary>>) do
    trimmed = drop_leading_spaces(rest)
    fence_run?(trimmed)
  end

  defp auto_closed_delimiter?(_), do: false

  defp fence_run?(<<>>), do: false

  defp fence_run?(<<char, rest::binary>>) when char in [?`, ?~] do
    fence_run?(rest, char, 1)
  end

  defp fence_run?(_), do: false

  defp fence_run?(<<>>, _char, count), do: count >= 3

  defp fence_run?(<<char, rest::binary>>, char, count), do: fence_run?(rest, char, count + 1)

  defp fence_run?(_other, _char, _count), do: false

  defp adjust_closing_body(body, chunk, %CodeBlock{} = block, remainder) do
    cond do
      body == "" ->
        ""

      remainder != "" ->
        body

      chunk_ends_with_newline?(chunk) ->
        body

      not ends_with_newline?(body) ->
        body

      ends_with_newline?(block.literal) ->
        body

      true ->
        trim_trailing_newline(body)
    end
  end

  defp chunk_ends_with_newline?(chunk) do
    String.ends_with?(chunk, "\n") or String.ends_with?(chunk, "\r\n")
  end

  defp ends_with_newline?(binary) do
    String.ends_with?(binary, "\r\n") or String.ends_with?(binary, "\n")
  end

  defp trim_trailing_newline(binary) do
    cond do
      String.ends_with?(binary, "\r\n") ->
        :binary.part(binary, 0, byte_size(binary) - 2)

      String.ends_with?(binary, "\n") ->
        :binary.part(binary, 0, byte_size(binary) - 1)

      true ->
        binary
    end
  end

  defp drop_leading_spaces(<<char, rest::binary>>) when char in [?\t, 0x20],
    do: drop_leading_spaces(rest)

  defp drop_leading_spaces(binary), do: binary

  defp drop_leading_newline(<<?\r, ?\n, rest::binary>>), do: rest
  defp drop_leading_newline(<<?\n, rest::binary>>), do: rest
  defp drop_leading_newline(binary), do: binary

  defp strip_trailing_newline(rest) do
    cond do
      String.ends_with?(rest, "\r\n") -> String.slice(rest, 0, byte_size(rest) - 2)
      String.ends_with?(rest, "\n") -> String.slice(rest, 0, byte_size(rest) - 1)
      true -> rest
    end
  end

  defp maybe_trim_leading_for_empty_container(%Heading{nodes: []}, new_nodes) do
    trim_leading_in_nodes(new_nodes)
  end

  defp maybe_trim_leading_for_empty_container(_last, new_nodes), do: new_nodes

  defp normalize_new_nodes_for_container(nodes, %BlockQuote{}), do: strip_blockquote_layer(nodes)
  defp normalize_new_nodes_for_container(nodes, %MultilineBlockQuote{}), do: strip_blockquote_layer(nodes)
  defp normalize_new_nodes_for_container(nodes, _last), do: nodes

  defp strip_blockquote_layer(nodes) when is_list(nodes) do
    Enum.flat_map(nodes, fn
      %BlockQuote{nodes: []} -> []
      %BlockQuote{nodes: children} -> children
      %MultilineBlockQuote{nodes: []} -> []
      %MultilineBlockQuote{nodes: children} -> children
      node -> [node]
    end)
  end

  defp maybe_compact_blockquote_children(%BlockQuote{}, children), do: compact_blockquote_children(children)
  defp maybe_compact_blockquote_children(%MultilineBlockQuote{}, children), do: compact_blockquote_children(children)
  defp maybe_compact_blockquote_children(_last, children), do: children

  defp compact_blockquote_children(children) when is_list(children) do
    children
    |> Enum.reduce([], fn child, acc ->
      case compact_blockquote_child(child) do
        nil -> acc
        updated -> acc ++ [updated]
      end
    end)
  end

  defp compact_blockquote_children(children), do: children

  defp compact_blockquote_child(%BlockQuote{nodes: nodes} = quote) do
    updated_nodes = compact_blockquote_children(nodes)

    if updated_nodes == [] do
      nil
    else
      %{quote | nodes: updated_nodes}
    end
  end

  defp compact_blockquote_child(%MultilineBlockQuote{nodes: nodes} = quote) do
    updated_nodes = compact_blockquote_children(nodes)

    if updated_nodes == [] do
      nil
    else
      %{quote | nodes: updated_nodes}
    end
  end

  defp compact_blockquote_child(node), do: node

  defp merge_inline_children(children) do
    children
    |> Enum.reduce([], &merge_inline_child/2)
    |> Enum.reverse()
  end

  defp merge_inline_child(child, []), do: [child]

  defp merge_inline_child(child, [last | rest] = acc) do
    cond do
      inline_wrapper_mergeable?(last, child) ->
        merged = merge_wrappers(last, child)
        [merged | rest]

      inline_code_mergeable?(last, child) ->
        merged = merge_code_literals(last, child)
        [merged | rest]

      true ->
        [child | acc]
    end
  end

  defp inline_wrapper_mergeable?(%Emph{}, %Emph{}), do: true
  defp inline_wrapper_mergeable?(%Strong{}, %Strong{}), do: true
  defp inline_wrapper_mergeable?(%Strikethrough{}, %Strikethrough{}), do: true
  defp inline_wrapper_mergeable?(_, _), do: false

  defp merge_wrappers(left, right) do
    Enum.reduce(right.nodes, left, fn child, acc -> append_child(acc, child) end)
  end

  defp inline_code_mergeable?(%Code{num_backticks: nb}, %Code{num_backticks: nb2}), do: nb == nb2
  defp inline_code_mergeable?(_, _), do: false

  defp merge_code_literals(%Code{literal: a} = left, %Code{literal: b}), do: %{left | literal: a <> b}

  defp skip_prefix_for_nodes?(_nodes, ""), do: false
  defp skip_prefix_for_nodes?([], _prefix), do: false

  defp skip_prefix_for_nodes?(nodes, prefix) do
    contains_line_break?(prefix) and block?(List.first(nodes))
  end

  defp contains_line_break?(prefix), do: String.contains?(prefix, "\n")

  defp do_prepend_text_prefix([], prefix), do: {[], prefix}

  defp do_prepend_text_prefix([node | rest], prefix) do
    {updated_node, remaining} = prepend_text_prefix_to_node(node, prefix)
    {updated_rest, final_remaining} = do_prepend_text_prefix(rest, remaining)
    {[updated_node | updated_rest], final_remaining}
  end

  defp prepend_text_prefix_to_node(node, ""), do: {node, ""}

  defp prepend_text_prefix_to_node(%{literal: literal} = node, prefix) when is_binary(literal) do
    cond do
      prefix == "" ->
        {node, ""}

      String.trim(prefix) == "" and String.starts_with?(literal, prefix) ->
        {node, ""}

      true ->
        {%{node | literal: prefix <> literal}, ""}
    end
  end

  defp prepend_text_prefix_to_node(%{nodes: child_nodes} = node, prefix) do
    {updated_children, remaining} = do_prepend_text_prefix(child_nodes, prefix)
    {%{node | nodes: updated_children}, remaining}
  end

  defp prepend_text_prefix_to_node(node, prefix), do: {node, prefix}

  defp trim_leading_in_nodes(nodes) do
    {updated_nodes, _trimmed?} = do_trim_leading(nodes, false)
    updated_nodes
  end

  defp do_trim_leading([], trimmed), do: {[], trimmed}

  defp do_trim_leading([node | rest], trimmed) do
    {updated_node, trimmed?} = trim_node_leading(node, trimmed)
    {updated_rest, final_trimmed} = do_trim_leading(rest, trimmed? || trimmed)
    {[updated_node | updated_rest], final_trimmed}
  end

  defp trim_node_leading(node, true), do: {node, true}

  defp trim_node_leading(%{literal: literal} = node, false) when is_binary(literal) do
    trimmed_literal = String.trim_leading(literal)
    {%{node | literal: trimmed_literal}, trimmed_literal != literal}
  end

  defp trim_node_leading(%{nodes: child_nodes} = node, trimmed) do
    {updated_children, trimmed?} = do_trim_leading(child_nodes, trimmed)
    {%{node | nodes: updated_children}, trimmed? || trimmed}
  end

  defp trim_node_leading(node, trimmed), do: {node, trimmed}

  # defp apply_fragment_whitespace(document, %Heading{}, nodes, prefix) do
  #   nodes
  # end

  defp apply_fragment_whitespace(document, nodes, prefix) do
    last = Enum.at(document.nodes, -1)

    case {last, find_rightmost_node(nodes)} do
      {%Heading{}, %{literal: literal} = rightmost_node} ->
        rest =
          document
          |> Document.get_private(:mdex_fragment_rest, "")

        replace_rightmost(nodes, %{rightmost_node | literal: rest <> literal})

      {_, %{literal: literal} = rightmost_node} ->
        rest =
          Document.get_private(document, :mdex_fragment_rest, "")

        case {rest, prefix} do
          {"\n\n", _prefix} ->
            [%Paragraph{nodes: nodes}]

          {rest, prefix} ->
            replace_rightmost(nodes, %{rightmost_node | literal: rest <> prefix <> literal})
        end

      _ ->
        nodes
    end
  end

  defp append_node(%Document{nodes: []} = doc, node, _delimiter) do
    cond do
      list_item?(node) -> %{doc | nodes: [list_from_item(node)]}
      block?(node) -> %{doc | nodes: [node]}
      true -> %{doc | nodes: [%Paragraph{nodes: [normalize_inline(node)]}]}
    end
  end

  defp append_node(%Document{nodes: nodes} = doc, node, _delimiter) do
    last = List.last(nodes)
    rightmost = find_rightmost_node(nodes)

    case {last, rightmost, node} do
      {
        %CodeBlock{fenced: f, fence_char: ch, fence_length: len, fence_offset: off, info: info, literal: a} = code_block,
        _,
        %CodeBlock{fenced: f, fence_char: ch, fence_length: len, fence_offset: off, info: info, literal: b}
      } ->
        %{doc | nodes: replace_last(nodes, %{code_block | literal: merge_codeblock_literals(a, b)})}

      {
        %CodeBlock{info: a, literal: ""} = code_block,
        _,
        %Text{literal: b}
      } ->
        %{doc | nodes: replace_last(nodes, %{code_block | info: a <> b})}

      {_, %Code{literal: a} = code, %Text{literal: b}} ->
        %{doc | nodes: replace_rightmost(nodes, %{code | literal: a <> b})}

      {_, %Code{literal: a} = code, %Code{literal: b}} ->
        %{doc | nodes: replace_rightmost(nodes, %{code | literal: a <> b})}

      {
        %MDEx.Paragraph{nodes: paragraph_nodes},
        _,
        %MDEx.Text{literal: b} = new_node
      } ->
        case List.last(paragraph_nodes) do
          %Strong{} ->
            paragraph = %Paragraph{nodes: paragraph_nodes ++ [new_node]}
            %{doc | nodes: replace_last(nodes, paragraph)}

          %{literal: a} = node ->
            %{doc | nodes: replace_rightmost(nodes, %{node | literal: a <> b})}
        end

      {_, %Text{literal: a} = code, %Text{literal: b}} ->
        %{doc | nodes: replace_rightmost(nodes, %{code | literal: a <> b})}

      {last, rightmost, child} ->
        cond do
          can_contain?(rightmost, child) ->
            %{doc | nodes: replace_rightmost(nodes, child)}

          can_contain?(last, child) ->
            %{doc | nodes: replace_last(nodes, append_child(last, child))}

          match?(%MDEx.List{}, last) and not block?(child) ->
            %MDEx.List{nodes: items} = last
            last_item = :lists.last(items)
            updated_item = append_child(last_item, child)
            updated_list = %{last | nodes: replace_last(items, updated_item)}
            %{doc | nodes: replace_last(nodes, updated_list)}

          list_item?(child) ->
            %{doc | nodes: nodes ++ [list_from_item(child)]}

          block?(child) ->
            %{doc | nodes: nodes ++ [child]}

          true ->
            %{doc | nodes: nodes ++ [%Paragraph{nodes: [normalize_inline(child)]}]}
        end
    end
  end

  defp find_rightmost_node([]), do: nil

  defp find_rightmost_node(nodes) do
    nodes
    |> List.last()
    |> get_rightmost_from_node()
  end

  defp get_rightmost_from_node(%{nodes: []}), do: nil
  defp get_rightmost_from_node(%{nodes: nodes}), do: find_rightmost_node(nodes)
  defp get_rightmost_from_node(node), do: node

  defp append_child(%{nodes: nodes} = parent, child) do
    child = normalize_inline(child)

    case nodes do
      [] ->
        %{parent | nodes: [child]}

      _ ->
        last = :lists.last(nodes)

        case {last, child} do
          {%Text{literal: a}, %Text{literal: b}} ->
            %{parent | nodes: replace_last(nodes, %Text{literal: a <> b})}

          {%Code{num_backticks: nb, literal: a}, %Code{num_backticks: nb2, literal: b}} ->
            %{parent | nodes: replace_last(nodes, %Code{num_backticks: max(nb, nb2), literal: a <> b})}

          _ ->
            %{parent | nodes: nodes ++ [child]}
        end
    end
  end

  defp replace_last([_], new), do: [new]
  defp replace_last([h | t], new), do: [h | replace_last(t, new)]

  defp replace_rightmost(nodes, new_node) do
    replace_rightmost_recursive(nodes, new_node)
  end

  defp replace_rightmost_recursive([], _), do: []

  defp replace_rightmost_recursive([node], new_node) do
    case get_rightmost_from_node(node) do
      ^node -> [new_node]
      _ -> [replace_node_rightmost(node, new_node)]
    end
  end

  defp replace_rightmost_recursive([h | t], new_node) do
    [h | replace_rightmost_recursive(t, new_node)]
  end

  defp replace_node_rightmost(%{nodes: nodes} = parent, new_node) do
    %{parent | nodes: replace_rightmost_recursive(nodes, new_node)}
  end

  defp replace_node_rightmost(node, new_node) do
    case get_rightmost_from_node(node) do
      ^node -> new_node
      _ -> node
    end
  end

  defp replace_nodes_at(nodes, index, replacements) do
    case Enum.split(nodes, index) do
      {left, [_old | right]} ->
        left ++ replacements ++ right

      _ ->
        nodes
    end
  end

  defp maybe_update_fenced_state(document) do
    recent_closed = Document.get_private(document, :mdex_recent_closed_fence)

    case List.last(document.nodes) do
      %CodeBlock{fenced: true, fence_char: char, fence_length: len} ->
        index = length(document.nodes) - 1

        cond do
          not is_nil(recent_closed) and recent_closed == index ->
            document
            |> Document.delete_private(:mdex_recent_closed_fence)
            |> Document.delete_private(:mdex_fenced_block)

          true ->
            document
            |> Document.delete_private(:mdex_recent_closed_fence)
            |> Document.put_private(:mdex_fenced_block, %{
              index: index,
              fence_char: char,
              fence_length: len
            })
        end

      _ ->
        document
        |> Document.delete_private(:mdex_recent_closed_fence)
        |> Document.delete_private(:mdex_fenced_block)
    end
  end

  defp escaped_literal?(literal) do
    String.contains?(literal, "\\") and Regex.match?(~r/\\([*_`\\])/u, literal)
  end

  defp unescape_literal(literal) do
    String.replace(literal, ~r/\\([*_`\\])/u, "\\1")
  end

  defp link_placeholder_delimiter?(delimiter) do
    delimiter in ["](mdex:incomplete-link)", "(mdex:incomplete-link)"]
  end

  defp complete_link?(string) do
    Regex.match?(~r/\[[^\]]+\]\([^\)]+\)/, string)
  end

  defp list_context?(%Document{nodes: []}), do: false

  defp list_context?(%Document{nodes: nodes}) do
    case List.last(nodes) do
      %MDEx.List{} -> true
      _ -> false
    end
  end

  defp maybe_store_list_acc(document, chunk) do
    trimmed = String.trim_trailing(chunk)
    trailing = String.slice(chunk, byte_size(trimmed), byte_size(chunk) - byte_size(trimmed)) || ""

    if starts_with_list_marker?(String.trim_leading(chunk)) do
      index =
        case list_append_context(document) do
          {:ok, %{prefix: prefix}} -> length(prefix)
          _ -> max(length(document.nodes) - 1, 0)
        end

      Document.put_private(document, :mdex_list_acc, %{index: index, chunk: trimmed, trailing: trailing})
    else
      document
    end
  end

  defp maybe_store_table_acc(document, chunk) do
    cond do
      not table_extension_enabled?(document) ->
        document

      Document.get_private(document, :mdex_table_acc) != nil ->
        document

      document.nodes == [] ->
        document

      not table_chunk_candidate?(chunk) ->
        document

      true ->
        index = max(length(document.nodes) - 1, 0)
        Document.put_private(document, :mdex_table_acc, %{index: index, chunk: chunk})
    end
  end

  defp table_extension_enabled?(%Document{options: options}) do
    options
    |> Keyword.get(:extension, [])
    |> Keyword.get(:table, false)
  end

  defp table_extension_enabled?(_), do: false

  defp table_chunk_candidate?(chunk) when is_binary(chunk) do
    trimmed = String.trim_leading(chunk)

    cond do
      trimmed == "" -> false
      String.starts_with?(trimmed, "|") -> true
      String.contains?(chunk, "\n|") -> true
      true -> false
    end
  end

  defp table_chunk_candidate?(_), do: false

  defp contains_table_node?(nodes) when is_list(nodes) do
    Enum.any?(nodes, &table_node?/1)
  end

  defp contains_table_node?(_), do: false

  defp table_node?(%Table{}), do: true
  defp table_node?(_), do: false

  defp blank_line_chunk?(chunk) when is_binary(chunk) do
    chunk != "" and Regex.match?(~r/^[\r\n]+$/, chunk)
  end

  defp blank_line_chunk?(_), do: false

  defp normalize_fragment_buffer(buffer) do
    buffer = buffer || ""

    if blank_line_chunk?(buffer) do
      {"", true}
    else
      {buffer, false}
    end
  end

  defp maybe_strip_buffer_prefix(nodes, buffer_text, new_text_buffer) do
    combined = (buffer_text || "") <> (new_text_buffer || "")

    if blank_line_chunk?(combined) and buffer_text != "" do
      strip_prefix_from_nodes(nodes, buffer_text)
    else
      nodes
    end
  end

  defp strip_prefix_from_nodes(nodes, ""), do: nodes
  defp strip_prefix_from_nodes([], _prefix), do: []

  defp strip_prefix_from_nodes([%{literal: literal} = node | rest], prefix) when is_binary(literal) do
    cond do
      literal == "" ->
        strip_prefix_from_nodes(rest, prefix)

      String.starts_with?(literal, prefix) ->
        updated_literal = String.replace_prefix(literal, prefix, "")

        updated_rest =
          if updated_literal == "" do
            rest
          else
            [%{node | literal: updated_literal} | rest]
          end

        updated_rest

      String.starts_with?(prefix, literal) ->
        remaining_prefix = String.replace_prefix(prefix, literal, "")
        strip_prefix_from_nodes(rest, remaining_prefix)

      true ->
        [node | rest]
    end
  end

  defp strip_prefix_from_nodes(nodes, _prefix), do: nodes

  defp maybe_wrap_nodes_after_break(nil, _), do: nil

  defp maybe_wrap_nodes_after_break(nodes, true) when is_list(nodes) do
    if inline_nodes?(nodes) do
      [%Paragraph{nodes: Enum.map(nodes, &normalize_inline/1)}]
    else
      nodes
    end
  end

  defp maybe_wrap_nodes_after_break(nodes, _), do: nodes

  defp inline_nodes?(nodes) do
    Enum.all?(nodes, fn node -> not block?(node) end)
  end

  defp maybe_reparse_with_source(document, chunk) when is_binary(chunk) do
    if shortcodes_enabled?(document) do
      if Document.get_private(document, :mdex_emphasis_acc) ||
           Document.get_private(document, :mdex_pending_break) ||
           Document.get_private(document, :mdex_list_acc) do
        document
      else
        source = Document.get_private(document, :mdex_stream_source, "")

        if unbalanced_backticks?(source) do
          document
        else
          normalized_source = normalize_shortcodes_source(source)

          case MDEx.parse_document(normalized_source, document.options) do
            {:ok, %Document{nodes: nodes}} ->
              document
              |> Map.put(:nodes, nodes)
              |> reset_streaming_state()

            _ ->
              document
          end
        end
      end
    else
      document
    end
  end

  defp maybe_reparse_with_source(document, _chunk), do: document

  defp shortcodes_enabled?(%Document{options: options}) do
    options
    |> Keyword.get(:extension, [])
    |> Keyword.get(:shortcodes, false)
  end

  defp shortcodes_enabled?(_), do: false

  defp unbalanced_backticks?(source) when is_binary(source) do
    rem(count_char(source, ?`), 2) == 1
  end

  defp unbalanced_backticks?(_), do: false

  defp count_char(binary, char) when is_binary(binary) and is_integer(char) do
    binary
    |> String.to_charlist()
    |> Enum.count(&(&1 == char))
  end

  defp normalize_shortcodes_source(source) when is_binary(source) do
    Regex.replace(~r/:([A-Za-z0-9_+\-]*)(?:\r?\n)+([A-Za-z0-9_+\-]*):/, source, fn _, start, rest ->
      ":" <> start <> rest <> ":"
    end)
  end

  defp normalize_shortcodes_source(_), do: ""

  defp reset_streaming_state(document) do
    document
    |> Document.put_private(:mdex_fragment_buffer, %{prefix: "", text: ""})
    |> Document.delete_private(:mdex_list_acc)
    |> Document.delete_private(:mdex_table_acc)
    |> Document.delete_private(:mdex_pending_break)
  end

  defp starts_with_list_marker?(binary) do
    task_marker?(binary) or bullet_marker?(binary) or ordered_marker?(binary)
  end

  defp task_marker?(<<marker, 32, ?[, _::binary>>) when marker in ~c"*+-", do: true
  defp task_marker?(<<marker, 9, ?[, _::binary>>) when marker in ~c"*+-", do: true
  defp task_marker?(_), do: false

  defp bullet_marker?(<<marker, 32, _::binary>>) when marker in ~c"*+-", do: true
  defp bullet_marker?(<<marker, 9, _::binary>>) when marker in ~c"*+-", do: true
  defp bullet_marker?(_), do: false

  defp ordered_marker?(binary) do
    case take_leading_digits(binary, "") do
      {"", _rest} -> false
      {_digits, <<?., 32, _::binary>>} -> true
      {_digits, <<?., 9, _::binary>>} -> true
      {_digits, <<?), 32, _::binary>>} -> true
      {_digits, <<?), 9, _::binary>>} -> true
      _ -> false
    end
  end

  defp take_leading_digits(<<char, rest::binary>>, acc) when char in ?0..?9 do
    take_leading_digits(rest, acc <> <<char>>)
  end

  defp take_leading_digits(binary, acc), do: {acc, binary}

  defp merge_codeblock_literals(a, b) do
    if ends_with_nl?(a), do: a <> b, else: a <> "\n" <> b
  end

  defp ends_with_nl?(<<>>), do: false

  defp ends_with_nl?(bin) do
    :binary.part(bin, byte_size(bin) - 1, 1) == "\n"
  end

  defp normalize_inline(%Code{num_backticks: 0} = n), do: %{n | num_backticks: 1}
  defp normalize_inline(n), do: n

  # Returns true if `parent` can directly contain `child` as per CommonMark rules.
  defp can_contain?(_, %Document{}), do: false
  defp can_contain?(%Document{}, %FrontMatter{}), do: true
  defp can_contain?(%Document{}, child), do: block?(child) and not list_item?(child)

  defp can_contain?(%MDEx.Text{}, %Text{}), do: true

  defp can_contain?(%BlockQuote{}, child), do: block?(child) and not list_item?(child)
  defp can_contain?(%FootnoteDefinition{}, child), do: block?(child) and not list_item?(child)
  defp can_contain?(%DescriptionTerm{}, child), do: block?(child) and not list_item?(child)
  defp can_contain?(%DescriptionDetails{}, child), do: block?(child) and not list_item?(child)
  defp can_contain?(%MultilineBlockQuote{}, child), do: block?(child) and not list_item?(child)
  defp can_contain?(%Alert{}, child), do: block?(child) and not list_item?(child)

  defp can_contain?(%MDEx.List{}, %ListItem{}), do: true
  defp can_contain?(%MDEx.List{}, %TaskItem{}), do: true

  defp can_contain?(%DescriptionList{}, %DescriptionItem{}), do: true
  defp can_contain?(%DescriptionItem{}, %DescriptionTerm{}), do: true
  defp can_contain?(%DescriptionItem{}, %DescriptionDetails{}), do: true

  defp can_contain?(%Paragraph{}, child), do: not block?(child)
  defp can_contain?(%Heading{}, child), do: not block?(child)
  defp can_contain?(%Emph{}, child), do: not block?(child)
  defp can_contain?(%Strong{}, child), do: not block?(child)
  defp can_contain?(%Link{}, child), do: not block?(child)
  defp can_contain?(%Image{}, child), do: not block?(child)
  defp can_contain?(%WikiLink{}, child), do: not block?(child)
  defp can_contain?(%Strikethrough{}, child), do: not block?(child)
  defp can_contain?(%Superscript{}, child), do: not block?(child)
  defp can_contain?(%SpoileredText{}, child), do: not block?(child)
  defp can_contain?(%Underline{}, child), do: not block?(child)
  defp can_contain?(%Subscript{}, child), do: not block?(child)
  defp can_contain?(%EscapedTag{}, child), do: not block?(child)

  defp can_contain?(%Table{}, %TableRow{}), do: true
  defp can_contain?(%TableRow{}, %TableCell{}), do: true
  defp can_contain?(%TableCell{}, %Text{}), do: true
  defp can_contain?(%TableCell{}, %Code{}), do: true
  defp can_contain?(%TableCell{}, %Emph{}), do: true
  defp can_contain?(%TableCell{}, %Strong{}), do: true
  defp can_contain?(%TableCell{}, %Link{}), do: true
  defp can_contain?(%TableCell{}, %Image{}), do: true
  defp can_contain?(%TableCell{}, %Strikethrough{}), do: true
  defp can_contain?(%TableCell{}, %HtmlInline{}), do: true
  defp can_contain?(%TableCell{}, %Math{}), do: true
  defp can_contain?(%TableCell{}, %WikiLink{}), do: true
  defp can_contain?(%TableCell{}, %FootnoteReference{}), do: true
  defp can_contain?(%TableCell{}, %Superscript{}), do: true
  defp can_contain?(%TableCell{}, %SpoileredText{}), do: true
  defp can_contain?(%TableCell{}, %Underline{}), do: true
  defp can_contain?(%TableCell{}, %Subscript{}), do: true

  defp can_contain?(_, _), do: false

  defp block?(%Alert{}), do: true
  defp block?(%BlockQuote{}), do: true
  defp block?(%CodeBlock{}), do: true
  defp block?(%DescriptionDetails{}), do: true
  defp block?(%DescriptionItem{}), do: true
  defp block?(%DescriptionList{}), do: true
  defp block?(%DescriptionTerm{}), do: true
  defp block?(%Document{}), do: true
  defp block?(%FootnoteDefinition{}), do: true
  defp block?(%Heading{}), do: true
  defp block?(%HtmlBlock{}), do: true
  defp block?(%ListItem{}), do: true
  defp block?(%MDEx.List{}), do: true
  defp block?(%MultilineBlockQuote{}), do: true
  defp block?(%Paragraph{}), do: true
  defp block?(%TableCell{}), do: true
  defp block?(%TableRow{}), do: true
  defp block?(%Table{}), do: true
  defp block?(%TaskItem{}), do: true
  defp block?(%ThematicBreak{}), do: true
  defp block?(_), do: false

  defp list_item?(%ListItem{}), do: true
  defp list_item?(%TaskItem{}), do: true
  defp list_item?(_), do: false

  defp list_from_item(%ListItem{} = item) do
    %MDEx.List{
      nodes: [item],
      list_type: item.list_type,
      marker_offset: item.marker_offset,
      padding: item.padding,
      start: item.start,
      delimiter: item.delimiter,
      bullet_char: item.bullet_char,
      tight: item.tight,
      is_task_list: item.is_task_list
    }
  end

  defp list_from_item(%TaskItem{} = task) do
    %MDEx.List{nodes: [task], tight: false, is_task_list: true}
  end

  defp trailing_whitespace(binary) do
    trimmed = String.trim_trailing(binary)
    diff = byte_size(binary) - byte_size(trimmed)

    if diff > 0 do
      :binary.part(binary, byte_size(binary) - diff, diff)
    else
      ""
    end
  end

  defp remove_hard_line_break_prefix(prefix, true), do: String.replace_prefix(prefix, "\n\n", "")
  defp remove_hard_line_break_prefix(prefix, false), do: prefix

  defp emphasis_delimiter?(delimiter) when is_binary(delimiter) and delimiter != "" do
    String.match?(delimiter, ~r/^[*_]+$/)
  end

  defp emphasis_delimiter?(_), do: false
end
