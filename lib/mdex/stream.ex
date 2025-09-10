defmodule MDEx.Stream do
  @moduledoc """
  Provides streaming Markdown parsing capabilities for processing Markdown content incrementally.

  > #### Experimental {: .warning}
  >
  > Streaming is still experimental, it may be incomplete and is subject to change.

  `MDEx.Stream` allows you to parse Markdown content as it arrives, making it ideal for
  real-time applications, large documents, or scenarios where you need to process content
  chunk by chunk. The stream lazily parses incoming chunks into AST nodes and accumulates
  them into a document structure.

  The stream emits individual child nodes of the document but not the Document node itself,
  allowing for efficient processing of parsed elements as they become available.

  ## Key Features

  - **Incremental parsing**: Process Markdown content as it arrives
  - **Memory efficient**: Parse large documents without loading everything into memory
  - **Real-time processing**: Emit nodes as soon as they're parsed
  - **Fragment handling**: Properly handles incomplete Markdown fragments
  - **Multiple input types**: Accepts binary data, charlists, iodata, and pre-parsed nodes

  ## Examples

  IO data:

      iex> stream = MDEx.stream()
      iex> stream = Enum.into(["**foo**", "**bar**"], stream)
      iex> Enum.take(stream, 2)
      [%MDEx.Strong{nodes: [%MDEx.Text{literal: "foo"}]}, %MDEx.Strong{nodes: [%MDEx.Text{literal: "bar"}]}]

  Collecting stream into a complete document:

      iex> stream = MDEx.stream()
      iex> stream = Enum.into(["Hello ", "World"], stream)
      iex> Enum.into(stream, %MDEx.Document{})
      %MDEx.Document{
        nodes: [
          %MDEx.Paragraph{
            nodes: [
              %MDEx.Text{literal: "Hello World"}
            ]
          }
        ]
      }

  """

  @enforce_keys [:document]
  @derive {Inspect, only: [:document]}
  defstruct document: %MDEx.Document{}, options: [], acc: "", emitted_rev: []

  defimpl Collectable do
    def into(%MDEx.Stream{} = stream) do
      collect = fn
        %MDEx.Stream{options: opts, document: doc, acc: acc, emitted_rev: emitted_rev} = st, {:cont, chunk}
        when is_binary(chunk) or is_list(chunk) ->
          bin = IO.chardata_to_string(chunk)

          new_acc = acc <> bin
          {completed, _delim, _lead, _trail} = MDEx.FragmentParser.complete(new_acc)

          document =
            case MDEx.parse_document(completed, opts) do
              {:ok, %MDEx.Document{} = d} -> d
              _ -> doc
            end

          document = MDEx.Stream.maybe_trim_open_fence(document, new_acc)

          emitted_rev =
            case MDEx.Stream.extract_fragment_nodes(bin, opts) do
              {:ok, nodes} -> :lists.foldl(fn n, a -> [n | a] end, emitted_rev, nodes)
              _ -> emitted_rev
            end

          %{st | document: document, acc: new_acc, emitted_rev: emitted_rev}

        %MDEx.Stream{document: doc, emitted_rev: emitted_rev} = st, {:cont, %_{} = node} ->
          %{st | document: MDEx.Tree.append(doc, node), emitted_rev: [node | emitted_rev]}

        %MDEx.Stream{options: opts, document: doc, acc: acc, emitted_rev: emitted_rev} = st, {:cont, list} when is_list(list) and list != [] ->
          if Enum.all?(list, &is_struct/1) do
            %{st | document: MDEx.Tree.append(doc, list), emitted_rev: :lists.foldl(fn n, a -> [n | a] end, emitted_rev, list)}
          else
            bin = IO.chardata_to_string(list)
            new_acc = acc <> bin
            {completed, _delim, _lead, _trail} = MDEx.FragmentParser.complete(new_acc)

            document =
              case MDEx.parse_document(completed, opts) do
                {:ok, %MDEx.Document{} = d} -> d
                _ -> doc
              end

            document = MDEx.Stream.maybe_trim_open_fence(document, new_acc)

            emitted_rev =
              case MDEx.Stream.extract_fragment_nodes(bin, opts) do
                {:ok, nodes} -> :lists.foldl(fn n, a -> [n | a] end, emitted_rev, nodes)
                _ -> emitted_rev
              end

            %{st | document: document, acc: new_acc, emitted_rev: emitted_rev}
          end

        %MDEx.Stream{} = st, :done ->
          st

        _st, :halt ->
          :ok

        _st, {:cont, other} ->
          raise ArgumentError, "collecting into MDEx.Stream requires IO data or nodes, got: #{inspect(other)}"
      end

      {stream, collect}
    end
  end

  defimpl Enumerable do
    def reduce(_s, {:halt, acc}, _fun), do: {:halted, acc}
    def reduce(s, {:suspend, acc}, fun), do: {:suspended, acc, &reduce(s, &1, fun)}

    def reduce(%MDEx.Stream{emitted_rev: rev}, {:cont, acc}, fun) do
      Enumerable.reduce(:lists.reverse(rev), {:cont, acc}, fun)
    end

    def count(_), do: {:error, __MODULE__}
    def member?(_, _), do: {:error, __MODULE__}
    def slice(_), do: {:error, __MODULE__}
  end

  @doc false
  def extract_fragment_nodes(markdown, options) do
    {completed, delim, leading, trailing} = MDEx.FragmentParser.complete(markdown)

    case MDEx.parse_document(completed, options) do
      {:ok, %MDEx.Document{nodes: [%MDEx.Paragraph{nodes: nodes}]}} ->
        {:ok, wrap_leading_trailing(nodes, leading, trailing, delim)}

      {:ok, %MDEx.Document{nodes: nodes}} ->
        {:ok, wrap_leading_trailing(nodes, leading, trailing, delim)}

      error ->
        error
    end
  end

  defp wrap_leading_trailing(nodes, leading, trailing, delim) do
    synthetic = delim == "`" and leading == " " and trailing == " "
    nodes = if leading != "" and not synthetic, do: [%MDEx.Text{literal: leading} | nodes], else: nodes
    if trailing != "" and not synthetic, do: nodes ++ [%MDEx.Text{literal: trailing}], else: nodes
  end

  @doc false
  def maybe_trim_open_fence(%MDEx.Document{nodes: nodes} = doc, acc) do
    if open_fence?(acc) do
      case nodes do
        [] ->
          doc

        _ ->
          last = :lists.last(nodes)

          case last do
            %MDEx.CodeBlock{literal: lit} = cb ->
              if String.ends_with?(lit, "\n") do
                trimmed = String.trim_trailing(lit, "\n")
                %{doc | nodes: replace_last(nodes, %{cb | literal: trimmed})}
              else
                doc
              end

            _ ->
              doc
          end
      end
    else
      doc
    end
  end

  defp replace_last([_], new), do: [new]
  defp replace_last([h | t], new), do: [h | replace_last(t, new)]

  defp open_fence?(bin) when is_binary(bin) do
    case :binary.match(bin, "\n") do
      :nomatch -> false
      {_, _} -> starts_with_fence?(bin) and not has_closing_fence_after_first_line?(bin)
    end
  end

  defp starts_with_fence?(bin) do
    leading(bin, "`") >= 3 or leading(bin, "~") >= 3
  end

  defp has_closing_fence_after_first_line?(bin) do
    {first, rest} = split_first_line(bin)

    cond do
      leading(first, "`") >= 3 -> scan_for_fence(rest, "`", leading(first, "`"))
      leading(first, "~") >= 3 -> scan_for_fence(rest, "~", leading(first, "~"))
      true -> false
    end
  end

  defp split_first_line(bin) do
    case :binary.match(bin, "\n") do
      :nomatch -> {bin, <<>>}
      {pos, _} -> {:binary.part(bin, 0, pos), :binary.part(bin, pos + 1, byte_size(bin) - pos - 1)}
    end
  end

  defp scan_for_fence(<<>>, _ch, _run), do: false

  defp scan_for_fence(bin, ch, run) do
    if leading(bin, ch) >= run do
      true
    else
      case :binary.match(bin, "\n") do
        :nomatch -> false
        {pos, _} -> scan_for_fence(:binary.part(bin, pos + 1, byte_size(bin) - pos - 1), ch, run)
      end
    end
  end

  defp leading(bin, ch) do
    cl = byte_size(ch)
    do_lead(bin, ch, cl, 0)
  end

  defp do_lead(<<>>, _ch, _cl, acc), do: acc

  defp do_lead(bin, ch, cl, acc) do
    if :binary.part(bin, 0, cl) == ch, do: do_lead(:binary.part(bin, cl, byte_size(bin) - cl), ch, cl, acc + 1), else: acc
  end
end
