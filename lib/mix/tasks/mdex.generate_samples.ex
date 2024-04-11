defmodule Mix.Tasks.Mdex.GenerateSamples do
  use Mix.Task

  @shortdoc "Generate samples."

  @layout ~S"""
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <title>MDEx Sample - <%= @filename %></title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:ital,wght@0,300;0,400;0,700;1,300;1,400;1,700&display=swap" rel="stylesheet">
    <style>
      * {
        font-family: 'JetBrains Mono', monospace;
        line-height: 1.5;
      }
      body {
        padding: 50px;
      }
      pre {
        font-size: 15px;
        margin: 20px;
        padding: 50px;
        border-radius: 10px;
      }
    </style>
  </head>
  <body>
    <%= if @index do %>
      <p><a href="https://github.com/leandrocp/mdex"><img src="https://raw.githubusercontent.com/leandrocp/mdex/main/assets/images/mdex_logo.png" width="512" alt="MDEx logo"></img></a></p>
      <p><a href="https://github.com/leandrocp/mdex">https://github.com/leandrocp/mdex</a></p>
    <% end %>
    <%= @inner_content %>
  </body>
  </html>
  """

  @files [
    {"req_readme.md", ~c"https://raw.githubusercontent.com/wojtekmach/req/main/README.md"}
  ]

  @impl true
  def run(_args) do
    :inets.start()
    :ssl.start()

    for {filename, url} <- @files do
      generate(filename, url)
    end

    langs()
  end

  defp generate(filename, url) do
    Mix.shell().info("#{filename} - #{url}")

    md = MDEx.to_html(download_source(url), features: [syntax_highlight_theme: "github_light"])

    html =
      EEx.eval_string(@layout,
        assigns: %{filename: filename, inner_content: md}
      )

    dest_path = Path.join([:code.priv_dir(:mdex), "generated", "samples", "#{filename}.html"])
    File.write!(dest_path, html)

    generate_index()
  end

  defp generate_index do
    Mix.shell().info("index.html")

    src_path = Path.join([:code.priv_dir(:mdex), "generated", "samples"])

    links =
      (src_path <> "/*.html")
      |> Path.wildcard()
      |> Enum.map(&Path.basename/1)
      |> Enum.reject(&(&1 == "index.html"))
      |> Enum.map(fn sample ->
        ["<p><a href=", ?", sample, ?", ">", sample, "</a></p>", "\n"]
      end)

    inner_content = [
      "<h1>MDEx Samples</h1>",
      "\n",
      links
    ]

    html =
      EEx.eval_string(@layout,
        assigns: %{inner_content: inner_content, index: true}
      )

    dest_path = Path.join([:code.priv_dir(:mdex), "generated", "samples", "index.html"])
    File.write!(dest_path, html)
  end

  defp langs do
    path = "langs.md"

    for theme <- [
          "onedark",
          "dracula",
          "catppuccin_macchiato",
          "github_light",
          "github_dark",
          "autumn",
          "base16_default_dark",
          "emacs",
          "nord",
          "nord_light",
          "onelight",
          "solarized_dark",
          "solarized_light",
          "sonokai",
          "spacebones_light"
        ] do
      Mix.shell().info("#{path} - #{theme}")

      md =
        [:code.priv_dir(:mdex), "generated", "samples", path]
        |> Path.join()
        |> File.read!()

      md = MDEx.to_html(md, features: [syntax_highlight_theme: theme])

      html =
        EEx.eval_string(@layout,
          assigns: %{filename: path, inner_content: md}
        )

      dest_path =
        Path.join([:code.priv_dir(:mdex), "generated", "samples", "#{path}_#{theme}.html"])

      File.write!(dest_path, html)
    end
  end

  defp download_source(url) do
    {:ok, {_, _, body}} = :httpc.request(url)
    to_string(body)
  end
end
