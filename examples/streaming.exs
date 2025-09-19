Mix.install([
  {:mdex, path: "..", override: true},
  {:mdex_gfm, "~> 0.1", override: true},
  {:nimble_parsec, "~> 1.0"},
  {:req, "~> 0.5"},
  {:phoenix_playground, "~> 0.1"}
])

defmodule DemoLayout do
  use Phoenix.Component

  def render("root.html", assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en" class="h-full">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>MDEx Streaming (Preview)</title>
        <link rel="icon" type="image/png" href="../assets/images/mdex_favicon.png">
      </head>
      <body>
        <script src="https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4"></script>
        <script src="/assets/phoenix/phoenix.js"></script>
        <script src="/assets/phoenix_live_view/phoenix_live_view.js"></script>

        <script>
          let liveSocket =
            new window.LiveView.LiveSocket(
              "/live",
              window.Phoenix.Socket
            )
          liveSocket.connect()

          window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
            reloader.enableServerLogs()
            window.liveReloader = reloader
          })

          window.addEventListener("phx:update", () => {
            const chunksContainer = document.getElementById("chunks-container")
            const renderedContainer = document.getElementById("rendered-container")
            const astContainer = document.getElementById("ast-container")
            if (chunksContainer) {
              chunksContainer.scrollTop = chunksContainer.scrollHeight
            }
            if (renderedContainer) {
              renderedContainer.scrollTop = renderedContainer.scrollHeight
            }
            if (astContainer) {
              astContainer.scrollTop = astContainer.scrollHeight
            }
          })
        </script>

        <%= @inner_content %>
      </body>
    </html>
    """
  end
end

defmodule RenderPanel do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div class="bg-white/80 backdrop-blur-sm dark:bg-gray-800/80 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700">
      <div class="px-4 md:px-6 py-3 md:py-4 border-b border-gray-200 dark:border-gray-700 flex items-center justify-between">
        <h3 class="text-base font-medium text-gray-900 dark:text-white">Rendered HTML</h3>
        <div class="text-xs text-gray-600 dark:text-gray-300">← → to navigate</div>
      </div>
      <div class="p-4 md:p-6">
        <div id="rendered-container" class="max-h-[50vh] overflow-y-auto">
          <%= if @html == "" do %>
            <div class="text-gray-500 dark:text-gray-400 italic text-center py-8">
              Rendered output will appear here.
            </div>
          <% else %>
            <div class={"max-w-none text-[13px] text-gray-900 dark:text-gray-100
                         [&_h1]:text-lg [&_h1]:font-semibold [&_h1]:mb-2 [&_h1]:mt-3
                         [&_h2]:text-base [&_h2]:font-semibold [&_h2]:mb-2 [&_h2]:mt-3
                         [&_h3]:text-sm [&_h3]:font-semibold [&_h3]:mb-2 [&_h3]:mt-3
                         [&_p]:mb-2 [&_p]:leading-relaxed
                         [&_ul]:my-2 [&_ul]:pl-4 [&_ul]:list-disc [&_ul]:list-inside
                         [&_ol]:my-2 [&_ol]:pl-4 [&_ol]:list-decimal [&_ol]:list-inside
                         [&_li]:mb-1
                         [&_a]:text-blue-600 [&_a]:hover:underline dark:[&_a]:text-blue-400
                         [&_code]:bg-gray-100 [&_code]:dark:bg-gray-800 [&_code]:px-1.5 [&_code]:py-0.5 [&_code]:rounded [&_code]:text-[12px] [&_code]:font-mono
                         [&_pre]:p-4 [&_pre]:rounded-lg [&_pre]:overflow-x-auto
                         [&_pre]:font-mono [&_pre]:text-[13px] [&_pre]:leading-6
                         [&_pre_code]:block [&_pre_code]:whitespace-pre [&_pre_code]:text-inherit
                         [&_blockquote]:border-l-2 [&_blockquote]:border-gray-400 [&_blockquote]:pl-3 [&_blockquote]:italic [&_blockquote]:text-gray-600 dark:[&_blockquote]:text-gray-400
                         [&_strong]:font-semibold [&_em]:italic
                         [&_table]:w-full [&_table]:table-fixed [&_table]:text-left
                         [&_thead]:bg-gray-100 dark:[&_thead]:bg-gray-700
                         [&_th]:px-3 [&_th]:py-2 [&_th]:font-medium [&_th]:border-b [&_th]:border-gray-300 dark:[&_th]:border-gray-600
                         [&_td]:px-3 [&_td]:py-2 [&_td]:align-middle [&_td]:border-b [&_td]:border-gray-200 dark:[&_td]:border-gray-700
                         [&_tr:hover]:bg-gray-50 dark:[&_tr:hover]:bg-gray-800"}>
              {Phoenix.HTML.raw(@html)}
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end

defmodule ChunksPanel do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div class="bg-white/80 backdrop-blur-sm dark:bg-gray-800/80 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700">
      <div class="px-4 md:px-6 py-3 md:py-4 border-b border-gray-200 dark:border-gray-700">
        <h3 class="text-base font-medium text-gray-900 dark:text-white">Markdown Chunks</h3>
      </div>
      <div class="p-4 md:p-6">
        <div id="chunks-container" class="max-h-[50vh] overflow-y-auto">
          <%= if @chunks == [] do %>
            <div class="text-gray-500 dark:text-gray-400 italic text-center py-8">
              No chunks yet. Click a demo button to start streaming.
            </div>
          <% else %>
            <div class="flex flex-wrap gap-0.5">
              <%= for chunk <- @chunks do %>
                <span class="inline-block bg-blue-100 dark:bg-blue-700 dark:border-blue-600 rounded text-xs text-gray-600 dark:text-blue-300 font-mono px-1.5 py-1.5"><%= String.slice(inspect(chunk), 1..-2//1) %></span>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end

defmodule AstPanel do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div class="bg-white/80 backdrop-blur-sm dark:bg-gray-800/80 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700">
      <div class="px-4 md:px-6 py-3 md:py-4 border-b border-gray-200 dark:border-gray-700">
        <h3 class="text-base font-medium text-gray-900 dark:text-white">Document AST</h3>
      </div>
      <div class="p-4 md:p-6">
        <div id="ast-container" class="max-h-[50vh] overflow-y-auto">
          <pre class="bg-gray-50 dark:bg-gray-900 rounded-lg p-4 text-[12px] overflow-x-auto text-gray-900 dark:text-gray-100 max-h-[70vh] overflow-y-auto"><%= inspect(@document, pretty: true, limit: :infinity, printable_limit: :infinity) %></pre>
        </div>
      </div>
    </div>
    """
  end
