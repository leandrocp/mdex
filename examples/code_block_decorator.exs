Mix.install([
  {:mdex, path: ".."}
])

defmodule CodeBlockDecoratorExample do
  def run do
    markdown = """
    # Code Block Decorator

    ```elixir highlight_lines=2,5,8-10
    defmodule do
      @langs [:elixir, :rust]

      def langs do
        @lang
      end

      def libs do
        [:comrak, :ammonia, :autumnus]
      end
    end
    ```
    """

    html =
      MDEx.to_html!(markdown,
        syntax_highlight: [
          formatter: {:html_inline, theme: "catppuccin_frappe"}
        ],
        render: [
          github_pre_lang: true,
          full_info_string: true
        ]
      )

    File.write!("code_block_decorator.html", html)
    IO.puts(html)
  end
end

CodeBlockDecoratorExample.run()
