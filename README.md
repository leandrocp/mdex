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
