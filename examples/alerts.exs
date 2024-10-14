Mix.install([
  {:mdex, path: ".."}
])

opts = [
  extension: [autolink: true],
  render: [unsafe_: true]
]

markdown = """
# Alerts Example

In this example we'll render blockquotes as alerts.

Ref https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#alerts

> [!NOTE]
> Useful information that users should know, even when skimming content.

> [!CAUTION]
> Advises about risks or negative outcomes of certain actions.
"""

note_html = fn content ->
  """
  <div class="max-w-md rounded-lg border bg-background p-4 shadow-sm mt-10" role="alert">
    <div class="flex items-center gap-2">
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="12"
        height="12"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="text-blue-500"
      >
        <path d="M8 2v4" />
        <path d="M16 2v4" />
        <path d="M3 10h18" />
        <path d="M10 14h4" />
        <path d="M12 12v6" />
        <rect width="18" height="18" x="3" y="4" rx="2" />
      </svg>
      <h5 class="text-sm font-medium text-blue-500">Note</h5>
    </div>
    <p class="mt-2 text-sm text-muted-foreground">
      #{content}
    </p>
  </div>
  """
end

caution_html = fn content ->
  """
  <div class="max-w-md rounded-lg border border-red-200 bg-red-50 p-4 shadow-sm mt-10" role="alert">
    <div class="flex items-center gap-2">
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="12"
        height="12"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="text-red-500"
      >
        <path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z" />
        <path d="M12 9v4" />
        <path d="M12 17h.01" />
      </svg>
      <h5 class="text-sm font-medium text-red-500">Caution</h5>
    </div>
    <p class="mt-2 text-sm text-red-700">
      #{content}
    </p>
  </div>
  """
end

html =
  markdown
  |> MDEx.parse_document!(opts)
  |> MDEx.traverse_and_update(fn
    # inject tailwind
    {"document", attrs, children} ->
      tailwind =
        MDEx.parse_document!("""
        <script src="https://cdn.tailwindcss.com"></script>
        """)

      {"document", attrs, children ++ tailwind}

    # inject a html block to render a note alert
    {"block_quote", _attrs, [{"paragraph", %{}, ["[!NOTE]", _note_attrs, note_content]}]} ->
      alert = note_html.(note_content)
      {"html_block", %{"literal" => alert}, []}

    # inject a html block to render a caution alert
    {"block_quote", _attrs, [{"paragraph", %{}, ["[!CAUTION]", _note_attrs, note_content]}]} ->
      alert = caution_html.(note_content)
      {"html_block", %{"literal" => alert}, []}

    node ->
      node
  end)
  |> MDEx.to_html!(opts)

File.write!("alerts.html", html)

IO.puts(html)
