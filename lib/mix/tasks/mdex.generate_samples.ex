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
        font-size: 14px;
        line-height: 1.5;
      }
      body {
        background-color: #ffffff;
      }
      pre {
        margin: 20px;
      }
    </style>
  </head>
  <body>
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
  end

  defp generate(filename, url) do
    Mix.shell().info("#{filename} - #{url}")

    md = MDEx.to_html(download_source(url), features: [syntax_highlight_theme: "github_light"])

    html =
      EEx.eval_string(@layout,
        assigns: %{filename: filename, inner_content: md}
      )

    dest_path =
      Path.join([:code.priv_dir(:mdex), "generated", "samples", "#{filename}.html"])

    File.write!(dest_path, html)
  end

  defp download_source(url) do
    {:ok, {_, _, body}} = :httpc.request(url)
    to_string(body)
  end
end
