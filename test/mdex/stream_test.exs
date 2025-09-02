defmodule MDEx.StreamTest do
  use ExUnit.Case
  import MDEx.Stream, only: [append: 2]

  test "stdio by default" do
    import ExUnit.CaptureIO

    output =
      capture_io(fn ->
        MDEx.Stream.new()
        |> append("# hello")
        |> append(" world")
        |> append("\n\n```elixir\n# Example")
        |> append("1+1\n```\n")
        |> Stream.run()
      end)

    expected =
      "<h1>hello world</h1>\n<pre class=\"athl\" style=\"color: #abb2bf; background-color: #282c34;\"><code class=\"language-elixir\" translate=\"no\" tabindex=\"0\"><div class=\"line\" data-line=\"1\"><span style=\"color: #7f848e;\"># Example1+1</span>\n</div></code></pre>"

    assert output == expected
  end

  @tag :tmp_dir
  test "save to file", %{tmp_dir: tmp_dir} do
    output_path = Path.join(tmp_dir, "output.md")
    file = File.stream!(output_path)

    MDEx.Stream.new(device: file)
    |> append("# hello")
    |> append(" world")
    |> append("\n\n```elixir\n# Example")
    |> append("1+1\n```\n")
    |> Stream.run()

    content = File.read!(output_path)

    expected =
      "<h1>hello world</h1>\n<pre class=\"athl\" style=\"color: #abb2bf; background-color: #282c34;\"><code class=\"language-elixir\" translate=\"no\" tabindex=\"0\"><div class=\"line\" data-line=\"1\"><span style=\"color: #7f848e;\"># Example1+1</span>\n</div></code></pre>"

    assert content == expected
  end

  test "writes to StringIO" do
    {:ok, string_io} = StringIO.open("")

    MDEx.Stream.new(device: string_io)
    |> append("# hello")
    |> append(" world")
    |> append("\n\n```elixir\n# Example")
    |> append("1+1\n```\n")
    |> Stream.run()

    {_input, output} = StringIO.contents(string_io)

    expected =
      "<h1>hello world</h1>\n<pre class=\"athl\" style=\"color: #abb2bf; background-color: #282c34;\"><code class=\"language-elixir\" translate=\"no\" tabindex=\"0\"><div class=\"line\" data-line=\"1\"><span style=\"color: #7f848e;\"># Example1+1</span>\n</div></code></pre>"

    assert output == expected

    StringIO.close(string_io)
  end
end
