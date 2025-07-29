### Pre-compilation

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


