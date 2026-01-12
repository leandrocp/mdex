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
  - [Phoenix HEEx](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Rendered.html)
  - JSON
  - XML
  - [Quill Delta](https://quilljs.com/docs/delta/)
- Floki-like [Document AST](https://hexdocs.pm/mdex/MDEx.Document.html)
- Req-like [Document pipeline API](https://hexdocs.pm/mdex/MDEx.Document.html)
- [GitHub Flavored Markdown](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax)
- Discord and GitLab Flavored-ish Markdown
- Wiki-style links
- Phoenix HEEx components and expressions
- [Streaming](https://hexdocs.pm/mdex/MDEx.Document.html#module-streaming) incomplete fragments
- [Emoji](https://www.webfx.com/tools/emoji-cheat-sheet) shortcodes
- Built-in [Syntax Highlighting](https://autumnus.dev) for code blocks
- [Code Block Decorators](https://hexdocs.pm/mdex/code_block_decorators-2.html)
- HTML sanitization
- [~MD Sigil](https://hexdocs.pm/mdex/MDEx.Sigil.html) for Markdown, HTML, HEEx, JSON, XML, and Quill Delta

## Installation

Add `:mdex` dependency:

```elixir
def deps do
  [
    {:mdex, "~> 0.11"}
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
iex> assigns = %{project: "MDEx"}
iex> ~MD[# {@project}]HEEX
%Phoenix.LiveView.Rendered{...}
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

## Examples

Livebook examples are available at [Pages / Examples](https://hexdocs.pm/mdex/gfm.html)

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
- [Jido](https://github.com/agentjido)
- And [more...](https://github.com/search?q=lang%3Aelixir+%3Amdex&type=code)

_Are you using MDEx and want to list your project here? Please send a PR!_

## Sponsors

💜 **Support MDEx Development**

If you or your company find MDEx useful, please consider sponsoring its development.

➡️ **[GitHub Sponsors](https://github.com/sponsors/leandrocp)**

Your support helps maintain and improve MDEx for the entire Elixir community!

**Current and previous sponsors**

<a href="https://dockyard.com" target="_blank"><img src="assets/images/dockyard_logo.svg" width="200" alt="DockYard" /></a>

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
|Phoenix HEEx components|✅|❌|❌|❌|
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
mdex          8983.16       0.111 ms     ±6.52%       0.110 ms       0.144 ms
md             461.00        2.17 ms     ±2.64%        2.16 ms        2.35 ms
earmark        110.47        9.05 ms     ±3.17%        9.02 ms       10.01 ms

Comparison:
mdex          8983.16
md             461.00 - 19.49x slower +2.06 ms
earmark        110.47 - 81.32x slower +8.94 ms

Memory usage statistics:

Name            average  deviation         median         99th %
mdex         0.00184 MB     ±0.00%     0.00184 MB     0.00184 MB
md              6.45 MB     ±0.00%        6.45 MB        6.45 MB
earmark         5.09 MB     ±0.00%        5.09 MB        5.09 MB

Comparison:
mdex         0.00184 MB
md              6.45 MB - 3506.37x memory usage +6.45 MB
earmark         5.09 MB - 2770.15x memory usage +5.09 MB
```

The most performance gain is using the `~MD` sigil to compile the Markdown instead of parsing it at runtime,
prefer using it when possible.

To finish, a friendly reminder that all libs have their own strengths and trade-offs so use the one that better suits your needs.

## Acknowledgements

- [comrak](https://crates.io/crates/comrak) crate for all the heavy work on parsing Markdown and rendering HTML
- [Floki](https://hex.pm/packages/floki) for the AST
- [Req](https://hex.pm/packages/req) for the pipeline API
- Logo based on [markdown-mark](https://github.com/dcurtis/markdown-mark)
