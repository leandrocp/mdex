Mix.install([
  {:mdex, path: ".."}
])

defmodule CodeBlockDecoratorExample do
  def run do
    markdown = """
    # Code Block Decorator

    ## highlight_lines=2,5,8-10

    ```elixir highlight_lines=2,5,8-10
    defmodule Lines do
      @langs ["elixir", "rust"]

      def langs do
        @langs
      end

      def libs do
        [:comrak, :ammonia, :autumnus]
      end
    end
    ```

    ## theme and highlight_lines_style

    ```elixir theme=dracula highlight_lines=2,5,8-10 highlight_lines_style="background-color: purple;"
    defmodule CustomStyle do
      @langs ["elixir", "rust"]

      def langs do
        @langs
      end

      def libs do
        [:comrak, :ammonia, :autumnus]
      end
    end
    ```

    ## include_highlights

    ```elixir include_highlights
    defmodule Highlights do
      @langs ["elixir", "rust"]

      def langs do
        @langs
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
