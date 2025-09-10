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
        <title>MDEx Streaming Demo</title>
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
          <pre class="bg-gray-50 dark:bg-gray-900 rounded-lg p-4 text-[12px] overflow-x-auto text-gray-900 dark:text-gray-100 max-h-[70vh] overflow-y-auto"><%= inspect(@stream.document, pretty: true, limit: :infinity, printable_limit: :infinity) %></pre>
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
       stream: MDEx.stream(@mdex_options),
       chunks: [],
       all_chunks: [],
       html: "",
       streaming: false,
       speed: 100,
       current_chunk: 0,
       total_chunks: 0
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-50 to-white dark:from-slate-950 dark:to-slate-900" phx-window-keydown="key_nav">
      <div class="max-w-7xl mx-auto px-8 py-8">
        <div class="text-center mb-12">
          <h1 class="text-3xl md:text-4xl font-semibold tracking-tight text-gray-900 dark:text-white mb-3">
            MDEx Streaming Demo
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
                  <div :if={length(@all_chunks) > 0} class="space-y-3">
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
          <.live_component module={ChunksPanel} id="chunks-panel" chunks={@chunks} />
          <.live_component module={AstPanel} id="ast-panel" stream={@stream} />
        </div>
      </div>
    </div>
    """
  end

  def handle_event("demo_readme", _params, socket) do
    # chunks = [
    #   "# MDEx\n\n",
    #   "High-performance CommonMark for Elixir.\n\n",
    #   "## 🔧 Basic Usage\n\n",
    #   "Here's how to parse Markdown with MDEx:\n\n",
    #   "```elixir\n",
    #   "# Parse a complete document\n",
    #   "markdown = \"# Hello World\\n\\nThis is **bold** text.\"\n",
    #   "{:ok, document} = MDEx.parse_document(markdown)\n\n",
    #   "# Convert to HTML\n",
    #   "html = MDEx.to_html!(document)\n",
    #   "# => \"<h1>Hello World</h1><p>This is <strong>bold</strong> text.</p>\"\n\n",
    #   "# Parse fragments for streaming\n",
    #   "{:ok, fragment} = MDEx.parse_fragment(\"**incomplete\")\n",
    #   "```\n\n",
    #   "## 🌊 Streaming Example\n\n",
    #   "The streaming API allows real-time processing:\n\n",
    #   "```elixir\n",
    #   "# Create a stream\n",
    #   "stream = MDEx.stream()\n\n",
    #   "# Collect chunks\n",
    #   "chunks = [\"# Title\\n\\n\", \"Some **bold** text\"]\n",
    #   "result = Enum.into(chunks, stream)\n\n",
    #   "# Enumerate nodes\n",
    #   "result\n",
    #   "|> Enum.map(&MDEx.to_html!/1)\n",
    #   "|> Enum.join(\"\")\n",
    #   "```\n\n",
    #   "> 💡 **Tip**: Use `MDEx.stream/0` for progressive rendering of large documents.\n"
    # ]

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

    simulate_streaming(chunks, socket)
  end

  def handle_event("demo_commonmark", _params, socket) do
    chunks = [
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

    simulate_streaming(chunks, socket)
  end

  def handle_event("demo_gfm", _params, socket) do
    chunks = [
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
    ]

    simulate_streaming(chunks, socket)
  end

  def handle_event("demo_ai_response", _params, socket) do
    chunks = [
      "# Creating a Programming Language from Scratch\n\n",
      "Building your own programming language is one of the most ",
      "**rewarding challenges** in computer science! Let me guide you through ",
      "this fascinating journey step by step.\n\n",
      "## 🎯 Overview\n\n",
      "Creating a programming language involves several key phases:\n\n",
      "1. **Design** - Define syntax and semantics\n",
      "2. **Lexical Analysis** - Tokenization\n",
      "3. **Parsing** - Build Abstract Syntax Tree (AST)\n",
      "4. **Semantic Analysis** - Type checking and validation\n",
      "5. **Code Generation** - Compile or interpret\n",
      "6. **Runtime** - Execution environment\n\n",
      "> 💡 **Pro Tip**: Start simple! Even the most complex languages ",
      "began with basic arithmetic expressions.\n\n",
      "## 🔧 Phase 1: Language Design\n\n",
      "First, let's design our language called **\"Lumina\"**. Here's what ",
      "we'll support:\n\n",
      "### Core Features\n",
      "- [x] Variables and assignment\n",
      "- [x] Arithmetic operations (`+`, `-`, `*`, `/`)\n",
      "- [x] Control flow (`if`, `while`, `for`)\n",
      "- [x] Functions with parameters\n",
      "- [x] Basic data types (numbers, strings, booleans)\n",
      "- [ ] Objects and classes *(future version)*\n",
      "- [ ] Modules and imports *(future version)*\n\n",
      "### Syntax Example\n",
      "```lumina\n",
      "// Variables\n",
      "let name = \"Alice\"\n",
      "let age = 25\n",
      "let isStudent = true\n\n",
      "// Functions\n",
      "fn greet(person) {\n",
      "    return \"Hello, \" + person + \"!\"\n",
      "}\n\n",
      "// Control flow\n",
      "if age >= 18 {\n",
      "    print(greet(name))\n",
      "} else {\n",
      "    print(\"Too young!\")\n",
      "}\n",
      "```\n\n",
      "## 🔍 Phase 2: Lexical Analysis (Tokenizer)\n\n",
      "The lexer breaks source code into **tokens**. Here's our implementation:\n\n",
      "```rust\n",
      "#[derive(Debug, Clone, PartialEq)]\n",
      "pub enum TokenType {\n",
      "    // Literals\n",
      "    Number(f64),\n",
      "    String(String),\n",
      "    Boolean(bool),\n",
      "    Identifier(String),\n\n",
      "    // Keywords\n",
      "    Let, Fn, If, Else, While, For,\n",
      "    Return, True, False,\n\n",
      "    // Operators\n",
      "    Plus, Minus, Star, Slash,\n",
      "    Equal, EqualEqual, Bang, BangEqual,\n",
      "    Greater, GreaterEqual, Less, LessEqual,\n\n",
      "    // Delimiters\n",
      "    LeftParen, RightParen,\n",
      "    LeftBrace, RightBrace,\n",
      "    Comma, Semicolon,\n\n",
      "    // Special\n",
      "    Newline, Eof,\n",
      "}\n\n",
      "pub struct Token {\n",
      "    pub token_type: TokenType,\n",
      "    pub lexeme: String,\n",
      "    pub line: usize,\n",
      "    pub column: usize,\n",
      "}\n",
      "```\n\n",
      "### Key Tokenizer Features\n",
      "| Feature | Implementation | Example |\n",
      "| ------- | -------------- | ------- |\n",
      "| Numbers | Regex: `\\d+(\\.\\d+)?` | `42`, `3.14` |\n",
      "| Strings | Delimited by `\"` | `\"Hello World\"` |\n",
      "| Identifiers | Regex: `[a-zA-Z_][a-zA-Z0-9_]*` | `myVar`, `_private` |\n",
      "| Keywords | Reserved words | `let`, `fn`, `if` |\n",
      "| Comments | `//` to end of line | `// This is a comment` |\n\n",
      "```rust\n",
      "impl Lexer {\n",
      "    pub fn tokenize(&mut self, source: &str) -> Result<Vec<Token>, LexError> {\n",
      "        let mut tokens = Vec::new();\n",
      "        let mut chars = source.char_indices().peekable();\n\n",
      "        while let Some((pos, ch)) = chars.next() {\n",
      "            match ch {\n",
      "                ' ' | '\\r' | '\\t' => continue,\n",
      "                '\\n' => {\n",
      "                    tokens.push(Token::new(TokenType::Newline, pos));\n",
      "                    self.line += 1;\n",
      "                    self.column = 1;\n",
      "                }\n",
      "                '+' => tokens.push(Token::new(TokenType::Plus, pos)),\n",
      "                '-' => tokens.push(Token::new(TokenType::Minus, pos)),\n",
      "                '*' => tokens.push(Token::new(TokenType::Star, pos)),\n",
      "                '/' => {\n",
      "                    if chars.peek() == Some(&(pos + 1, '/')) {\n",
      "                        // Skip comment line\n",
      "                        while let Some((_, ch)) = chars.next() {\n",
      "                            if ch == '\\n' break;\n",
      "                        }\n",
      "                    } else {\n",
      "                        tokens.push(Token::new(TokenType::Slash, pos));\n",
      "                    }\n",
      "                }\n",
      "                // ... more cases\n",
      "            }\n",
      "        }\n\n",
      "        tokens.push(Token::new(TokenType::Eof, source.len()));\n",
      "        Ok(tokens)\n",
      "    }\n",
      "}\n",
      "```\n\n",
      "## 🌳 Phase 3: Parser (AST Construction)\n\n",
      "The parser builds an **Abstract Syntax Tree** from tokens using ",
      "recursive descent parsing:\n\n",
      "```rust\n",
      "#[derive(Debug, Clone)]\n",
      "pub enum Expr {\n",
      "    Binary {\n",
      "        left: Box<Expr>,\n",
      "        operator: TokenType,\n",
      "        right: Box<Expr>,\n",
      "    },\n",
      "    Unary {\n",
      "        operator: TokenType,\n",
      "        right: Box<Expr>,\n",
      "    },\n",
      "    Literal(LiteralValue),\n",
      "    Variable(String),\n",
      "    Call {\n",
      "        callee: Box<Expr>,\n",
      "        arguments: Vec<Expr>,\n",
      "    },\n",
      "}\n\n",
      "#[derive(Debug, Clone)]\n",
      "pub enum Stmt {\n",
      "    Expression(Expr),\n",
      "    Let {\n",
      "        name: String,\n",
      "        initializer: Option<Expr>,\n",
      "    },\n",
      "    Function {\n",
      "        name: String,\n",
      "        params: Vec<String>,\n",
      "        body: Vec<Stmt>,\n",
      "    },\n",
      "    If {\n",
      "        condition: Expr,\n",
      "        then_branch: Box<Stmt>,\n",
      "        else_branch: Option<Box<Stmt>>,\n",
      "    },\n",
      "    While {\n",
      "        condition: Expr,\n",
      "        body: Box<Stmt>,\n",
      "    },\n",
      "    Return(Option<Expr>),\n",
      "    Block(Vec<Stmt>),\n",
      "}\n",
      "```\n\n",
      "### Grammar Rules\n",
      "Our parser follows this grammar (in EBNF):\n\n",
      "```ebnf\n",
      "program        → statement* EOF ;\n",
      "statement      → letStmt | fnStmt | ifStmt | whileStmt \n",
      "               | returnStmt | blockStmt | exprStmt ;\n",
      "letStmt        → \"let\" IDENTIFIER ( \"=\" expression )? \";\" ;\n",
      "fnStmt         → \"fn\" IDENTIFIER \"(\" parameters? \")\" block ;\n",
      "parameters     → IDENTIFIER ( \",\" IDENTIFIER )* ;\n",
      "ifStmt         → \"if\" expression block ( \"else\" block )? ;\n",
      "whileStmt      → \"while\" expression block ;\n",
      "returnStmt     → \"return\" expression? \";\" ;\n",
      "blockStmt      → \"{\" statement* \"}\" ;\n",
      "exprStmt       → expression \";\" ;\n\n",
      "expression     → assignment ;\n",
      "assignment     → IDENTIFIER \"=\" assignment | logicOr ;\n",
      "logicOr        → logicAnd ( \"||\" logicAnd )* ;\n",
      "logicAnd       → equality ( \"&&\" equality )* ;\n",
      "equality       → comparison ( ( \"==\" | \"!=\" ) comparison )* ;\n",
      "comparison     → term ( ( \">\" | \">=\" | \"<\" | \"<=\" ) term )* ;\n",
      "term           → factor ( ( \"+\" | \"-\" ) factor )* ;\n",
      "factor         → unary ( ( \"*\" | \"/\" ) unary )* ;\n",
      "unary          → ( \"!\" | \"-\" ) unary | call ;\n",
      "call           → primary ( \"(\" arguments? \")\" )* ;\n",
      "arguments      → expression ( \",\" expression )* ;\n",
      "primary        → NUMBER | STRING | \"true\" | \"false\" \n",
      "               | IDENTIFIER | \"(\" expression \")\" ;\n",
      "```\n\n",
      "### Parser Implementation\n",
      "```rust\n",
      "impl Parser {\n",
      "    fn expression(&mut self) -> Result<Expr, ParseError> {\n",
      "        self.assignment()\n",
      "    }\n\n",
      "    fn assignment(&mut self) -> Result<Expr, ParseError> {\n",
      "        let expr = self.logic_or()?;\n\n",
      "        if self.match_token(&TokenType::Equal) {\n",
      "            let value = self.assignment()?;\n",
      "            if let Expr::Variable(name) = expr {\n",
      "                return Ok(Expr::Assign {\n",
      "                    name,\n",
      "                    value: Box::new(value),\n",
      "                });\n",
      "            }\n",
      "            return Err(ParseError::InvalidAssignmentTarget);\n",
      "        }\n\n",
      "        Ok(expr)\n",
      "    }\n\n",
      "    fn binary_expr(&mut self, \n",
      "                   mut parse_fn: impl FnMut(&mut Self) -> Result<Expr, ParseError>,\n",
      "                   operators: &[TokenType]) -> Result<Expr, ParseError> {\n",
      "        let mut expr = parse_fn(self)?;\n\n",
      "        while let Some(operator) = self.match_tokens(operators) {\n",
      "            let right = parse_fn(self)?;\n",
      "            expr = Expr::Binary {\n",
      "                left: Box::new(expr),\n",
      "                operator,\n",
      "                right: Box::new(right),\n",
      "            };\n",
      "        }\n\n",
      "        Ok(expr)\n",
      "    }\n",
      "}\n",
      "```\n\n",
      "## 🔬 Phase 4: Semantic Analysis\n\n",
      "Before execution, we need to validate the program:\n\n",
      "### Type Checking System\n",
      "```rust\n",
      "#[derive(Debug, Clone, PartialEq)]\n",
      "pub enum Type {\n",
      "    Number,\n",
      "    String,\n",
      "    Boolean,\n",
      "    Function {\n",
      "        params: Vec<Type>,\n",
      "        return_type: Box<Type>,\n",
      "    },\n",
      "    Void,\n",
      "    Unknown,\n",
      "}\n\n",
      "pub struct TypeChecker {\n",
      "    scopes: Vec<HashMap<String, Type>>,\n",
      "    current_function: Option<Type>,\n",
      "}\n\n",
      "impl TypeChecker {\n",
      "    pub fn check_program(&mut self, stmts: &[Stmt]) -> Result<(), TypeError> {\n",
      "        self.begin_scope();\n",
      "        \n",
      "        for stmt in stmts {\n",
      "            self.check_statement(stmt)?;\n",
      "        }\n",
      "        \n",
      "        self.end_scope();\n",
      "        Ok(())\n",
      "    }\n\n",
      "    fn check_binary_expr(&mut self, \n",
      "                         left: &Expr, \n",
      "                         op: &TokenType, \n",
      "                         right: &Expr) -> Result<Type, TypeError> {\n",
      "        let left_type = self.check_expression(left)?;\n",
      "        let right_type = self.check_expression(right)?;\n\n",
      "        match (op, &left_type, &right_type) {\n",
      "            (TokenType::Plus, Type::Number, Type::Number) => Ok(Type::Number),\n",
      "            (TokenType::Plus, Type::String, Type::String) => Ok(Type::String),\n",
      "            (TokenType::Minus | TokenType::Star | TokenType::Slash, \n",
      "             Type::Number, Type::Number) => Ok(Type::Number),\n",
      "            (TokenType::EqualEqual | TokenType::BangEqual, _, _) \n",
      "                if left_type == right_type => Ok(Type::Boolean),\n",
      "            (TokenType::Greater | TokenType::GreaterEqual | \n",
      "             TokenType::Less | TokenType::LessEqual,\n",
      "             Type::Number, Type::Number) => Ok(Type::Boolean),\n",
      "            _ => Err(TypeError::IncompatibleTypes {\n",
      "                expected: left_type,\n",
      "                found: right_type,\n",
      "                operation: format!(\"{:?}\", op),\n",
      "            }),\n",
      "        }\n",
      "    }\n",
      "}\n",
      "```\n\n",
      "### Error Detection\n",
      "Our semantic analyzer catches common errors:\n\n",
      "- **Undefined variables**: `print(unknownVar)` ❌\n",
      "- **Type mismatches**: `\"hello\" + 42` ❌\n",
      "- **Invalid operations**: `true * false` ❌\n",
      "- **Return outside function**: `return 42` ❌\n",
      "- **Wrong argument count**: `fn add(a, b) {...}; add(1)` ❌\n\n",
      "## ⚡ Phase 5: Interpreter (Tree-Walking)\n\n",
      "For our first implementation, we'll use a **tree-walking interpreter**:\n\n",
      "```rust\n",
      "pub struct Interpreter {\n",
      "    globals: Environment,\n",
      "    environment: Environment,\n",
      "    locals: HashMap<usize, usize>, // expr_id -> depth\n",
      "}\n\n",
      "#[derive(Debug, Clone)]\n",
      "pub enum Value {\n",
      "    Number(f64),\n",
      "    String(String),\n",
      "    Boolean(bool),\n",
      "    Function(LuminaFunction),\n",
      "    Nil,\n",
      "}\n\n",
      "#[derive(Debug, Clone)]\n",
      "pub struct LuminaFunction {\n",
      "    name: String,\n",
      "    params: Vec<String>,\n",
      "    body: Vec<Stmt>,\n",
      "    closure: Environment,\n",
      "}\n\n",
      "impl Interpreter {\n",
      "    pub fn interpret(&mut self, statements: &[Stmt]) -> Result<(), RuntimeError> {\n",
      "        for statement in statements {\n",
      "            self.execute(statement)?;\n",
      "        }\n",
      "        Ok(())\n",
      "    }\n\n",
      "    fn evaluate(&mut self, expr: &Expr) -> Result<Value, RuntimeError> {\n",
      "        match expr {\n",
      "            Expr::Literal(value) => Ok(value.clone().into()),\n",
      "            Expr::Variable(name) => self.lookup_variable(name, expr),\n",
      "            Expr::Binary { left, operator, right } => {\n",
      "                let left_val = self.evaluate(left)?;\n",
      "                let right_val = self.evaluate(right)?;\n",
      "                self.apply_binary_operator(operator, left_val, right_val)\n",
      "            }\n",
      "            Expr::Call { callee, arguments } => {\n",
      "                let function = self.evaluate(callee)?;\n",
      "                let mut args = Vec::new();\n",
      "                for arg in arguments {\n",
      "                    args.push(self.evaluate(arg)?);\n",
      "                }\n",
      "                self.call_function(function, args)\n",
      "            }\n",
      "            // ... other cases\n",
      "        }\n",
      "    }\n\n",
      "    fn call_function(&mut self, callee: Value, args: Vec<Value>) -> Result<Value, RuntimeError> {\n",
      "        match callee {\n",
      "            Value::Function(function) => {\n",
      "                if args.len() != function.params.len() {\n",
      "                    return Err(RuntimeError::WrongArity {\n",
      "                        expected: function.params.len(),\n",
      "                        got: args.len(),\n",
      "                    });\n",
      "                }\n\n",
      "                let previous = self.environment.clone();\n",
      "                self.environment = function.closure.clone();\n",
      "\n",
      "                // Bind parameters\n",
      "                for (param, arg) in function.params.iter().zip(args.iter()) {\n",
      "                    self.environment.define(param.clone(), arg.clone());\n",
      "                }\n\n",
      "                let result = self.execute_block(&function.body);\n",
      "                self.environment = previous;\n\n",
      "                match result {\n",
      "                    Err(RuntimeError::Return(value)) => Ok(value),\n",
      "                    Err(e) => Err(e),\n",
      "                    Ok(_) => Ok(Value::Nil),\n",
      "                }\n",
      "            }\n",
      "            _ => Err(RuntimeError::NotCallable),\n",
      "        }\n",
      "    }\n",
      "}\n",
      "```\n\n",
      "### Built-in Functions\n",
      "Let's add some useful built-ins:\n\n",
      "```rust\n",
      "impl Interpreter {\n",
      "    fn setup_builtins(&mut self) {\n",
      "        // print function\n",
      "        self.globals.define(\"print\".to_string(), Value::NativeFunction {\n",
      "            name: \"print\".to_string(),\n",
      "            arity: 1,\n",
      "            callable: |args| {\n",
      "                println!(\"{}\", args[0]);\n",
      "                Ok(Value::Nil)\n",
      "            },\n",
      "        });\n\n",
      "        // clock function (returns current time)\n",
      "        self.globals.define(\"clock\".to_string(), Value::NativeFunction {\n",
      "            name: \"clock\".to_string(),\n",
      "            arity: 0,\n",
      "            callable: |_| {\n",
      "                let now = std::time::SystemTime::now()\n",
      "                    .duration_since(std::time::UNIX_EPOCH)\n",
      "                    .unwrap()\n",
      "                    .as_secs_f64();\n",
      "                Ok(Value::Number(now))\n",
      "            },\n",
      "        });\n\n",
      "        // sqrt function\n",
      "        self.globals.define(\"sqrt\".to_string(), Value::NativeFunction {\n",
      "            name: \"sqrt\".to_string(),\n",
      "            arity: 1,\n",
      "            callable: |args| {\n",
      "                if let Value::Number(n) = &args[0] {\n",
      "                    Ok(Value::Number(n.sqrt()))\n",
      "                } else {\n",
      "                    Err(RuntimeError::TypeError {\n",
      "                        expected: \"number\".to_string(),\n",
      "                        got: format!(\"{:?}\", args[0]),\n",
      "                    })\n",
      "                }\n",
      "            },\n",
      "        });\n",
      "    }\n",
      "}\n",
      "```\n\n",
      "## 🚀 Complete Example Program\n\n",
      "Let's test our language with a comprehensive example:\n\n",
      "```lumina\n",
      "// Fibonacci sequence calculator\n",
      "fn fibonacci(n) {\n",
      "    if n <= 1 {\n",
      "        return n\n",
      "    }\n",
      "    return fibonacci(n - 1) + fibonacci(n - 2)\n",
      "}\n\n",
      "// Prime number checker\n",
      "fn isPrime(num) {\n",
      "    if num <= 1 {\n",
      "        return false\n",
      "    }\n",
      "    \n",
      "    let i = 2\n",
      "    while i * i <= num {\n",
      "        if num % i == 0 {\n",
      "            return false\n",
      "        }\n",
      "        i = i + 1\n",
      "    }\n",
      "    return true\n",
      "}\n\n",
      "// Main execution\n",
      "let start = clock()\n",
      "\n",
      "print(\"=== Lumina Language Demo ===\")\n",
      "print(\"\")\n\n",
      "// Test variables and expressions\n",
      "let name = \"Lumina\"\n",
      "let version = 1.0\n",
      "let isAwesome = true\n\n",
      "print(\"Language: \" + name)\n",
      "print(\"Version: \" + version)\n",
      "print(\"Is awesome: \" + isAwesome)\n",
      "print(\"\")\n\n",
      "// Test functions and recursion\n",
      "print(\"Fibonacci numbers:\")\n",
      "let i = 0\n",
      "while i <= 10 {\n",
      "    let fib = fibonacci(i)\n",
      "    print(\"F(\" + i + \") = \" + fib)\n",
      "    i = i + 1\n",
      "}\n",
      "print(\"\")\n\n",
      "// Test conditionals and loops\n",
      "print(\"Prime numbers up to 20:\")\n",
      "let num = 2\n",
      "while num <= 20 {\n",
      "    if isPrime(num) {\n",
      "        print(num + \" is prime\")\n",
      "    }\n",
      "    num = num + 1\n",
      "}\n\n",
      "let end = clock()\n",
      "print(\"\")\n",
      "print(\"Execution time: \" + (end - start) + \" seconds\")\n",
      "```\n\n",
      "## 🎨 Advanced Features\n\n",
      "Once you have the basics working, consider adding:\n\n",
      "### 1. Advanced Data Structures\n",
      "```lumina\n",
      "// Arrays\n",
      "let numbers = [1, 2, 3, 4, 5]\n",
      "print(numbers[0]) // 1\n",
      "numbers.push(6)\n\n",
      "// Objects/Maps\n",
      "let person = {\n",
      "    name: \"Alice\",\n",
      "    age: 30,\n",
      "    greet: fn() {\n",
      "        return \"Hello, I'm \" + this.name\n",
      "    }\n",
      "}\n\n",
      "print(person.name) // \"Alice\"\n",
      "print(person.greet()) // \"Hello, I'm Alice\"\n",
      "```\n\n",
      "### 2. Error Handling\n",
      "```lumina\n",
      "fn divide(a, b) {\n",
      "    if b == 0 {\n",
      "        throw \"Division by zero!\"\n",
      "    }\n",
      "    return a / b\n",
      "}\n\n",
      "try {\n",
      "    let result = divide(10, 0)\n",
      "    print(result)\n",
      "} catch error {\n",
      "    print(\"Error: \" + error)\n",
      "}\n",
      "```\n\n",
      "### 3. Modules and Imports\n",
      "```lumina\n",
      "// math.lumina\n",
      "export fn pi() { return 3.14159 }\n",
      "export fn square(x) { return x * x }\n\n",
      "// main.lumina\n",
      "import { pi, square } from \"./math\"\n\n",
      "print(\"π = \" + pi())\n",
      "print(\"5² = \" + square(5))\n",
      "```\n\n",
      "## 🛠️ Development Tools\n\n",
      "Professional languages need good tooling:\n\n",
      "### REPL (Read-Eval-Print Loop)\n",
      "```rust\n",
      "fn run_repl() {\n",
      "    let mut interpreter = Interpreter::new();\n",
      "    let mut input = String::new();\n\n",
      "    println!(\"Lumina REPL v1.0\");\n",
      "    println!(\"Type 'exit' to quit\\n\");\n\n",
      "    loop {\n",
      "        print!(\"lumina> \");\n",
      "        io::stdout().flush().unwrap();\n",
      "        \n",
      "        input.clear();\n",
      "        io::stdin().read_line(&mut input).unwrap();\n",
      "        \n",
      "        let line = input.trim();\n",
      "        if line == \"exit\" {\n",
      "            break;\n",
      "        }\n\n",
      "        match run_code(line, &mut interpreter) {\n",
      "            Ok(value) => {\n",
      "                if !matches!(value, Value::Nil) {\n",
      "                    println!(\"{}\", value);\n",
      "                }\n",
      "            }\n",
      "            Err(error) => println!(\"Error: {}\", error),\n",
      "        }\n",
      "    }\n",
      "}\n",
      "```\n\n",
      "### Language Server Protocol (LSP)\n",
      "For editor integration, implement an LSP server:\n\n",
      "- **Syntax highlighting**\n",
      "- **Auto-completion**\n",
      "- **Error diagnostics**\n",
      "- **Go to definition**\n",
      "- **Hover information**\n",
      "- **Refactoring support**\n\n",
      "### Package Manager\n",
      "```toml\n",
      "# lumina.toml\n",
      "[package]\n",
      "name = \"my-project\"\n",
      "version = \"1.0.0\"\n",
      "authors = [\"Your Name <you@example.com>\"]\n\n",
      "[dependencies]\n",
      "http = \"1.2.0\"\n",
      "json = \"2.1.0\"\n\n",
      "[dev-dependencies]\n",
      "test-framework = \"0.5.0\"\n",
      "```\n\n",
      "## 🚄 Performance Optimizations\n\n",
      "### Bytecode Compiler\n",
      "Instead of tree-walking, compile to bytecode:\n\n",
      "```rust\n",
      "#[derive(Debug, Clone)]\n",
      "pub enum OpCode {\n",
      "    Constant(usize),  // Load constant from pool\n",
      "    Add,              // Pop two, push sum\n",
      "    Subtract,\n",
      "    Multiply,\n",
      "    Divide,\n",
      "    Negate,\n",
      "    Equal,\n",
      "    Greater,\n",
      "    Less,\n",
      "    Print,            // Pop and print\n",
      "    Pop,              // Discard top of stack\n",
      "    DefineGlobal(usize), // Define global variable\n",
      "    GetGlobal(usize),    // Get global variable\n",
      "    SetGlobal(usize),    // Set global variable\n",
      "    GetLocal(usize),     // Get local variable\n",
      "    SetLocal(usize),     // Set local variable\n",
      "    Jump(usize),         // Unconditional jump\n",
      "    JumpIfFalse(usize),  // Jump if top is falsy\n",
      "    Call(usize),         // Call function with N args\n",
      "    Return,              // Return from function\n",
      "}\n\n",
      "pub struct Chunk {\n",
      "    pub code: Vec<OpCode>,\n",
      "    pub constants: Vec<Value>,\n",
      "    pub lines: Vec<usize>, // Line numbers for debugging\n",
      "}\n\n",
      "pub struct VM {\n",
      "    chunk: Chunk,\n",
      "    ip: usize,           // Instruction pointer\n",
      "    stack: Vec<Value>,   // Value stack\n",
      "    globals: HashMap<String, Value>,\n",
      "    call_stack: Vec<CallFrame>,\n",
      "}\n\n",
      "impl VM {\n",
      "    pub fn run(&mut self) -> Result<(), RuntimeError> {\n",
      "        loop {\n",
      "            let instruction = &self.chunk.code[self.ip];\n",
      "            self.ip += 1;\n\n",
      "            match instruction {\n",
      "                OpCode::Constant(index) => {\n",
      "                    let constant = self.chunk.constants[*index].clone();\n",
      "                    self.stack.push(constant);\n",
      "                }\n",
      "                OpCode::Add => {\n",
      "                    let b = self.stack.pop().unwrap();\n",
      "                    let a = self.stack.pop().unwrap();\n",
      "                    self.stack.push(self.add_values(a, b)?);\n",
      "                }\n",
      "                OpCode::Print => {\n",
      "                    let value = self.stack.pop().unwrap();\n",
      "                    println!(\"{}\", value);\n",
      "                }\n",
      "                OpCode::Return => {\n",
      "                    if self.call_stack.is_empty() {\n",
      "                        return Ok(());\n",
      "                    }\n",
      "                    // Handle function return...\n",
      "                }\n",
      "                // ... other opcodes\n",
      "            }\n",
      "        }\n",
      "    }\n",
      "}\n",
      "```\n\n",
      "### Garbage Collection\n",
      "Implement mark-and-sweep GC:\n\n",
      "```rust\n",
      "pub struct GarbageCollector {\n",
      "    objects: Vec<Rc<RefCell<Object>>>,\n",
      "    gray_stack: Vec<Rc<RefCell<Object>>>,\n",
      "    bytes_allocated: usize,\n",
      "    next_gc: usize,\n",
      "}\n\n",
      "impl GarbageCollector {\n",
      "    pub fn collect_garbage(&mut self, vm: &VM) {\n",
      "        self.mark_roots(vm);\n",
      "        self.trace_references();\n",
      "        self.sweep();\n",
      "        self.next_gc = self.bytes_allocated * 2;\n",
      "    }\n\n",
      "    fn mark_roots(&mut self, vm: &VM) {\n",
      "        // Mark stack values\n",
      "        for value in &vm.stack {\n",
      "            self.mark_value(value);\n",
      "        }\n",
      "        \n",
      "        // Mark globals\n",
      "        for value in vm.globals.values() {\n",
      "            self.mark_value(value);\n",
      "        }\n",
      "    }\n\n",
      "    fn sweep(&mut self) {\n",
      "        self.objects.retain(|obj| {\n",
      "            if obj.borrow().is_marked {\n",
      "                obj.borrow_mut().is_marked = false;\n",
      "                true\n",
      "            } else {\n",
      "                self.bytes_allocated -= obj.borrow().size();\n",
      "                false\n",
      "            }\n",
      "        });\n",
      "    }\n",
      "}\n",
      "```\n\n",
      "## 📚 Resources and Next Steps\n\n",
      "### Essential Books\n",
      "1. **\"Crafting Interpreters\"** by Robert Nystrom\n",
      "   - 🌟 Best resource for building interpreters\n",
      "   - Covers both tree-walking and bytecode VMs\n",
      "   - Excellent hands-on approach\n\n",
      "2. **\"Language Implementation Patterns\"** by Terence Parr\n",
      "   - Great for parser techniques\n",
      "   - Covers ANTLR and advanced parsing\n\n",
      "3. **\"Compilers: Principles, Techniques, and Tools\"** (Dragon Book)\n",
      "   - The classic compiler textbook\n",
      "   - Comprehensive but academic\n\n",
      "### Online Resources\n",
      "- 🔗 [Let's Build a Compiler](https://compilers.iecc.com/crenshaw/)\n",
      "- 🔗 [Programming Languages: Application and Interpretation](http://cs.brown.edu/courses/cs173/2012/book/)\n",
      "- 🔗 [Write You a Haskell](http://dev.stephendiehl.com/fun/)\n",
      "- 🔗 [Build Your Own Lisp](http://buildyourownlisp.com/)\n\n",
      "### Tools and Frameworks\n",
      "| Tool | Language | Purpose |\n",
      "| ---- | -------- | ------- |\n",
      "| ANTLR | Multi | Parser generator |\n",
      "| Yacc/Bison | C/C++ | Parser generator |\n",
      "| PEG.js | JavaScript | Parsing expression grammars |\n",
      "| Nom | Rust | Parser combinator |\n",
      "| Pest | Rust | PEG parser |\n",
      "| LLVM | Multi | Code generation backend |\n\n",
      "### Testing Your Language\n",
      "```lumina\n",
      "// test_suite.lumina\n",
      "print(\"=== Lumina Test Suite ===\")\n\n",
      "// Test arithmetic\n",
      "assert(2 + 3 == 5, \"Addition test\")\n",
      "assert(10 - 4 == 6, \"Subtraction test\")\n",
      "assert(3 * 7 == 21, \"Multiplication test\")\n",
      "assert(15 / 3 == 5, \"Division test\")\n\n",
      "// Test variables\n",
      "let x = 42\n",
      "assert(x == 42, \"Variable assignment\")\n",
      "x = x + 8\n",
      "assert(x == 50, \"Variable mutation\")\n\n",
      "// Test functions\n",
      "fn double(n) {\n",
      "    return n * 2\n",
      "}\n",
      "assert(double(5) == 10, \"Function call\")\n\n",
      "// Test recursion\n",
      "fn factorial(n) {\n",
      "    if n <= 1 {\n",
      "        return 1\n",
      "    }\n",
      "    return n * factorial(n - 1)\n",
      "}\n",
      "assert(factorial(5) == 120, \"Recursion test\")\n\n",
      "print(\"All tests passed! 🎉\")\n",
      "```\n\n",
      "## 🎯 Conclusion\n\n",
      "Creating a programming language is an incredible journey that teaches you:\n\n",
      "- **Computer Science Fundamentals**: Parsing, compilers, algorithms\n",
      "- **Software Architecture**: How to design complex systems\n",
      "- **Problem Solving**: Breaking down complex problems\n",
      "- **Language Design**: What makes languages usable and expressive\n\n",
      "> 🚀 **Remember**: Start simple, iterate often, and don't be afraid to ",
      "experiment! Every major language started as someone's side project.\n\n",
      "The language we built today (**Lumina**) demonstrates all the core concepts. ",
      "From here, you can:\n\n",
      "- Add more data types (arrays, objects)\n",
      "- Implement classes and inheritance\n",
      "- Build a standard library\n",
      "- Create development tools\n",
      "- Optimize for performance\n",
      "- Share with the community!\n\n",
      "**Happy language building!** 🎉\n\n",
      "---\n\n",
      "*This guide covered the essentials of language creation. For deeper topics ",
      "like advanced optimizations, static analysis, or language-specific features, ",
      "explore the resources mentioned above.*\n"
    ]

    simulate_streaming(chunks, socket)
  end

  def handle_event("clear", _params, socket) do
    socket
    |> assign(
      stream: MDEx.stream(@mdex_options),
      chunks: [],
      all_chunks: [],
      html: "",
      streaming: false,
      current_chunk: 0,
      total_chunks: 0
    )
    |> then(&{:noreply, &1})
  end

  def handle_event("update_speed", %{"speed" => speed}, socket) do
    actual_speed = 1001 - String.to_integer(speed)
    {:noreply, assign(socket, :speed, actual_speed)}
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

  def handle_info(:stream_tick, %{assigns: %{streaming: true, current_chunk: current_chunk, total_chunks: total_chunks}} = socket)
      when current_chunk < total_chunks do
    chunk = Enum.at(socket.assigns.all_chunks, current_chunk)
    next_chunk = current_chunk + 1
    chunks = socket.assigns.chunks ++ [chunk]
    stream = Enum.into([chunk], socket.assigns.stream)
    html = html_from(stream.document)

    socket =
      socket
      |> assign(:chunks, chunks)
      |> assign(:stream, stream)
      |> assign(:html, html)
      |> assign(:current_chunk, next_chunk)

    if next_chunk < total_chunks do
      Process.send_after(self(), :stream_tick, socket.assigns.speed)
      {:noreply, socket}
    else
      send(self(), :streaming_complete)
      {:noreply, socket}
    end
  end

  def handle_info(:stream_tick, socket), do: {:noreply, socket}

  def handle_info(:streaming_complete, socket) do
    {:noreply, assign(socket, :streaming, false)}
  end

  defp simulate_streaming(chunks, socket) do
    speed = socket.assigns.speed
    total_chunks = length(chunks)

    updated_socket =
      assign(socket, %{
        stream: MDEx.stream(@mdex_options),
        chunks: [],
        all_chunks: chunks,
        html: "",
        streaming: true,
        speed: speed,
        current_chunk: 0,
        total_chunks: total_chunks
      })

    Process.send_after(self(), :stream_tick, speed)

    {:noreply, updated_socket}
  end

  defp update_position(socket, position) do
    position = min(max(position, 0), socket.assigns.total_chunks)
    chunks = Enum.take(socket.assigns.all_chunks, position)
    stream = rebuild_stream(chunks)
    html = html_from(stream.document)

    assign(socket, %{
      current_chunk: position,
      chunks: chunks,
      stream: stream,
      html: html
    })
  end

  defp rebuild_stream(chunks) do
    Enum.into(chunks, MDEx.stream(@mdex_options))
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
