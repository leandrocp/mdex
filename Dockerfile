# https://github.com/phoenixframework/phoenix/blob/v1.7/priv/templates/phx.gen.release/Dockerfile.eex
ARG ELIXIR_VERSION=1.18.3
ARG OTP_VERSION=27.3.4
ARG DEBIAN_VERSION=bullseye-20250428-slim
ARG IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"

FROM ${IMAGE}

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

ENTRYPOINT ["elixir", "-e", "Mix.install([:mdex]); IO.puts(MDEx.to_html!(\"# It Works!\"))"]
