# MDEx

<!-- MDOC -->

<div align="center">
  <img src="https://raw.githubusercontent.com/leandrocp/mdex/main/assets/images/mdex_logo.png" width="360" alt="MDEx logo" />
  <br>

  <a href="https://hex.pm/packages/mdex">
    <img alt="Hex Version" src="https://img.shields.io/hexpm/v/mdex">
  </a>

  <a href="https://hexdocs.pm/mdex">
    <img alt="Hex Docs" src="http://img.shields.io/badge/hex.pm-docs-green.svg?style=flat">
  </a>

  <a href="https://opensource.org/licenses/MIT">
    <img alt="MIT" src="https://img.shields.io/hexpm/l/mdex">
  </a>

  <p align="center">Fast and Extensible Markdown for Elixir.</p>
</div>

## Features

- Fast
- Compliant with the [CommonMark spec](https://commonmark.org)
- [Plugins](https://hexdocs.pm/mdex/plugins.html)
- Formats:
  - Markdown (CommonMark)
  - HTML
  - JSON
  - XML
- Floki-like [Document AST](https://hexdocs.pm/mdex/MDEx.Document.html)
- Req-like [Pipeline API](https://hexdocs.pm/mdex/MDEx.Pipe.html)
- [GitHub Flavored Markdown](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax)
- Discord and GitLab Flavored-ish Markdown
- Wiki-style links
- [Emoji](https://www.webfx.com/tools/emoji-cheat-sheet) shortcodes
- Built-in [Syntax Highlighting](https://autumnus.dev) for code blocks
- [Code Block Decorators](https://hexdocs.pm/mdex/code_block_decorators.html)
- HTML sanitization
- [~MD Sigil](https://hexdocs.pm/mdex/MDEx.Sigil.html) for Markdown, HTML, JSON, and XML

## Examples

Livebook examples are available at [Pages / Examples](https://hexdocs.pm/mdex/gfm.html)

## Installation

Add `:mdex` dependency:

```elixir
def deps do
  [
    {:mdex, "~> 0.8"}
  ]
end
```

## Usage

```elixir
iex> MDEx.to_html!("# Hello :smile:", extension: [shortcodes: true])
"<h1>Hello 😄</h1>"
```

```elixir
iex> import MDEx.Sigil
iex> ~MD[
...> # Hello :smile:
...> ]HTML
"<h1>Hello 😄</h1>"
```
```elixir
iex> import MDEx.Sigil
iex> ~MD[
...> # Hello :smile:
...> ]
%MDEx.Document{nodes: [%MDEx.Heading{nodes: [%MDEx.Text{literal: "Hello "}, %MDEx.ShortCode{code: "smile", emoji: "😄"}], level: 1, setext: false}]}
```

## Foundation

The library is built on top of:

- [comrak](https://crates.io/crates/comrak) - a fast Rust port of [GitHub's CommonMark parser](https://github.com/github/cmark-gfm)
- [ammonia](https://crates.io/crates/ammonia) for HTML Sanitization
- [autumnus](https://crates.io/crates/autumnus) for Syntax Highlighting

<!-- MDOC -->

## Used By

- [BeaconCMS](https://github.com/BeaconCMS/beacon)
- [Tableau](https://github.com/elixir-tools/tableau)
- [Bonfire](https://github.com/bonfire-networks/bonfire-app)
- [00](https://github.com/technomancy-dev/00)
- [Plural Console](https://github.com/pluralsh/console)
- [Exmeralda](https://github.com/bitcrowd/exmeralda)
- [Algora](https://github.com/algora-io/algora)
- [Ash AI](https://github.com/ash-project/ash_ai)
- [Canada Navigator](https://github.com/canada-ca/navigator)
- And [more...](https://github.com/search?q=lang%3Aelixir+%3Amdex&type=code)

_Are you using MDEx and want to list your project here? Please send a PR!_

## Motivation

MDEx was born out of the necessity of parsing CommonMark files, to parse hundreds of files quickly, and to be easily extensible by consumers of the library.

- [earmark](https://hex.pm/packages/earmark) is extensible but [can't parse](https://github.com/RobertDober/earmark_parser/issues/126) all kinds of documents and is slow to convert hundreds of markdowns.
- [md](https://hex.pm/packages/md) is very extensible but the doc says "If one needs to perfectly parse the common markdown, Md is probably not the correct choice" and CommonMark was a requirement to parse many existing files.
- [markdown](https://hex.pm/packages/markdown) is not precompiled and has not received updates in a while.
- [cmark](https://hex.pm/packages/cmark) is a fast CommonMark parser but it requires compiling the C library, is hard to extend, and was archived on Apr 2024.

## Comparison

|Feature|MDEx|Earmark|md|cmark|
| --- | --- | --- | --- | --- |
|Active|✅|✅|✅|❌|
|Pure Elixir|❌|✅|✅|❌|
|Extensible|✅|✅|✅|❌|
|Syntax Highlighting|✅|❌|❌|❌|
|Code Block Decorators|✅|❌|❌|❌|
|AST|✅|✅|✅|❌|
|AST to Markdown|✅|⚠️²|❌|❌|
|To HTML|✅|✅|✅|✅|
|To JSON|✅|❌|❌|❌|
|To XML|✅|❌|❌|✅|
|To Manpage|❌|❌|❌|✅|
|To LaTeX|❌|❌|❌|✅|
|Emoji|✅|❌|❌|❌|
|GFM³|✅|✅|❌|❌|
|GitLab⁴|⚠️¹|❌|❌|❌|
|Discord⁵|⚠️¹|❌|❌|❌|

1. Partial support
2. Possible with [earmark_reversal](https://hex.pm/packages/earmark_reversal)
3. GitHub Flavored Markdown
4. GitLab Flavored Markdown
5. Discord Flavored Markdown

## Benchmark

A [simple script](benchmark.exs) is available to compare existing libs:

```
Name              ips        average  deviation         median         99th %
cmark          7.17 K       0.139 ms     ±4.20%       0.138 ms       0.165 ms
mdex           2.71 K        0.37 ms     ±7.95%        0.36 ms        0.45 ms
md            0.196 K        5.11 ms     ±2.51%        5.08 ms        5.55 ms
earmark      0.0372 K       26.91 ms     ±2.09%       26.77 ms       30.25 ms

Comparison:
cmark          7.17 K
mdex           2.71 K - 2.65x slower +0.23 ms
md            0.196 K - 36.69x slower +4.98 ms
earmark      0.0372 K - 193.04x slower +26.77 ms
```

The most performance gain is using the `~MD` sigil to compile the Markdown instead of parsing it at runtime,
prefer using it when possible:

```
Comparison:
mdex_sigil_MD    176948.46 K
cmark                31.47 K - 5622.76x slower +31.77 μs
mdex_to_html/1        7.32 K - 24184.36x slower +136.67 μs
md                    2.05 K - 86176.93x slower +487.01 μs
earmark               0.21 K - 855844.67x slower +4836.68 μs
```

To finish, a friendly reminder that all libs have their own strengths and trade-offs so use the one that better suits your needs.

## Acknowledgements

- [comrak](https://crates.io/crates/comrak) crate for all the heavy work on parsing Markdown and rendering HTML
- [Floki](https://hex.pm/packages/floki) for the AST
- [Req](https://hex.pm/packages/req) for the pipeline API
- Logo based on [markdown-mark](https://github.com/dcurtis/markdown-mark)
