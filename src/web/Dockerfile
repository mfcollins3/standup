# syntax=docker/dockerfile:1

# Builds the Standup web app as a container image that contains only the Mix
# release. The image is built for both linux/amd64 and linux/arm64.
#
# The build context is the src/web directory:
#
#   docker build -t standup-web src/web
#
# Run the image with:
#
#   DB_URI           postgresql://USER:PASS@HOST:5432/DATABASE
#   DATABASE_SSL     true, to connect to the database with TLS
#   SECRET_KEY_BASE  generate one with `mix phx.gen.secret`
#   PHX_HOST         the public host name of the app
#
# The container listens on port 8080 and answers GET /healthz.
#
# Keep the versions below in sync with src/web/.tool-versions (Elixir, Erlang
# and Node.js) and "packageManager" in src/web/assets/package.json (pnpm).
#
# The builder and runner images are based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the builder image
#     E.g.: docker.io/hexpm/elixir:1.20.5-erlang-29.1.2-debian-trixie-20261104-slim
#   - https://hub.docker.com/_/debian/tags?name=trixie-20261104-slim - for the runner image
#     E.g.: docker.io/debian:trixie-20261104-slim
#
# We use Debian instead of Alpine to avoid production compatibility issues (such
# as DNS resolution failures, and dynamically linked NIFs/precompiled binaries).
# The builder and runner images use the same Debian version.

ARG ELIXIR_VERSION=1.20.5
ARG OTP_VERSION=29.1.2
ARG DEBIAN_VERSION=trixie-20261104-slim
ARG NODE_VERSION=26.13.0
ARG PNPM_VERSION=12.16.1

ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}"
ARG NODE_IMAGE="docker.io/node:${NODE_VERSION}-trixie-slim"


# ---------------------------------------------------------------------------
# node: provides Node.js and pnpm to the builder, which builds the browser
# assets with Vite. pnpm 12 is installed from npm into this stage so that the
# builder only gets the files it needs.
# ---------------------------------------------------------------------------
FROM ${NODE_IMAGE} AS node

ARG PNPM_VERSION
RUN npm install --global "pnpm@${PNPM_VERSION}"


# ---------------------------------------------------------------------------
# builder: compiles the app, builds the assets, and creates the release.
# ---------------------------------------------------------------------------
FROM ${BUILDER_IMAGE} AS builder

# install build dependencies
RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git \
  && rm -rf /var/lib/apt/lists/*

# install Node.js and pnpm from the node stage
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules/pnpm /usr/local/lib/node_modules/pnpm
RUN ln -s ../lib/node_modules/pnpm/pnpm /usr/local/bin/pnpm

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force \
  && mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# install the JavaScript dependencies. This is done before the rest of the
# assets are copied, so that the install is only repeated when the dependencies
# change. phoenix_vite links the Phoenix packages from deps/, so this has to run
# after `mix deps.get`. The pnpm store is kept in a cache mount, so changed
# dependencies are only downloaded when they are not in the store yet.
ENV CI=true \
  npm_config_store_dir=/pnpm-store
COPY assets/package.json assets/pnpm-lock.yaml assets/pnpm-workspace.yaml assets/
RUN --mount=type=cache,id=pnpm-store,target=/pnpm-store \
  mix assets.setup

COPY priv priv

COPY lib lib

# Compile the release. LiveView writes the colocated hooks that Vite needs to
# _build during this step.
RUN mix compile

COPY assets assets

# compile assets
RUN mix assets.deploy

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release


# ---------------------------------------------------------------------------
# final: a new build stage so that the final image will only contain the
# compiled release and other runtime necessities.
# ---------------------------------------------------------------------------
FROM ${RUNNER_IMAGE} AS final

RUN apt-get update \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 libsctp1 locales ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# set runner ENV
ENV MIX_ENV="prod" \
  PHX_SERVER="true" \
  PORT="8080"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/standup ./

# Run as a user that is not root
USER nobody

EXPOSE 8080

# If using an environment that doesn't automatically reap zombie processes, it is
# advised to add an init process such as tini via `apt-get install`
# above and adding an entrypoint. See https://github.com/krallin/tini for details
# ENTRYPOINT ["/tini", "--"]

# Migrate the database, then start the server.
CMD ["/app/bin/docker-start"]
