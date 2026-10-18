# Naked Standup

## Table of Contents

1. [Getting started](#getting-started)

## Getting started

### Prerequisites

- [Aspire CLI](https://aspire.dev/get-started/install-cli/)
- [Commitizen](https://commitizen-tools.github.io/commitizen/#global-installation-recommended)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Fast Node Manager](https://github.com/Schniz/fnm)
- [Git](https://git-scm.com)
- [GitHub CLI](https://cli.github.com)
- [pnpm](https://pnpm.io/installation)
- [PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell) **(OPTIONAL)**
- [prek](https://prek.j178.dev/installation/)
- [Python 3.15](https://www.python.org/downloads/)
- [Visual Studio Code](https://code.visualstudio.com)
  - [Aspire extension](https://aspire.dev/get-started/aspire-vscode-extension/)
  - [Remote Development extension pack](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.vscode-remote-extensionpack)

### Clone the repository

To begin working with the source code for Naked Standup, you will need to clone
the [Git repository](https://github.com/mfcollins3/standup) from
[GitHub](https://github.com). Cloning the Git repository will give you a
complete, local copy of the repository for you to work in. Begin by opening a
terminal and navigate to the location in your file system where you want to
host the repository. Then run:

```bash
gh repo clone mfcollins3/standup
```

This command will create the `standup` subdirectory in the current working
directory and will clone the GitHub repository into it.

### Set up the local project workspace

Naked Standup requires additional tools and libraries to be downloaded and
configured, and in some cases, source code generated, before you can build and
run Naked Standup locally. The steps required to prepare your local project
workspace have been automated and placed into scripts that you can run. In the
same terminal, run:

- **Apple macOS or Linux:**

  ```bash
  cd standup
  ./setup.sh
  ```

- **Microsoft Windows or PowerShell users:**

  ```powershell
  cd standup
  &"./setup.ps1"
  ```

### Running Naked Standup locally

Naked Standup uses [Aspire](https://aspire.dev) as a local orchestrator to run
locally for development, debugging, and testing. Aspire will use Docker Desktop
to download and run services used by Naked Standup, will start the Naked
Standup applications and services, and will connect them all together allowing
you to run and explore Naked Standup locally.

To run Naked Standup, open a terminal to the location where the Naked Standup
repository is hosted and run:

```bash
aspire run
```

The `aspire run` command will start the Naked Standup application and will
output the URL of the dashboard and the URL of the Naked Standup application
that you can connect to in the terminal.
