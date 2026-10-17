# Naked Standup

## Table of Contents

1. [Getting started](#getting-started)

## Getting started

### Prerequisites

- [Commitizen](https://commitizen-tools.github.io/commitizen/#global-installation-recommended)
- [Git](https://git-scm.com)
- [GitHub CLI](https://cli.github.com)
- [PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell) **(OPTIONAL)**
- [prek](https://prek.j178.dev/installation/)
- [Python 3.15](https://www.python.org/downloads/)

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
  ./setup.sh
  ```

- **Microsoft Windows or PowerShell users:**

  ```powershell
  &"./setup.ps1"
  ```
