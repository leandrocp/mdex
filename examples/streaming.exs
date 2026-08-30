mdex_path = System.get_env("MDEX_PATH", Path.expand("..", __DIR__))

Mix.install(
  [
    {:mdex, path: mdex_path},
    {:lumis, "~> 0.6"},
    {:phoenix_playground, "~> 0.1.9"},
    {:req, "~> 0.7.4"}
  ],
  config: [mdex_native: [syntax_highlighter: :lumis]]
)

defmodule MDExStreamingDemo do
  use Phoenix.LiveView

  @default_url "https://raw.githubusercontent.com/leandrocp/mdex/main/README.md"
  @display_chunk_bytes 64
  @max_body_bytes 2_000_000

  @mdex_options [
    extension: [
      alerts: true,
      autolink: true,
      footnotes: true,
      shortcodes: true,
      strikethrough: true,
      table: true,
      tasklist: true
    ],
    parse: [relaxed_autolinks: true, relaxed_tasklist_matching: true],
    syntax_highlight: [
      engine: :lumis,
      opts: [
        formatter: {:html_multi_themes, themes: [light: "github_light", dark: "github_dark"], default_theme: "light-dark()"}
      ]
    ]
  ]

  @pipeline_markdown """
  ```elixir
  Req.get!(url, into: :self).body
  |> MDEx.stream(options)
  |> Enum.each(&send(live_view, {:markdown_chunk, &1}))

  # In the LiveView process:
  stream_insert(socket, :markdown, chunk)
  ```
  """

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    url = Map.get(params, "url", @default_url)
    live_view_memory = process_memory()

    {:ok,
     socket
     |> stream_configure(:markdown, dom_id: fn {id, _document} -> "markdown-#{id}" end)
     |> stream(:markdown, [])
     |> assign(
       url: url,
       delay_ms: 25,
       auto_scroll: true,
       status: :idle,
       error: nil,
       run_id: nil,
       received_bytes: 0,
       received_chunks: 0,
       markdown_updates: 0,
       rendered_chunks: 0,
       producer_memory: 0,
       producer_peak_memory: 0,
       live_view_memory: live_view_memory,
       live_view_peak_memory: live_view_memory,
       display_chunk_bytes: @display_chunk_bytes,
       pipeline_html: MDEx.to_html!(@pipeline_markdown, @mdex_options)
     )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <style>
      :root {
        color-scheme: light dark;
        font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      }

      body { margin: 0; background: #f5f7fb; color: #172033; }
      * { box-sizing: border-box; }
      button, input { font: inherit; }
      code { font-family: "SFMono-Regular", Consolas, "Liberation Mono", monospace; }

      .page { min-height: 100vh; padding: 2rem 1rem 4rem; }
      .shell { width: min(1040px, 100%); margin: 0 auto; }
      .hero { margin-bottom: 1.25rem; }
      .hero h1 { margin: 0 0 .4rem; font-size: clamp(2rem, 5vw, 3.5rem); letter-spacing: -.05em; }
      .hero p { margin: 0; color: #5d667a; font-size: 1.05rem; }

      .card { background: #fff; border: 1px solid #dfe4ee; border-radius: 16px; box-shadow: 0 14px 40px rgba(25, 38, 71, .08); }
      .controls { padding: 1rem; margin-bottom: 1rem; }
      .url-form { display: grid; grid-template-columns: 1fr auto auto; gap: .65rem; }
      .url-input { width: 100%; min-width: 0; border: 1px solid #cbd3e1; border-radius: 10px; padding: .72rem .85rem; background: #fff; color: #172033; }
      .button { border: 0; border-radius: 10px; padding: .72rem 1rem; cursor: pointer; font-weight: 700; }
      .button-primary { color: #fff; background: #4f46e5; }
      .button-secondary { color: #313a4d; background: #e9edf5; }
      .button[disabled] { cursor: not-allowed; opacity: .5; }

      .pace { display: grid; grid-template-columns: auto 1fr auto; align-items: center; gap: .8rem; margin-top: 1rem; }
      .pace label { color: #465066; font-weight: 650; }
      .pace input[type="range"] { width: 100%; accent-color: #4f46e5; }
      .pace output { min-width: 7.5rem; text-align: right; color: #465066; font-variant-numeric: tabular-nums; }
      .auto-scroll { grid-column: 1 / -1; display: inline-flex; align-items: center; gap: .55rem; width: fit-content; cursor: pointer; }
      .auto-scroll input { width: 1rem; height: 1rem; accent-color: #4f46e5; }

      .telemetry { margin-bottom: 1rem; padding: 1rem; color: #5d667a; }
      .status { display: flex; flex-wrap: wrap; gap: .5rem 1rem; align-items: center; font-size: .9rem; }
      .status strong { color: #172033; }
      .status-dot { width: .55rem; height: .55rem; border-radius: 50%; background: #98a2b4; }
      .status-dot.streaming { background: #16a34a; box-shadow: 0 0 0 .3rem rgba(22, 163, 74, .13); animation: pulse 1.2s infinite; }
      .status-dot.complete { background: #4f46e5; }
      .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: .7rem; margin: 1rem 0 0; }
      .metric { min-width: 0; padding: .75rem; border: 1px solid #e3e7ef; border-radius: 10px; background: #f8f9fc; }
      .metric dt { margin-bottom: .25rem; color: #737d90; font-size: .72rem; font-weight: 750; letter-spacing: .07em; text-transform: uppercase; }
      .metric dd { margin: 0; color: #172033; font-size: 1rem; font-weight: 750; font-variant-numeric: tabular-nums; }
      .metric small { display: block; margin-top: .18rem; color: #737d90; font-size: .75rem; }
      .metrics-note { margin: .8rem 0 0; font-size: .78rem; }
      .error { padding: .8rem 1rem; margin-bottom: 1rem; border: 1px solid #fecaca; border-radius: 12px; background: #fef2f2; color: #991b1b; }

      .output { padding: clamp(1.1rem, 4vw, 2.5rem); min-height: 24rem; overflow-wrap: anywhere; }
      .empty { display: grid; place-items: center; min-height: 20rem; color: #7a8498; text-align: center; }
      .markdown-chunk { display: contents; }
      .markdown-body { line-height: 1.7; }
      .markdown-body h1, .markdown-body h2, .markdown-body h3 { line-height: 1.25; letter-spacing: -.025em; margin: 1.5em 0 .55em; }
      .markdown-body h1:first-child, .markdown-body h2:first-child { margin-top: 0; }
      .markdown-body a { color: #4338ca; }
      .markdown-body img { max-width: 100%; }
      .markdown-body blockquote { margin-left: 0; padding-left: 1rem; border-left: 4px solid #a5b4fc; color: #566078; }
      .markdown-body code { padding: .12rem .35rem; border-radius: 5px; background: #eef1f7; }
      .markdown-body pre { overflow-x: auto; padding: 1rem; border-radius: 10px; background: #111827; color: #e5e7eb; }
      .markdown-body pre code { padding: 0; background: transparent; }
      .markdown-body table { display: block; max-width: 100%; overflow-x: auto; border-collapse: collapse; }
      .markdown-body th, .markdown-body td { padding: .5rem .7rem; border: 1px solid #d7dce6; text-align: left; }
      .markdown-body hr { margin: 2rem 0; border: 0; border-top: 1px solid #d7dce6; }

      .how-it-works { margin-top: 1rem; padding: 1.25rem; color: #5d667a; }
      .how-it-works h2 { margin: 0; color: #313a4d; font-size: 1.2rem; }
      .how-it-works p { margin: .35rem 0 1rem; }
      .how-it-works pre { overflow-x: auto; margin: 0; }

      @keyframes pulse { 50% { opacity: .55; } }

      @media (max-width: 720px) {
        .url-form { grid-template-columns: 1fr auto; }
        .url-input { grid-column: 1 / -1; }
        .pace { grid-template-columns: 1fr auto; }
        .pace label { grid-column: 1 / -1; }
      }

      @media (prefers-color-scheme: dark) {
        body { background: #0d1320; color: #e7eaf0; }
        .hero p, .telemetry, .pace label, .pace output, .how-it-works { color: #aeb6c7; }
        .card { background: #151d2c; border-color: #2a3447; box-shadow: none; }
        .url-input { background: #0f1726; border-color: #354057; color: #e7eaf0; }
        .button-secondary { color: #d8dce5; background: #2a3447; }
        .status strong, .metric dd, .how-it-works h2 { color: #e7eaf0; }
        .metric { border-color: #303b50; background: #101827; }
        .metric dt, .metric small { color: #98a3b7; }
        .error { border-color: #7f1d1d; background: #3b1118; color: #fecaca; }
        .markdown-body a { color: #a5b4fc; }
        .markdown-body blockquote { color: #b5bdcd; }
        .markdown-body code { background: #273145; }
        .markdown-body th, .markdown-body td { border-color: #3a4559; }
        .markdown-body hr { border-color: #3a4559; }
        .empty { color: #8f99ac; }
      }
    </style>

    <main class="page">
      <div class="shell">
        <header class="hero">
          <h1>MDEx streaming playground</h1>
          <p>Stream a remote Markdown document through Req, MDEx, and Phoenix LiveView.</p>
        </header>

        <section class="card controls">
          <form id="url-form" phx-submit="start" class="url-form">
            <input
              class="url-input"
              type="url"
              name="url"
              value={@url}
              aria-label="Markdown URL"
              placeholder="https://example.com/document.md"
              required
            />
            <button class="button button-primary" type="submit">
              {if @status == :streaming, do: "Restart", else: "Stream URL"}
            </button>
            <button
              class="button button-secondary"
              type="button"
              phx-click="stop"
              disabled={@status != :streaming}
            >
              Stop
            </button>
          </form>

          <form id="pace-form" phx-change="pace" class="pace">
            <label for="delay-ms">Playback delay per {@display_chunk_bytes}-byte chunk</label>
            <input
              id="delay-ms"
              type="range"
              name="delay_ms"
              min="0"
              max="1000"
              step="10"
              value={@delay_ms}
            />
            <output for="delay-ms">{@delay_ms} ms</output>
            <label class="auto-scroll" for="auto-scroll">
              <input type="hidden" name="auto_scroll" value="false" />
              <input
                id="auto-scroll"
                type="checkbox"
                name="auto_scroll"
                value="true"
                checked={@auto_scroll}
              />
              Auto-scroll as chunks arrive
            </label>
          </form>
        </section>

        <section id="stream-metrics" class="card telemetry" aria-live="polite">
          <div class="status">
            <span class={["status-dot", Atom.to_string(@status)]}></span>
            <strong>{status_label(@status)}</strong>
            <span>Run data</span>
          </div>

          <dl class="metrics">
            <div class="metric">
              <dt>Req source</dt>
              <dd id="source-metrics">{format_bytes(@received_bytes)}</dd>
              <small>{@received_chunks} chunks · paced at {@display_chunk_bytes} bytes</small>
            </div>
            <div class="metric">
              <dt>MDEx</dt>
              <dd id="mdex-metrics">{@markdown_updates} updates</dd>
              <small>{max(@markdown_updates - @rendered_chunks, 0)} replacements</small>
            </div>
            <div class="metric">
              <dt>LiveView DOM</dt>
              <dd id="dom-metrics">{@rendered_chunks} chunks</dd>
              <small>
                {stable_chunks(@status, @rendered_chunks)} stable · {mutable_chunks(@status, @rendered_chunks)} open
              </small>
            </div>
            <div class="metric">
              <dt>Producer memory</dt>
              <dd id="producer-memory">{format_bytes(@producer_memory)}</dd>
              <small>peak {format_bytes(@producer_peak_memory)}</small>
            </div>
            <div class="metric">
              <dt>LiveView memory</dt>
              <dd id="live-view-memory">{format_bytes(@live_view_memory)}</dd>
              <small>peak {format_bytes(@live_view_peak_memory)}</small>
            </div>
          </dl>

          <p class="metrics-note">
            Memory is measured for each BEAM process. The browser keeps stable chunks. MDEx keeps only the source that may still change.
          </p>
        </section>

        <div :if={@error} class="error" role="alert">{@error}</div>

        <div :if={@status == :idle} class="card empty">
          <p>Press <strong>Stream URL</strong> to fetch the MDEx README, or enter another Markdown URL.</p>
        </div>

        <article
          :if={@status != :idle}
          id="markdown-output"
          class="card output markdown-body"
          phx-update="stream"
          phx-hook="AutoScroll"
          data-auto-scroll={to_string(@auto_scroll)}
        >
          <div
            :for={{dom_id, {_id, document}} <- @streams.markdown}
            id={dom_id}
            class="markdown-chunk"
          >
            {Phoenix.HTML.raw(MDEx.to_html!(document))}
          </div>
        </article>

        <section id="how-it-works" class="card how-it-works">
          <h2>How it works</h2>
          <p>Req reads the source. MDEx parses each chunk. LiveView updates the matching DOM child.</p>
          <div class="markdown-body">{Phoenix.HTML.raw(@pipeline_html)}</div>
        </section>
      </div>
    </main>

    <script phx-no-curly-interpolation>
      window.hooks.AutoScroll = {
        mounted() { this.scrollToLatest() },
        updated() { this.scrollToLatest() },
        scrollToLatest() {
          if (this.el.dataset.autoScroll === "true") {
            window.requestAnimationFrame(() => {
              window.scrollTo({ top: document.documentElement.scrollHeight, behavior: "smooth" })
            })
          }
        }
      }
    </script>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("pace", params, socket) do
    {:noreply,
     assign(socket,
       delay_ms: parse_delay(params["delay_ms"]),
       auto_scroll: params["auto_scroll"] == "true"
     )}
  end

  def handle_event("start", %{"url" => raw_url}, socket) do
    url = String.trim(raw_url)

    case validate_url(url) do
      :ok ->
        live_view = self()
        live_view_memory = process_memory()
        run_id = make_ref()

        socket =
          socket
          |> cancel_async(:markdown_fetch)
          |> stream(:markdown, [], reset: true)
          |> assign(
            url: url,
            run_id: run_id,
            status: :streaming,
            error: nil,
            received_bytes: 0,
            received_chunks: 0,
            markdown_updates: 0,
            rendered_chunks: 0,
            producer_memory: 0,
            producer_peak_memory: 0,
            live_view_memory: live_view_memory,
            live_view_peak_memory: live_view_memory
          )
          |> start_async(:markdown_fetch, fn -> stream_url(url, live_view, run_id) end)

        {:noreply, socket}

      {:error, message} ->
        {:noreply, assign(socket, error: message, status: :error)}
    end
  end

  def handle_event("stop", _params, socket) do
    {:noreply,
     socket
     |> cancel_async(:markdown_fetch)
     |> assign(status: :stopped, run_id: nil)}
  end

  @impl Phoenix.LiveView
  def handle_info(
        {:pace_chunk, run_id, producer, bytes, producer_memory},
        %{assigns: %{run_id: run_id}} = socket
      ) do
    send(producer, {:continue, run_id, socket.assigns.delay_ms})

    {:noreply,
     socket
     |> update(:received_bytes, &(&1 + bytes))
     |> update(:received_chunks, &(&1 + 1))
     |> put_memory(:producer, producer_memory)
     |> put_memory(:live_view, process_memory())}
  end

  def handle_info({:pace_chunk, _run_id, _producer, _bytes, _memory}, socket), do: {:noreply, socket}

  def handle_info(
        {:markdown_chunk, run_id, {id, _document} = chunk, producer_memory},
        %{assigns: %{run_id: run_id}} = socket
      ) do
    {:noreply,
     socket
     |> stream_insert(:markdown, chunk)
     |> update(:markdown_updates, &(&1 + 1))
     |> update(:rendered_chunks, &max(&1, id + 1))
     |> put_memory(:producer, producer_memory)
     |> put_memory(:live_view, process_memory())}
  end

  def handle_info({:markdown_chunk, _run_id, _chunk, _memory}, socket), do: {:noreply, socket}

  @impl Phoenix.LiveView
  def handle_async(:markdown_fetch, {:ok, {run_id, _status}}, %{assigns: %{run_id: run_id}} = socket) do
    {:noreply, assign(socket, status: :complete, run_id: nil)}
  end

  def handle_async(:markdown_fetch, {:ok, {_run_id, _status}}, socket), do: {:noreply, socket}

  def handle_async(:markdown_fetch, {:exit, {:shutdown, :cancel}}, socket), do: {:noreply, socket}

  def handle_async(:markdown_fetch, {:exit, reason}, socket) do
    {:noreply, assign(socket, status: :error, run_id: nil, error: exception_message(reason))}
  end

  defp stream_url(url, live_view, run_id) do
    response = Req.get!(url, into: :self)

    unless response.status in 200..299 do
      Req.cancel_async_response(response)
      raise "request returned HTTP #{response.status}"
    end

    response.body
    |> rechunk(@display_chunk_bytes)
    |> enforce_body_limit()
    |> pace_with_live_view(live_view, run_id)
    |> MDEx.stream(@mdex_options)
    |> Enum.each(fn chunk ->
      send(live_view, {:markdown_chunk, run_id, chunk, process_memory()})
    end)

    {run_id, response.status}
  end

  defp rechunk(chunks, bytes) do
    Stream.flat_map(chunks, &split_binary(&1, bytes, []))
  end

  defp split_binary("", _bytes, chunks), do: Enum.reverse(chunks)

  defp split_binary(binary, bytes, chunks) when byte_size(binary) <= bytes do
    Enum.reverse([binary | chunks])
  end

  defp split_binary(binary, bytes, chunks) do
    <<chunk::binary-size(^bytes), rest::binary>> = binary
    split_binary(rest, bytes, [chunk | chunks])
  end

  defp enforce_body_limit(chunks) do
    Stream.transform(chunks, 0, fn chunk, total ->
      total = total + byte_size(chunk)

      if total > @max_body_bytes do
        raise "response exceeded the #{div(@max_body_bytes, 1_000_000)} MB demo limit"
      end

      {[chunk], total}
    end)
  end

  defp pace_with_live_view(chunks, live_view, run_id) do
    Stream.map(chunks, fn chunk ->
      send(live_view, {:pace_chunk, run_id, self(), byte_size(chunk), process_memory()})

      receive do
        {:continue, ^run_id, delay_ms} -> Process.sleep(delay_ms)
      after
        5_000 -> raise "LiveView did not acknowledge the source chunk"
      end

      chunk
    end)
  end

  defp validate_url(url) do
    case URI.new(url) do
      {:ok, %URI{scheme: scheme, host: host}} when scheme in ["http", "https"] and is_binary(host) -> :ok
      _ -> {:error, "Enter an absolute http:// or https:// URL."}
    end
  end

  defp parse_delay(value) do
    value
    |> String.to_integer()
    |> min(1000)
    |> max(0)
  rescue
    ArgumentError -> 25
  end

  defp status_label(:idle), do: "Ready"
  defp status_label(:streaming), do: "Streaming"
  defp status_label(:complete), do: "Complete"
  defp status_label(:stopped), do: "Stopped"
  defp status_label(:error), do: "Error"

  defp stable_chunks(status, chunks), do: chunks - mutable_chunks(status, chunks)

  defp mutable_chunks(:complete, _chunks), do: 0
  defp mutable_chunks(_status, 0), do: 0
  defp mutable_chunks(_status, _chunks), do: 1

  defp put_memory(socket, :producer, bytes) do
    socket
    |> assign(:producer_memory, bytes)
    |> update(:producer_peak_memory, &max(&1, bytes))
  end

  defp put_memory(socket, :live_view, bytes) do
    socket
    |> assign(:live_view_memory, bytes)
    |> update(:live_view_peak_memory, &max(&1, bytes))
  end

  defp process_memory do
    {:memory, bytes} = Process.info(self(), :memory)
    bytes
  end

  defp format_bytes(bytes) when bytes < 1_000, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_000_000, do: "#{Float.round(bytes / 1_000, 1)} kB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_000_000, 1)} MB"

  defp exception_message({exception, _stacktrace}) when is_exception(exception), do: Exception.message(exception)
  defp exception_message(exception) when is_exception(exception), do: Exception.message(exception)
  defp exception_message(reason), do: "Streaming failed: #{inspect(reason)}"
end

unless System.get_env("MDEX_STREAMING_EXAMPLE_NO_SERVER") == "1" do
  open_browser? = System.get_env("MDEX_STREAMING_EXAMPLE_NO_BROWSER") != "1"
  PhoenixPlayground.start(live: MDExStreamingDemo, open_browser: open_browser?)
end
