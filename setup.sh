#!/usr/bin/env bash

# Copyright 2026 Michael F. Collins, III
# Licensed under the Naked Standup Source-Available Temporary License
# See LICENSE.md for license terms.

# setup.sh
#
# This script is used to prepare the Naked Standup project for development. 
# setup.sh will install necessary dependencies and tools, and will perform any 
# necessary configuration steps and setup tasks. This script only needs to be 
# run once, immediately after cloning the repository.
#
# Usage: ./setup.sh

set -e

# Install Spec Kit's agents, prompts, and tools for the host platform.
uvx --from git+https://github.com/github/spec-kit.git specify init \
    --here \
    --ai copilot \
    --script sh \
    --force

# Restore constitution.md because Spec Kit overwrote it with a template.
git restore .specify/memory/constitution.md
