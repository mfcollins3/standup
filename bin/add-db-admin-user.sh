#!/usr/bin/env bash

# Copyright 2026 Michael F. Collins, III
# Licensed under the Naked Standup Source-Available Temporary License
# See LICENSE.md for license terms.

MY_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
MY_UPN=$(az ad signed-in-user show --query userPrincipalName -o tsv)

az postgres flexible-server microsoft-entra-admin create \
  --resource-group rg-standup-dev \
  --server-name psql-standup-gwogbfg3k7hpm \
  --object-id "$MY_OBJECT_ID" \
  --display-name "$MY_UPN" \
  --type User
