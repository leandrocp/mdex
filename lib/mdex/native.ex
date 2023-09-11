defmodule MDEx.Native do
  @moduledoc false

  mix_config = Mix.Project.config()
  version = mix_config[:version]
  github_url = mix_config[:package][:links][:GitHub]
  mode = if Mix.env() in [:dev, :test], do: :debug, else: :release

  use RustlerPrecompiled,
    otp_app: :mdex,
    crate: "comrak_nif",
    base_url: "#{github_url}/releases/download/v#{version}",
    version: version,
    nif_versions: ["2.15"],
    mode: mode,
    force_build: System.get_env("MDEX_BUILD") in ["1", "true"]

  def to_html(_md), do: :erlang.nif_error(:nif_not_loaded)
  def to_html_with_options(_md, _options), do: :erlang.nif_error(:nif_not_loaded)
end
