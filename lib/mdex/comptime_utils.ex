# https://github.com/elixir-explorer/explorer/blob/d11216282bbdb0dcaef2519c2bfefda46c2981e0/lib/explorer/comptime_utils.ex

defmodule MDEx.ComptimeUtils do
  @moduledoc false

  def cpu_with_all_caps?(needed_flags, opts \\ []) do
    opts = Keyword.validate!(opts, cpu_info_file_path: "/proc/cpuinfo", target: nil)

    case File.read(opts[:cpu_info_file_path]) do
      {:ok, contents} ->
        flags =
          contents
          |> String.split("\n")
          |> Stream.filter(&String.starts_with?(&1, "flags"))
          |> Stream.map(fn line ->
            [_, flags] = String.split(line, ": ")
            String.split(flags)
          end)
          |> Stream.uniq()
          |> Enum.to_list()
          |> List.flatten()

        Enum.all?(needed_flags, fn flag -> flag in flags end)

      {:error, _} ->
        false
    end
  end
end
