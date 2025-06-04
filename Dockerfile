ARG ELIXIR_VERSION=1.18.3
ARG OTP_VERSION=27.3.4
ARG UBUNTU_VERSION=jammy-20250404
ARG IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-ubuntu-${UBUNTU_VERSION}"

FROM ${IMAGE}

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

ENTRYPOINT ["elixir", "-e", "Mix.install([:mdex]); IO.puts(MDEx.to_html!(\"# It Works!\"))"]
