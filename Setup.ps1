#!/usr/bin/env pwsh

# Copyright 2026 Michael F. Collins, III
# Licensed under the Naked Standup Source-Available Temporary License
# See LICENSE.md for license terms.

# Setup.ps1
#
# This script is used to prepare the Naked Standup project for development.
# Setup.ps1 will install necessary dependencies and tools, and will perform any 
# necessary configuration steps and setup tasks. This script only needs to be 
# run once, immediately after cloning the repository.
#
# Usage: &"./Setup.ps1"

$ErrorActionPreference = "Stop"

# Install Spec Kit's agents, prompts, and tools for the host platform.
uvx --from git+https://github.com/github/spec-kit.git specify init `
    --here `
    --ai copilot `
    --script ps `
    --force

# Restore constitution.md because Spec Kit overwrote it with a template.
git restore .specify/memory/constitution.md

# Install development tools using mise.
if ($IsMacOS) {
    mise install

    # Generate the Xcode workspace for the Apple applications.
    Push-Location Apple
    tuist install
    tuist generate
    Pop-Location
}
