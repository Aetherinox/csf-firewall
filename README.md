<div align="center">

🕙 `Last Sync: 09/26/2025 01:03 UTC`

</div>

<div align="center">
<h6>♾️ Official repository for Config Server Firewall (CSF) ♾️</h1>
</div>

<div align="center">

<img src="src/csf/csf-logo.png" height="230">

<!-- prettier-ignore-start -->
[![Version][github-version-img]][github-version-uri]
[![Downloads][github-downloads-img]][github-downloads-uri]
[![Size][github-size-img]][github-size-img]
[![Last Commit][github-commit-img]][github-commit-img]
[![Contributors][contribs-all-img]](#contributors-)

[![Built with Material for MkDocs](https://img.shields.io/badge/Powered_by_Material_for_MkDocs-526CFE?style=for-the-badge&logo=MaterialForMkDocs&logoColor=white)](https://aetherinox.github.io/csf-firewall/)
<!-- prettier-ignore-end -->

<br />
<br />

</div>

<br />

<p>

ConfigServer Firewall (CSF) is a robust and widely used firewall for Linux servers, offering an intuitive graphical interface that lets you manage your own firewall rules and supports both iptables and nftables.

<br />

In August 2025, the original developer of ConfigServer Firewall ceased operations. Since then, this repository has continued actively maintaining CSF, releasing updates as they become available. In addition to ConfigServer Firewall, we also provide:

- A free IPSET blocklist service (fully compatible with CSF)
  - Ipsets include lists from [AbuseIPDB](https://abuseipdb.com/) and [IPThreat](https://ipthreat.net/).
  - For information on how to use these sets, read the section [IP Rulesets & Blocklists](#ip-sets--blocklist).
- Addon scripts to enhance CSF with OpenVPN and Docker support

</p>

<br />

<div align="center">

<br />

<p float="left">
  <img style="padding-right:15px;" src="https://raw.githubusercontent.com/Aetherinox/csf-firewall/refs/heads/main/docs/images/readme/1.png" width="300" />
  <img src="https://raw.githubusercontent.com/Aetherinox/csf-firewall/refs/heads/main/docs/images/readme/2.png" width="300" /> 
</p>

<p float="left">
  <img style="padding-right:15px;" src="https://raw.githubusercontent.com/Aetherinox/csf-firewall/refs/heads/main/docs/images/readme/3.png" width="300" />
  <img src="https://raw.githubusercontent.com/Aetherinox/csf-firewall/refs/heads/main/docs/images/readme/4.png" width="300" /> 
</p>

<p float="left">
  <img style="padding-right:15px;" src="https://raw.githubusercontent.com/Aetherinox/csf-firewall/refs/heads/main/docs/images/readme/5.png" width="300" />
  <img src="https://raw.githubusercontent.com/Aetherinox/csf-firewall/refs/heads/main/docs/images/readme/6.png" width="300" /> 
</p>

</div>

<br />

---

<br />

- [Summary](#summary)
  - [Releases](#releases)
  - [Folders](#folders)
- [Features](#features)
  - [Firewall \& Network Security](#firewall--network-security)
  - [Login \& User Monitoring](#login--user-monitoring)
  - [Alerts \& Notifications](#alerts--notifications)
  - [Intrusion Detection \& Exploit Protection](#intrusion-detection--exploit-protection)
  - [Management \& Control](#management--control)
- [How 📁 Extras/Scripts Works](#how--extrasscripts-works)
- [Install](#install)
  - [Using Patcher](#using-patcher)
  - [Install Manually](#install-manually)
    - [Step 1: Prerequisites](#step-1-prerequisites)
    - [Step 2: Download and Install CSF](#step-2-download-and-install-csf)
- [Testing the Firewall](#testing-the-firewall)
- [Configuring CSF](#configuring-csf)
- [Enabling CSF Firewall](#enabling-csf-firewall)
- [Managing the Firewall](#managing-the-firewall)
- [Enable CSF Firewall Web UI](#enable-csf-firewall-web-ui)
- [Install Docker Patch](#install-docker-patch)
  - [Clone](#clone)
  - [Configure](#configure)
  - [Run Patch](#run-patch)
  - [Manual Run](#manual-run)
  - [Advanced Logs](#advanced-logs)
- [Install OpenVPN Patch](#install-openvpn-patch)
  - [Clone](#clone-1)
  - [Configure](#configure-1)
  - [Run Patch](#run-patch-1)
  - [Manual Run](#manual-run-1)
  - [Advanced Logs](#advanced-logs-1)
- [IP Sets / Blocklist](#ip-sets--blocklist)
  - [Main Lists](#main-lists)
  - [Privacy Lists](#privacy-lists)
  - [Spam Lists](#spam-lists)
  - [Geographical (Continents \& Countries)](#geographical-continents--countries)
  - [Transmission (BitTorrent Client)](#transmission-bittorrent-client)
- [Notes](#notes)
  - [CSF to Iptable Commands](#csf-to-iptable-commands)
    - [Default Policy](#default-policy)
    - [Clear Iptables / Open Firewall](#clear-iptables--open-firewall)
    - [List Rules](#list-rules)
    - [List Chains](#list-chains)
    - [Unblock Port](#unblock-port)
    - [Allow OpenVPN](#allow-openvpn)
- [References for More Help](#references-for-more-help)
- [Questions \& Answers](#questions--answers)
- [Contributors ✨](#contributors-)

<br />

---

<br />

## Summary

In August 2025, the original developer, Way to the Web Ltd, discontinued development of ConfigServer Firewall. This repository has since taken over, continuing its development by adding new features and providing ongoing bug fixes.

<br />
<br />

### Releases

Each release posted on the [Releases Page](https://github.com/Aetherinox/csf-firewall/releases) contains several `.zip` files:
- `csf-firewall-vxx.xx.zip`
  - Latest official version of ConfigServer Firewall. You do not need this if you already have CSF installed on your system.
- `csf-firewall-vx.x.x-scripts.zip`
  - These files are optional patches maintained by this repository. They assist with setting up and configuring OpenVPN and Docker with your copy of CSF. The script files include:
    - 📄 install.sh
    - 📄 csfpost.sh
    - 📄 csfpre.sh
    - 📄 docker.sh
    - 📄 openvpn.sh

<br />
<br />

### Folders

This repository contains several folders:
- 📁 `src`
  - Source code related to ConfigServer Firewall
- 📁 `blocklists` 
  - Free ipset blocklist service
  - List of IP addresses which have been reported for ssh brute-force attempts, port scanning, etc.
  - 100% Confidence, powered by services such as [AbuseIPDB](https://abuseipdb.com/)
  - IPs are no older than 90 days old _(updated daily)_, and also contain blocks to protect your privacy from certain online services
  - Add to `csf.blocklists`
- 📁 `extras/example_configs`
  - Ready-to-use CSF config files
    - 📄 `extras/example_configs/etc/csf/csf.conf` (full version)
    - 📄 `extras/example_configs/etc/csf/csf.conf.clean` (clean version)
    - 📄 `extras/example_configs/etc/GeoIP.conf` GeoIP Config File for [MaxMind geo-blocking](https://www.maxmind.com/en/home)
- 📁 `extras/scripts`
  - Docker patch which allows CSF and Docker to work together
  - OpenVPN integration patch

<br />

---

<br />

## Features


Interested in Config Server Firewall & Security? Check out a partial list of the included features below:

<br />

### Firewall & Network Security

- Easy-to-use SPI firewall powered by iptables/nftables
- Pre-configured for cPanel and DirectAdmin (standard ports open by default)
- Auto-detects non-standard SSH ports during installation
- Works with multiple network interfaces
- Supports IPv6 via ip6tables
- Block traffic on unused server IPs to reduce attack surface
- Country-based access control (allow/deny by ISO Country Code)
- Protection against:
    - SYN floods
    - Ping of Death
    - Port scans
    - Connection flooding (per IP/per port detection)
- Permanent or temporary IP blocking (with TTL support)
- Integration with blocklists like DShield and Spamhaus DROP
- BOGON packet protection

<br />

### Login & User Monitoring

- Login Failure Daemon (LFD): detects repeated login failures (brute force protection)
- Monitors authentication for:
    - SSH (OpenSSH)
    - FTP (Pure-ftpd, vsftpd, Proftpd)
    - Mail (Courier IMAP, Dovecot, Kerio, Exim SMTP AUTH, POP3/IMAP)
    - Web (cPanel/WHM, Webmail, htpasswd-protected pages)
    - ModSecurity (v1 & v2)
    - Suhosin
    - Custom services via regex and log file matching
- POP3/IMAP login tracking (limit logins per hour)
- Distributed attack detection (across multiple servers)
- LFD clustering – share blocks/whitelists across a server group
- Temporary IP allows (with TTL)

<br />

### Alerts & Notifications

- SSH and su login notifications
- Root access notifications (WHM)
- Alerts for:
    - High server load average
    - Excessive email sending per hour (spamming detection)
    - Suspicious processes running
    - Abnormal file activity in /tmp and similar directories
    - Excessive user processes or resource usage
    - Account changes (password updates, shell changes, etc.)

<br />

### Intrusion Detection & Exploit Protection

- Intrusion Detection System (IDS) – monitors system/application binaries
- Suspicious process and file reporting
- Exploit checks
- Directory and file integrity monitoring
- ModSecurity log reporting
- Messenger Service – optionally redirect blocked users to a custom page explaining why access is denied

<br />

### Management & Control

- Integrated UI for major control panels:
    - cPanel, DirectAdmin, InterWorx, CWP, VestaCP, CyberPanel, Webmin
- cPanel reseller access (per-reseller firewall controls: Allow, Deny, Unblock, Search)
- Integrated with CloudFlare Firewall
- Upgrade firewall directly from control panel or shell
- Quick start mode for servers with large allow/deny lists
- Easy Dynamic DNS support (auto-allow your changing home IP)
- System statistics & graphs (CPU, load, memory, etc.)
- ipset support for handling large IP lists efficiently
- Integrated support for cse within the UI

<br />

---

<br />

## How 📁 Extras/Scripts Works

You can read this if you want, or skip it. It outlines exactly how the patches work:
  - Download all the files in the `/patch` folder to your system.
  - Set the `install.sh` file to be executable.
    - `sudo chmod +x install.sh`
  - Run the `install.sh` script
    - `sudo ./install.sh`
    - The script will first check to see if you have ConfigServer Firewall and all of its prerequisites installed. It will install them if they are not installed. This includes:
      - ConfigServer Firewall
      - ipset package
      - iptables / ip6tables package
    - Two new files will be added:
      - `/usr/local/csf/bin/csfpre.sh`
      - `/usr/local/csf/bin/csfpost.sh`
    - The patches will then be moved onto your system in the locations:
      - `/usr/local/include/csf/post.d/docker.sh`
      - `/usr/local/include/csf/post.d/openvpn.sh`
    - The `Docker` patch will first check to ensure you have the following:
      - **Must** have Docker installed
        - This script will **NOT** install docker. You must do that.
      - **Must** have a valid docker network adapter named `docker*` or `br-*`
    - The `OpenVPN` patch will first check to ensure you have the following:
      - **Must** have OpenVPN Server installed
      - **Must** have a valid network tunnel named `tun*` (tun0, tun1, etc)
      - **Must** have an outside network adapter named either `eth*` or `enp*`
      - If any of the checks above are not true, OpenVPN patcher will skip
        - You can check your list of network adapters using any of the commands below:
          - `ip link show`
          - `ifconfig`
        - You can check if OpenVPN server is installed by using the commmand:
          - `openvpn --version`
  
<br />

  - If you attempt to run the `install.sh` any time after the initial setup:
    - The script will check if ConfigServer Firewall and all prerequisites are installed.
      - **If they are not installed**; they will be installed.
      - **If they are already installed**; nothing will happen. The script does **NOT** update your packages. It installs the latest version of each package from the time that you run the script and do not already have ConfigServer Firewall installed.
    - The script will look at all of the files it added the first time and check the MD5 hash.
      - If the `csfpre`, `csfpost`, or patch files do not exist; they will be re-added to your system.
      - **If the patch files are different** from the one the patcher comes with, you will be prompted / asked if you wish to overwrite your already installed copy
      - **If the patch files are the same** as the ones which comes with the patcher; nothing will be done and it will skip that step.

<br />

When you start up the CSF service, the `csfpost.sh` file will loop through every patch / file added to the `post.d` folder, and run the code inside of those files. The code inside each patch contains iptable / firewall rules which allow that app to communicate between your system and the outside world.

<br />

Even if you were to completely wipe your iptable rules, as soon as you restart the CSF service; those rules will be added right back.

<br />

---

<br />

## Install

You can install ConfigServer Firewall and all prerequisites one of two ways:

1. [Install Using Patcher](#install-using-patcher)
2. [Install Manually](#install-manually)

<br />

### Using Patcher

If you would like to install ConfigServer Firewall using this repo's patcher; download the patch:
```shell
git clone https://github.com/aetherinox/csf-firewall.git .
```

<br />

Set the permissions for the `install.sh` file:

```shell
sudo chmod +x ./patch/install.sh
```

<br />

Run the script:

```shell
sudo ./patch/install.sh
```

<br />

If ConfigServer Firewall is not already installed on your system; you should see:

```
  Installing package iptables
  Installing package ipset
  Installing package ConfigServer Firewall

  Docker patch will now start ...
```
<br />

### Install Manually

These steps explain how to install ConfigServer Firewall manually.

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

## Testing the Firewall

Before enabling and configuring CSF, it is crucial to test whether it is compatible with your server. Run the following command to initiate the test:

```shell
sudo perl /usr/local/csf/bin/csftest.pl
```

The test will check for any potential issues or conflicts. If the test completes successfully, you will see the message “RESULT: csf should function on this server.” If there are any problems, the test will provide information on how to resolve them.

<br />

---

<br />

## Configuring CSF

Now that CSF is installed, you can start configuring it to suit your server’s requirements. The main configuration file for CSF is located at /etc/csf/csf.conf. You can use your preferred text editor to modify the file, such as nano or vim:

```shell
sudo nano /etc/csf/csf.conf
```

<br />

Some essential settings you may want to modify include:

> [!NOTE]
> When you run the patcher `install.sh`; **TESTING MODE** will automatically be disabled after everything as successfully completed.

<br />

- `TESTING`: Set this value to 0 to disable testing mode and activate the firewall.
- `TCP_IN` and `TCP_OUT`: These settings define the allowed incoming and outgoing TCP ports, respectively. Add or remove ports as required, separated by commas.
- `UDP_IN` and `UDP_OUT`: These settings define the allowed incoming and outgoing UDP ports, respectively. Add or remove ports as required, separated by commas.
- `DENY_IP_LIMIT`: This setting defines the maximum number of IP addresses that can be listed in the /etc/csf/csf.deny file. Adjust this limit as needed.
- `CT_LIMIT`: This setting controls the number of connections from a single IP address that are allowed before the IP is temporarily blocked. Adjust this value according to your server’s requirements.

<br />

These are just a few of the numerous configuration options available in CSF. Make sure to review the configuration file and adjust the settings to suit your server’s needs. After making changes to the configuration file, save and exit the text editor.

<br />

---

<br />

## Enabling CSF Firewall

Once you have configured the CSF firewall, it is time to enable it. To do so, run the following command:

```shell
sudo csf -e
```

<br />

This command will restart the CSF and LFD (Login Failure Daemon) services, applying your configuration changes and activating the firewall.

<br />

---

<br />

## Managing the Firewall

For a list of commands associated to CSF which help you manage your firewall, please refer to our documentation at:

- https://aetherinox.github.io/csf-firewall/usage/cheatsheet/commands/

<br />

---

<br />

## Enable CSF Firewall Web UI

ConfigServer Firewall offers a web interface for the your firewall from a web browser. To enable and access the CSF web interface, please follow the documentation at:

- https://aetherinox.github.io/csf-firewall/install/webui/

<br />

---

<br />

## Install Docker Patch

After you have installed CSF, the WebUI, and enabled both `lfd` and `csf` services; it's now time to run the docker patcher. The docker patch will check your docker configuration, and add a series of iptable rules so that docker can communicate with the outside world and users can access your containers.

<br />

The docker patch does several things:

- Allows for you to restart CSF without having to restart your docker containers.
- Scans every container you have set up in docker and adds a whitelist firewall rule

<br />

### Clone

Within your server, change to whatever directory where you want to download everything (including patch):

```shell
cd $HOME/Documents
```

<br />

Clone the repo

```shell
git clone https://github.com/aetherinox/csf-firewall.git .
```

<br />
<br />

### Configure

The `/patch/docker.sh` file has a few configs you can adjust. Open it in a text editor and change the values to your preference.

```bash
docker0_eth="docker0"
file_csf_allow="/etc/csf/csf.allow"
csf_comment="Docker container whitelist"
containers_ip_cidr=(
    '172.17.0.0/16'
)
```

<br />

Each setting is defined below:

| Setting | Default | Description |
| --- | --- | --- |
| `docker0_eth` | `docker0` | <br>main docker network interface <br><br> |
| `file_csf_allow` | `/etc/csf/csf.allow` | <br>Path to your `csf.allow` file <br><br> |
| `csf_comment` | `Docker container whitelist` | <br>comment added to each new whitelisted docker ip in the file `/etc/csf/csf.allow` <br><br> |
| `containers_ip_cidr` | `172.17.0.0/16` | <br>list of ip address blocks you will be using for your docker setup. these blocks will be whitelisted through ConfigServer Firewall <br><br> |
| `cfg_dev_enabled` | `false` | <br>debug mode <br><br> |

<br />
<br />

### Run Patch

Set the permissions (if needed)

```shell
sudo chmod +x /patch/install.sh
```

<br />

Run the script:

```shell
cd /patch/
sudo ./install.sh
```

<br />

On certain distros of Linux, you may need to use the following instead to run the patcher:

```shell
sudo sh install.sh
```

<br />

The `docker.sh` file will be installed to `/usr/local/include/csf/post.d`

<br />
<br />

### Manual Run

You can manually run the `docker.sh` script. It will also allow you to specify arguments such as `--dev` to get more detailed logging as the firewall is set up. This should only be done if you know what you're doing.

```shell ignore
sudo chmod +x /patch/docker.sh
sudo /patch/docker.sh
```

<br />

You can call arguments by running the file using:

```shell ignore
sudo /patch/docker.sh --dev
```

<br />

You can also find out what version you are running by appending `--version` to either the `install.sh` or `docker.sh` file:

```shell ignore
./patch/install.sh --version
```

<br />

```shell ignore
  ┌────────────────────────────────────────────────────────────────────────────────────────┐

     ConfigServer Firewall - Installer Script (v14.24.0)

     Installs Docker and OpenVPN patches into your existing CSF setup.
     This script requires that you have iptables installed on your system. 
     The required packages will be installed if you do not have them.

     @repo        https://github.com/Aetherinox/csf-firewall
     @system      Ubuntu | 24.04
     @notice      Before running this script, open /path/to/dock.sh
                  and edit the settings at the top of the file.

  └────────────────────────────────────────────────────────────────────────────────────────┘
```

<br />

```shell ignore
sudo /patch/docker.sh --version
```

<br />

```shell ignore
  ┌────────────────────────────────────────────────────────────────────────────────────────┐

     ConfigServer Firewall - Docker Patch (v14.24.0)

     Sets up your firewall rules to work with Docker and Traefik. 
     This script requires that you have iptables installed on your system. 
     The required packages will be installed if you do not have them.

     @repo        https://github.com/Aetherinox/csf-firewall
     @system      Ubuntu | 24.04
     @notice      Before running this script, open /path/to/dock.sh
                  and edit the settings at the top of the file.

  └────────────────────────────────────────────────────────────────────────────────────────┘
```

<br />
<br />

### Advanced Logs

This script includes debugging prints / logs. To view these, restart `csf.service` by running the following command in terminal:

```shell ignore
sudo csf -r
```

<br />

All steps performed by the script will be displayed in terminal:

```shell ignore
  + POSTROUTING   Adding IPs from primary IP list
                  + 172.17.0.0/16
                  + RULE:                  -t nat -A POSTROUTING ! -o docker0 -s 172.17.0.0/16 -j MASQUERADE
                  + RULE:                  -t nat -A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE

 ---------------------------------------------------------------------------------------------------

  + BRIDGES       Configuring network bridges

                  BRIDGE                   e8a57188323a                          
                  DOCKER INTERFACE         docker0                               
                  SUBNET                   172.17.0.0/16                         
                  + RULE:                  -t nat -A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE
                  + RULE:                  -t nat -A DOCKER -i docker0 -j RETURN
                  + RULE:                  -A DOCKER-ISOLATION-STAGE-1 -i docker0 ! -o docker0 -j DOCKER-ISOLATION-STAGE-2
                  + RULE:                  -A DOCKER-ISOLATION-STAGE-2 -o docker0 -j DROP
```

<br />

---

<br />

## Install OpenVPN Patch

This repo includes an OpenVPN patch which automatically sets up ConfigServer Firewall to accept connections from your OpenVPN server; while still restricting other incoming and outgoing connections you may not want going through.

<br />

### Clone

Within your server, change to whatever directory where you want to download everything (including patch):

```shell
cd $HOME/Documents
```

<br />

Clone the repo

```shell
git clone https://github.com/aetherinox/csf-firewall.git .
```

<br />
<br />

### Configure

The `/patch/openvpn.sh` file has a few configs you can adjust. Open it in a text editor and change the values to your preference.

```bash
ETH_ADAPTER=$(ip route | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//")
TUN_ADAPTER=$(ip -br l | awk '$1 ~ "^tun[0-9]" { print $1}')
IP_PUBLIC=$(curl ipinfo.io/ip)
DEBUG_ENABLED="false"
IP_POOL=(
    '10.8.0.0/24'
)
```

<br />

Each setting is defined below:

| Setting | Description |
| --- | --- |
| `ETH_ADAPTER` | <br>primary network adapter on host machine <br><br> |
| `TUN_ADAPTER` | <br>openvpn tunnel adapter, usually `tun0` <br><br> |
| `IP_PUBLIC` | <br>server's public ip address <br><br> |
| `DEBUG_ENABLED` | <br>debugging / better logs <br><br> |
| `IP_POOL` | <br>openvpn ip pool <br><br> |

<br />

The script tries to automatically detect the values specified above, however, you can manually specify your own values. 

<br />

As an example, instead of automatically detecting your server's public IP address or ethernet adapters, you can specify your own by changing the following:

```bash
# old code
ETH_ADAPTER=$(ip route | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//")
TUN_ADAPTER=$(ip -br l | awk '$1 ~ "^tun[0-9]" { print $1}')
IP_PUBLIC=$(curl ipinfo.io/ip)

# manually specified ip
ETH_ADAPTER="eth0"
TUN_ADAPTER="tun0"
IP_PUBLIC="216.55.100.5"
```

<br />
<br />

### Run Patch

Set the permissions:

```shell
sudo chmod +x /patch/install.sh
```

<br />

Run the script:

```shell
cd /patch/
sudo ./install.sh
```

<br />

On certain distros of Linux, you may need to use the following instead to run the patcher:

```shell
sudo sh install.sh
```

<br />

The `openvpn.sh` file will be installed to `/usr/local/include/csf/post.d`

<br />
<br />

### Manual Run

You can manually run the `openvpn.sh` script. It will also allow you to specify arguments such as `--dev` to get more detailed logging as the firewall is set up. This should only be done if you know what you're doing.

```shell ignore
sudo chmod +x /patch/openvpn.sh
sudo /patch/openvpn.sh
```

<br />

You can call arguments by running the file using:

```shell ignore
sudo /patch/openvpn.sh --dev
```

<br />

You can also find out what version you are running by appending `--version` to either the `install.sh` or `openvpn.sh` file:

```shell ignore
./patch/install.sh --version
```

<br />

```shell ignore
ConfigServer Firewall Configuration - v2.0.0.0
https://github.com/Aetherinox/csf-firewall
Ubuntu | 24.04
```

<br />

```shell ignore
sudo /patch/openvpn.sh --version
```

<br />

```shell ignore
ConfigServer Firewall OpenVPN Patch - v2.0.0.0
https://github.com/Aetherinox/csf-firewall
Ubuntu | 24.04
```

<br />
<br />

### Advanced Logs

This script includes debugging prints / logs. To view these, restart `csf.service` by running the following command in terminal:
```shell ignore
sudo csf -ra
```

<br />

All steps performed by the script will be displayed in terminal:
```shell ignore
  + OPENVPN       Adding OpenVPN Rules

                  + RULE                   -A INPUT -i tun+ -j ACCEPT            
                  + RULE                   -A FORWARD -i tun+ -j ACCEPT          
                  + RULE                   -A FORWARD -o tun0 -j ACCEPT
                  + RULE                   -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE
                  + RULE                   -A FORWARD -i tun+ -o enp0s3 -m state --state RELATED,ESTABLISHED -j ACCEPT
                  + RULE                   -A FORWARD -i enp0s3 -o tun+ -m state --state RELATED,ESTABLISHED -j ACCEPT
                  + RULE                   -t nat -A POSTROUTING -j SNAT --to-source XX.XXX.XXX.XXX
                  + RULE                   -t nat -A POSTROUTING -s 10.8.0.0/24 -o enp0s3 -j MASQUERADE
```

<br />

---

<br />

## IP Sets / Blocklist

This repository contains a set of ipsets which are automatically updated every `6 hours`. You may add these sets to your ConfigServer Firewall `/etc/csf/csf.blocklists` with the following new line:

```
CSF_MASTER|43200|400000|https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/master.ipset
CSF_HIGHRISK|43200|0|https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/highrisk.ipset
```

<br />
<br />

### Main Lists

These are the primary lists that most people will be interested in. They contain a large list of IP addresses which have been reported recently for abusive behavior. These statistics are gathered from numerous websites such as [AbuseIPDB](https://www.abuseipdb.com/) and [IPThreat](https://ipthreat.net/). IPs on this list have a 100% confidene level, which means you should get no false-positives from any of the IPs in these lists. IP addresses in these lists have been flagged for engaging in the following:

- SSH Bruteforcing
- Port Scanning
- DDoS Attacks
- IoT Targeting
- Phishing

<br />

For the majority of people, using the blocklists `master.ipset` and `highrisk.ipset` will be all you need. It is a massive collection, all with a 100% confidence level, which means you should get none or minimal false positives. 

<br />

| Set Name | Description | Severity | View |
| --- | --- | --- | --- |
| `master.ipset` | <sub>Abusive IP addresses which have been reported for port scanning and SSH brute-forcing. HIGHLY recommended. <br> Includes [AbuseIPDB](https://www.abuseipdb.com/), [IPThreat](https://ipthreat.net/), [CinsScore](https://cinsscore.com), [GreensNow](https://blocklist.greensnow.co/greensnow.txt)</sub> | ★★★★★ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/master.ipset) |
| `highrisk.ipset` | <sub>IPs with highest risk to your network and have a possibility that the activity which comes from them are going to be fraudulent.</sub> | ★★★★★ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/highrisk.ipset) |

<br />
<br />

### Privacy Lists

These blocklists give you more control over what 3rd party services can access your server, and allows you to remove bad actors or services hosting such services.

<br />

| Set | Description | Severity | View |
| --- | --- | --- | --- |
| `privacy_general.ipset` | <sub>Servers which scan ports for data collection and research purposes. List includes [Censys](https://censys.io), [Shodan](https://www.shodan.io/), [Project25499](https://blogproject25499.wordpress.com/), [InternetArchive](https://archive.org/), [Cyber Resilience](https://cyberresilience.io), [Internet Measurement](https://internet-measurement.com), [probe.onyphe.net](https://onyphe.net), [Security Trails](https://securitytrails.com) </sub> | ★★★★⚝ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/privacy/privacy_general.ipset) |
| `privacy_ahrefs.ipset` | <sub>Ahrefs SEO and services</sub> | ★★⚝⚝⚝ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/privacy/privacy_ahrefs.ipset) |
| `privacy_amazon_aws.ipset` | <sub>Amazon AWS</sub> | ★★⚝⚝⚝ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/privacy/privacy_amazon_aws.ipset) |
| `privacy_amazon_ec2.ipset` | <sub>Amazon EC2</sub> | ★★⚝⚝⚝ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/privacy/privacy_amazon_ec2.ipset) |
| `privacy_applebot.ipset` | <sub>Apple Bots</sub> | ★★★⚝⚝ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/privacy/privacy_applebot.ipset) |
| `privacy_bing.ipset` | <sub>Microsoft Bind and Bing Crawlers / Bots</sub> | ★★⚝⚝⚝ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/privacy/privacy_bing.ipset) |
| `privacy_bunnycdn.ipset` | <sub>Bunny CDN</sub> | ★★⚝⚝⚝ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/privacy/privacy_bunnycdn.ipset) |
| `privacy_cloudflarecdn.ipset` | <sub>Cloudflare CDN</sub> | ★★⚝⚝⚝ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/privacy/privacy_cloudflarecdn.ipset) |
| `privacy_cloudfront.ipset` | <sub>Cloudfront DNS</sub> | ★⚝⚝⚝⚝ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/privacy/privacy_cloudfront.ipset) |
| `privacy_duckduckgo.ipset` | <sub>DuckDuckGo Web Crawlers / Bots</sub> | ★★⚝⚝⚝ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/privacy/privacy_duckduckgo.ipset) |
| `privacy_facebook.ipset` | <sub>Facebook Bots & Trackers</sub> | ★★★⚝⚝ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/privacy/privacy_facebook.ipset) |
| `privacy_fastly.ipset` | <sub>Fastly CDN</sub> | ★⚝⚝⚝⚝ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/privacy/privacy_fastly.ipset) |
| `privacy_google.ipset` | <sub>Google Crawlers</sub> | ★★⚝⚝⚝ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/privacy/privacy_google.ipset) |
| `privacy_pingdom.ipset` | <sub>Pingdom Monitoring Service</sub> | ★★⚝⚝⚝ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/privacy/privacy_pingdom.ipset) |
| `privacy_rssapi.ipset` | <sub>RSS API Reader</sub> | ★★⚝⚝⚝ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/privacy/privacy_rssapi.ipset) |
| `privacy_stripe_api.ipset` | <sub>Stripe Payment Gateway API</sub> | ★★⚝⚝⚝ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/privacy/privacy_stripe_api.ipset) |
| `privacy_stripe_armada_gator.ipset` | <sub>Stripe Armada Gator</sub> | ★★⚝⚝⚝ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/privacy/privacy_stripe_armada_gator.ipset) |
| `privacy_stripe_webhooks.ipset` | <sub>Stripe Webhook Service</sub> | ★★⚝⚝⚝ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/privacy/privacy_stripe_webhooks.ipset) |
| `privacy_telegram.ipset` | <sub>Telegram Trackers and Crawlers</sub> | ★★★⚝⚝ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/privacy/privacy_telegram.ipset) |
| `privacy_uptimerobot.ipset` | <sub>Uptime Robot Monitoring Service</sub> | ★⚝⚝⚝⚝ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/privacy/privacy_uptimerobot.ipset) |
| `privacy_webpagetest.ipset` | <sub>Webpage Test Services</sub> | ★★⚝⚝⚝ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/privacy/privacy_webpagetest.ipset) |

<br />
<br />

### Spam Lists

These blocklists allow you to remove the possibility of spam sources accessing your server.

<br />

| Set | Description | Severity | View |
| --- | --- | --- | --- |
| `spam_forums.ipset` | <sub>List of known forum / blog spammers and bots</sub> | ★★★⚝⚝ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/spam/spam_forums.ipset) |
| `spam_spamhaus.ipset` | <sub>Bad actor IP addresses registered with Spamhaus</sub> | ★★★★⚝ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/spam/spam_spamhaus.ipset) |

<br />
<br />

### Geographical (Continents & Countries)
These blocklists allow you to determine what geographical locations can access your server. These can be used as either a whitelist or a blacklist. Includes both **continents** and **countries**.

<br />

| Set | Description | Severity | View |
| --- | --- | --- | --- |
| `GeoLite2 Database` | <sub>Lists IPs by continent and country from GeoLite2 database. Contains both IPv4 and IPv6 subnets</sub> | ★★★★★ | [view](https://dev.maxmind.com/geoip/geolite2-free-geolocation-data/) |
| `Ip2Location Database` | <sub>Coming soon</sub> | ★★★★★ | [view](https://lite.ip2location.com/database-download) |

<br />
<br />

### Transmission (BitTorrent Client)

This section includes blocklists which you can import into the [bittorrent client Transmission](https://transmissionbt.com/).

<br />

- In this repo, copy the direct URL to the Transmission blocklist, provided below:
  - https://github.com/Aetherinox/csf-firewall/raw/main/blocklists/transmission/blocklist.gz
- Open your Transmission application; depending on the version you run, do ONE of the follow two choices:
  - Paste the link to Transmission > Settings > Peers > Blocklist
  - Paste the link to Transmission > Edit > Preferences > Privacy > Enable Blocklist

<br />

| Set | Description | Severity | View | Website |
| --- | --- | --- | --- | --- |
| `bt-transmission` | <sub>A large blocklist for the BitTorrent client [Transmission](https://transmissionbt.com/)</sub> | ★★★★★ | [view](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/transmission/blocklist.ipset) | [view](https://transmissionbt.com/) |

<br />

---

<br />

## Notes

This section simply outlines notes about ConfigServer Firewall

<br />

### CSF to Iptable Commands

ConfigServer Firewall is a way to manage your existing firewall rules. In order for ConfigServer Firewall to work, your server must have the library `iptables` installed. ConfigServer Firewall is basically a wrapper for iptables, and has the additional option of adding a web UI so that you can visually manage your firewall instead of using commands. Without `iptables`, ConfigServer Firewall is useless.

<br />

If you were to uninstall ConfigServer Firewall from your server; you would still have the ability to do everything CSF can, but you would have to manually run commands on the package iptables. 

<br />

This section gives you the commands that ConfigServer Firewall uses to manage your firewall, and gives you the iptables alternative command if you do not wish to use CSF.

<br />
<br />

#### Default Policy

ConfigServer Firewall and iptables come with three main CHAINS. ConfigServer Firewall will set these three main chains to have the policy `DROP`. 

This `DROP` policy means that no connections are allowed to access any of these chains on your server, meaning nobody can connect to your server; unless you have added rules to allow access by an IP address or port. 

To set the policy of these chains; run:

```shell
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP 
sudo iptables -P OUTPUT DROP
```

<br />

You can select from the list of available policies. 

- `ACCEPT` Accepts packets into or out of your server.
- `DROP` Denies access to a port or server, but makes the connection appear to be to an unoccupied IP address. Scanners may choose not to continue scanning addresses which appear unoccupied.
- `REJECT` Denies access to a port or server, but tells the connecting party that the server and port are really there, but they've been denied access to transmit data or connect.

<br />

As a general rule:
  - Use `ACCEPT` to allow access to a port or IP by a connecting party.
  - Use `DROP` for connections to hosts you don't want people to see.
  - Use `REJECT` when you want the other end to know the port is unreachable.

<br />
<br />

#### Clear Iptables / Open Firewall

To clear every single iptables rule and open your firewall back up, run the following command. Note that this will completely turn off iptables / CSF's blocking abilities. Your server will be open to connections:

```shell
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo iptables -t mangle -F
sudo iptables -t mangle -X
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT
```

<br />
<br />

#### List Rules

To list all of your iptable rules, and the rules that CSF has added to your firewall, run:

```shell
sudo iptables --list --line-numbers -n
```

<br />
<br />

#### List Chains

To list all of the chains in iptables, run:

```shell
sudo iptables -L | grep Chain
```

<br />

A list of the available CHAINS are provided below:

> [!NOTE]
> Out of box, ConfigServer Firewall & Iptables makes use of three chains
>   - `INPUT` Packets coming _from_ the network and going _to_ your server 
>   - `OUTPUT` Packets originating _from_ your server and going _to_ the network.
>   - `FORWARD` Packets forwarded by your server, if/when it acts as a router between different networks such as <sup> `DOCKER` </sup>
> 
> **Additional Chains**
>   - `NAT` This table is consulted when a packet that creates a new connection is encountered. It consists of four built-ins:
>     - `PREROUTING` for altering packets as soon as they come in
>     - `INPUT` for altering packets destined for local sockets
>     - `OUTPUT` for altering locally-generated packets before routing
>     - `POSTROUTING` for altering packets as they are about to go out
>   - `MANGLE` Used for specialized packet alteration.
>   - `DOCKER` Rules that determine whether a packet that is not part of an established connection should be accepted, based on the port forwarding configuration of running containers.
>   - `DOCKER-USER` A placeholder for user-defined rules that will be processed before rules in the <sup> `DOCKER-FORWARD` </sup> and <sup> `DOCKER` </sup> chains.
>   - `DOCKER-FORWARD` The first stage of processing for Docker's networks. Rules that pass packets that are not related to established connections to the other Docker chains, as well as rules to accept packets that are part of established connections.
>   - `DOCKER-ISOLATION-STAGE-1` Rules to isolate Docker networks from each other.
>   - `DOCKER-INGRESS` Rules related to Swarm networking.

<br />
<br />

#### Unblock Port

If you make use of the ConfigServer Firewall WebUI; one of the features available is the ability to whitelist / allow access to certain ports. If you do not wish to use the WebUI, you can unblock these ports in your terminal using `iptables`.

To access unblocking ports in CSF, open your WebUI:

<p align="center"><img style="width: 80%;text-align: center;" src="docs/images/readme/20.jpg"></p>

<br />

Select **Firewall Configuration**, and then scroll down until you see the settings:

- `TCP_IN`
- `TCP_OUT`

<br />

<p align="center"><img style="width: 80%;text-align: center;" src="docs/images/readme/21.jpg"></p>

<br />

To unblock a port using Iptables using the command that CSF would use, you can run the following. For this example, we will unblock port `43` which can be used for the `whois` package:

```shell
sudo iptables -I OUTPUT ! -o lo -m conntrack --ctstate NEW -p tcp --dport 43 -j ACCEPT
```

<br />

Remember to change `--dport 43` to the port you wish to unblock, change `-p tcp` to specify either `TCP` or `UDP`, and change `-D OUTPUT` to specify the chain you want the port to allow access through.

<br />

To re-block port `43` and disallow connections, delete the rule in iptables:

```shell
sudo iptables -D OUTPUT ! -o lo -m conntrack --ctstate NEW -p tcp --dport 43 -j ACCEPT
```

<br />

To view the firewall rule in your iptables, run:

```shell
sudo iptables --list --line-numbers -n
```

<br />

Running this command should output all your table rules. Your new rule will appear as:

```
Chain OUTPUT (policy DROP)
num  target     prot opt source               destination         
1    ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:43 ctstate NEW
```

<br />
<br />

#### Allow OpenVPN

To allow OpenVPN through CSF / Iptables, run the following command. Replace `tun0` with your channel adapter name.

```shell
TUN_ADAPTER=$(ip -br l | awk '$1 ~ "^tun[0-9]" { print $1}')
sudo iptables -A FORWARD -o ${TUN_ADAPTER} -j ACCEPT
```

<br />

Next, add a `POSTROUTING` rule. If you do not want to use your default adapter name, replace `${ETH_ADAPTER}` with the name. For ours, we will use `eth0`.

```shell
ETH_ADAPTER=$(ip route | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//")
sudo iptables -t nat -A POSTROUTING -o ${ETH_ADAPTER} -j MASQUERADE
```

<br />

Now we need to add a few rules for the IP block our OpenVPN server will use. In this example, we'll use `10.8.0.0/24`.

```shell
ETH_ADAPTER=$(ip route | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//")
sudo iptables -t nat -A POSTROUTING -s "10.8.0.0/24" -o ${ETH_ADAPTER} -j MASQUERADE
```

<br />

Next, add the iptable rules for your OpenVPN server's port. Replace `1194` with your OpenVPN port if it is different. Replace `${ETH_ADAPTER}` with your desired ethernet adapter name if you do not wish to use the default defined below.

```shell
ETH_ADAPTER=$(ip route | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//")
sudo iptables -A INPUT -i ${ETH_ADAPTER} -m state --state NEW -p udp --dport 1194 -j ACCEPT
sudo iptables -A FORWARD -i tun+ -o ${ETH_ADAPTER} -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i ${ETH_ADAPTER} -o tun+ -m state --state RELATED,ESTABLISHED -j ACCEPT
```

<br />

Finally, set the adapter name `tun+` to have access to the `OUTPUT` chain. 

The `+` symbol is a wildcard rule; which means that if you create multiple OpenVPN tunnels, they'll automatically be allowed through the OUTPUT chain, such as `tun1`, `tun2`, etc. If you only want one specific tunnel to be allowed, change `tun+` to `tun0`, or whatever tunnel you want to allow.

```shell
sudo iptables  -A OUTPUT -o tun+ -j ACCEPT
```

<br />

Your OpenVPN server should now be able to allow connections between CSF / Iptables and OpenVPN.

<br />

---

<br />

## References for More Help

If you need additional help apart from this guide to configure CSF; use the following pages for more help:
- Chapter 1: [How to Install and Configure CSF Firewall on Linux](https://tecadmin.net/install-csf-firewall-on-linux/)
- Chapter 2: [How to Enable CSF Firewall Web UI](https://tecadmin.net/how-to-enable-csf-firewall-web-ui/)

<br />

---

<br />

## Questions & Answers

Have a question? See if it's answered here:

<br />

<details>
<summary>I can't get the statistics button to show</summary>

<br />

In order to view statistics in CSF, you must ensure you do the following steps. First, enable the setting within `/etc/csf/csf.conf`:

```bash
ST_ENABLE = "1"
```

<br />

You can confirm the setting by running:

```shell
grep ST_ENABLE /etc/csf/csf.conf

# Should return:
ST_ENABLE = "1"
```

<br />

Next, ensure you have the `ServerStats` perl module installed:

```shell
ls -l /usr/local/csf/lib/ConfigServer/ServerStats.pm

# Should return:
-rw------- 1 root root 138268 Aug 25 08:46 /usr/local/csf/lib/ConfigServer/ServerStats.pm
```

<br />

Finally, ensure you installed the perl module `GD::Graph / GD`:

```shell
# Ubuntu/Debian
sudo apt-get install -y libgd-graph-perl libgd-perl

# CentOS/RHEL
sudo yum install -y perl-GDGraph perl-GD
```

<br />

Then give CSF / LFD a restart:

```shell
sudo csf -ra
```

<br />

You can also run the following command to test the required module. If no errors pop up, then you should be able to run the statistics functionality without issues:

```shell
perl /usr/local/csf/lib/ConfigServer/ServerStats.pm
```

</details>

<br />

<details>
<summary>What other perl modules are required?</summary>

<br />

You can confirm the required perl modules by running in terminal:

```shell
# Core modules (usually installed, but included for completeness)
perl -MCPAN -e 'install strict'
perl -MCPAN -e 'install warnings'
perl -MCPAN -e 'install IO::Socket::INET'
perl -MCPAN -e 'install Socket'
perl -MCPAN -e 'install File::Path'
perl -MCPAN -e 'install File::Basename'
perl -MCPAN -e 'install File::Copy'
perl -MCPAN -e 'install File::Temp'
perl -MCPAN -e 'install Fcntl'
perl -MCPAN -e 'install Time::Local'
perl -MCPAN -e 'install POSIX'
perl -MCPAN -e 'install IPC::Open3'
perl -MCPAN -e 'install Sys::Hostname'
perl -MCPAN -e 'install Cwd'

# ServerStats and web reporting modules
perl -MCPAN -e 'install IO::Socket::SSL'
perl -MCPAN -e 'install LWP::UserAgent'
perl -MCPAN -e 'install HTTP::Request'
perl -MCPAN -e 'install JSON'
perl -MCPAN -e 'install Net::SSLeay'
perl -MCPAN -e 'install Crypt::SSLeay'
perl -MCPAN -e 'install Digest::MD5'
perl -MCPAN -e 'install Digest::SHA'

# Optional / recommended modules for extended CSF features
perl -MCPAN -e 'install Regexp::Common'
perl -MCPAN -e 'install Email::Valid'
perl -MCPAN -e 'install Time::HiRes'
perl -MCPAN -e 'install Mail::Sendmail'
perl -MCPAN -e 'install Net::SMTP'
```

<br />

Or if you’re on a Debian/Ubuntu system:

```shell
apt-get install -y perl libio-socket-ssl-perl libwww-perl libjson-perl libnet-ssleay-perl libcrypt-ssleay-perl
```

<br />

On CentOS/RHEL:

```shell
yum install -y perl perl-IO-Socket-SSL perl-libwww-perl perl-JSON perl-Net-SSLeay perl-Crypt-SSLeay
```

<br />

Or you can install using **CPAN**

```shell
cpan install IO::Socket::SSL LWP::UserAgent JSON Net::SSLeay Crypt::SSLeay Digest::MD5 Digest::SHA Email::Valid
```

</details>

<br />

<details>
<summary>Are you officially taking over development on CSF?</summary>

<br />

_Yes. This repository will continue to release updates to Config Server Firewall, both bug fixes and new functionality._

</details>

<br />

<details>
<summary>What happened to the dark theme?</summary>

<br />

_The dark theme was officially integrated into ConfigServer Firewall. It will release with `v` with a theme selector._

</details>

<br />

<details>
<summary>Will cPanel continue to support CSF?</summary>

<br />

_I cannot say for certain. Nobody from cPanel has reached out to me. I hope they continue to support it._

</details>

<br />

<details>
<summary>what about documentation?</summary>

<br />

_Since I started managing ConfigServer Firewall; I have been working on re-doing the current documentation so that it supports CSF in its entirety._

</details>

<br />

<details>
<summary>I see emojis, is this written with AI?</summary>

<br />

_I hate AI. If you enjoy using it, that's fine. I have a few select emojis that I use which indicate whether my docs are talking about a folder or file. I have written it all by hand._

</details>

<br />

---

<br />

## Contributors ✨

We are always looking for contributors. If you feel that you can provide something useful to Gistr, then we'd love to review your suggestion. Before submitting your contribution, please review the following resources:

- [Pull Request Procedure](.github/PULL_REQUEST_TEMPLATE.md)
- [Contributor Policy](CONTRIBUTING.md)

<br />

Want to help but can't write code?
- Review [active questions by our community](https://github.com/Aetherinox/csf-firewall/labels/help%20wanted) and answer the ones you know.

<br />

![Alt](https://repobeats.axiom.co/api/embed/a968656a3592fa904ffbcc3abd666aa2d40b8648.svg "Repobeats analytics image")

<br />

The following people have helped get this project going:

<br />

<div align="center">

<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->
[![Contributors][contribs-all-img]](#contributors-)
<!-- ALL-CONTRIBUTORS-BADGE:END -->

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top"><a href="https://gitlab.com/Aetherinox"><img src="https://avatars.githubusercontent.com/u/118329232?v=4?s=40" width="80px;" alt="Aetherinox"/><br /><sub><b>Aetherinox</b></sub></a><br /><a href="https://github.com/Aetherinox/csf-firewall/commits?author=Aetherinox" title="Code">💻</a> <a href="#projectManagement-Aetherinox" title="Project Management">📆</a> <a href="#fundingFinding-Aetherinox" title="Funding Finding">🔍</a></td>
    </tr>
  </tbody>
</table>
</div>
<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->
<!-- ALL-CONTRIBUTORS-LIST:END -->

<br />
<br />

<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->

<!-- BADGE > GENERAL -->
  [general-npmjs-uri]: https://npmjs.com
  [general-nodejs-uri]: https://nodejs.org
  [general-npmtrends-uri]: http://npmtrends.com/csf-firewall

<!-- BADGE > VERSION > GITHUB -->
  [github-version-img]: https://img.shields.io/github/v/tag/Aetherinox/csf-firewall?logo=GitHub&label=Version&color=ba5225
  [github-version-uri]: https://github.com/Aetherinox/csf-firewall/releases

<!-- BADGE > VERSION > NPMJS -->
  [npm-version-img]: https://img.shields.io/npm/v/csf-firewall?logo=npm&label=Version&color=ba5225
  [npm-version-uri]: https://npmjs.com/package/csf-firewall

<!-- BADGE > VERSION > PYPI -->
  [pypi-version-img]: https://img.shields.io/pypi/v/csf-firewall-plugin
  [pypi-version-uri]: https://pypi.org/project/csf-firewall-plugin/

<!-- BADGE > LICENSE > MIT -->
  [license-mit-img]: https://img.shields.io/badge/MIT-FFF?logo=creativecommons&logoColor=FFFFFF&label=License&color=9d29a0
  [license-mit-uri]: https://github.com/Aetherinox/csf-firewall/blob/main/LICENSE

<!-- BADGE > GITHUB > DOWNLOAD COUNT -->
  [github-downloads-img]: https://img.shields.io/github/downloads/Aetherinox/csf-firewall/total?logo=github&logoColor=FFFFFF&label=Downloads&color=376892
  [github-downloads-uri]: https://github.com/Aetherinox/csf-firewall/releases

<!-- BADGE > NPMJS > DOWNLOAD COUNT -->
  [npmjs-downloads-img]: https://img.shields.io/npm/dw/%40aetherinox%2Fcsf-firewall?logo=npm&&label=Downloads&color=376892
  [npmjs-downloads-uri]: https://npmjs.com/package/csf-firewall

<!-- BADGE > GITHUB > DOWNLOAD SIZE -->
  [github-size-img]: https://img.shields.io/github/repo-size/Aetherinox/csf-firewall?logo=github&label=Size&color=59702a
  [github-size-uri]: https://github.com/Aetherinox/csf-firewall/releases

<!-- BADGE > NPMJS > DOWNLOAD SIZE -->
  [npmjs-size-img]: https://img.shields.io/npm/unpacked-size/csf-firewall/latest?logo=npm&label=Size&color=59702a
  [npmjs-size-uri]: https://npmjs.com/package/csf-firewall

<!-- BADGE > CODECOV > COVERAGE -->
  [codecov-coverage-img]: https://img.shields.io/codecov/c/github/Aetherinox/csf-firewall?token=MPAVASGIOG&logo=codecov&logoColor=FFFFFF&label=Coverage&color=354b9e
  [codecov-coverage-uri]: https://codecov.io/github/Aetherinox/csf-firewall

<!-- BADGE > ALL CONTRIBUTORS -->
  [contribs-all-img]: https://img.shields.io/github/all-contributors/Aetherinox/csf-firewall?logo=contributorcovenant&color=de1f6f&label=contributors
  [contribs-all-uri]: https://github.com/all-contributors/all-contributors

<!-- BADGE > GITHUB > BUILD > NPM -->
  [github-build-img]: https://img.shields.io/github/actions/workflow/status/Aetherinox/csf-firewall/npm-release.yml?logo=github&logoColor=FFFFFF&label=Build&color=%23278b30
  [github-build-uri]: https://github.com/Aetherinox/csf-firewall/actions/workflows/npm-release.yml

<!-- BADGE > GITHUB > BUILD > Pypi -->
  [github-build-pypi-img]: https://img.shields.io/github/actions/workflow/status/Aetherinox/csf-firewall/release-pypi.yml?logo=github&logoColor=FFFFFF&label=Build&color=%23278b30
  [github-build-pypi-uri]: https://github.com/Aetherinox/csf-firewall/actions/workflows/pypi-release.yml

<!-- BADGE > GITHUB > TESTS -->
  [github-tests-img]: https://img.shields.io/github/actions/workflow/status/Aetherinox/csf-firewall/npm-tests.yml?logo=github&label=Tests&color=2c6488
  [github-tests-uri]: https://github.com/Aetherinox/csf-firewall/actions/workflows/npm-tests.yml

<!-- BADGE > GITHUB > COMMIT -->
  [github-commit-img]: https://img.shields.io/github/last-commit/Aetherinox/csf-firewall?logo=conventionalcommits&logoColor=FFFFFF&label=Last%20Commit&color=313131
  [github-commit-uri]: https://github.com/Aetherinox/csf-firewall/commits/main/

<!-- prettier-ignore-end -->
<!-- markdownlint-restore -->
