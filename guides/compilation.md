### Pre-compilation

MDEx uses the `:mdex_native` dependency for its Rust-backed Markdown parser, HTML sanitizer, and syntax highlighter. Precompiled binaries are available for these targets, so Rust is not required in the common case:

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

If you need to compile the native dependency yourself:

1. [Install Rust](https://www.rust-lang.org/tools/install)

2. Install a C compiler or build packages

It depends on your OS, for example in Ubuntu you can install the `build-essential` package.

3. Run:

```sh
export MDEX_NATIVE_BUILD=1
mix deps.get
mix compile
```

To enable syntax highlighting with Lumis, add `:lumis` to your deps:

```elixir
{:lumis, "~> 0.1"}
```

Then configure `:mdex_native` before compiling dependencies:

```elixir
config :mdex_native, syntax_highlighter: :lumis
```

To use Syntect instead:

```elixir
config :mdex_native, syntax_highlighter: :syntect
```

Disable with `nil` to download a minimal NIF without any syntax highlighter:


```elixir
config :mdex_native, syntax_highlighter: nil
```

Syntax highlighting is disabled by default in MDEx. Even after compiling `:mdex_native` with Lumis or Syntect, pass `:syntax_highlight` options to enable highlighting for a render.

With `syntax_highlight: nil`, MDEx still adds the language class for code blocks but does not syntax highlight them.

### Legacy CPUs

Modern CPU features are enabled by default in `:mdex_native`. If your environment has an older CPU,
you can use legacy artifacts by adding the following configuration to your `config.exs`:

```elixir
config :mdex_native, use_legacy_artifacts: true
```
