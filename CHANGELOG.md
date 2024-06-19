# Changelog

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
