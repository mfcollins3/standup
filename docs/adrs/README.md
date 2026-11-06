# Architectural Decision Records

This directory contains the Architectural Decision Records (ADRs) for Naked
Standup. An ADR captures an important architectural decision, the context that
led to it, and its consequences. See [adr.github.io](https://adr.github.io/) for
more about ADRs.

New ADRs are created in the `proposed` state with a file name that starts with
`draft-`. When an ADR is approved, its status is changed to `accepted`.

| ADR | Status | Decision |
| --- | ------ | -------- |
| [Build the web app with Phoenix LiveView, phoenix_vite and React islands](draft-web-app-phoenix-with-phoenix-vite-and-react.md) | proposed | The web app is a Phoenix LiveView application bundled with phoenix_vite, with React and TypeScript islands for rich browser components, and pnpm for JavaScript dependencies. |
| [Use an Aspire TypeScript AppHost for local orchestration and Azure provisioning](draft-aspire-typescript-apphost-for-orchestration-and-provisioning.md) | proposed | An Aspire AppHost written in TypeScript runs the web app and PostgreSQL locally, and defines the Azure resources the product is deployed to. |
| [Build the container image once and deliver it from GHCR to Azure Container Registry](draft-build-once-container-delivery-ghcr-to-acr.md) | proposed | GitHub Actions builds the multi-platform image once, publishes it to GHCR, and the deployment imports that same image into Azure Container Registry instead of rebuilding it. |
