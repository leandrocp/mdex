# MDEx

A fast 100% CommonMark-compatible GitHub Flavored Markdown parser and formatter for Elixir.

Use Rust's [comrak crate](https://crates.io/crates/comrak) under the hood.

[![Documentation](http://img.shields.io/badge/hex.pm-docs-green.svg?style=flat)](https://hexdocs.pm/mdex)
[![Package](https://img.shields.io/hexpm/v/mdex.svg)](https://hex.pm/packages/mdex)

## Installation

Add `:mdex` dependecy:

```elixir
def deps do
  [
    {:mdex, "~> 0.1"}
  ]
end
```

## Benchmark

A [simple script](benchmark.exs) is available to compare existing libs:

```
Name              ips        average  deviation         median         99th %
cmark         24.01 K      0.0417 ms    ±14.11%      0.0405 ms      0.0631 ms
mdex          16.37 K      0.0611 ms     ±9.65%      0.0601 ms      0.0870 ms
md             0.85 K        1.18 ms     ±4.72%        1.16 ms        1.36 ms
earmark        0.47 K        2.14 ms     ±2.82%        2.13 ms        2.42 ms

Comparison:
cmark         24.01 K
mdex          16.37 K - 1.47x slower +0.0194 ms
md             0.85 K - 28.36x slower +1.14 ms
earmark        0.47 K - 51.47x slower +2.10 ms
```

## Motivation

If any of the available libraries are working for you, keep using it, if not then keep reading.

* `earmark` [can't parse](https://github.com/RobertDober/earmark_parser/issues/126) all kinds of documents and is slow to convert hundreds of markdowns.
* `md` is fast and extensible but the doc says "If one needs to perfectly parse the common markdown, Md is probably not the correct choice" so it also fails to parse many documents.
* `markdown` is not precompiled and has not received updates in a while.
* `cmark` is a fast CommonMark parser but it requires compiling the C library and it's harder to extend (unless you're confortable with C).

So given those trade-offs, mdex brings some benefits over the alternatives:
- Fast
- CommonMark spec
- Binary is precompiled, no need to compile anything
- Easier to work with since it's Rust
