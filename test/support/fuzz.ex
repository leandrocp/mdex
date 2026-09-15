defmodule MDEx.Fuzz do
  @moduledoc """
  Case template and shared helpers for the MDEx fuzz suite.

  `use MDEx.Fuzz` sets up an async property test module, imports the shared
  generators and helpers, and tags the module with `:fuzz` so the suite can be
  selected with `mix test --only fuzz` or skipped with `mix test --exclude fuzz`.

  Properties run at StreamData's default of 100 generations. Do not try to raise
  that with a helper such as `check all(x <- gen(), property_options())`:
  `check all` only reads its options when they are a literal keyword list in the
  source, so the call is parsed as a filter clause, the keyword list is truthy,
  the filter always passes, and the budget is silently dropped.

  StreamData seeds itself from the ExUnit seed, so a failing run is reproduced
  with the seed ExUnit printed:

      mix test test/mdex/options_fuzz_test.exs --seed 123456

  """

  use ExUnitProperties

  @doc false
  defmacro __using__(_opts) do
    quote do
      use ExUnit.Case, async: true
      use ExUnitProperties

      import MDEx.Fuzz

      @moduletag :fuzz
    end
  end

  @doc """
  Parses `html` into a Floki tree with attributes sorted.

  Attribute order is a serialization detail, so comparing normalized trees keeps
  failures about real rendering differences instead of attribute shuffling.
  The string is trimmed first because `MDEx` trims its rendered output while
  comrak does not, which otherwise shows up as a stray trailing text node.
  """
  def html_tree(html) do
    html
    |> String.trim()
    |> Floki.parse_fragment!()
    |> normalize_html_tree()
  end

  defp normalize_html_tree(nodes) when is_list(nodes), do: Enum.map(nodes, &normalize_html_tree/1)

  defp normalize_html_tree({tag, attributes, children}) do
    {tag, Enum.sort(attributes), normalize_html_tree(children)}
  end

  defp normalize_html_tree(node), do: node

  @doc """
  Splits `binary` into chunks of `size` bytes, so the last chunk may be shorter.

  Chunks split on byte boundaries on purpose: streaming has to cope with a
  multi-byte grapheme arriving across two chunks.
  """
  def binary_chunks(binary, size), do: binary_chunks(binary, size, [])

  defp binary_chunks("", _size, chunks), do: Enum.reverse(chunks)

  defp binary_chunks(binary, size, chunks) when byte_size(binary) <= size do
    Enum.reverse([binary | chunks])
  end

  defp binary_chunks(binary, size, chunks) do
    <<chunk::binary-size(^size), rest::binary>> = binary
    binary_chunks(rest, size, [chunk | chunks])
  end

  @doc """
  Non-empty alphanumeric text, safe to interpolate without creating markup.
  """
  def nonempty_text, do: string(:alphanumeric, min_length: 1, max_length: 48)

  @doc """
  Possibly empty alphanumeric text for option values such as prefixes.
  """
  def option_string, do: string(:alphanumeric, max_length: 24)

  @doc """
  Assign values that exercise HEEx escaping.
  """
  def heex_value do
    one_of([
      string(:alphanumeric, max_length: 48),
      member_of(["<MDEx>", "Elixir & Rust", ~s("quoted"), "{value}"])
    ])
  end
end
