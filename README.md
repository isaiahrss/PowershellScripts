# Isaiah's PowerShell Scripts Collection

![Logo](https://your-image-url.com/logo.png)

## Introduction
Welcome to my PowerShell scripts repository! This collection includes various scripts that I have developed to automate tasks and improve efficiency. The purpose of this repo is to showcase my powershell scripting ability and share my contribiutions openly. Feel free to explore, use, and contribute.

#Notes
The folder structure is pretty basic. I have everything in one folder (scripts) but as the collections grows, i will group scripts and modules based on the feature list below. All of the scripts here are generally easy to use and require only a few variables to customize. 

## Features
- **Automated Configuration Management**: Scripts to automate SCCM tasks.
- **Intune Management**: Scripts for managing Intune policies and devices.
- **Active Directory Automation**: Automate AD tasks like user creation and group management.
- **Network Configuration**: Scripts to manage network settings and firewall rules.

## Installation and Usage
1. **Clone the repository**:
    ```sh
    git clone https://github.com/your-username/your-repo.git
    ```
2. **Navigate to the script directory**:
    ```sh
    cd your-repo/scripts
    ```
3. **Run a script**:
    ```powershell
    ./your-script.ps1
    ```

## Examples
Here are some examples of how to use the scripts in this repository:

### Example 1: Running a Script to Create AD Users
```powershell
.\Create-ADUsers.ps1 -UserList users.csv
