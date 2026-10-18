#!/usr/bin/env pwsh

$ErrorActionPreference = 'Stop'

# Install prek to manage Git hook execution
prek install `
    --hook-type commit-msg `
    --hook-type pre-commit `
    --hook-type pre-push
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
