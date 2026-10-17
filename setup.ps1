#!/usr/bin/env pwsh

$ErrorActionPreference = 'Stop'

# Install prek to manage Git hook execution
prek install
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
