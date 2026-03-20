# Standup

## About Standup

Standup is a solution for geographically distributed teams who need to collaborate and synchronize with each other. Standup solves the problem of finding an ideal time to have daily stand up meetings for managers and stakeholders. Instead of holding a single stand up meeting each day, stand ups are asynchronous where team members record short videos with their stand up report and can share them instantly with the rest of their team.

The advantages of Standup over traditional stand up meetings are clear:

1. Meetings are asynchronous. Team members can record status reports at a time natural for them, such as the start of their day. Team members can review status reports at their convenience.
1. Status information is not lost. Traditional, in-person meetings, are typically not recorded. Unless a product manager is recording status information, the status reports are lost after a team member stops speaking, and all status information is lost after the meeting is over. By using persisted videos, status updates can be reviewed multiple times to verify status information and audit progress over time.

Standup is designed to help to facilitate communication and collaboration of teams over time. Standup allows the use of multiple devices to view status reports: from desktop to mobile phones to televisions.

## Getting Started

Before cloning the [GitHub repository](https://github.com/mfcollins3/standup), please review the [software requirements](docs/software_requirements/README.md) documentation for instructions on what software needs to be installed in your development environment to build and run the Naked Standup product locally. After your local development environment has been configured, you can clone the repository:

```shell
gh repo clone mfcollins3/standup
```

The `gh repo clone` command will clone the repository from [GitHub](https://github.com) and will check out the `main` branch in the `standup` directory. 

Naked Standup requires additional tools and libraries to be downloaded and installed, and some source code needs to be generated in order to build and run locally. The steps required to prepare your new repository clone for development have been automated using the [`setup.sh`](setup.sh) and [`Setup.ps1`](Setup.ps1) scripts.

__Apple macOS or Linux developers:__: run:

```bash
cd standup
./setup.sh
```

__PowerShell or Microsoft Windows developers__: run

```powershell
cd standup
&"./Setup.ps1"
```

Once the `setup` script completes, your local project workspace is ready for development and you should be able to build and run Naked Standup locally. You do not need to re-run the `setup` script again for this repository.
