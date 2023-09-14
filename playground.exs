Mix.install([{:mdex, path: "."}, :rustler])

defmodule Playground do
  def layout(inner_content) do
    layout = ~S"""
    <html>
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com">
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
        <link href="https://fonts.googleapis.com/css2?family=Ubuntu+Mono&display=swap" rel="stylesheet">
        <style>
          * { font-family: "Ubuntu Mono", monospace; }
        </style>
      </head>
      <body>
        <%= @inner_content %>
      </body>
    </html>
    """

    EEx.eval_string(layout, assigns: [inner_content: inner_content])
  end

  @options [features: [syntax_highlight_theme: "Dracula"]]

  @inner_content ~S"""
  # Elixir

  ```elixir
  # elixir example

  def fib(n), do: fib(n, 1, 1)

  def fib(0, _a, _b), do: []

  def fib(n, a, b) when n > 0 do
    [a | fib(n - 1, b, a + b)]
  end
  ```

  # Ruby

  ```ruby
  # ruby example

  def fibonacci(n)
    return n if (0..1).include?(n)
    (fibonacci(n - 1) + fibonacci(n - 2))
  end
  ```
  # Rust

  ```rust
  // rust example

  fn fibonacci(n: u32) -> u32 {
    match n {
      0 => 1,
      1 => 1,
      _ => fibonacci(n - 1) + fibonacci(n - 2),
    }
  }
  ```

  # Swift

  ```swift
  // swift example

  func fibonacciTo(max: Int) -> SequenceOf<Int> {
    return SequenceOf { _ -> GeneratorOf<Int> in
      var (a, b) = (1, 0)

      return GeneratorOf {
        (b, a) = (a, b + a)
        if b > max { return nil }
        return b
      }
    }
  }
  ```
  """

  def run! do
    inner_content = MDEx.to_html(@inner_content, @options)
    document = layout(inner_content)
    File.write!("playground.html", document)
  end
end

Playground.run!()
