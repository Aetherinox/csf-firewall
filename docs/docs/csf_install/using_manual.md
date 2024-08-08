---
title: Install CSF > Using Manual Mode
tags:
  - install
---

# Install CSF: Using Patch

These steps explain how to install ConfigServer Firewall manually using a direct download of ConfigServer Firewall.

<br />

#### Step 1: Prerequisites
- A Linux server running CentOS, Debian, Ubuntu, or any other compatible Linux distribution. 
- Root access or a user account with sudo privileges.
- Perl installed on your server. If Perl is not installed, you can install it by running the following commands:
  - For CentOS/RHEL:
    ```shell
    sudo yum install perl ipset
    ```

  - For Debian/Ubuntu:

    ```shell
    sudo apt-get update 
    sudo apt-get install perl ipset
    ```

<br />

#### Step 2: Download and Install CSF
To download and install CSF, follow these steps:

<br />

- Log in to your server via SSH. 
- Download the latest version of CSF using the wget command:
    ```shell
    wget https://download.configserver.com/csf.tgz
    ```
- Extract the downloaded archive:
    ```shell
    tar -xzf csf.tgz
    ```
- Navigate to the extracted directory:
    ```shell
    cd csf
    ```
- Run the installation script:
    ```shell
    sudo sh install.sh
    ```

<br />

CSF will now be installed on your server, along with its Web UI (ConfigServer Firewall & Security) if you have a control panel like cPanel or DirectAdmin installed.

<br />

---

<br />
