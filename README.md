# MDEx

<!-- MDOC -->

<p align="center">
  <img src="https://raw.githubusercontent.com/leandrocp/mdex/main/assets/images/mdex_logo.png" width="512" alt="MDEx logo">
</p>

<p align="center">
  A fast 100% CommonMark-compatible GitHub Flavored Markdown parser and formatter for Elixir.
</p>

<p align="center">
  <a href="https://hex.pm/packages/mdex">
    <img alt="Hex Version" src="https://img.shields.io/hexpm/v/mdex">
  </a>

  <a href="https://hexdocs.pm/mdex">
    <img alt="Hex Docs" src="http://img.shields.io/badge/hex.pm-docs-green.svg?style=flat">
  </a>

  <a href="https://opensource.org/licenses/MIT">
    <img alt="MIT" src="https://img.shields.io/hexpm/l/mdex">
  </a>
</p>

## Features

- Fast. Check out the [benchmark](https://github.com/leandrocp/mdex#benchmark)
- Compatible with the [CommonMark spec](https://spec.commonmark.org) and the [GitHub Flavored Markdown Spec](https://github.github.com/gfm/)
- Binary is precompiled, no need to compile anything
- Code syntax highlithging, performed by [Autumn](https://github.com/leandrocp/autumn)

Check out some samples at https://mdex-c31.pages.dev

## Installation

Add `:mdex` dependecy:

```elixir
def deps do
  [
    {:mdex, "~> 0.1"}
  ]
end
```

## Usage

```elixir
Mix.install([{:mdex, "~> 0.1"}])
```

```elixir
MDEx.to_html("# Hello")
#=> "<h1>Hello</h1>\n"
```

And you can change how the markdown is parsed and formatted by passing options to `MDEx.to_html/2` to enable more features:

### GitHub Flavored Markdown with emojis

```elixir
MDEx.to_html(
  ~S"""
  # GitHub Flavored Markdown :rocket:

  - [x] Task A
  - [x] Task B
  - [ ] Task C

  | Feature | Status |
  | ------- | ------ |
  | Fast | :white_check_mark: |
  | GFM  | :white_check_mark: |

  Check out the spec at https://github.github.com/gfm/
  """,
  extension: [
    strikethrough: true,
    tagfilter: true,
    table: true,
    autolink: true,
    tasklist: true,
    footnotes: true,
    shortcodes: true,
  ],
  parse: [
    smart: true,
    relaxed_tasklist_matching: true,
    relaxed_autolinks: true
  ],
  render: [
     github_pre_lang: true,
     escape: true
  ]
) |> IO.puts()
#=> <p>GitHub Flavored Markdown 🚀</p>
#=> <ul>
#=>   <li><input type="checkbox" checked="" disabled="" /> Task A</li>
#=>   <li><input type="checkbox" checked="" disabled="" /> Task B</li>
#=>   <li><input type="checkbox" disabled="" /> Task C</li>
#=> </ul>
#=> <table>
#=>   <thead>
#=>     <tr>
#=>       <th>Feature</th>
#=>       <th>Status</th>
#=>     </tr>
#=>   </thead>
#=>   <tbody>
#=>     <tr>
#=>       <td>Fast</td>
#=>       <td>✅</td>
#=>     </tr>
#=>     <tr>
#=>       <td>GFM</td>
#=>       <td>✅</td>
#=>     </tr>
#=>   </tbody>
#=> </table>
#=> <p>Check out the spec at <a href="https://github.github.com/gfm/">https://github.github.com/gfm/</a></p>
```

### Code Syntax Highlighting

````elixir
MDEx.to_html(~S"""
```elixir
String.upcase("elixir")
```
""",
features: [syntax_highlight_theme: "catppuccin_latte"]
) |> IO.puts()
#=> <pre class=\"autumn highlight\" style=\"background-color: #282C34; color: #ABB2BF;\">
#=>   <code class=\"language-elixir\" translate=\"no\">
#=>     <span class=\"namespace\" style=\"color: #61AFEF;\">String</span><span class=\"operator\" style=\"color: #C678DD;\">.</span><span class=\"function\" style=\"color: #61AFEF;\">upcase</span><span class=\"\" style=\"color: #ABB2BF;\">(</span><span class=\"string\" style=\"color: #98C379;\">&quot;elixir&quot;</span><span class=\"\" style=\"color: #ABB2BF;\">)</span>
#=>   </code>
#=> </pre>
````

## Demo and Samples

A [livebook](https://github.com/leandrocp/mdex/blob/main/playground.livemd) and a [script](https://github.com/leandrocp/mdex/blob/main/playground.exs) are available to play with and experiment with this library, or you can check out all [available samples](https://github.com/leandrocp/mdex/tree/main/priv/generated/samples) at https://mdex-c31.pages.dev

## Used By

- [BeaconCMS](https://github.com/BeaconCMS/beacon)
- [Tableau](https://github.com/elixir-tools/tableau)

_Using it and want your project listed here? Please send a PR!_

## Benchmark

A [simple script](benchmark.exs) is available to compare existing libs:

```
Name              ips        average  deviation         median         99th %
cmark         22.82 K      0.0438 ms    ±16.24%      0.0429 ms      0.0598 ms
mdex           3.57 K        0.28 ms     ±9.79%        0.28 ms        0.33 ms
md             0.34 K        2.95 ms    ±10.56%        2.90 ms        3.62 ms
earmark        0.25 K        4.04 ms     ±4.50%        4.00 ms        4.44 ms

Comparison:
cmark         22.82 K
mdex           3.57 K - 6.39x slower +0.24 ms
md             0.34 K - 67.25x slower +2.90 ms
earmark        0.25 K - 92.19x slower +4.00 ms
```

## Motivation

* `earmark` is extensible but [can't parse](https://github.com/RobertDober/earmark_parser/issues/126) all kinds of documents and is slow to convert hundreds of markdowns.
* `md` is very extensible but the doc says "If one needs to perfectly parse the common markdown, Md is probably not the correct choice" which is probably the cause for failing to parse many documents.
* `markdown` is not precompiled and has not received updates in a while.
* `cmark` is a fast CommonMark parser but it requires compiling the C library, is hard to extend, and was archieved on Apr 2024

_Note that MDEx is the only one that syntax highlights out-of-the-box which contributes to make it slower than cmark._

To finish, a friendly reminder that all libs have their own strengths and trade-offs.

## Looking for help with your Elixir project?

<img src="https://raw.githubusercontent.com/leandrocp/mdex/main/assets/images/dockyard_logo.png" width="256" alt="DockYard logo">

At DockYard we are [ready to help you build your next Elixir project](https://dockyard.com/phoenix-consulting).
We have a unique expertise in Elixir and Phoenix development that is unmatched and we love to [write about Elixir](https://dockyard.com/blog/categories/elixir).

Have a project in mind? [Get in touch](https://dockyard.com/contact/hire-us)!

## Acknowledgements

* Use Rust's [comrak crate](https://crates.io/crates/comrak) under the hood.
* [Logo](https://www.flaticon.com/free-icons/rpg) created by by Freepik - Flaticon
* [Logo font](https://github.com/quoteunquoteapps/CourierPrime) designed by [Alan Greene](https://github.com/a-dg)