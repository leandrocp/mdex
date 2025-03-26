# https://github.com/elixir-explorer/explorer/blob/d11216282bbdb0dcaef2519c2bfefda46c2981e0/lib/explorer/polars_backend/native.ex

defmodule MDEx.Native do
  @moduledoc false

  mix_config = Mix.Project.config()
  version = mix_config[:version]
  github_url = mix_config[:package][:links][:GitHub]
  mode = if Mix.env() in [:dev, :test], do: :debug, else: :release

  use_legacy =
    Application.compile_env(
      :mdex,
      :use_legacy_artifacts,
      System.get_env("MDEX_USE_LEGACY_ARTIFACTS") in ["true", "1"]
    )

  variants_for_linux = [
    legacy_cpu: fn ->
      # These are the same from the release workflow.
      # See the meaning in: https://unix.stackexchange.com/a/43540
      needed_caps = ~w[fxsr sse sse2 ssse3 sse4_1 sse4_2 popcnt avx fma]

      use_legacy or
        (is_nil(use_legacy) and
           not MDEx.ComptimeUtils.cpu_with_all_caps?(needed_caps))
    end
  ]

  other_variants = [legacy_cpu: fn -> use_legacy end]

  use RustlerPrecompiled,
    otp_app: :mdex,
    crate: "comrak_nif",
    version: version,
    base_url: "#{github_url}/releases/download/v#{version}",
    targets: ~w(
      aarch64-apple-darwin
      aarch64-unknown-linux-gnu
      aarch64-unknown-linux-musl
      arm-unknown-linux-gnueabihf
      riscv64gc-unknown-linux-gnu
      x86_64-apple-darwin
      x86_64-pc-windows-gnu
      x86_64-pc-windows-msvc
      x86_64-unknown-freebsd
      x86_64-unknown-linux-gnu
      x86_64-unknown-linux-musl
    ),
    variants: %{
      "x86_64-unknown-linux-gnu" => variants_for_linux,
      "x86_64-pc-windows-msvc" => other_variants,
      "x86_64-pc-windows-gnu" => other_variants,
      "x86_64-unknown-freebsd" => other_variants
    },
    nif_versions: ["2.15", "2.16"],
    mode: mode,
    force_build: System.get_env("MDEX_BUILD") in ["1", "true"]

  def safe_html(_unsafe_html, _sanitize, _escape_content, _escape_curly_braces_in_code), do: :erlang.nif_error(:nif_not_loaded)

  # markdown
  #   - to document (parse)
  #   - to html
  #   - to xml
  def parse_document(_md, _opts), do: :erlang.nif_error(:nif_not_loaded)
  def markdown_to_html(_md), do: :erlang.nif_error(:nif_not_loaded)
  def markdown_to_html_with_options(_md, _opts), do: :erlang.nif_error(:nif_not_loaded)
  def markdown_to_xml(_md), do: :erlang.nif_error(:nif_not_loaded)
  def markdown_to_xml_with_options(_md, _opts), do: :erlang.nif_error(:nif_not_loaded)

  # document
  #   - to markdown (commonmark)
  #   - to html
  #   - to xml
  def document_to_commonmark(_doc), do: :erlang.nif_error(:nif_not_loaded)
  def document_to_commonmark_with_options(_doc, _opts), do: :erlang.nif_error(:nif_not_loaded)
  def document_to_html(_doc), do: :erlang.nif_error(:nif_not_loaded)
  def document_to_html_with_options(_doc, _opts), do: :erlang.nif_error(:nif_not_loaded)
  def document_to_xml(_doc), do: :erlang.nif_error(:nif_not_loaded)
  def document_to_xml_with_options(_doc, _opts), do: :erlang.nif_error(:nif_not_loaded)
end
