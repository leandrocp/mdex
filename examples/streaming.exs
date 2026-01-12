Mix.install([
  {:mdex, "~> 0.10"},
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
            if (chunksContainer) {
              chunksContainer.scrollTop = chunksContainer.scrollHeight
            }
            if (renderedContainer) {
              renderedContainer.scrollTop = renderedContainer.scrollHeight
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
    <div class="bg-white/70 dark:bg-slate-900/70 backdrop-blur-xl rounded-2xl shadow-xl border border-slate-200/50 dark:border-slate-800/50 overflow-hidden">
      <div class="px-6 py-4 bg-gradient-to-r from-slate-50 to-white dark:from-slate-900 dark:to-slate-800/50 border-b border-slate-200 dark:border-slate-700/50">
        <h3 class="text-base font-bold text-slate-900 dark:text-white">Rendered Output</h3>
      </div>
      <div class="p-6">
        <div id="rendered-container" class="max-h-[50vh] overflow-y-auto">
          <%= if @html == "" do %>
            <div class="text-slate-500 dark:text-slate-400 text-center py-12">
              Rendered output will appear here
            </div>
          <% else %>
            <div class={"prose prose-slate dark:prose-invert max-w-none
                         [&_h1]:text-2xl [&_h1]:font-bold [&_h1]:mb-4 [&_h1]:mt-6 [&_h1]:text-slate-900 dark:[&_h1]:text-white
                         [&_h2]:text-xl [&_h2]:font-bold [&_h2]:mb-3 [&_h2]:mt-5 [&_h2]:text-slate-900 dark:[&_h2]:text-white
                         [&_h3]:text-lg [&_h3]:font-semibold [&_h3]:mb-2 [&_h3]:mt-4 [&_h3]:text-slate-900 dark:[&_h3]:text-white
                         [&_p]:mb-4 [&_p]:leading-7 [&_p]:text-slate-700 dark:[&_p]:text-slate-300
                         [&_ul]:my-4 [&_ul]:pl-6 [&_ul]:list-disc [&_ul]:space-y-2
                         [&_ol]:my-4 [&_ol]:pl-6 [&_ol]:list-decimal [&_ol]:space-y-2
                         [&_li]:text-slate-700 dark:[&_li]:text-slate-300
                         [&_a]:text-blue-600 [&_a]:hover:text-blue-700 [&_a]:underline [&_a]:decoration-blue-300 [&_a]:underline-offset-2 dark:[&_a]:text-blue-400 dark:[&_a]:hover:text-blue-300
                         [&_code]:bg-slate-100 [&_code]:dark:bg-slate-800 [&_code]:px-1.5 [&_code]:py-0.5 [&_code]:rounded-md [&_code]:text-sm [&_code]:font-mono [&_code]:text-slate-900 dark:[&_code]:text-slate-100
                         [&_pre]:bg-slate-900 dark:[&_pre]:bg-slate-950 [&_pre]:p-4 [&_pre]:rounded-xl [&_pre]:overflow-x-auto
                         [&_pre]:font-mono [&_pre]:text-sm [&_pre]:leading-6
                         [&_pre_code]:block [&_pre_code]:whitespace-pre [&_pre_code]:bg-transparent [&_pre_code]:p-0
                         [&_blockquote]:border-l-4 [&_blockquote]:border-blue-500 [&_blockquote]:pl-4 [&_blockquote]:italic [&_blockquote]:text-slate-600 dark:[&_blockquote]:text-slate-400 [&_blockquote]:my-4
                         [&_strong]:font-bold [&_strong]:text-slate-900 dark:[&_strong]:text-white
                         [&_em]:italic
                         [&_table]:w-full [&_table]:my-6 [&_table]:border-collapse
                         [&_thead]:bg-slate-100 dark:[&_thead]:bg-slate-800
                         [&_th]:px-4 [&_th]:py-3 [&_th]:font-bold [&_th]:text-left [&_th]:border-b-2 [&_th]:border-slate-300 dark:[&_th]:border-slate-600 [&_th]:text-slate-900 dark:[&_th]:text-white
                         [&_td]:px-4 [&_td]:py-3 [&_td]:border-b [&_td]:border-slate-200 dark:[&_td]:border-slate-700 [&_td]:text-slate-700 dark:[&_td]:text-slate-300
                         [&_tr:hover]:bg-slate-50 dark:[&_tr:hover]:bg-slate-800/50
                         [&_hr]:my-8 [&_hr]:border-slate-300 dark:[&_hr]:border-slate-700
                         [&_img]:rounded-xl [&_img]:shadow-lg
                         [&_span[data-math-style='display']]:block [&_span[data-math-style='display']]:my-6 [&_span[data-math-style='display']]:text-center [&_span[data-math-style='display']]:text-lg [&_span[data-math-style='display']]:font-serif [&_span[data-math-style='display']]:italic [&_span[data-math-style='display']]:text-slate-800 dark:[&_span[data-math-style='display']]:text-slate-200
                         [&_span[data-math-style='inline']]:font-serif [&_span[data-math-style='inline']]:italic [&_span[data-math-style='inline']]:text-slate-800 dark:[&_span[data-math-style='inline']]:text-slate-200 [&_span[data-math-style='inline']]:mx-0.5"}>
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
    <div class="bg-white/70 dark:bg-slate-900/70 backdrop-blur-xl rounded-2xl shadow-xl border border-slate-200/50 dark:border-slate-800/50 overflow-hidden">
      <div class="px-6 py-4 bg-gradient-to-r from-slate-50 to-white dark:from-slate-900 dark:to-slate-800/50 border-b border-slate-200 dark:border-slate-700/50">
        <h3 class="text-base font-bold text-slate-900 dark:text-white">Markdown Chunks</h3>
      </div>
      <div class="p-6">
        <div id="chunks-container" class="max-h-[50vh] overflow-y-auto">
          <%= if @chunks == [] do %>
            <div class="text-slate-500 dark:text-slate-400 text-center py-12">
              No chunks yet
            </div>
          <% else %>
            <div class="flex flex-wrap gap-1">
              <%= for chunk <- @chunks do %>
                <span class="inline-flex items-center bg-gradient-to-br from-blue-50 to-blue-100 dark:from-blue-900/30 dark:to-blue-800/30 border border-blue-200 dark:border-blue-700/50 rounded-lg text-xs text-slate-700 dark:text-blue-300 font-mono px-2 py-1.5 shadow-sm"><%= String.slice(inspect(chunk), 1..-2//1) %></span>
              <% end %>
            </div>
          <% end %>
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
      tasklist: true,
      math_dollars: true
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
    syntax_highlight: [formatter: {:html_inline, theme: "github_light"}],
    streaming: true
  ]

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       document: MDEx.new(@mdex_options),
       chunks: [],
       html: "",
       streaming: false,
       speed: 80,
       current_chunk: 0,
       total_chunks: 0,
       stream_ref: nil
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-50 via-blue-50/20 to-slate-100 dark:from-slate-950 dark:via-slate-900 dark:to-slate-950">
      <div class="max-w-7xl mx-auto px-6 py-12">
        <!-- Header -->
        <div class="text-center mb-8">
          <h1 class="text-4xl md:text-5xl font-bold tracking-tight bg-gradient-to-r from-slate-900 via-blue-900 to-slate-900 dark:from-white dark:via-blue-400 dark:to-white bg-clip-text text-transparent">
            MDEx Streaming
          </h1>
        </div>

        <!-- Controls -->
        <div class="mb-8">
          <div class="bg-white/70 dark:bg-slate-900/70 backdrop-blur-xl rounded-2xl shadow-xl border border-slate-200/50 dark:border-slate-800/50 p-5">
            <div class="flex items-center gap-6 flex-wrap">
              <!-- Demo Actions -->
              <div class="flex gap-3">
                <button phx-click="start_demo" class="px-6 py-2.5 text-sm font-semibold text-white bg-gradient-to-r from-blue-600 to-blue-500 hover:from-blue-700 hover:to-blue-600 rounded-xl shadow-lg shadow-blue-500/25 transition-all disabled:opacity-50 disabled:cursor-not-allowed disabled:shadow-none" disabled={@streaming}>
                  Start
                </button>
                <button phx-click="clear" class="px-6 py-2.5 text-sm font-semibold text-slate-700 dark:text-slate-300 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 rounded-xl transition-all">
                  Clear
                </button>
              </div>

              <!-- Speed Control -->
              <div class="flex items-center gap-4 flex-1 min-w-[240px]">
                <label class="text-sm font-semibold text-slate-700 dark:text-slate-300 whitespace-nowrap">
                  Speed
                </label>
                <form phx-change="update_speed" class="flex-1">
                  <input
                    type="range"
                    name="speed"
                    min="1"
                    max="1000"
                    step="1"
                    value={1001 - @speed}
                    disabled={@streaming}
                    class="w-full h-2 bg-slate-200 dark:bg-slate-700 rounded-full appearance-none cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-4 [&::-webkit-slider-thumb]:h-4 [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-blue-600 [&::-webkit-slider-thumb]:cursor-pointer"
                  />
                </form>
                <span class="text-sm font-mono font-semibold text-slate-700 dark:text-slate-300 bg-slate-100 dark:bg-slate-800 px-3 py-1.5 rounded-lg whitespace-nowrap">
                  <%= @speed %>ms
                </span>
              </div>

              <!-- Progress -->
              <div class="flex items-center gap-3">
                <%= if @total_chunks == 0 do %>
                  <span class="text-xs font-semibold text-slate-500 dark:text-slate-400 bg-slate-100 dark:bg-slate-800 px-3 py-1.5 rounded-full">
                    Waiting
                  </span>
                  <span class="text-sm font-mono font-semibold text-slate-600 dark:text-slate-400 bg-slate-100 dark:bg-slate-800 px-3 py-1.5 rounded-lg">
                    - / -
                  </span>
                <% else %>
                  <span :if={@streaming} class="text-xs font-semibold text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-900/30 px-3 py-1.5 rounded-full animate-pulse">
                    Streaming
                  </span>
                  <span class="text-sm font-mono font-semibold text-slate-700 dark:text-slate-300 bg-slate-100 dark:bg-slate-800 px-3 py-1.5 rounded-lg">
                    <%= @current_chunk %> / <%= @total_chunks %>
                  </span>
                <% end %>
              </div>
            </div>
          </div>
        </div>

        <!-- Panels -->
        <div class="space-y-6">
          <.live_component module={RenderPanel} id="render-panel" html={@html} />
          <.live_component module={ChunksPanel} id="chunks-panel" chunks={Enum.take(@chunks, @current_chunk)} />
        </div>
      </div>
    </div>
    """
  end

  def handle_event("start_demo", _params, socket) do
    content = """
    # Streaming Music App with Phoenix LiveView

    :rocket: Launch a collaborative listening room with real-time diffs driven by `Phoenix LiveView`.

    ## Why LiveView Fits

    Phoenix LiveView keeps the render pipeline on the server, letting state changes push efficient patches into the session. This means listeners enjoy responsive updates without custom JavaScript, yet you retain declarative Elixir code.

    ### Experience Goals

    - :notes: Seamless streaming controls
    - :headphones: Shared queue awareness
    - :sparkles: Animated feedback without page reload
    - :musical_keyboard: Keyboard shortcuts for power users

    ## Task Board

    - [x] Initialize project scaffolding
    - [ ] Wire up LiveView routes
      - [x] Create router
      - [ ] Add authentication
    - [ ] Connect to the audio backend
    - [ ] Style the listening room
    - [ ] Publish real-time metrics dashboard

    ## Architecture Snapshot

    | Layer | Responsibility | LiveView Hook |
    | --- | --- | --- |
    | LiveView | Stateful UI process | mount / handle_event |
    | PubSub | Broadcast track events | Phoenix.PubSub |
    | Context | Business logic | StreamMusic.Library |
    | Presence | Listener roster tracking | Phoenix.Presence |
    | Data | Persistent playlists | Ecto schemas |

    ## Setup Command

    ```bash
    mix phx.new stream_music --live
    cd stream_music
    mix deps.get
    ```

    ## LiveView Outline

    ```elixir
    defmodule StreamMusicWeb.PlayerLive do
      use StreamMusicWeb, :live_view
      alias Phoenix.PubSub

      @topic "stream_music:queue"

      def mount(_params, _session, socket) do
        if connected?(socket) do
          Phoenix.PubSub.subscribe(StreamMusic.PubSub, @topic)
        end
        {:ok, assign(socket, playlist: [], now_playing: nil, search: "", volume: 60, listeners: %{})}
      end

      def handle_event("search", %{"query" => query}, socket) do
        {:noreply, assign(socket, search: query)}
      end

      def handle_event("queue", %{"track" => track}, socket) do
        Phoenix.PubSub.broadcast(StreamMusic.PubSub, @topic, {:queue, track})
        {:noreply, update(socket, :playlist, fn list -> list ++ [track] end)}
      end

      def handle_event("play", %{"track" => track}, socket) do
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
    ```

    ### Progressive Streaming

    LiveViews start with a static render before upgrading to the persistent connection, so first meaningful paint stays fast while future updates travel over a single channel.

    ### Performance Metrics

    The connection latency can be modeled as:

    $$
    L = \\frac{RTT}{2} + P_{server}
    $$

    Where $L$ is total latency, $RTT$ is round-trip time, and $P_{server}$ is server processing time.

    For optimal user experience, aim for $L < 100ms$ to maintain the illusion of instantaneous updates.

    ## Interaction Flow

    1. Visitor opens the lobby and receives the rendered `PlayerLive`.
    2. `mount/3` seeds assigns with playlist snapshots.
    3. Track searches call `handle_event/3` to refine results.
    4. Queue updates broadcast through PubSub and hydrate everyone.
    5. Presence diff pushes listener join or leave events.

    ### Playlist Signals

    - **Now Playing**: highlight the active track and waveform
    - **Queue**: show pending entries with avatars
    - **History**: list completed tracks for replay fans

    ### Commands for Library Context

    Run the generator to scaffold data boundaries:

    - `mix phx.gen.live Library Track tracks title:string artist:string duration:integer source_url:string`
    - `mix phx.gen.schema Library.Room rooms slug:string theme:string description:text`

    ### Queue Feedback

    | Event | LiveView Callback | Outcome |
    | --- | --- | --- |
    | :mag: Search query | `handle_event "search"` | Update suggestions |
    | :heavy_plus_sign: Queue track | `handle_event "queue"` | Append playlist |
    | :arrow_forward: Play track | `handle_event "play"` | Change headline state |
    | :busts_in_silhouette: Presence diff | `handle_info {:presence_diff, diff}` | Refresh listener list |
    | :checkered_flag: Track finished | `handle_info {:playback_done, track}` | Rotate playlist |

    ### Listener Journey

    - Enter lobby and see :headphones: welcome banner
    - Use instant search to find a favorite song
    - Add the track to the collaborative queue
    - Watch :rocket: transitions as the now playing card updates
    - React with inline emoji to celebrate the vibe
    - Share with friends via <hello@example.com> or https://streammusic.app

    ![App Screenshot](https://placehold.co/600x300/6366f1/white?text=Stream+Music+App)

    ## Real-Time Considerations

    > **Important**: Keep these best practices in mind when building real-time features.
    >
    > Performance is critical for user experience in collaborative apps.

    - Keep assigns minimal to avoid large diffs
    - Stream lists with `Phoenix.LiveView.stream/4` for scalable queues
    - Push events with `push_event/3` for waveform animations
    - Use `temporary_assigns` to discard transient payloads
    - ~~Avoid polling~~ Use LiveView for real-time updates
    - Balance updates between server broadcasts and client hooks

    ### Client Integration

    ```javascript
    // Subscribe to live updates
    const socket = new Socket("/socket", {params: {token: userToken}})
    socket.connect()

    const channel = socket.channel("room:lobby", {})
    channel.join()
      .receive("ok", resp => { console.log("Joined successfully", resp) })
      .receive("error", resp => { console.log("Unable to join", resp) })

    channel.on("new_track", payload => {
      updateNowPlaying(payload.track)
    })
    ```

    ### Deployment Notes

    :package: Infrastructure Requirements

    - Configure [CDN edge caching](https://docs.example.com/cdn) for artwork
    - Enable `live_session` routes for authentication
    - Tune WebSocket pool size for expected rooms
    - Leverage clustered nodes for resilient PubSub

    <p>
      <small class="text-blue-600 dark:text-blue-300 font-medium">
        💡 Pro Tip: Start with a single node and scale horizontally as your user base grows.
        Monitor metrics at https://metrics.streammusic.app
      </small>
    </p>

    ## Next Steps

    1. Finalize UI polish in Tailwind components
    2. Integrate payment tiers for premium rooms
    3. Add offline fallbacks when connection drops
    4. Extend analytics pipeline for retention insights

    ## Celebration

    Wrap the launch with :tada: playlists and a :musical_note: release party!

    ---

    *Built with :purple_heart: using [Elixir](https://elixir-lang.org) and [MDEx](https://hex.pm/packages/mdex)*
    """

    chunks = chunk_for_ai_streaming(content)
    simulate_streaming(socket, chunks)
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

  defp html_from(%MDEx.Document{} = document), do: MDEx.to_html!(document, @mdex_options)

  defp chunk_for_ai_streaming(text) do
    text
    |> String.graphemes()
    |> do_random_chunk([])
  end

  defp do_random_chunk([], acc), do: Enum.reverse(acc)

  defp do_random_chunk(graphemes, acc) do
    chunk_size = Enum.random(3..20)
    {chunk, rest} = Enum.split(graphemes, chunk_size)

    case chunk do
      [] -> Enum.reverse(acc)
      _ -> do_random_chunk(rest, [Enum.join(chunk) | acc])
    end
  end
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
