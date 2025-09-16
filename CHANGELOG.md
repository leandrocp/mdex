# Changelog

## Unreleased

### Added
  - [Document] Add pretty print inspection for document AST
  - [Document] Add access by integer index for nodes in depth-first traversal order

### Fixed
  - [Collectable] Fix inline node merging

## 0.8.4 (2025-09-09

### Changes
  - [Delta] Support extra newlines between consecutive paragraphs (@Valian)

### Fixed
  - [Delta] Correct escape characters in table entries (@Valian)

## 0.8.3 (2025-09-08)

### Added
  - Add `MDEx.to_delta/2` and `MDEx.to_delta!/2` functions to convert Markdown to Quill Delta format (@Valian)
  - Support for all MDEx node types in Delta conversion with comprehensive attribute mappings (@Valian)
  - Custom converter system for Delta format allowing node-specific behavior overrides (@Valian)

### Changed
  - [Document] Collect (`Enum.into/2`) nodes into documents respecting nested structures and inline/block rules
  - [Document] Merge documents using `Enum.into/2`

## 0.8.2 (2025-08-20)

### Added
  - Add new `extension` option `cjk_friendly_emphasis`
  - [Docs] Add Custom Theme example
  - [Docs] Add Code Block Decorators guide
  - [Docs] Add mdex_gfm plugin

### Changed
  - [Deps] Update `autumnus` to v0.7.3
  - [Deps] Update `autumn` to v0.5.2

## 0.8.1 (2025-07-29)

### Added
  - [Sigil] Enable Code Block Decorators in `~MD` sigil

### Changed
  - [Docs] Add Livebook examples
  - [Docs] Reorganize docs to make it easier to navigate

## 0.8.0 (2025-07-26)

### Added
  - [Syntax Highlighter] Add support for Code Block Decorators
  - [Syntax Highlighter] Add language `caddy` and `fish`

### Changed
  - [Deps] Require `autumnn >= 0.5.0`
  - [Deps] Update `autumnus` to v0.7.0

### Breaking Changes
  - [Syntax Highlighter] Replace line tags `<span>` with `<div>`

## 0.7.5 (2025-07-02)

### Fixed
  - Match all nodes in `MDEx.Pipe.update_nodes/3`

## 0.7.4 (2025-07-02)

### Fixed
  - Accept the soft deprecated `:unsafe_` in `:render` options

## 0.7.3 (2025-06-24)

### Added
  - Add `MDEx.anchorize/1` to format text as an anchor (@paradox460)

### Changed
  - Build `x86_64-pc-windows-msvc` target on `windows-2022` instead of unsupported `windows-2019`

## 0.7.2 (2025-06-23)

### Fixed
  - Make sure `:syntax_highlight` is decoded with latest `autumn` version

## 0.7.1 (2025-06-20)

### Added
  - [Syntax Highlighter] Allow to disable the built-in syntax highlighter
  - [Options] Limited support for `:image_url_rewriter` extension
  - [Options] Limited support for `:link_url_rewriter` extension

### Changed
  - [Sigil] Disable `autolink` to avoid conflicts on HEEx templates
  - [Options] Rename `:unsafe_` to `:unsafe` in `:render` options. The old `:unsafe_` option still works.
  - [Syntax Highlighter] Update `autumnus` to v0.4.0 with new languages and themes

### Fixed
  - [Sigils] Remove `smart: true` option to avoid automatic conversion of punctuation.
  - [Docs] Update image in Dockerfile example

## 0.7.0 (2025-05-21)

This versions introduces a new sigil `~MD` that supersedes the `~M` and `~m` sigils.

To migrate from `~M` to `~MD`, you can simply replace `~M` with `~MD` in your code.

To migrate from `~m` to `~MD`, you should define an `assigns` map with the values you want to expose:

```elixir
# before
lang = ":elixir"
~m|`lang = #{lang}`|

