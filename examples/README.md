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

## LiveView

Convert markdown to a LiveView HEEx template supporting Phoenix components

```sh
iex live_view.exs
```

To replicate this example in a real application, copy the `MDEx.LiveView` module into your application,
then import it in your LiveView or in your application `Web` module (see `DemoLive` in the example).

Note that you can change the options passed to `MDEx.to_html!/2` in the `sigil_M` macro.