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
mdex         16694.30      0.0599 ms     ±5.98%      0.0596 ms      0.0713 ms
md             858.68        1.16 ms     ±3.74%        1.15 ms        1.30 ms
earmark        478.00        2.09 ms     ±1.90%        2.09 ms        2.20 ms

Comparison:
mdex         16694.30
md             858.68 - 19.44x slower +1.10 ms
earmark        478.00 - 34.93x slower +2.03 ms
```
