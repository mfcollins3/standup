#!/usr/bin/env bash

set -euo pipefail

# Install prek to manage Git hook execution
prek install \
    --hook-type commit-msg \
    --hook-type pre-commit \
    --hook-type pre-push

# Install the project dependencies for the Aspire AppHost
pushd aspire-apphost > /dev/null
pnpm install --frozen-lockfile
popd > /dev/null
