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
  - [Quill Delta](https://quilljs.com/docs/delta/)
- Floki-like [Document AST](https://hexdocs.pm/mdex/MDEx.Document.html)
- Req-like [Document pipeline API](https://hexdocs.pm/mdex/MDEx.Document.html)
- [GitHub Flavored Markdown](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax)
- Discord and GitLab Flavored-ish Markdown
- Wiki-style links
- [Streaming](https://hexdocs.pm/mdex/MDEx.Document.html#module-streaming) incomplete fragments
- [Emoji](https://www.webfx.com/tools/emoji-cheat-sheet) shortcodes
- Built-in [Syntax Highlighting](https://autumnus.dev) for code blocks
- [Code Block Decorators](https://hexdocs.pm/mdex/code_block_decorators-2.html)
- HTML sanitization
- [~MD Sigil](https://hexdocs.pm/mdex/MDEx.Sigil.html) for Markdown, HTML, JSON, XML, and Quill Delta

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

Or use [Igniter](https://hexdocs.pm/igniter):

```sh
mix igniter.install mdex
```

## Usage

```elixir
iex> MDEx.to_html!("# Hello :smile:", extension: [shortcodes: true])
"<h1>Hello 😄</h1>"
```

```elixir
iex> MDEx.new(markdown: "# Hello :smile:", extension: [shortcodes: true]) |> MDEx.to_html!()
"<h1>Hello 😄</h1>"
```

```elixir
iex> import MDEx.Sigil
iex> ~MD[# Hello :smile:]HTML
"<h1>Hello 😄</h1>"
```

```elixir
iex> import MDEx.Sigil
iex> ~MD[# Hello :smile:]
#MDEx.Document(3 nodes)<
├── 1 [heading] level: 1, setext: false
│   ├── 2 [text] literal: "Hello "
│   └── 3 [short_code] code: "smile", emoji: "😄"
>
```

```elixir
iex> MDEx.new(streaming: true)
...> |> MDEx.Document.put_markdown("**Install")
...> |> MDEx.to_html!()
"<p><strong>Install</strong></p>"
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
|Streaming (fragments)|✅|❌|❌|❌|
|AST|✅|✅|✅|❌|
|AST to Markdown|✅|⚠️²|❌|❌|
|To HTML|✅|✅|✅|✅|
|To JSON|✅|❌|❌|❌|
|To XML|✅|❌|❌|✅|
|To Manpage|❌|❌|❌|✅|
|To LaTeX|❌|❌|❌|✅|
|To Quill Delta|✅|❌|❌|❌|
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

A [benchmark](benchmark.exs) is available to compare existing libs:

```
Name              ips        average  deviation         median         99th %
mdex          4546.79        0.22 ms     ±6.19%        0.22 ms        0.27 ms
md             475.87        2.10 ms     ±3.35%        2.09 ms        2.27 ms
earmark        142.21        7.03 ms     ±2.84%        6.98 ms        7.68 ms

Comparison:
mdex          4546.79
md             475.87 - 9.55x slower +1.88 ms
earmark        142.21 - 31.97x slower +6.81 ms

Memory usage statistics:

Comparison:
mdex           0.152 MB
md              6.37 MB - 41.86x memory usage +6.21 MB
earmark         4.34 MB - 28.51x memory usage +4.18 MB
```

The most performance gain is using the `~MD` sigil to compile the Markdown instead of parsing it at runtime,
prefer using it when possible.

To finish, a friendly reminder that all libs have their own strengths and trade-offs so use the one that better suits your needs.

## Acknowledgements

- [comrak](https://crates.io/crates/comrak) crate for all the heavy work on parsing Markdown and rendering HTML
- [Floki](https://hex.pm/packages/floki) for the AST
- [Req](https://hex.pm/packages/req) for the pipeline API
- Logo based on [markdown-mark](https://github.com/dcurtis/markdown-mark)
