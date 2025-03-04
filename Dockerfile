FROM hexpm/elixir:1.18.2-erlang-27.2.4-ubuntu-noble-20250127

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix archive.install hex igniter_new --force && \
    mix igniter.new my_app --install mdex --yes

WORKDIR /app/my_app

RUN echo '#!/bin/bash\n\
elixir --version\n\
mix deps | grep "mdex"\n\
exec "$@"' > /app/my_app/entrypoint.sh && chmod +x /app/my_app/entrypoint.sh

ENTRYPOINT ["/app/my_app/entrypoint.sh"]
