ARG ELIXIR_VERSION=1.17.3-otp-27
ARG OTP_VERSION=27.1.2
ARG DEBIAN_VERSION=bookworm-20240130-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

######################### Build

FROM elixir:${ELIXIR_VERSION} as builder

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
COPY lib/ /app/lib
COPY rel/ /app/rel

RUN mix deps.compile && \
    mix compile && \
    mix release

######################### Runner

FROM ${RUNNER_IMAGE}

RUN mkdir youtube-audio && \
    mkdir youtube-video && \
    apt-get update && \
    apt-get -y install tini locales openssl && \
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

CMD ["/app/startup.sh"]