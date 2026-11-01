# Release notes

MDEx now renders **Markdown** with _less_ overhead. See the [changelog](https://hexdocs.pm/mdex/changelog.html)
or open an issue at <https://github.com/leandrocp/mdex/issues>.

## Highlights

- Faster `MDEx.to_html/2`
- Same output, same options
- [x] Benchmarks with fixed inputs

```elixir
MDEx.to_html!("# Hello", extension: [table: true])
```

| Function | Returns |
| -------- | ------- |
| `to_html/2` | `{:ok, html}` |
| `to_html!/2` | `html` |

> Tip: pass `syntax_highlight: nil` when you don't need highlighting.
