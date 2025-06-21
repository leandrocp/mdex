## Examples

Currently all examples depend on unrelead code present only in the `main` branch,
to execute it will need Rust installed to compile the dependencies.

### Liquid

Render [Liquid Tags](https://shopify.github.io/liquid/)

```sh
elixir liquid.exs && open liquid.html
```

## Mermaid

Render [Mermaid Diagrams](https://mermaid-js.github.io/mermaid/)

```sh
elixir mermaid.exs && open mermaid.html
```

## Alerts

Render [GitHub Alerts](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#alerts)

```sh
elixir alerts.exs && open alerts.html
```

## Highlight

Render `==` as `<mark>` tags as described at https://www.markdownguide.org/extended-syntax/#highlight

```sh
elixir highlight.exs && open highlight.html
```

## NimblePublisher + LiveView

Build your blog posts using the [NimblePublisher](https://github.com/dashbitco/nimble_publisher) library and serve them with LiveView.

```sh
iex nimble_publisher.exs
```

Open [localhost:4000](http://localhost:4000) to view the rendered blog post.
