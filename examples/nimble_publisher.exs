Mix.install([
  :mdex,
  {:phoenix_live_view, "~> 1.0"},
  {:phoenix_playground, "~> 0.1"},
  {:nimble_publisher, "~> 1.1"},
  {:phoenix_html, "~> 4.2"}
])

defmodule MDEx.Posts.Post do
  @enforce_keys [:id, :title, :date, :body]
  defstruct [:id, :title, :date, :body]

  def build(filepath, attrs, body) do
    [year, month, day, id] =
      filepath |> Path.rootname() |> Path.split() |> List.last() |> String.split("-", parts: 4)

    id =
      id
      |> String.trim_trailing(".md")
      |> String.downcase()

    date = Date.from_iso8601!("#{year}-#{month}-#{day}")

    struct!(__MODULE__, Map.merge(attrs, %{id: id, date: date, body: body}))
  end
end

defmodule MDEx.Posts.Parser do
  def parse(_path, contents) do
    [header, markdown_body] = String.split(contents, "---\n", trim: true, parts: 2)

    {%{} = attrs, _} = Code.eval_string(header, [])
    html_body = markdown_to_html!(markdown_body)

    {attrs, html_body}
  end

  defp markdown_to_html!(markdown_body) do
    MDEx.to_html!(markdown_body,
      syntax_highlight: [formatter: {:html_inline, theme: "github_dark"}],
      extension: [
        strikethrough: true,
        underline: true,
        tagfilter: true,
        table: true,
        autolink: true,
        tasklist: true,
        footnotes: true,
        shortcodes: true
      ],
      parse: [
        smart: true,
        relaxed_tasklist_matching: true,
        relaxed_autolinks: true
      ],
      render: [
        github_pre_lang: true,
        escape: true,
        hardbreaks: true
      ]
    )
  end
end

defmodule MDEx.Posts.HTMLConverter do
  # ⚠️ Important ⚠️
  # You need to provide a custom converter, because otherwise NimblePublisher
  # will apply their default markdown -> HTML conversion which will
  # interfere with MDEx's conversion.
  def convert(_extname, body, _attrs, _opts), do: body
end

defmodule MDEx.Posts do
  use NimblePublisher,
    # Update this filepath to your application
    # and move the `posts` folder inside your `priv` folder.
    #
    # from: Application.app_dir(:my_app, "priv/posts/*.md"),
    from: Path.join([Path.absname(__DIR__), "posts", "*.md"]),
    build: MDEx.Posts.Post,
    parser: MDEx.Posts.Parser,
    html_converter: MDEx.Posts.HTMLConverter,
    as: :posts,
    highlighters: []

  @posts Enum.sort_by(@posts, & &1.date, {:desc, Date})

  def all_posts, do: @posts

  defmodule NotFoundError do
    defexception [:message, plug_status: 404]
  end

  def get_post_by_id!(id) do
    Enum.find(all_posts(), &(&1.id == id)) ||
      raise NotFoundError, "post with id=#{id} not found"
  end
end

defmodule MDEx.DemoLive do
  use Phoenix.LiveView
  import Phoenix.HTML

  def mount(%{"id" => post_id}, _session, socket) do
    post = MDEx.Posts.get_post_by_id!(post_id)
    {:ok, assign(socket, :post, post)}
  end

  # Show the first blog post by default.
  # In your app, you'd show an overview of the blog posts instead.
  def mount(_params, session, socket) do
    mount(%{"id" => "example-post"}, session, socket)
  end

  def render(assigns) do
    ~H"""
    <h1>{@post.title}</h1>
    <h2>{@post.date}</h2>
    <article>
    {raw(@post.body)}
    </article>
    """
  end
end

PhoenixPlayground.start(live: MDEx.DemoLive)