end

defmodule StreamingDemo do
  use Phoenix.LiveView

  @mdex_options [
    extension: [
      alerts: true,
      autolink: true,
      footnotes: true,
      shortcodes: true,
      strikethrough: true,
      table: true,
      tagfilter: true,
      tasklist: true
    ],
    parse: [
      relaxed_autolinks: true,
      relaxed_tasklist_matching: true
    ],
    render: [
      github_pre_lang: true,
      full_info_string: true,
      unsafe: true
    ],
    syntax_highlight: [formatter: {:html_inline, theme: "github_light"}]
  ]

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       document: MDEx.new(@mdex_options),
       chunks: [],
       html: "",
       streaming: false,
       speed: 100,
       current_chunk: 0,
       total_chunks: 0,
       stream_ref: nil
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-50 to-white dark:from-slate-950 dark:to-slate-900" phx-window-keydown="key_nav">
      <div class="max-w-7xl mx-auto px-8 py-8">
        <div class="text-center mb-12">
          <h1 class="text-3xl md:text-4xl font-semibold tracking-tight text-gray-900 dark:text-white mb-3">
            MDEx Streaming (Preview)
          </h1>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-12 gap-6 mb-8">
          <!-- Examples Section -->
          <div class="lg:col-span-4 xl:col-span-3">
            <div class="bg-white/80 backdrop-blur-sm dark:bg-gray-800/80 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700">
              <div class="px-6 py-4 border-b border-gray-200 dark:border-gray-700">
                <h2 class="text-base font-medium text-gray-900 dark:text-white">Examples</h2>
              </div>
              <div class="p-6">
                <div class="flex flex-col gap-2">
                  <button phx-click="demo_simple" class="px-4 py-2 text-sm font-medium text-gray-800 dark:text-gray-100 bg-white/70 dark:bg-gray-700/70 border border-gray-200 dark:border-gray-600 rounded-lg hover:bg-white dark:hover:bg-gray-700 transition-colors">
                    Play
                  </button>
                  <%!--
                  <button phx-click="demo_commonmark" class="px-4 py-2 text-sm font-medium text-gray-800 dark:text-gray-100 bg-white/70 dark:bg-gray-700/70 border border-gray-200 dark:border-gray-600 rounded-lg hover:bg-white dark:hover:bg-gray-700 transition-colors">
                    CommonMark
                  </button>
                  <button phx-click="demo_gfm" class="px-4 py-2 text-sm font-medium text-gray-800 dark:text-gray-100 bg-white/70 dark:bg-gray-700/70 border border-gray-200 dark:border-gray-600 rounded-lg hover:bg-white dark:hover:bg-gray-700 transition-colors">
                    GitHub (GFM)
                  </button>
                  <button phx-click="demo_readme" class="px-4 py-2 text-sm font-medium text-gray-800 dark:text-gray-100 bg-white/70 dark:bg-gray-700/70 border border-gray-200 dark:border-gray-600 rounded-lg hover:bg-white dark:hover:bg-gray-700 transition-colors">
                    Readme
                  </button>
                  <button phx-click="demo_ai_response" class="px-4 py-2 text-sm font-medium text-gray-800 dark:text-gray-100 bg-white/70 dark:bg-gray-700/70 border border-gray-200 dark:border-gray-600 rounded-lg hover:bg-white dark:hover:bg-gray-700 transition-colors">
                    AI Response
                  </button>
                  --%>
                  <button phx-click="clear" class="px-4 py-2 text-sm font-medium text-red-700 dark:text-red-400 bg-red-50 dark:bg-red-900/20 border border-red-300 dark:border-red-600 rounded-lg hover:bg-red-100 dark:hover:bg-red-900/40 transition-colors">
                    Clear
                  </button>
                </div>
              </div>
            </div>
          </div>

          <!-- Controls Section -->
          <div class="lg:col-span-8 xl:col-span-9">
            <div class="bg-white/80 backdrop-blur-sm dark:bg-gray-800/80 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700">
            <div class="px-6 py-4 border-b border-gray-200 dark:border-gray-700">
              <h2 class="text-base font-medium text-gray-900 dark:text-white">Controls</h2>
            </div>
              <div class="p-6">
                <div class="space-y-6">
                  <!-- Speed Control -->
                  <div class="space-y-3">
                    <div class="flex items-center justify-between">
                      <label class="text-sm font-medium text-gray-700 dark:text-gray-300">
                        Speed
                      </label>
                      <span class="text-sm font-mono bg-gray-100 dark:bg-gray-700 px-2 py-1 rounded text-gray-900 dark:text-gray-100">
                        <%= @speed %>ms
                      </span>
                    </div>
                    <form phx-change="update_speed">
                      <input
                        type="range"
                        name="speed"
                        min="1"
                        max="1000"
                        step="1"
                        value={1001 - @speed}
                        class="w-full h-2 bg-gray-200 dark:bg-gray-600 rounded-lg appearance-none cursor-pointer"
                      />
                    </form>
                    <div class="flex justify-between text-xs text-gray-500 dark:text-gray-400">
                      <span>Slow</span>
                      <span>Fast</span>
                    </div>
                  </div>

                  <!-- Progress -->
                  <div :if={@total_chunks > 0} class="space-y-3">
                    <div class="flex items-center justify-between">
                      <div class="flex items-center gap-2">
                        <label class="text-sm font-medium text-gray-700 dark:text-gray-300">
                          Progress
                        </label>
                        <span :if={@streaming} class="text-xs text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-900/20 px-2 py-0.5 rounded-full">
                          Streaming
                        </span>
                      </div>
                      <span class="text-sm font-mono bg-gray-100 dark:bg-gray-700 px-2 py-1 rounded text-gray-900 dark:text-gray-100">
                        <%= @current_chunk %> / <%= @total_chunks %>
                      </span>
                    </div>
                    <div class="flex items-center gap-2">
                      <button 
                        phx-click="prev_chunk"
                        class="px-2 py-1 text-xs font-medium bg-gray-100 dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded disabled:opacity-50"
                        disabled={@streaming or @current_chunk <= 0}>
                        &larr; Prev
                      </button>
                      <form phx-change="update_chunk_position" class="flex-1">
                        <input 
                          type="range" 
                          name="position"
                          min="0" 
                          max={max(@total_chunks, 1)}
                          step="1"
                          value={@current_chunk}
                          class="w-full h-2 bg-gray-200 dark:bg-gray-600 rounded-lg appearance-none transition-all duration-300 cursor-pointer"
                        />
                      </form>
                      <button 
                        phx-click="next_chunk"
                        class="px-2 py-1 text-xs font-medium bg-gray-100 dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded disabled:opacity-50"
                        disabled={@streaming or @current_chunk >= @total_chunks}>
                        Next &rarr;
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
        <div class="space-y-6">
          <.live_component module={RenderPanel} id="render-panel" html={@html} />
          <.live_component module={ChunksPanel} id="chunks-panel" chunks={Enum.take(@chunks, @current_chunk)} />
          <.live_component module={AstPanel} id="ast-panel" document={@document} />
        </div>
      </div>
    </div>
    """
  end

  def handle_event("demo_readme", _params, socket) do
    chunks =
      Req.get!("https://raw.githubusercontent.com/leandrocp/mdex/refs/heads/main/README.md").body
      |> String.graphemes()
      |> then(fn chars ->
        Stream.unfold(chars, fn
          [] ->
            nil

          remaining when length(remaining) <= 10 ->
            {Enum.join(remaining, ""), []}

          remaining ->
            piece_length = Enum.random(8..30)
            {piece_chars, rest} = Enum.split(remaining, piece_length)
            {Enum.join(piece_chars, ""), rest}
        end)
        |> Enum.to_list()
      end)

    simulate_streaming(socket, chunks)
  end

  def handle_event("demo_simple", _params, socket) do
    simulate_streaming(
      socket,
      [
        "# Streaming\n",
        "`Starting ",
        "streaming...`\n\n",
        "## TODO\n\n",
        "- [x] Collect *nodes*\n",
        "- [x] Collect",
        " *heading*\n",
        "- [x] Collect *code*\n",
        "- [ ] Collect *table*\n",
        "- [ ] Collect ...\n",
        "## Code Blocks\n\n",
        "**Elixir",
        "** example:\n",
        "```",
        "elixir\n",
        "defmodule StreamDemo do\n",
        "  def stream(chunks), do: @magic\n",
        "end\n",
        "```\n",
        "**Rust** example:\n",
        "```rust\nfn parse_document<'a>",
        "(env: Env<'a>, md: &str, options: ExOptions) -> NifResult<Term<'a>>\n",
        "```\n\n",
        "![Image",
        "](https://placehold.co/200x100/green/white?text=Image) ",
        "\n\n## Features\n\n",
        "| Name | Status |\n| ---- | ------ |\n",
        "| CommonMark | :rocket: |\n",
        "| GFM | :rocket: |\n",
        "| Streaming | :warn",
        "ing: |\n",
        "\n\n"
      ]
    )
  end

  def handle_event("demo_commonmark", _params, socket) do
    simulate_streaming(
      socket,
      [
        "# CommonMark Complete ",
        "Reference Guide\n\n",
        "Welcome to the **comprehensive** ",
        "CommonMark demonstration! This guide showcases ",
        "*every* major element type with ",
        "realistic streaming chunks.\n\n",
        "## Headings & Text Formatting\n\n",
        "### All Six Heading Levels\n",
        "#### Level 4 Heading\n",
        "##### Level 5 Heading\n",
        "###### Level 6 Heading\n\n",
        "Text can be **bo",
        "ld**, *ital",
        "ic*, or ***bo",
        "th***. ",
        "You can also use __alternative bo",
        "ld__ and ",
        "_alternative ital",
        "ic_ syntax. For ",
        "~~strike",
        "through~~ text (if supported), ",
        "and `inline co",
        "de` snippets.\n\n",
        "## Links & Images\n\n",
        "Here are different types of links:\n",
        "- Direct link: [MDEx Repo",
        "sitory](https://github.com/leandrocp/mdex)\n",
        "- Autolink: <https://common",
        "mark.org>\n",
        "- Reference link: [CommonMark Sp",
        "ec][spec]\n",
        "- Email link: <hello@exam",
        "ple.com>\n\n",
        "Images come in various sizes:\n",
        "![Small ic",
        "on](https://placehold.co/32x32/blue/white?text=small) ",
        "![Medium ban",
        "ner](https://placehold.co/400x100/green/white?text=CommonMark) ",
        "![Large place",
        "holder](https://placehold.co/600x300/purple/white?text=Demo+Image)\n\n",
        "## Lists & Organization\n\n",
        "### Unordered Lists\n",
        "- First item with **bo",
        "ld**\n",
        "- Second item with *ital",
        "ic*\n",
        "  - Nested item A\n",
        "  - Nested item B with `co",
        "de`\n",
        "    - Deep nested item\n",
        "- Third item with [li",
        "nk](https://example.com)\n",
        "+ Alternative bullet style\n",
        "* Another bullet style\n\n",
        "### Ordered Lists\n",
        "1. **Primary st",
        "ep** - This is important\n",
        "2. *Secondary st",
        "ep* - This has emphasis\n",
        "   1. Sub-step one\n",
        "   2. Sub-step two with `code snip",
        "pet`\n",
        "   3. Sub-step three\n",
        "3. **Final st",
        "ep** - Complete!\n\n",
        "### Mixed List Example\n",
        "1. First ordered item\n",
        "   - Unordered sub-item\n",
        "   - Another sub-item\n",
        "2. Second ordered item\n",
        "   1. Nested ordered\n",
        "   2. Another nested\n\n",
        "## Code Examples\n\n",
        "Inline code: `const mess",
        "age = 'Hello, World!'`\n\n",
        "### JavaScript Example\n",
        "```javascript\n",
        "// Modern JavaScript example\n",
        "const fetchData = async (url) => {\n",
        "  try {\n",
        "    const response = await fetch(url);\n",
        "    const data = await response.json();\n",
        "    return { success: true, data };\n",
        "  } catch (error) {\n",
        "    return { success: false, error: error.message };\n",
        "  }\n",
        "};\n",
        "```\n\n",
        "### Elixir Example\n",
        "```elixir\n",
        "defmodule StreamDemo do\n",
        "  @doc \"Processes markdown chunks in real-time\"\n",
        "  def process_chunks(chunks) when is_list(chunks) do\n",
        "    chunks\n",
        "    |> Stream.map(&String.trim/1)\n",
        "    |> Stream.reject(&(&1 == \"\"))\n",
        "    |> Enum.into(MDEx.stream())\n",
        "  end\n",
        "end\n",
        "```\n\n",
        "### Python Example\n",
        "```python\n",
        "# Data processing with pandas\n",
        "import pandas as pd\n",
        "import numpy as np\n",
        "\n",
        "def analyze_markdown_usage(files):\n",
        "    \"\"\"Analyze markdown element usage patterns\"\"\"\n",
        "    data = []\n",
        "    for file in files:\n",
        "        with open(file, 'r') as f:\n",
        "            content = f.read()\n",
        "            data.append({\n",
        "                'headings': content.count('#'),\n",
        "                'links': content.count('['),\n",
        "                'code_blocks': content.count('```')\n",
        "            })\n",
        "    return pd.DataFrame(data)\n",
        "```\n\n",
        "## Blockquotes & Callouts\n\n",
        "> **Important No",
        "te**: This is a standard blockquote.\n",
        "> It can span multiple lines and contain *format",
        "ting*.\n",
        "> \n",
        "> > This is a nested blockquote for additional emphasis.\n",
        "> \n",
        "> You can include `co",
        "de` and [links](https://example.com) too!\n\n",
        "> 💡 **Pro Ti",
        "p**: Use meaningful commit messages\n",
        "> when working with version control systems.\n\n",
        "> ⚠️ **Warn",
        "ing**: Always validate user input\n",
        "> before processing in production applications.\n\n",
        "> ✅ **Succ",
        "ess**: CommonMark provides excellent\n",
        "> cross-platform compatibility for documentation.\n\n",
        "## Tables & Data\n\n",
        "### Feature Comparison\n",
        "| Feature | CommonMark | GitHub Flavored | MDEx |\n",
        "|---------|------------|-----------------|------|\n",
        "| Basic formatting | ✅ | ✅ | ✅ |\n",
        "| Tables | ❌ | ✅ | ✅ |\n",
        "| Task lists | ❌ | ✅ | ✅ |\n",
        "| Streaming | ❌ | ❌ | ✅ |\n",
        "| Strikethrough | ❌ | ✅ | ✅ |\n\n",
        "### Performance Metrics\n",
        "| Parser | Speed (docs/sec) | Memory (MB) | File Size |\n",
        "|--------|------------------|-------------|----------|\n",
        "| MDEx | **15,000** | 2.1 | Small |\n",
        "| Alternative A | 8,500 | 4.2 | Medium |\n",
        "| Alternative B | 3,200 | 8.1 | Large |\n\n",
        "### Syntax Elements Coverage\n",
        "| Element | Supported | Example | Notes |\n",
        "|---------|-----------|---------|-------|\n",
        "| Headings | ✅ | `# Title` | 6 levels |\n",
        "| **Bold** | ✅ | `**text**` | Strong emphasis |\n",
        "| *Italic* | ✅ | `*text*` | Emphasis |\n",
        "| `Code` | ✅ | `` `code` `` | Inline code |\n",
        "| Links | ✅ | `[text](url)` | Multiple formats |\n",
        "| Images | ✅ | `![alt](url)` | With alt text |\n",
        "| Lists | ✅ | `- item` | Nested support |\n\n",
        "---\n\n",
        "## Advanced Elements\n\n",
        "### Mathematical Expressions\n",
        "While not part of core CommonMark, many renderers support:\n",
        "- Inline math: E = mc²\n",
        "- Complex formulas: Σ(x₁ + x₂ + ... + xₙ)\n\n",
        "### Special Characters & Escaping\n",
        "You can escape special characters with backslashes:\n",
        "- \\*not italic\\*\n",
        "- \\[not a link\\]\n",
        "- \\`not code\\`\n",
        "- \\# not a heading\n\n",
        "### HTML Integration\n",
        "<div style=\"border: 2px solid #007acc; padding: 16px; border-radius: 8px; background: #f0f8ff;\">\n",
        "  <strong>HTML Block:</strong> CommonMark allows raw HTML for advanced formatting.\n",
        "  You can include <em>inline HTML</em> and <code>complex structures</code>.\n",
        "</div>\n\n",
        "### Definition Lists (Extended)\n",
        "CommonMark\n",
        ": A strongly defined, highly compatible specification of Markdown.\n",
        "\n",
        "MDEx\n",
        ": A fast CommonMark parser and renderer for Elixir, built with Rust.\n",
        "\n",
        "Streaming\n",
        ": Real-time processing of markdown content as it's being generated.\n\n",
        "## Line Breaks & Spacing\n\n",
        "Hard line break (two spaces):  \n",
        "This appears on a new line.\n\n",
        "Soft line break\n",
        "continues the paragraph.\n\n",
        "---\n\n",
        "## Final Thoughts\n\n",
        "This comprehensive demo showcases:\n\n",
        "1. **Complete element coverage** - Every major CommonMark element\n",
        "2. **Realistic chunking** - Simulates natural AI response streaming\n",
        "3. **Practical examples** - Real-world usage patterns\n",
        "4. **Visual variety** - Different content types and structures\n\n",
        "> 🎉 **Success!** You've seen a complete CommonMark demonstration.\n",
        "> This streaming approach makes content feel naturally generated,\n",
        "> perfect for AI chat interfaces and progressive content loading.\n\n",
        "### Resources\n",
        "- [CommonMark Specification](https://commonmark.org/)\n",
        "- [MDEx Documentation](https://hexdocs.pm/mdex/)\n",
        "- [Markdown Guide](https://www.markdownguide.org/)\n\n",
        "---\n\n",
        "*Generated with ❤️ using MDEx streaming capabilities*\n\n",
        "[spec]: https://commonmark.org/spec/"
      ]
    )
  end

  def handle_event("demo_gfm", _params, socket) do
    simulate_streaming(socket, [
      "# GitHub Flavored ",
      "Markdown (GFM) Demo\n\n",
      "Welcome to the **comprehensive** ",
      "GitHub Flavored Markdown showcase! This demo highlights ",
      "all the *special features* that make GFM perfect for ",
      "collaborative development.\n\n",
      "## 📋 Task Lists\n\n",
      "Perfect for tracking project progress:\n\n",
      "### Project Milestones\n",
      "- [x] Set up repository\n",
      "- [x] Create initial ",
      "documentation\n",
      "- [x] Implement core features\n",
      "- [ ] Add comprehensive te",
      "sts\n",
      "- [ ] Performance optimizations\n",
      "- [ ] Deploy to production\n\n",
      "### Bug Fixes\n",
      "- [x] Fix header styling issues\n",
      "- [x] Resolve mobile layout problems\n",
      "- [ ] Address accessibility co",
      "ncerns\n",
      "- [ ] Update documentation\n\n",
      "## 📊 Enhanced Tables\n\n",
      "GitHub supports advanced table formatting:\n\n",
      "### Repository Comparison\n",
      "| Repository | Stars | Language | License | Status |\n",
      "|------------|------:|----------|---------|--------|\n",
      "| MDEx | **2,500** | Elixir | MIT | ✅ Active |\n",
      "| CommonMark | 5,000 | C | BSD | ✅ Stable |\n",
      "| Marked | 32,000 | JavaScript | MIT | ✅ Active |\n",
      "| markdown-it | 17,500 | JavaScript | MIT | ✅ Active |\n\n",
      "### Performance Benchmarks\n",
      "| Parser | Speed (ops/sec) | Memory (MB) | Bundle Size |\n",
      "|--------|----------------:|------------:|------------:|\n",
      "| **MDEx** | **15,000** | **2.1** | **Small** |\n",
      "| Parser A | 8,500 | 4.2 | Medium |\n",
      "| Parser B | 3,200 | 8.1 | Large |\n",
      "| Parser C | 12,000 | 3.5 | Medium |\n\n",
      "## 🎨 Text Styling\n\n",
      "### Basic Formatting\n",
      "- **Bo",
      "ld text** for emphasis\n",
      "- *Ital",
      "ic text* for subtle emphasis\n",
      "- ~~Strike",
      "through~~ for corrections\n",
      "- `inline co",
      "de` for technical terms\n\n",
      "### Advanced Formatting\n",
      "- Combine **bo",
      "ld** and *ital",
      "ic* for ***strong emphasis***\n",
      "- Chemical formulas: H<sub>2</sub>O and E=mc<sup>2</sup>\n",
      "- Keyboard shortcuts: <kbd>Ctrl</kbd>+<kbd>C</kbd>\n\n",
      "## 🔗 Links & References\n\n",
      "### Autolinking\n",
      "GitHub automatically creates links:\n",
      "- URLs: https://github.com/leandrocp/mdex\n",
      "- Emails: hello@github.com\n\n",
      "### Mentions & References\n",
      "- User mentions: @octocat @github\n",
      "- Team mentions: @github/docs-team\n",
      "- Issue references: #42 #123\n",
      "- PR references: #456 #789\n",
      "- Commit SHAs: a1b2c3d4e5f6\n\n",
      "## 💻 Code Examples\n\n",
      "### Syntax Highlighting\n",
      "```elixir\n",
      "# Elixir streaming example\n",
      "defmodule GitHubDemo do\n",
      "  def stream_markdown(chunks) do\n",
      "    chunks\n",
      "    |> Enum.into(MDEx.stream(extension: [tables: true]))\n",
      "    |> Enum.map(&MDEx.to_html!/1)\n",
      "  end\n",
      "end\n",
      "```\n\n",
      "### JavaScript Example\n",
      "```javascript\n",
      "// GitHub API integration\n",
      "async function fetchRepo(owner, repo) {\n",
      "  const response = await fetch(\n",
      "    `https://api.github.com/repos/${owner}/${repo}`\n",
      "  );\n",
      "  \n",
      "  if (!response.ok) {\n",
      "    throw new Error(`HTTP ${response.status}`);\n",
      "  }\n",
      "  \n",
      "  return response.json();\n",
      "}\n",
      "```\n\n",
      "### Shell Commands\n",
      "```bash\n",
      "# Clone and setup\n",
      "git clone https://github.com/leandrocp/mdex.git\n",
      "cd mdex\n",
      "mix deps.get\n",
      "mix test\n",
      "```\n\n",
      "## 😀 Emojis & Icons\n\n",
      "GitHub supports emoji shortcodes:\n",
      "- Emotions: :smile: :heart: :thumbsup: :tada:\n",
      "- Objects: :rocket: :computer: :book: :bulb:\n",
      "- Nature: :tree: :ocean: :sun_with_face: :rainbow:\n",
      "- Symbols: :warning: :information_source: :heavy_check_mark: :x:\n\n",
      "Status indicators:\n",
      "- ✅ Completed\n",
      "- ⚠️ Warning\n",
      "- ❌ Failed\n",
      "- 🔄 In Progress\n",
      "- 📝 Documentation\n",
      "- 🐛 Bug Fix\n",
      "- ✨ New Feature\n\n",
      "## 🎨 Color References\n\n",
      "GitHub renders color values:\n",
      "- Hex colors: `#ff6b6b` `#4ecdc4` `#45b7d1`\n",
      "- RGB colors: `rgb(255, 107, 107)` `rgb(78, 205, 196)`\n",
      "- HSL colors: `hsl(0, 100%, 71%)` `hsl(174, 60%, 55%)`\n\n",
      "### Brand Colors\n",
      "| Brand | Color | Hex Code |\n",
      "|-------|-------|----------|\n",
      "| GitHub | `#24292f` | Dark Gray |\n",
      "| Success | `#1a7f37` | Green |\n",
      "| Warning | `#d1242f` | Red |\n",
      "| Info | `#0969da` | Blue |\n\n",
      "## 💬 Blockquotes & Callouts\n\n",
      "> **Note**: This is a standard blockquote\n",
      "> that can span multiple lines and include\n",
      "> *formatting* and `code`.\n\n",
      "> [!NOTE]\n",
      "> Useful information that users should know,\n",
      "> even when skimming content.\n\n",
      "> [!TIP]\n",
      "> Helpful advice for doing things better\n",
      "> or more easily.\n\n",
      "> [!IMPORTANT]\n",
      "> Key information users need to know\n",
      "> to achieve their goal.\n\n",
      "> [!WARNING]\n",
      "> Urgent info that needs immediate\n",
      "> user attention to avoid problems.\n\n",
      "> [!CAUTION]\n",
      "> Advises about risks or negative outcomes\n",
      "> of certain actions.\n\n",
      "## 📁 Collapsible Sections\n\n",
      "<details>\n",
      "<summary>📊 Detailed Performance Metrics</summary>\n\n",
      "### Memory Usage Analysis\n",
      "| Operation | Memory (MB) | Time (ms) |\n",
      "|-----------|-------------|----------|\n",
      "| Parse | 1.2 | 15 |\n",
      "| Render | 0.8 | 8 |\n",
      "| Stream | 0.5 | 3 |\n\n",
      "### CPU Utilization\n",
      "- Parsing: 23% average\n",
      "- Rendering: 15% average\n",
      "- Streaming: 8% average\n",
      "</details>\n\n",
      "<details open>\n",
      "<summary>🔧 Configuration Options</summary>\n\n",
      "```elixir\n",
      "@mdex_options [\n",
      "  extension: [\n",
      "    autolink: true,\n",
      "    strikethrough: true,\n",
      "    table: true,\n",
      "    tasklist: true\n",
      "  ]\n",
      "]\n",
      "```\n",
      "</details>\n\n",
      "## 📐 Math & Formulas\n\n",
      "### Inline Math\n",
      "The quadratic formula is $x = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}$\n\n",
      "### Block Math\n",
      "$$\n",
      "\\begin{aligned}\n",
      "\\nabla \\times \\vec{\\mathbf{B}} -\\, \\frac1c\\, \\frac{\\partial\\vec{\\mathbf{E}}}{\\partial t} &= \\frac{4\\pi}{c}\\vec{\\mathbf{j}} \\\\\n",
      "\\nabla \\cdot \\vec{\\mathbf{E}} &= 4 \\pi \\rho \\\\\n",
      "\\nabla \\times \\vec{\\mathbf{E}}\\, +\\, \\frac1c\\, \\frac{\\partial\\vec{\\mathbf{B}}}{\\partial t} &= \\vec{\\mathbf{0}} \\\\\n",
      "\\nabla \\cdot \\vec{\\mathbf{B}} &= 0\n",
      "\\end{aligned}\n",
      "$$\n\n",
      "## 🏗️ Complex Structures\n\n",
      "### Nested Task Lists\n",
      "- [x] **Phase 1: Foundation**\n",
      "  - [x] Project setup\n",
      "  - [x] Basic structure\n",
      "  - [x] Initial tests\n",
      "- [ ] **Phase 2: Development**\n",
      "  - [x] Core features\n",
      "  - [ ] Advanced features\n",
      "    - [x] Streaming support\n",
      "    - [ ] Performance optimization\n",
      "    - [ ] Memory management\n",
      "  - [ ] Documentation\n",
      "- [ ] **Phase 3: Release**\n",
      "  - [ ] Final testing\n",
      "  - [ ] Security audit\n",
      "  - [ ] Production deployment\n\n",
      "### Mixed Content Lists\n",
      "1. **Setup Instructions**\n",
      "   \n",
      "   ```bash\n",
      "   git clone repo\n",
      "   cd repo\n",
      "   ```\n",
      "   \n",
      "2. **Configuration**\n",
      "   \n",
      "   | Option | Value | Description |\n",
      "   |--------|-------|-------------|\n",
      "   | debug | true | Enable debug mode |\n",
      "   | port | 4000 | Server port |\n",
      "   \n",
      "3. **Start Development**\n",
      "   \n",
      "   > :bulb: **Tip**: Use `mix phx.server` for live reloading\n\n",
      "---\n\n",
      "## 🎯 Summary\n\n",
      "This comprehensive demo showcases:\n\n",
      "✅ **Task lists** for project management\n",
      "✅ **Enhanced tables** with alignment\n",
      "✅ **Advanced formatting** options\n",
      "✅ **Code syntax** highlighting\n",
      "✅ **Emoji support** for better UX\n",
      "✅ **Mentions & references** for collaboration\n",
      "✅ **Collapsible sections** for organization\n",
      "✅ **Math formulas** for technical docs\n",
      "✅ **Color references** for design\n\n",
      "> 🚀 **GitHub Flavored Markdown** provides everything needed\n",
      "> for professional documentation, issue tracking, and\n",
      "> collaborative development workflows!\n\n",
      "*Generated with :heart: using MDEx streaming + GFM extensions*"
    ])
  end

  def handle_event("demo_ai_response", _params, socket) do
    simulate_streaming(socket, [
      "# ",
      "Stre",
      "ami",
      "ng Mu",
      "sic ",
      "App",
      " w",
      "ith ",
      "Phone",
      "ix ",
      "Live",
      "Vi",
      "ew

:rocket:",
      " La",
      "unch",
      " a",
      " col",
      "lab",
      "orati",
      "ve l",
      "ist",
      "en",
      "ing ",
      "room ",
      "with",
      "h re",
      "al",
      "-time",
      " di",
      "ffs ",
      "dr",
      "iven",
      " by",
      " `Phoenix LiveView`",
      ".

#",
      "# W",
      "hy",
      " Liv",
      "eView",
      " Fi",
      "ts

",
      "Ph",
      "oenix",
      " Li",
      "veVi",
      "ew",
      " kee",
      "ps ",
      "the r",
      "end",
      "r p",
      "ip",
      "elin",
      "e on ",
      "the",
      " set",
      "ve",
      "r, le",
      "tti",
      "ng s",
      "ta",
      "te c",
      "han",
      "ges p",
      "ush ",
      "eff",
      "ic",
      "ient",
      " patc",
      "hes",
      " int",
      "o ",
      "the s",
      "ess",
      "ion.",
      " T",
      "his ",
      "mea",
      "ns li",
      "sten",
      "ers",
      " e",
      "njoy",
      " resp",
      "owns",
      "ive ",
      "up",
      "dates",
      " wi",
      "thou",
      "t ",
      "cust",
      "om ",
      "JavaS",
      "crip",
      "t, ",
      "ye",
      "t yo",
      "u ret",
      "ain",
      " dec",
      "la",
      "rativ",
      "e E",
      "lixi",
      "r ",
      "code",
      ".

",
      "### E",
      "xper",
      "ien",
      "ce",
      " Goa",
      "ls

-",
      " :notes:",
      " Sea",
      "ml",
      "ess s",
      "tree",
      "amin",
      "g ",
      "cont",
      "rol",
      "s
- :headphones:",
      " Sha",
      "red",
      " q",
      "ueue",
      " awar",
      "ene",
      "ss
-",
      " :sparkles:",
      " Anim",
      "ate",
      "d fe",
      "ed",
      "back",
      " wi",
      "thout",
      " pag",
      "e r",
      "el",
      "oad
",
      "- :musical_keyboard:",
      " Ke",
      "yboa",
      "rd",
      " shor",
      "tcu",
      "ts f",
      "or",
      " pow",
      "er ",
      "users",
      "

##",
      "# T",
      "as",
      "k Bo",
      "ard

",
      "- [",
      "x] I",
      "ni",
      "tiali",
      "ze ",
      "proj",
      "ec",
      "t sc",
      "aff",
      "oldin",
      "g
- ",
      "[ ]",
      " W",
      "ire ",
      "up Li",
      "veV",
      "iew ",
      "ro",
      "utes
",
      "- [",
      " ] C",
      "on",
      "next",
      " to",
      " the ",
      "audi",
      "o b",
      "ac",
      "kind",
      "
- [ ",
      "] S",
      "tyle",
      " t",
      "he li",
      "ste",
      "ning",
      " r",
      "oom
",
      "- [",
      " ] Pu",
      "blis",
      "h r",
      "ea",
      "l-ti",
      "me me",
      "tri",
      "cs d",
      "as",
      "hboar",
      "d

",
      "## A",
      "rc",
      "hite",
      "ctu",
      "re Sn",
      "apsh",
      "ot
",
      "
|",
      " Lay",
      "er | ",
      "Res",
      "pons",
      "ib",
      "ility",
      " | ",
      "Live",
      "Vi",
      "ew H",
      "ook",
      " |
| ",
      "--- ",
      "| -",
      "--",
      " | -",
      "-- |
",
      "| L",
      "iveV",
      "ie",
      "w | S",
      "tat",
      "eful",
      " U",
      "I pr",
      "oce",
      "ss | ",
      "moun",
      "t /",
      " h",
      "andl",
      "e_eve",
      "nt ",
      "|
| ",
      "Pu",
      "bSub ",
      "| B",
      "road",
      "ca",
      "st t",
      "rac",
      "k eve",
      "nts ",
      "| P",
      "ho",
      "enix",
      ".PubS",
      "ub ",
      "|
| ",
      "Co",
      "ntext",
      " | ",
      "Busi",
      "ne",
      "ss l",
      "ogi",
      "c | S",
      "trea",
      "mMu",
      "si",
      "c.Li",
      "brary",
      " |
",
      "| Pr",
      "es",
      "ence ",
      "| L",
      "iste",
      "ne",
      "r ro",
      "ste",
      "r tra",
      "ckin",
      "g |",
      " P",
      "hoen",
      "ix.Pr",
      "ese",
      "nce ",
      "|
",
      "| Dat",
      "a |",
      " Per",
      "si",
      "sten",
      "t p",
      "layli",
      "sts ",
      "| E",
      "ct",
      "o sc",
      "hemas",
      " |
",
      "
## ",
      "Se",
      "tup C",
      "omm",
      "and",
      "

",
      "```bash
mix phx.new stream_music --live
cd stream_music
mix deps.get
mix ecto.create
mix assets.deploy
`",
      "``

## LiveView Outline

`",
      "``elixir
defmodule StreamMusicWeb.PlayerLive do
  use StreamMusicWeb, :live_view
  alias Phoenix.PubSub
  @topic \"stream_music:queue\"
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(StreamMusic.PubSub, @topic)
    end
    {:ok, assign(socket, playlist: [], now_playing: nil, search: \"\", volume: 60, listeners: %{})}
  end
  def handle_event(\"search\", %{\"query\" => query}, socket) do
    {:noreply, assign(socket, search: query)}
  end
  def handle_event(\"queue\", %{\"track\" => track}, socket) do
    Phoenix.PubSub.broadcast(StreamMusic.PubSub, @topic, {:queue, track})
    {:noreply, update(socket, :playlist, fn list -> list ++ [track] end)}
  end
  def handle_event(\"play\", %{\"track\" => track}, socket) do
    Phoenix.PubSub.broadcast(StreamMusic.PubSub, @topic, {:play, track})
    {:noreply, assign(socket, now_playing: track)}
  end
  def handle_info({:queue, track}, socket) do
    {:noreply, update(socket, :playlist, fn list -> list ++ [track] end)}
  end
  def handle_info({:play, track}, socket) do
    {:noreply, assign(socket, now_playing: track)}
  end
end
`",
      "``

### Progressive Streaming

LiveViews start with a static render before upgrading to the persistent connection, so first meaningful paint stays fast while future updates travel over a single channel.

## Interaction Flow

1. Visitor opens the lobby and receives the rendered `",
      "Pla",
      "ye",
      "rLiv",
      "e`.
2. `",
      "mou",
      "nt/3",
      "` seeds assigns with playlist snapshots.
3. Track searches call `",
      "handl",
      "e_e",
      "vent",
      "/3",
      "` to refine results.
4. Queue updates broadcast through PubSub and hydrate everyone.
5. Presence diff pushes listener join or leave events.

### Playlist Signals

- **Now Playing**: highlight the active track and waveform
- **Queue**: show pending entries with avatars
- **History**: list completed tracks for replay fans

### Data Model

| Entity | Fields | Purpose |
| --- | --- | --- |
| Track | title, artist, duration, source_url | Primary media unit |
| Room | slug, theme, description | Group listening context |
| Listener | handle, avatar_url, status | Presence representation |
| Vote | listener_id, track_id, score | Lightweight reactions |

### Commands for Library Context

Run the generator to scaffold data boundaries:

- `",
      "mix",
      " phx.",
      "gen.",
      "liv",
      "e ",
      "Libr",
      "ary T",
      "rac",
      "k tr",
      "ac",
      "ks ti",
      "tle",
      ":str",
      "in",
      "g ar",
      "tis",
      "t:str",
      "ing ",
      "dur",
      "at",
      "ion:",
      "integ",
      "er ",
      "sour",
      "ce",
      "_url:",
      "str",
      "ing`
- `",
      "mi",
      "x ph",
      "x.g",
      "en.sc",
      "hema",
      " Li",
      "br",
      "ary.",
      "Room ",
      "roo",
      "ms s",
      "lu",
      "g:str",
      "ing",
      " the",
      "me",
      ":str",
      "ing",
      " desc",
      "ript",
      "ion",
      ":t",
      "ext`

### Queue Feedback

| Event | LiveView Callback | Outcome |
| --- | --- | --- |
| Search query | handle_event \"search\" | Update suggestions |
| Queue track | handle_event \"queue\" | Append playlist |
| Play track | handle_event \"play\" | Change headline state |
| Presence diff | handle_info {:presence_diff, diff} | Refresh listener list |
| Track finished | handle_info {:playback_done, track} | Rotate playlist |

### Listener Journey

- Enter lobby and see :headphones: welcome banner
- Use instant search to find a favorite song
- Add the track to the collaborative queue
- Watch :rocket: transitions as the now playing card updates
- React with inline emoji to celebrate the vibe

## Real-Time Considerations

- Keep assigns minimal to avoid large diffs
- Stream lists with `",
      "Phone",
      "ix.",
      "Live",
      "Vi",
      "ew.st",
      "rea",
      "m/4` for scalable queues
- Push events with `",
      "pu",
      "sh_e",
      "ven",
      "t/3` for waveform animations
- Use `",
      "temp",
      "ora",
      "ry",
      "_ass",
      "igns` to discard transient payloads
- Balance updates between server broadcasts and client hooks

## Metrics and Observability

:bar_chart: Track key indicators with Telemetry and dashboards.

| Metric | Tooling | Frequency |
| --- | --- | --- |
| Concurrent listeners | Telemetry.Metrics | 5s |
| Track skips | LiveView handle_event counts | 10s |
| Average session length | Database view | 60s |
| Queue depth | Stream instrumentation | 5s |

### Deployment Notes

- Configure CDN edge caching for artwork
- Enable `",
      "liv",
      "e_se",
      "ss",
      "ion` ",
      "rou",
      "tes ",
      "fo",
      "r au",
      "the",
      "ntica",
      "tion",
      "
- ",
      "Tu",
      "ne W",
      "ebSoc",
      "ket",
      " poo",
      "l ",
      "size ",
      "for",
      " exp",
      "ec",
      "ted ",
      "roo",
      "ms
- ",
      "Leve",
      "rag",
      "e ",
      "clus",
      "tered",
      " no",
      "des ",
      "fo",
      "r res",
      "ili",
      "ent ",
      "Pu",
      "bSub",
      "

#",
      "# Nex",
      "t St",
      "eps",
      "

",
      "1. F",
      "inali",
      "ze ",
      "UI p",
      "ol",
      "ish i",
      "n T",
      "ailw",
      "in",
      "d co",
      "mpo",
      "nents",
      "
2. ",
      "Int",
      "eg",
      "rate",
      " paym",
      "ent",
      " tie",
      "rs",
      " for ",
      "pre",
      "mium",
      " r",
      "ooms",
      "
3.",
      " Add ",
      "offl",
      "one",
      " f",
      "allb",
      "acks ",
      "whe",
      "n co",
      "nn",
      "ectio",
      "n d",
      "rops",
      "
4",
      ". Ex",
      "ten",
      "d ana",
      "lyti",
      "cs ",
      "pi",
      "peli",
      "ne fo",
      "r r",
      "eten",
      "ti",
      "on in",
      "sig",
      "hts
",
      "
#",
      "## C",
      "ele",
      "brati",
      "on

",
      "Wra",
      "p ",
      "the ",
      "launc",
      "h w",
      "ith ",
      ":tada:",
      " play",
      "lis",
      "ts a",
      "and",
      " a :musical_note:",
      " re",
      "lease",
      " par",
      "ty!",
      "
"
    ])
  end

  def handle_event("clear", _params, socket) do
    socket
    |> assign(
      document: MDEx.new(@mdex_options),
      chunks: [],
      html: "",
      streaming: false,
      current_chunk: 0,
      total_chunks: 0,
      stream_ref: nil
    )
    |> then(&{:noreply, &1})
  end

  def handle_event("update_speed", %{"speed" => speed}, socket) do
    actual_speed = 1001 - String.to_integer(speed)
    {:noreply, assign(socket, :speed, actual_speed)}
  end

  def handle_event("update_chunk_position", _params, %{assigns: %{streaming: true}} = socket) do
    {:noreply, socket}
  end

  def handle_event("update_chunk_position", %{"position" => position}, socket) do
    position = String.to_integer(position)
    {:noreply, update_position(socket, position)}
  end

  def handle_event("prev_chunk", _params, %{assigns: %{streaming: false}} = socket) do
    pos = max(socket.assigns.current_chunk - 1, 0)
    {:noreply, update_position(socket, pos)}
  end

  def handle_event("prev_chunk", _params, socket), do: {:noreply, socket}

  def handle_event("next_chunk", _params, %{assigns: %{streaming: false}} = socket) do
    pos = min(socket.assigns.current_chunk + 1, socket.assigns.total_chunks)
    {:noreply, update_position(socket, pos)}
  end

  def handle_event("next_chunk", _params, socket), do: {:noreply, socket}

  def handle_event("key_nav", %{"key" => key}, socket) do
    case key do
      "ArrowLeft" ->
        if socket.assigns.streaming, do: {:noreply, socket}, else: {:noreply, update_position(socket, max(socket.assigns.current_chunk - 1, 0))}

      "ArrowRight" ->
        if socket.assigns.streaming,
          do: {:noreply, socket},
          else: {:noreply, update_position(socket, min(socket.assigns.current_chunk + 1, socket.assigns.total_chunks))}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_info({:stream_chunk, ref, chunk}, %{assigns: %{stream_ref: ref}} = socket) do
    document = Enum.into([chunk], socket.assigns.document)
    html = html_from(document)

    socket =
      socket
      |> update(:chunks, fn chunks -> chunks ++ [chunk] end)
      |> assign(:document, document)
      |> assign(:html, html)
      |> update(:current_chunk, &(&1 + 1))

    {:noreply, socket}
  end

  def handle_info({:stream_chunk, _ref, _chunk}, socket), do: {:noreply, socket}

  def handle_info({:streaming_complete, ref}, %{assigns: %{stream_ref: ref}} = socket) do
    {:noreply, assign(socket, :streaming, false)}
  end

  def handle_info({:streaming_complete, _ref}, socket), do: {:noreply, socket}

  defp simulate_streaming(socket, chunks) do
    speed = socket.assigns.speed
    total_chunks = Enum.count(chunks)
    stream_ref = make_ref()
    parent = self()

    Task.start(fn ->
      chunks
      |> Stream.each(fn chunk ->
        Process.sleep(speed)
        send(parent, {:stream_chunk, stream_ref, chunk})
      end)
      |> Stream.run()

      send(parent, {:streaming_complete, stream_ref})
    end)

    updated_socket =
      assign(socket, %{
        document: MDEx.new(@mdex_options),
        chunks: [],
        html: "",
        streaming: true,
        speed: speed,
        current_chunk: 0,
        total_chunks: total_chunks,
        stream_ref: stream_ref
      })

    {:noreply, updated_socket}
  end

  defp update_position(socket, position) do
    available_chunks = length(socket.assigns.chunks)

    position =
      position
      |> min(socket.assigns.total_chunks)
      |> max(0)
      |> min(available_chunks)

    chunks = Enum.take(socket.assigns.chunks, position)
    document = rebuild_document(chunks)
    html = html_from(document)

    assign(socket, %{
      current_chunk: position,
      document: document,
      html: html
    })
  end

  defp rebuild_document(chunks) do
    Enum.into(chunks, MDEx.new(@mdex_options))
  end

  defp html_from(%MDEx.Document{} = document), do: MDEx.to_html!(document, @mdex_options)
end

defmodule DemoRouter do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:put_root_layout, html: {DemoLayout, :root})
    plug(:put_secure_browser_headers)
  end

  scope "/" do
    pipe_through(:browser)
    live("/", StreamingDemo)
  end
end

PhoenixPlayground.start(plug: DemoRouter, open_browser: true)
