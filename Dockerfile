ARG ELIXIR_VERSION=1.16.2
ARG OTP_VERSION=26.2.5
ARG DEBIAN_VERSION=bookworm-20240130-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

######################### Build

FROM elixir:${ELIXIR_VERSION} as builder

RUN apt-get update -y && \
    apt-get -y install curl && \
    apt-get clean && \
    rm -f /var/lib/apt/lists/*_*

RUN mkdir /app

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

ENV MIX_ENV "prod"

COPY mix.exs /app
COPY mix.lock /app/mix.lock

RUN mix deps.get --only $MIX_ENV
RUN mkdir /app/config

COPY config/config.exs config/${MIX_ENV}.exs config/runtime.exs /app/config/
RUN mix deps.compile

COPY lib/ /app/lib
COPY rel/ /app/rel

RUN mix compile && \
    mix release

######################### Runner

FROM ${RUNNER_IMAGE}

RUN apt-get update && \
    apt-get -y install tini && \
    apt-get clean && \
    rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"

ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/teslamate_philips_hue_gradient_signe_table_lamp /app

# Copy scripts
COPY --chown=nobody:root startup.sh /app/startup.sh

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["/app/startup.sh"]%