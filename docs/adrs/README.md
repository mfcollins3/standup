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
