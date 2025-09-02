defmodule MDEx.Stream do
  @moduledoc """
  Lazy Markdown streaming.

  Streaming allows you to efficiently collect (append) chunks of Markdown content,
  complete or incomplete, and render the content progressively to a specified output device
  like a file or standard output.

  This modules implements both the `Collectable` and `Enumerable` protocols,
  enabling you to collect (append) chunks of Markdown content and also manipulate the stream.

  For example, starting with an empty document:

      stream = MDEx.Stream.new()

  Append chunks of Markdown content progressively:

      stream
      |> MDEx.Stream.append("#")
      |> MDEx.Stream.append("Hello World Examples\\n\\n")
      |> MDEx.Stream.append("*")
      |> MDEx.Stream.append(" Elixir\\n")
      |> MDEx.Stream.append("\`\`\`\\n")
      |> MDEx.Stream.append("elixir\\nIO.puts(\\"Hello, World!\\")\\n")
      |> MDEx.Stream.append("\`\`\`")

  Note that the chunks can be incomplete


  """

  defstruct [:device, :buffer]

  def new(opts \\ []) do
    device = opts[:device] || :stdio
    %MDEx.Stream{device: device, buffer: []}
  end

  def append(%MDEx.Stream{buffer: buffer} = stream, chunk) do
    %{stream | buffer: [buffer, chunk]}
  end
end

defimpl Enumerable, for: MDEx.Stream do
  def count(_stream), do: {:error, __MODULE__}
  def member?(_stream, _element), do: {:error, __MODULE__}
  def slice(_stream), do: {:error, __MODULE__}

  def reduce(%MDEx.Stream{device: device, buffer: buffer}, acc, fun) do
    case acc do
      {:halt, acc} ->
        {:halted, acc}

      {:suspend, acc} ->
        {:suspended, acc, &reduce(%MDEx.Stream{device: device, buffer: buffer}, &1, fun)}

      {:cont, acc} ->
        markdown_content = IO.iodata_to_binary(buffer)
        html_content = MDEx.to_html!(markdown_content)

        case device do
          %File.Stream{path: path, modes: modes} ->
            {:ok, file} = File.open(path, [:write | modes -- [:read_ahead, :raw, :binary]])
            IO.write(file, html_content)
            File.close(file)
            {:done, acc}

          device ->
            IO.write(device, html_content)
            {:done, acc}
        end
    end
  end
end
