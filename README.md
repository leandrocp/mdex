# MDEx

<!-- MDOC -->

<p align="center">
  <img src="https://raw.githubusercontent.com/leandrocp/mdex/main/assets/images/mdex_logo.png" width="360" alt="MDEx logo">
</p>

<p align="center">
  Fast and Extensible Markdown for Elixir.
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

- Support formats:
  - Markdown (CommonMark)
  - HTML
  - JSON
  - XML
- Floki-like [Document AST](https://hexdocs.pm/mdex/MDEx.Document.html)
- Req-like [Pipeline API](https://hexdocs.pm/mdex/MDEx.Pipe.html)
- Compliant with the [CommonMark spec](https://commonmark.org)
- Additional features:
  - GitHub Flavored Markdown
  - Discord and GitLab features
  - Wiki-style links
  - Emoji shortcodes
  - [Syntax highlighting](https://autumnus.dev) for code blocks
  - HTML sanitization
  - ~MD sigil for Markdown, HTML, JSON, and XML

### Foundation

The library is built on top of:

- [comrak](https://crates.io/crates/comrak) - a fast Rust port of [GitHub's CommonMark parser](https://github.com/github/cmark-gfm)
- [ammonia](https://crates.io/crates/ammonia) for HTML sanitization
- [autumnus](https://crates.io/crates/autumnus) for syntax highlighting

## Installation

Add `:mdex` dependency:

```elixir
def deps do
  [
    {:mdex, "~> 0.7"}
  ]
end
```

## Usage

```elixir
Mix.install([{:mdex, "~> 0.7"}])
```

```elixir
iex> MDEx.to_html!("# Hello")
"<h1>Hello</h1>"
```

```elixir
iex> MDEx.to_html!("# Hello :smile:", extension: [shortcodes: true])
"<h1>Hello 😄</h1>"
```

## Plugins

- [mdex_mermaid](https://hex.pm/packages/mdex_mermaid) - Render [Mermaid](https://mermaid.js.org) diagrams in code blocks

## Req-like Pipeline

[MDEx.Pipe](https://hexdocs.pm/mdex/MDEx.Pipe.html) provides a high-level API to manipulate a Markdown document and build plugins that can be attached to a pipeline:

````elixir
document = ~s"""
# Super Diagram

```mermaid
graph TD
  A[Enter Chart Definition] --> B(Preview)
  B --> C{decide}
  C --> D[Keep]
  C --> E[Edit Definition]
  E --> B
  D --> F[Save Image and Code]
  F --> B
```
"""

MDEx.new()
|> MDExMermaid.attach(mermaid_version: "11")
|> MDEx.to_html(document: document)
````

## ~MD Sigil

Convert and generate AST (MDEx.Document), Markdown (CommonMark), HTML, JSON, and XML formats.

```elixir
iex> import MDEx.Sigil
iex> ~MD|# Hello from `~MD` sigil|
%MDEx.Document{
  nodes: [
    %MDEx.Heading{
      nodes: [
        %MDEx.Text{literal: "Hello from "},
        %MDEx.Code{num_backticks: 1, literal: "~MD"},
        %MDEx.Text{literal: " sigil"}
      ],
      level: 1,
      setext: false
    }
  ]
}
```

```elixir
iex> import MDEx.Sigil
iex> ~MD|`~MD` also converts to HTML format|HTML
"<p><code>~MD</code> also converts to HTML format</p>"
```

```elixir
iex> import MDEx.Sigil
iex> ~MD|and to XML as well|XML
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE document SYSTEM \"CommonMark.dtd\">\n<document xmlns=\"http://commonmark.org/xml/1.0\">\n  <paragraph>\n    <text xml:space=\"preserve\">and to XML as well</text>\n  </paragraph>\n</document>"
```

`~MD` also accepts an `assigns` map to pass variables to the document:

```elixir
iex> import MDEx.Sigil
iex> assigns = %{lang: "Elixir"}
iex> ~MD|Running <%= @lang %>|HTML
"<p>Running Elixir</p>"
```

See more info at https://hexdocs.pm/mdex/MDEx.Sigil.html

## Code Block Decorators

Code block decorators allow you to customize the appearance and behavior of individual code blocks by adding special attributes to the info string (the part after the opening backticks).

### Prerequisites

To use code block decorators, you must enable both `:render` options:

```elixir
render: [
  github_pre_lang: true,
  full_info_string: true
]
```

### Available Decorators

| Decorator | Description | Supported Formatters | Example |
|-----------|-------------|---------------------|---------|
| `theme` | Override the syntax highlighting theme | All | `theme=github_dark` |
| `pre_class` | Add custom CSS classes to `<pre>` element | All | `pre_class="my-class"` |
| `highlight_lines` | Highlight single and/or range of lines | All | `highlight_lines="1,3-5"` |
| `highlight_lines_style` | Custom inline styles for highlighted lines | HTML inline only | `highlight_lines_style="background: yellow"` |
| `highlight_lines_class` | Custom CSS class for highlighted lines | All | `highlight_lines_class="emphasis"` |
| `include_highlights` | Add syntax token names as data attributes | All | `include_highlights` |

### Examples

_Following examples assume `render: [github_pre_lang: true, full_info_string: true]` is set._

#### Override Theme

Change the syntax highlighting theme for a specific code block:

````md
```elixir theme=github_dark
def hello do
  "Hello, world!"
end
```
````

Output: `<pre class="athl" style="color: #c9d1d9; background-color: #0d1117;">...`

#### Add Custom CSS Classes

Add your own CSS classes to the `<pre>` element:

````md
```javascript pre_class="code-example interactive"
console.log("Hello!");
```
````

Output: `<pre class="athl code-example interactive">...`

#### Highlight Specific Lines

Highlight individual lines or ranges (inclusive):

````md
# Highlight lines 1, 4, 5, and 6

```python highlight_lines="1,4-6"
import math

def calculate(x):
    result = x * 2
    # return calculated result
    return math.sqrt(x)
```
````

With `:html_inline` formatter, lines get styles from the theme's highlight color, for eg:

```html
<span style="background-color: #dae9f9;" data-line="1">...
```

With `:html_linked` formatter, the class `highlighted` is added to the highlighted lines, for eg:

```html
<span class="line highlighted" data-line="1">...
```

#### Custom Highlight Styling

Use either `highlight_lines_style` or `highlight_lines_class` to customize the appearance of highlighted lines:

````md
```ruby highlight_lines="2" highlight_lines_style="background: #ffeb3b; font-weight: bold;"
class User
  def initialize(name)
    @name = name
  end
end
```
````

#### Include Syntax Token Information

Add syntax token names in `data-highlight` attributes, useful for debugging or custom styling:

````md
```rust include_highlights
let x: i32 = 42;
```
````

Output: `<span data-highlight="keyword">let</span>`

#### Combine Multiple Decorators

Use multiple decorators together:

````md
```typescript theme=github_light pre_class="example" highlight_lines="2-3" include_highlights
interface User {
  name: string;    // highlighted
  email: string;   // highlighted
  age?: number;
}
```
````

### Important Notes

1. **Formatter Support**: Not all decorators work with all formatters:
   - `highlight_lines_style` only works with `:html_inline` formatter
   - `theme` only works with `:html_inline` formatter

2. **CSS Classes**: The `athl` class is always added to `<pre>` elements when using syntax highlighting

3. **Line Numbers**: The `data-line` attribute is added to each line for reference

4. **Order**: It's expected the first word of the code fence info string to be the language name, followed by decorators.
   - For example, `elixir theme=github_dark` is valid, but `theme=github_dark elixir` is not.

5. **Performance**: Decorators are processed at render time, so using many decorators may impact performance

## Safety

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

## Parsing

Converts Markdown to an AST data structure that can be inspected and manipulated to change the content of the document programmatically.

The data structure format is inspired on [Floki](https://github.com/philss/floki) (with `:attributes_as_maps = true`) so we can keep similar APIs and keep the same mental model when
working with these documents, either Markdown or HTML, where each node is represented as a struct holding the node name as the struct name and its attributes and children, for eg:

```elixir
%MDEx.Heading{
  level: 1
  nodes: [...],
}
```

The parent node that represents the root of the document is the [MDEx.Document](https://hexdocs.pm/mdex/MDEx.Document.html) struct,
where you can find more more information about the AST and what operations are available.

The complete list of nodes is listed in the [documentation](https://hexdocs.pm/mdex/), section `Document Nodes`.

## Formatting

Formatting is the process of converting from one format to another, for example from AST or Markdown to HTML.
Formatting to XML and to Markdown is also supported.

You can use [MDEx.parse_document/2](https://hexdocs.pm/mdex/MDEx.html#parse_document/2) to generate an AST or any of the `to_*` functions
to convert to Markdown (CommonMark), HTML, JSON, or XML.

## Examples

### GitHub Flavored Markdown with [emojis](https://www.webfx.com/tools/emoji-cheat-sheet/)

```elixir
MDEx.to_html!(~S"""
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
  unsafe: true,
]) |> IO.puts()
"""
<p>GitHub Flavored Markdown 🚀</p>
<ul>
  <li><input type="checkbox" checked="" disabled="" /> Task A</li>
  <li><input type="checkbox" checked="" disabled="" /> Task B</li>
  <li><input type="checkbox" disabled="" /> Task C</li>
</ul>
<table>
  <thead>
    <tr>
      <th>Feature</th>
      <th>Status</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Fast</td>
      <td>✅</td>
    </tr>
    <tr>
      <td>GFM</td>
      <td>✅</td>
    </tr>
  </tbody>
</table>
<p>Check out the spec at <a href="https://github.github.com/gfm/">https://github.github.com/gfm/</a></p>
"""
```

### Code Syntax Highlighting

````elixir
MDEx.to_html!(~S"""
```elixir
String.upcase("elixir")
```
""",
syntax_highlight: [
  formatter: {:html_inline, theme: "catppuccin_latte"}
]
) |> IO.puts()
"""
<pre class=\"autumn highlight\" style=\"background-color: #282C34; color: #ABB2BF;\">
  <code class=\"language-elixir\" translate=\"no\">
    <span class=\"namespace\" style=\"color: #61AFEF;\">String</span><span class=\"operator\" style=\"color: #C678DD;\">.</span><span class=\"function\" style=\"color: #61AFEF;\">upcase</span><span class=\"\" style=\"color: #ABB2BF;\">(</span><span class=\"string\" style=\"color: #98C379;\">&quot;elixir&quot;</span><span class=\"\" style=\"color: #ABB2BF;\">)</span>
  </code>
</pre>
"""
````

## Pre-compilation

Pre-compiled binaries are available for the following targets, so you don't need to have Rust installed to compile and use this library:

- `aarch64-apple-darwin`
- `aarch64-unknown-linux-gnu`
- `aarch64-unknown-linux-musl`
- `arm-unknown-linux-gnueabihf`
- `riscv64gc-unknown-linux-gnu`
- `x86_64-apple-darwin`
- `x86_64-pc-windows-gnu`
- `x86_64-pc-windows-msvc`
- `x86_64-unknown-freebsd`
- `x86_64-unknown-linux-gnu`
- `x86_64-unknown-linux-musl`

**Note:** The pre-compiled binaries for Linux are compiled using Ubuntu 22 on libc 2.35, which requires minimum Ubuntu 22, Debian Bookworm or a system with a compatible libc version. For older Linux systems, you'll need to compile manually.

### Compile manually

But in case you need or want to compile it yourself, you can do the following:

1. [Install Rust](https://www.rust-lang.org/tools/install)

2. Install a C compiler or build packages

It depends on your OS, for example in Ubuntu you can install the `build-essential` package.

3. Run:

```sh
export MDEX_BUILD=1
mix deps.get
mix compile
```

### Legacy CPUs

Modern CPU features are enabled by default but if your environment has an older CPU,
you can use legacy artifacts by adding the following configuration to your `config.exs`:

```elixir
config :mdex, use_legacy_artifacts: true
```

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
