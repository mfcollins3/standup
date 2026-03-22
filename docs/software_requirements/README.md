# Software Requirements

Before cloning the Naked Standup repository, it is important to have your development environments set up. This document lists what software is required to be installed in your development environment to be successful in building and running the Naked Standup product from source code. Please read this document carefully and ensure that all of the requirements are met before working with the source code for the Naked Standup product.

## Platform Support

Naked Standup runs on Microsoft Windows, Apple macOS, and Linux, and can also be developed on all three platforms. Not all Naked Standup components will work, build, or run on all three platforms. For example, Naked Standup's applications for Apple macOS and Apple devices require an Apple Mac computer running macOS.

Not all software packages are either compatible or required for each platform. Each software package description includes a reference table that you can use to determine if the software package is required for your development platform. The following symbols are used to indicate the requirement status of the software product:

- :white_check_mark:: the software package is required to build and run Naked Standup on this platform;
- :grey_question:: the software package is optional, but recommended, on this platform;
- :x:: the software package is not compatible or required on this platform.

## Required Software

The following software packages are required to be installed in your local development environment to work with the source code for the Naked Time product.

1. [Homebrew](#homebrew)
1. [PowerShell](#powershell)
1. [Git](#git)
1. [GitHub CLI](#github-cli)
1. [GitHub Copilot CLI](#github-copilot-cli)
1. [Python](#python)
1. [uv](#uv)
1. [mise-en-place](#mise-en-place)
1. [Xcodes.app](#xcodesapp)
1. [Xcode](#xcode)

### Homebrew

| Operating System | Required? |
| ---------------- | --------- |
| Apple macOS | :white_check_mark: |
| Linux | :white_check_mark: |
| Microsoft Windows | :x: |

[Homebrew](https://brew.sh) is a popular package manager for Apple macOS and Linux. Homebrew is capable of installing many popular open source and commercial software packages, programming language tools, and development libraries. Homebrew also makes it easy to keep software packages up to date by detecting when new versions of installed software are available and upgrading the installed software packages to the latest versions.

To install Homebrew, open a terminal and run:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

After installing Homebrew, you will need to restart your terminal for the environmental changes to take effect.

### PowerShell

| Operating System | Required? |
| ---------------- | --------- |
| Apple macOS | :grey_question: |
| Linux | :grey_question: |
| Microsoft Windows | :white_check_mark: |

[PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/overview) is a cross-platform task automation solution created by [Microsoft](https://www.microsoft.com). PowerShell is based on [.NET](https://dotnet.microsoft.com) and provides a command line shell, scripting language, and a configuration management framework. PowerShell provides a great platform for building automation scripts for software and system configuration.

- __Apple macOS or Linux__: PowerShell can be installed using [Homebrew](#homebrew). In a terminal, run:

```bash
brew install --cask powershell
```

- __Microsoft Windows__: PowerShell can be installed using [WinGet](https://learn.microsoft.com/en-us/windows/package-manager/winget/). In a terminal, run:

```powershell
winget install --id Microsoft.PowerShell --source winget
```

### Git

| Operating System | Required? |
| ---------------- | --------- |
| Apple macOS | :white_check_mark: |
| Linux | :white_check_mark: |
| Microsoft Windows | :white_check_mark: |

[Git](https://git-scm.com) is a popular version control management tool. Version control tools like Git track changes to files and directories in a software project over time. Version control tools also support development workflows through the use of branches to support stable and isolated development of new features. Git is a _distributed_ version control tool where each developer works in their own clone of the Git repository and developers work without a central server allowing for offline development. When changes are available to be shared, developers can share their changes with each other's Git repositories or can use a shared repository such as a Git repository hosted on a service such as [GitHub](https://github.com).

- __Apple macOS or Linux__: Git can be installed using [Homebrew](#homebrew). In a terminal, run:

```bash
brew install git
```

- __Microsoft Windows__: Git can be installed using [WinGet](https://learn.microsoft.com/en-us/windows/package-manager/winget/). In a PowerShell terminal, run:

```powershell
winget install --id Git.Git -e --source winget
```

### GitHub CLI

| Operating System | Required? |
| ---------------- | --------- |
| Apple macOS | :white_check_mark: |
| Linux | :white_check_mark: |
| Microsoft Windows | :white_check_mark: |

[GitHub CLI](https://cli.github.com) is a command line interface for GitHub. GitHub CLI can be used to execute many GitHub tasks such as cloning or managing repositories, issues, and projects. GitHub CLI is useful for automating common management tasks involving GitHub projects and repositories.

- __Apple macOS or Linux__: GitHub CLI can be installed using [Homebrew](#homebrew). In a terminal, run:

```bash
brew install gh
```

- __Microsoft Windows__: GitHib CLI can be installed using [WinGet](https://learn.microsoft.com/en-us/windows/package-manager/winget/). In a PowerShell terminal, run:

```powershell
winget install --id GitHub.cli
```

### GitHub Copilot CLI

| Operating System | Required? |
| ---------------- | --------- |
| Apple macOS | :grey_question: |
| Linux | :grey_question: |
| Microsoft Windows | :grey_question: |

[GitHub Copilot CLI](https://github.com/features/copilot/cli/) is a version of [GitHub Copilot](https://github.com/features/copilot) that runs in a terminal. GitHub Copilot CLI provides the agent behavior to drive software development activities from the terminal outside of Visual Studio Code or other development tools.

- __Apple macOS or Linux__: GitHub Copilot CLI can be installed using [Homebrew](#homebrew). In a terminal, run:

```bash
brew install copilot-cli
```

- __Microsoft Windows__: GitHub Copilot CLI can be installed using [WinGet](https://learn.microsoft.com/en-us/windows/package-manager/winget/). In a PowerShell terminal, run:

```powershell
winget install GitHub.Copilot
```

### Python

| Operating System | Required? |
| ---------------- | --------- |
| Apple macOS | :white_check_mark: |
| Linux | :white_check_mark: |
| Microsoft Windows | :white_check_mark: |

[Python](https://python.org) is a popular general purpose programming language that is useful for building command line and terminal applications, web applications, APIs and web services, data science applications, and artificial intelligence applications. Python is a friendly and easy-to-learn programming language with a very large ecosystem of libraries and tools.

- __Apple macOS or Linux__: Python can be installed using [Homebrew](#homebrew). In a terminal, run:

```bash
brew install python3
```

To add unversioned symlinks, you will need to add `/opt/homebrew/opt/python@3.14/libexec/bin` to your `PATH` environment variable. All scripts and documentation using Python in the Naked Time product use the versioned executables.

- __Microsoft Windows__: Python can be installed from the [Microsoft Store](https://apps.microsoft.com/detail/9NQ7512CXL7T?hl=en-us&gl=US&ocid=pdpshare). For Microsoft Windows developers, it is recommended to install Python using the Python Install Manager tool. For more information, see the [Using Python on Windows](https://docs.python.org/3/using/windows.html) documentation.

### uv

| Operating System | Required? |
| ---------------- | --------- |
| Apple macOS | :white_check_mark: |
| Linux | :white_check_mark: |
| Microsoft Windows | :white_check_mark: |

[`uv`](https://docs.astral.sh/uv/) is a fast Python package and project management tool. `uv` is intended to replace Python tools such as `pip`, `pip-tools`, `pipx`, `virtualenv` and others.

- __Apple macOS or Linux__: `uv` can be installed using [Homebrew](#homebrew). In a terminal, run:

```bash
brew install uv
```

Alternatively, you can use the standalone installer to download and install `uv`. To install `uv` using the standalone installer, open a terminal and run:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

- __Microsoft Windows__: `uv` can be installed using [WinGet](https://learn.microsoft.com/en-us/windows/package-manager/winget/). In a PowerShell terminal, run:

```powershell
winget install --id=astral-sh.uv  -e
```

Alternatively, you can use the standalone installer to download and install `uv`. To install `uv` using the standalone installer, open a PowerShell terminal and run:

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

### mise-en-place

| Operating System | Required? |
| ---------------- | --------- |
| Apple macOS | :white_check_mark: |
| Linux | :x: |
| Microsoft Windows | :x: |

[mise-en-place](https://mise.jdx.dev/) is a package and version manager for developers. mise-en-place can be used as a replacement for many popular development tools and programming language version managers such as `nvm`, `pyenv`, and `rbenv`. We use mise-en-place to install [Tuist](https://tuist.io).

To install mise-en-place, open a terminal and run:

```bash
curl https://mise.run | sh
```

### Xcodes.app

| Operating System | Required? |
| ---------------- | --------- |
| Apple macOS | :white_check_mark: |
| Linux | :x: |
| Microsoft Windows | :x: |

[Xcodes.app](https://www.xcodes.app/) is a version manager for [Xcode](#xcode). Xcodes.app can be used to download multiple versions of Xcode and easily switch between them for different projects. We use Xcodes.app to install Xcode on our development machines.

Xcodes.app can be installed by downloading the installer from the [Xcodes.app website](https://www.xcodes.app).

### Xcode

| Operating System | Required? |
| ---------------- | --------- |
| Apple macOS | :white_check_mark: |
| Linux | :x: |
| Microsoft Windows | :x: |

[Xcode](https://developer.apple.com/xcode) is Apple's development environment for building applications for Apple macOS, iOS, iPadOS, tvOS, visionOS, and watchOS. Xcode supports C, C++, Objective-C, and Swift programming language development for Apple platforms.

We recommend using [Xcodes.app](#xcodesapp) to download and install Xcode on your development machine.
