For security reasons, every piece of raw HTML is omitted from the output by default:

```elixir
iex> MDEx.to_html!("<h1>Hello</h1>")
"<!-- raw HTML omitted -->"
```

That's not very useful for most cases, but you have a few options:

### Escape

The most basic is render raw HTML but escape it:

```elixir
iex> MDEx.to_html!("<h1>Hello</h1>", render: [escape: true])
"&lt;h1&gt;Hello&lt;/h1&gt;"
```

### Sanitize

But if the input is provided by external sources, it might be a good idea to sanitize it:

```elixir
iex> MDEx.to_html!("<a href=https://elixir-lang.org>Elixir</a>", render: [unsafe: true], sanitize: MDEx.default_sanitize_options())
"<p><a href=\"https://elixir-lang.org\" rel=\"noopener noreferrer\">Elixir</a></p>"
```

Note that you must pass the `unsafe: true` option to first generate the raw HTML in order to sanitize it.

It does clean HTML with a [conservative set of defaults](https://docs.rs/ammonia/latest/ammonia/fn.clean.html)
that works for most cases, but you can overwrite those rules for further customization.

For example, let's modify the [link rel](https://docs.rs/ammonia/latest/ammonia/struct.Builder.html#method.link_rel) attribute
to add `"nofollow"` into the `rel` attribute:

```elixir
iex> MDEx.to_html!("<a href=https://someexternallink.com>External</a>", render: [unsafe: true], sanitize: [link_rel: "nofollow noopener noreferrer"])
"<p><a href=\"https://someexternallink.com\" rel=\"nofollow noopener noreferrer\">External</a></p>"
```

In this case the default rule set is still applied but the `link_rel` rule is overwritten.

### Unsafe

If those rules are too strict and you really trust the input, or you really need to render raw HTML,
then you can just render it directly without escaping nor sanitizing:

```elixir
iex> MDEx.to_html!("<script>alert('hello')</script>", render: [unsafe: true])
"<script>alert('hello')</script>"
```