# after
assigns = %{lang: ":elixir"}
~MD|`lang = <%= @lang %>`|
```

### Breaking Changes
  * Minimum required Elixir version is now v1.15

### Deprecations
  * Deprecate `~M` sigil in favor of `~MD`
  * Deprecate `~m` sigil in favor of `~MD`

### Enhancements
  * Introduce the `~MD` sigil

## 0.6.2 (2025-05-13)

### Enhancements
  * [Deps] Update comrak to v0.39
  * [Deps] Move doc dependencies to `:doc` group to avoid unnecessary downloads
  * [Sanitize] Added the following tag attribute rules by default:
    - code: class translate tabindex
    - pre: class style
    - span: class style data-line
  * [Pipe] Added `MDEx.Pipe.is_sanitize_enabled/1`
  * [Pipe] Added `MDEx.Pipe.get_sanitize_option/3`

### Breaking Changes
  * [comrak] Removed option `:experimental_inline_sourcepos`. It's included by default now.

### Fixes
  * [Syntax Highlight] Class and style are applied when sanitize is enabled

### Docs
  * Add comparison table with other libraries

## 0.6.1 (2025-04-18)

### Changes
  * [Syntax Highlighter] Defaults to `[formatter: [{:html_inline, theme: "onedark"}]]`

## 0.6.0 (2025-04-18)

This version introduces some minor breaking changes and some deprecations, see the change log below.

The biggest change is the migration from [Inkjet](https://crates.io/crates/inkjet) to [Autumnus](https://autumnus.dev) for the syntax highlighter,
which can cause breaking changes in the syntax highlighter output, for example a missing theme or different class names or styles.
Please open an issue if you find any problems.

### Breaking Changes
  * [Syntax Highlighter] Renamed `<pre>` tag class from "autumn-hl" to "athl"
  * [Syntax Highlighter] Changed `<span>` tag class from "ahl-{token}" to "{token}", for eg: "ahl-punctuation" changed to "punctuation"
  * Removed type `t:MDEx.features_option/0`
  * Removed function `MDEx.default_features_options/0`
  * Removed function `MDEx.Pipe.put_features_options/2`

### Deprecations
  * Option `:features` is deprecated in favor of `:syntax_highlight` and `:sanitize`

### Enhancements
  * Lines are now wrapped in `<span>` tags as `<span class="line" data-line="{line_number}">`, for eg: `<span class="line" data-line="12">...`
  * Added `tabindex="0"` attribute into `<code>` tag for better accessibility
  * Added function `MDEx.Pipe.put_syntax_highlight_options/2`
  * Added function `MDEx.Pipe.put_sanitize_options/2`

### Changes
  * Replaced Inkjet with Autumnus in the Syntax Highlighter adapter

## 0.5.0 (2025-03-31)

### Enhancements
  * Introduce `MDEx.Pipe` - a Req-like pipeline to manipulate Markdown documents and write plugins
  * Added `JSON` modifier to `~m` and `~M` sigils
  * Added `MDEx.Document.wrap/1`

### Fixes
  * Revert to NIF 2.15 only

### Changes
  * Updated `comrak` to v0.37.0

## 0.4.3 (2025-03-29)

### Enhancements
  * New logo
  * Custom sanitization options by @kivikakk
  * Added `to_json/1` and `to_json/2` to convert Markdown or MDEx.Document to JSON
  * Added support to parse JSON to MDEx.Document in `parse_document/1` and `parse_document/2`
  * Document and validate all options (comrak and ammonia)

### Fixes
  * Fix `:unsafe_` options in sigils, effectively enabling them
  * [Docs] Tag `Alert` node as Document Node

### Breaking changes
  * Bump minimum required Elixir version to 1.14
  * Sigils now properly enable the `:unsafe_` option, which may cause breaking changes to some users

### Deprecations
  * Renamed `to_commonmark/1` and `to_commonmark/2` to `to_markdown/1` and `to_markdown/2`
  * Renamed `to_commonmark!/1` and `to_commonmark!/2` to `to_markdown!/1` and `to_markdown!/2`

## 0.4.2 (2025-03-25)

### Enhancements
  * Added target `riscv64gc-unknown-linux-gnu target`
  * Added binaries for NIF version 2.16

### Fixes
  * Fixed glibc version mismatch on `x86_64-unknown-linux-gnu` target

### Docs
  * Added section Pre-compilation listing all targets, how to compile the project,
    and how to enable targets for legacy CPUs.
  * Added example in `MDEx.Document` on how to bump Heading levels

## 0.4.1 (2025-03-24)

### Enhancements
  * Added target `arm-unknown-linux-gnueabihf` used by Raspberry Pi

## 0.4.0 (2025-03-10)

### Enhancements
  * Added support for [GitHub](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#alerts)
    and [GitLab](https://docs.gitlab.com/user/markdown/#alerts) alerts.
  * Process alerts by default in Sigils.
  * Added `:experimental_minimize_commonmark` render option.

### Docs
  * Add nimble_publisher example by @PJUllrich

### Chores
  * Add sample Dockerfile for debugging

## 0.3.3 (2025-02-03)

### Fixes
  * Fix `MDEx.Document.fetch/2` spec

## 0.3.2 (2025-01-11)

### Enhancements
  * Add `MDEx.safe_html/2` utility function to sanitize and escape HTML content

### Fixes
  * HTML: encode `{` and `}` only inside `<code>` tags to avoid disabling LiveView expressions

## 0.3.1 (2025-01-08)

### Enhancements
  * HTML: encode `{` and `}` as `&lbrace;` and `&rbrace;` to avoid LiveView syntax errors in HEEx templates

## 0.3.0 (2024-12-16)

Be aware, this version introduces major breaking changes:
- AST format has changed
- Sigils `~m` and `~M` now returns `%MDEx.Document{}` instead of a Markdown string (use the `MD` modifier to have the old behavior)

These changes enables the implementation of protocols to improve the manipulation of the AST,
see the [MDEx.Document](https://hexdocs.pm/mdex/MDEx.Document.html) module and [examples](https://github.com/leandrocp/mdex/tree/main/examples) for more info.

### Breaking changes
  * Changed the AST format from `{name, attributes, children}` to structs as `%MDEx.Heading{level: 1, nodes: [%MDEx.Text{literal: "Hello"}]}`
  * Sigils `~m` and `~M` now returns `%MDEx.Document{}` instead of a Markdown string
  * Removed `MDEx.attribute/2` in favor of pattern matching key/value pairs in node structs

### Enhancements
  * New AST format based on structs
  * Introduced modifiers `HTML`, `XML`, and `MD` for both sigils `~m` and `~M`
  * Introduced `MDEx.traverse_and_update/3` with the `acc` argument
  * Updated autumn to properly escape curly braces in HEEx template on LiveView 1.0
  * Updated comrak to v0.31
      - New node `MDEx.Subscript`
      - New attr `is_task_item` in list nodes
      - New option `render.figure_with_caption`
      - New option `render.tasklist_classes`
      - New option `render.ol_width`

## 0.2.0 (2024-10-09)

### Breaking changes
  * `to_html/1` and `to_html/2` now returns `{:ok, String.t()}` or `{:error, %MDEx.DecodeError{}}` instead of just `String.t()`.
    The reason is because now they may accept an AST as input which may cause decoding errors.
    Replace with `to_html!/1` and `to_html!/2` to have the same behavior as before.

### Fixes
  * Fix misspelling of `thematic` causing render errors - [#73](https://github.com/leandrocp/mdex/pull/73) by @jonklein

### Enhancements
  * Added `to_commonmark/1` and `to_commonmark/2` to convert an AST to CommonMark - [#70](https://github.com/leandrocp/mdex/pull/70) by @jonklein
  * Added `~M` sigil (no interpolation) with `AST` and `MD` modifiers (defaults to HTML without the modifier)
  * Added `~m` sigil (supports interpolation and escaping) with `AST` and `MD` modifiers (defaults to HTML without the modifier)
  * Added `parse_document/1` and `parse_document/2` to parse Markdown to AST
  * Added low-level functions `traverse_and_update/2` and `attribute/2` to manipulate AST
  * Added `to_html!/1` and `to_html!/2`, the raising version of `to_html/1` and `to_html/2` (similar to previous `to_html/1` and `to_html/2`)
  * Changed `to_html/1` and `to_html/2` to accept AST as input
  * Added examples directory to show how to use the new APIs

## 0.1.18 (2024-07-13)

### Enhancements
  * Bump comrak from [0.24.1 to 0.26.0](https://github.com/kivikakk/comrak/blob/9f4d391abe2857031f993c4cdddf1ebba7cdbc7d/changelog.txt#L1-L60)
  * Add new `extension` options: underline, spoiler, greentext
  * Add new `render` options: experimental_inline_sourcepos, escaped_char_spans, ignore_setext, ignore_empty_links, gfm_quirks, prefer_fenced

## 0.1.17 (2024-06-19)

### Enhancements
  * Relax minimum required Elixir version to 1.13
  * Bump comrak to 0.24.1
  * Bump ammonia to 4.0
  * Add new `extension` options: multiline_block_quotes, math_dollars, math_code, shortcodes, wikilinks_title_after_pipe, wikilinks_title_before_pipe
  * Add new `render` option: escaped_char_spans
  * Add new option `features.syntax_highlight_inline_style` to control whether to embed inline styles or not. Default is `true`.

### Changed
  * Build binaries on MacOS 12

## 0.1.16 (2024-04-29)

### Enhancements
  * Added language `objc` to syntax highlighter.

## 0.1.15 (2024-04-16)

### Enhancements
  * Update rustler to `~> 0.32`
  * Update rustler_precompiled `~> 0.7`
  * Added legacy targets

### Backwards incompatible changes
  * Minimum required Elixir version is now 1.14
  * Removed target `arm-unknown-linux-gnueabihf`
  * Removed target `riscv64gc-unknown-linux-gnu`

## 0.1.14 (2024-04-11)

### Backwards incompatible changes
  * [Syntax Highlight] Renamed parent `<pre>` class from `autumn-highlight` to `autumn-hl`
  * [Syntax Highlight] Added prefix `ahl-` to each scope class

### Enhancements
  * Update autumn to 0.2.2 (#33)
  * Update comrak to 0.20.0 (#27) - @supernintendo

## 0.1.13 (2023-11-20)

### Enhancements
  * Update autumn themes to add base16-tomorrow and base16-tomorrow-night - @paradox460

## 0.1.12 (2023-11-06)

### Fixes
  * Comrak docs links

### Enhancements
  * Add languages: jsx, tsx, vim
  * Bump injket v0.10.2

## 0.1.11 (2023-10-25)

### Fixes
  * Syntax highlighting - remove newlines to avoid formatting incorrectly

## 0.1.10 (2023-10-24)

### Enhancements
  * Add translate="no" attr in `<code>` tag

### Fixes
  * Fix Javascript syntax highlight
  * Fix Typescript syntax highlight

## 0.1.9 (2023-09-29)

### Enhancements
  * Add logo
  * Add icon

## 0.1.8 (2023-09-29)

### Enhancements
  * Fallback to plain text on invalid language
  * Syntax highlight injections
  * Add samples

## 0.1.7 (2023-09-27)

### Enhancements
  * Syntax highlight code using tree-sitter and helix editor themes. Use https://github.com/leandrocp/autumn/tree/main/native/inkjet_nif under the hood.

## 0.1.6 (2023-09-14)

### Enhancements
  * Load extra themes and syntaxes with https://crates.io/crates/two-face

## 0.1.5 (2023-09-12)

### Enhancements
  * Sanitize output with https://crates.io/crates/ammonia
  * Syntax Highlight with https://crates.io/crates/syntect

## 0.1.4 (2023-09-11)

### Fixes
  * Compile on Ubuntu 20 to fix libc version mismatch

## 0.1.3 (2023-09-11)

### Enhancements
  * NIF version 2.15

## 0.1.2 (2023-09-11)

### Enhancements
  * Guard markdown arg

### Fixes
  * specs

## 0.1.1 (2023-09-11)

### Enhancements
  * Update Rust to edition 2021
  * Add `@spec` to public functions

## 0.1.0 (2023-09-11)

### Enhancements
  * `MDEx.to_html/1` to convert Markdown to HTML using default options.
  * `MDEx.to_html/2` to convert Markdown to HTML using custom options.
