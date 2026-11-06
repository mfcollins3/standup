# Naked Standup AppHost

This directory contains the [Aspire](https://aspire.dev) AppHost for Naked
Standup. The AppHost is written in TypeScript (`apphost.mts`). It runs the
product locally for development and testing, and it is where the Azure
resources are defined when the product is deployed.

When you run the AppHost locally, Aspire starts:

| Resource   | What it is                                                              |
| ---------- | ----------------------------------------------------------------------- |
| `postgres` | A PostgreSQL container, with its data kept in a Docker volume.          |
| `db`       | The `standup` database on that server.                                  |
| `web`      | The Phoenix app in [`../web`](../web), started with `mix` from source.  |

Aspire generates the database credentials and passes the connection details to
the web app as environment variables. `src/web/config/runtime.exs` uses `DB_URI`
to configure Ecto, and `PORT` for the HTTP port. Starting the app also creates
and migrates the database.

## Prerequisites

* The [Aspire CLI](https://aspire.dev/get-started/install-cli/) (13.6 or later)
* A container runtime that Aspire supports, such as Docker
* Elixir and Erlang/OTP (see `../web/.tool-versions`)
* Node.js and [pnpm](https://pnpm.io) (see `packageManager` in `package.json`)

## Run locally

Install the web app's dependencies once, then start the AppHost:

```shell
cd src/web
mix deps.get
mix assets.setup

cd ../apphost
pnpm install
export pnpm_config_allow_builds='{"esbuild":true}'  # see below
aspire run
```

`aspire run` prints a link to the Aspire dashboard. The dashboard shows each
resource, its logs, and the URL of the web app.

To run in the background, use `aspire run --detach`, and use `aspire describe`,
`aspire logs`, and `aspire stop` to work with it.

Running `mix phx.server` in `src/web` still works without Aspire. It uses the
database settings in `src/web/config/dev.exs`.

### Why `pnpm_config_allow_builds` is needed

pnpm does not run the build scripts of dependencies until they are approved.
`pnpm-workspace.yaml` approves the script of `esbuild`, which `tsx` needs. The
Aspire CLI installs the AppHost's dependencies itself with
`pnpm install --ignore-workspace`. That ignores `pnpm-workspace.yaml`, and pnpm
has no other place for this setting, so the install fails with
`ERR_PNPM_IGNORED_BUILDS`. Setting the `pnpm_config_allow_builds` environment
variable gives pnpm the approval and lets the Aspire CLI install the
dependencies.

## Checks

```shell
aspire restore      # generate the typed SDK in .aspire/ (it is not committed)
pnpm run build      # lint and type-check apphost.mts
```

The continuous integration workflow runs these checks for every pull request.

## Files

| File                  | Purpose                                                      |
| --------------------- | ------------------------------------------------------------ |
| `apphost.mts`         | Defines the resources.                                       |
| `aspire.config.json`  | The Aspire SDK version, the integrations, and launch profile. |
| `.aspire/`            | The generated TypeScript SDK. Recreate it with `aspire restore`. |
