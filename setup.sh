#!/usr/bin/env bash

set -euo pipefail

# Install prek to manage Git hook execution
prek install \
    --hook-type commit-msg \
    --hook-type pre-commit \
    --hook-type pre-push
