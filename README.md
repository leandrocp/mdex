# MDEx

<!-- MDOC -->

<p align="center">
  <img src="https://raw.githubusercontent.com/leandrocp/mdex/main/assets/images/mdex_logo.png" width="512" alt="MDEx logo">
</p>

<p align="center">
  A CommonMark-compliant fast and extensible Markdown parser and formatter for Elixir.
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

Compliant with [CommonMark](https://spec.commonmark.org) and [GitHub Flavored Markdown](https://github.github.com/gfm) specifications with extra [extensions](https://docs.rs/comrak/latest/comrak/struct.ExtensionOptions.html)
as Wiki Links, Discord Markdown tags, and emoji. Also supports syntax highlighting out-of-the-box using the [Autumn](https://github.com/leandrocp/autumn) library.

Under the hood it's calling the [comrak](https://crates.io/crates/comrak) APIs to process Markdown,
a fast Rust crate that ports the cmark fork maintained by GitHub, a widely and well adopted Markdown implementation.

The AST format is based on [Floki](https://hex.pm/packages/floki) so the same API to manipulate HTML can be used to manipulate Markdown documents.
Check out some examples at [mdex/examples/](https://github.com/leandrocp/mdex/tree/main/examples)

And some samples are available at https://mdex-c31.pages.dev

## Installation

Add `:mdex` dependency:

```elixir
def deps do
  [
    {:mdex, "~> 0.2"}
  ]
end
```

## Usage

```elixir
Mix.install([{:mdex, "~> 0.2"}])
```

```elixir
MDEx.to_html!("# Hello")
"<h1>Hello</h1>\n"
```

```elixir
MDEx.to_html!("# Hello :smile:", extension: [shortcodes: true])
"<h1>Hello 😄</h1>\n"
```

## Sigils

Convert between Markdown, HTML, and AST.

```elixir
import MDEx.Sigil
```

```elixir
~M|# Hello from `~M` sigil|
"<h1>Hello from <code>~M</code> sigil</h1>\n"
```

```elixir
~M|`~M` can return the AST too|AST
[
  {"document", [], [{"paragraph", [], [{"code", [{"num_backticks", 1}, {"literal", "~M"}], []}, " can return the AST too"]}]}
]
"<h1>Hello</h1>\n"
```

```elixir
title = "Hello from variable"

~m|[{"document", [], [{"heading", [], ["#{title}"]}]}]|
"<h1>Hello from variable</h1>\n"
```

See all modifiers and examples at https://hexdocs.pm/mdex/MDEx.Sigil.html

## Safety

For security reasons, every piece of raw HTML is omitted from the output by default:

```elixir
MDEx.to_html!("<h1>Hello</h1>")
"<!-- raw HTML omitted -->\n"
```

That's not very useful for most cases, so you can render raw HTML but escaping it for safety:

```elixir
MDEx.to_html!("<h1>Hello</h1>", render: [escape: true])
"&lt;h1&gt;Hello&lt;/h1&gt;\n"
```

If the input is provided by external sources, it might be a good idea to sanitize it instead for extra security:

```elixir
MDEx.to_html!("<a href=https://elixir-lang.org/>Elixir</a>", render: [unsafe_: true], features: [sanitize: true])
"<p><a href=\"https://elixir-lang.org/\" rel=\"noopener noreferrer\">Elixir</a></p>\n"
```

Note that you must pass the `unsafe_: true` option to first generate the raw HTML in order to sanitize it.

All sanization rules are defined in the [ammonia docs](https://docs.rs/ammonia/latest/ammonia/fn.clean.html).
For example, the link in the example below was marked as `noopener noreferrer` to prevent attacks.

If those rules are too strict and you really trust the input, or you really need to render raw HTML,
then you can just render it directly without escaping nor sanitizing:

```elixir
MDEx.to_html!("<script>alert('hello')</script>", render: [unsafe_: true])
"<script>alert('hello')</script>\n"
```

## Parsing

Converts Markdown to an AST data structure that can be inspected and manipulated to change the content of the document.

The data structure shape is exactly the same as the one used by [Floki](https://github.com/philss/floki) so we can reuse the same APIs and keep the same mental model when
working with these documents, either Markdown or HTML, where each node is represented as:

```elixir
{name, attributes, children}
```

Example:

```elixir
MDEx.parse_document!("# Hello")
[{"document", [], [{"heading", [{"level", 1}, {"setext", false}], ["Hello"]}]}]
```

Note that text nodes have no attributes nor children, so it's represented as a string inside a list.

You can find the full AST spec on the MDEx module types section.

## Formatting

Converts the AST to a human-readable document, most commonly to HTML, example:

```elixir
MDEx.to_html!([{"document", [], [{"heading", [{"level", 1}, {"setext", false}], ["Hello"]}]}])
"<h1>Hello</h1>\n"
```

_More formats can be added in the future._

Any missing attribute will be filled with the default value, and extra attributes will be ignored. So you could have the same result with:

```elixir
MDEx.to_html!([{"document", [], [{"heading", [], ["Hello"]}]}])
"<h1>Hello</h1>\n"
```

Default values are defined on a best-case scenario but as a good practice you should provide all attributes for each node.

Trying to format malformed ASTs will return a `{:error, %DecodeError{}}` describing what and where the error occurred, for example:

```elixir
{:error, decode_error} = MDEx.to_html([{"code", [{1, "foo"}], []}], [])
{:error,
 %MDEx.DecodeError{
   reason: :attr_key_not_string,
   found: "1",
   node: "(<<\"code\">>, [{1,<<\"foo\">>}], [])",
   attr: "(1, <<\"foo\">>)",
   kind: "Integer"
 }}

decode_error |> Exception.message() |> IO.puts()
# invalid attribute key
#
# Expected an attribute key encoded as UTF-8 binary
#
# Got:
#
#   1
#
# Type:
#
#   Integer
#
# In this node:
#
#   (<<"code">>, [{1,<<"foo">>}], [])
#
# In this attribute:
#
#   (1, <<"foo">>)
```

## Options

You can enable extensions and change the output of the generated Markdown by passing any of the available [Comrak Options](https://docs.rs/comrak/latest/comrak/struct.Options.html)
as keyword lists or also an additional `:features` option.

_The full documentation and list of all options with description and examples can be found on the links below:_

* `:extension` - https://docs.rs/comrak/latest/comrak/struct.ExtensionOptions.html
* `:parse` - https://docs.rs/comrak/latest/comrak/struct.ParseOptions.html
* `:render` - https://docs.rs/comrak/latest/comrak/struct.RenderOptions.html
* `:features` - see the available options below

### Features Options

* `:sanitize` (defaults to `false`) - sanitize output using [ammonia](https://crates.io/crates/ammonia). See the [Safety](#module-safety) section for more info.
* `:syntax_highlight_theme` (defaults to `"onedark"`) - syntax highlight code fences using [autumn themes](https://github.com/leandrocp/autumn/tree/main/priv/themes),
you should pass the filename without special chars and without extension, for example you should pass `syntax_highlight_theme: "adwaita_dark"` to use the [Adwaita Dark](https://github.com/leandrocp/autumn/blob/main/priv/themes/adwaita-dark.toml) theme
* `:syntax_highlight_inline_style` (defaults to `true`) - embed styles in the output for each generated token. You'll need to [serve CSS themes](https://github.com/leandrocp/autumn?tab=readme-ov-file#linked) if inline styles are disabled to properly highlight code

See some examples below on how to use the provided options:

### GitHub Flavored Markdown with [emojis](https://www.webfx.com/tools/emoji-cheat-sheet/)

```elixir
MDEx.to_html!(
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
# <p>GitHub Flavored Markdown 🚀</p>
# <ul>
#   <li><input type="checkbox" checked="" disabled="" /> Task A</li>
#   <li><input type="checkbox" checked="" disabled="" /> Task B</li>
#   <li><input type="checkbox" disabled="" /> Task C</li>
# </ul>
# <table>
#   <thead>
#     <tr>
#       <th>Feature</th>
#       <th>Status</th>
#     </tr>
#   </thead>
#   <tbody>
#     <tr>
#       <td>Fast</td>
#       <td>✅</td>
#     </tr>
#     <tr>
#       <td>GFM</td>
#       <td>✅</td>
#     </tr>
#   </tbody>
# </table>
# <p>Check out the spec at <a href="https://github.github.com/gfm/">https://github.github.com/gfm/</a></p>
```

### Code Syntax Highlighting

````elixir
MDEx.to_html!(~S"""
```elixir
String.upcase("elixir")
```
""",
features: [syntax_highlight_theme: "catppuccin_latte"]
) |> IO.puts()
# <pre class=\"autumn highlight\" style=\"background-color: #282C34; color: #ABB2BF;\">
#   <code class=\"language-elixir\" translate=\"no\">
#     <span class=\"namespace\" style=\"color: #61AFEF;\">String</span><span class=\"operator\" style=\"color: #C678DD;\">.</span><span class=\"function\" style=\"color: #61AFEF;\">upcase</span><span class=\"\" style=\"color: #ABB2BF;\">(</span><span class=\"string\" style=\"color: #98C379;\">&quot;elixir&quot;</span><span class=\"\" style=\"color: #ABB2BF;\">)</span>
#   </code>
# </pre>
````

## Demo and Samples

A [livebook](https://github.com/leandrocp/mdex/blob/main/playground.livemd) and a [script](https://github.com/leandrocp/mdex/blob/main/playground.exs) are available to play with and experiment with this library, or you can check out all [available samples](https://github.com/leandrocp/mdex/tree/main/priv/generated/samples) at https://mdex-c31.pages.dev

## Used By

- [BeaconCMS](https://github.com/BeaconCMS/beacon)
- [Tableau](https://github.com/elixir-tools/tableau)
- And [more...](https://github.com/search?q=lang%3Aelixir+%3Amdex&type=code)

_Are you using MDEx and want to list your project here? Please send a PR!_

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

MDEx was born out of the necessity of parsing CommonMark files, to parse hundreds of files quickly, and to be easily extensible by consumer of the library.

* [earmark](https://hex.pm/packages/earmark) is extensible but [can't parse](https://github.com/RobertDober/earmark_parser/issues/126) all kinds of documents and is slow to convert hundreds of markdowns.
* [md](https://hex.pm/packages/md) is very extensible but the doc says "If one needs to perfectly parse the common markdown, Md is probably not the correct choice" and CommonMark was a requirement to parse many existing files.
* [markdown](https://hex.pm/packages/markdown) is not precompiled and has not received updates in a while.
* [cmark](https://hex.pm/packages/cmark) is a fast CommonMark parser but it requires compiling the C library, is hard to extend, and was archived on Apr 2024

_Note that MDEx is the only one that syntax highlights out-of-the-box which contributes to make it slower than cmark._

To finish, a friendly reminder that all libs have their own strengths and trade-offs so use the one that better suit your needs.

## Looking for help with your Elixir project?

<img src="https://raw.githubusercontent.com/leandrocp/mdex/main/assets/images/dockyard_logo.png" width="256" alt="DockYard logo">

At DockYard we are [ready to help you build your next Elixir project](https://dockyard.com/phoenix-consulting).
We have a unique expertise in Elixir and Phoenix development that is unmatched and we love to [write about Elixir](https://dockyard.com/blog/categories/elixir).

Have a project in mind? [Get in touch](https://dockyard.com/contact/hire-us)!

## Acknowledgements

* [comrak](https://crates.io/crates/comrak) crate for all the heavy work on parsing Markdown and rendering HTML
* [Floki](https://hex.pm/packages/floki) for the AST manipulation
* [Logo](https://www.flaticon.com/free-icons/rpg) created by Freepik - Flaticon
* [Logo font](https://github.com/quoteunquoteapps/CourierPrime) designed by [Alan Greene](https://github.com/a-dg)
