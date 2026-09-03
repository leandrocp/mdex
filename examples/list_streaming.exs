mdex_path = System.get_env("MDEX_PATH", Path.expand("..", __DIR__))

Mix.install(
  [{:mdex, path: mdex_path}],
  config: [mdex_native: [syntax_highlighter: :lumis]],
  lockfile: Path.join(mdex_path, "mix.lock")
)

[
  ~s|# Streaming|,
  ~s| with MDEx\n\n|,
  ~s|Markdown arrives|,
  ~s| in **small|,
  ~s| chunks**.\n\n|,
  ~s|```elixir\n|,
  ~s|child = spawn|,
  ~s|(fn -> send(current, {self(), 1 + 2}) end)\n|,
  ~s|```\n|
]
|> MDEx.stream()
|> Enum.each(fn {idx, doc} ->
  IO.puts("-- chunk: #{idx}")
  IO.puts(doc)
  IO.puts("\n")
end)
