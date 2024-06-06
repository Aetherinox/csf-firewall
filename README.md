<div align="center">
<h1>⭕ CSF Firewall ⭕</h1>
<br />
<p>ConfigServer Security & Firewall (CSF) is a popular and powerful firewall solution for Linux servers. It provides a user-friendly interface and a wide range of security features to protect your server from various threats. In this article, we will guide you through the process of installing and configuring CSF on your Linux server.</p>

<br />

</div>

<div align="center">

<!-- prettier-ignore-start -->

<!-- prettier-ignore-end -->

</div>

<br />

---

<br />

- [Download](#download)
- [Features](#features)
- [Installation](#installation)
  - [Step 1: Prerequisites](#step-1-prerequisites)
  - [Step 2: Download and Install CSF](#step-2-download-and-install-csf)
  - [Step 3: Testing the Firewall](#step-3-testing-the-firewall)
  - [Step 4: Configuring CSF](#step-4-configuring-csf)
  - [Step 5: Enabling CSF Firewall](#step-5-enabling-csf-firewall)
  - [Step 6: Managing the Firewall](#step-6-managing-the-firewall)
    - [Start Firewall](#start-firewall)
    - [Stop Firewall](#stop-firewall)
    - [Restart Firewall](#restart-firewall)
    - [List Firewall Rules](#list-firewall-rules)
    - [Add IP to Allow List](#add-ip-to-allow-list)
    - [Remove IP to Allow List](#remove-ip-to-allow-list)
    - [Add IP to Deny List](#add-ip-to-deny-list)
    - [Remove IP from Deny List](#remove-ip-from-deny-list)
    - [Add Temp Block IP](#add-temp-block-ip)
    - [Remove Temp Block IP](#remove-temp-block-ip)
  - [Step 7: Uninstalling CSF (Optional)](#step-7-uninstalling-csf-optional)
- [Enable CSF Firewall Web UI](#enable-csf-firewall-web-ui)
  - [Step 1 – Install Required Perl Modules:](#step-1--install-required-perl-modules)
- [Step 2 – Enable CSF Firewall Web UI:](#step-2--enable-csf-firewall-web-ui)
- [Step 3 – Access and Use Web UI:](#step-3--access-and-use-web-ui)


<br />

---

<br />

## Download
The latest version of csf can be downloaded here:
- https://download.configserver.com/csf.tgz

<br />

---

<br />

## Features

- Straight-forward SPI iptables firewall script
- Daemon process that checks for login authentication failures for:
    - Courier imap, Dovecot, uw-imap, Kerio
    - openSSH
    - cPanel, WHM, Webmail (cPanel servers only)
    - Pure-ftpd, vsftpd, Proftpd
    - Password protected web pages (htpasswd)
    - Mod_security failures (v1 and v2)
    - Suhosin failures
    - Exim SMTP AUTH
    - Custom login failures with separate log file and regular expression matching
- POP3/IMAP login tracking to enforce logins per hour
- SSH login notification
- SU login notification
- Excessive connection blocking
- UI Integration for cPanel, DirectAdmin, InterWorx, CentOS Web Panel (CWP), VestaCP, CyberPanel - and Webmin
- Easy upgrade between versions from within the control panel
- Easy upgrade between versions from shell
- Pre-configured to work on a cPanel server with all the standard cPanel ports open
- Pre-configured to work on a DirectAdmin server with all the standard DirectAdmin ports open
- Auto-configures the SSH port if it’s non-standard on installation
- Block traffic on unused server IP addresses – helps reduce the risk to your server
- Alert when end-user scripts sending excessive emails per hour – for identifying spamming scripts
- Suspicious process reporting – reports potential exploits running on the server
- Excessive user processes reporting
- Excessive user process usage reporting and optional termination
- Suspicious file reporting – reports potential exploit files in /tmp and similar directories
- Directory and file watching – reports if a watched directory or a file changes
- Block traffic on a variety of Block Lists including DShield Block List and Spamhaus DROP List
- BOGON packet protection
- Pre-configured settings for Low, Medium or High firewall security (cPanel servers only)
- Works with multiple ethernet devices
- Server Security Check – Performs a basic security and settings check on the server (via cPanel/- DirectAdmin/Webmin UI)
- Allow Dynamic DNS IP addresses – always allow your IP address even if it changes whenever you connect to the internet
- Alert sent if server load average remains high for a specified length of time
- mod_security log reporting (if installed)
- Email relay tracking – tracks all email sent through the server and issues alerts for excessive usage (cPanel servers only)
- IDS (Intrusion Detection System) – the last line of detection alerts you to changes to system and application binaries
- SYN Flood protection
- Ping of death protection
- Port Scan tracking and blocking
- Permanent and Temporary (with TTL) IP blocking
- Exploit checks
- Account modification tracking – sends alerts if an account entry is modified, e.g. if the password is changed or the login shell
- Shared syslog aware
- Messenger Service – Allows you to redirect connection requests from blocked IP addresses to preconfigured text and html pages to inform the visitor that they have been blocked in the firewall. This can be particularly useful for those with a large user base and help process support requests more efficiently
- Country Code blocking – Allows you to deny or allow access by ISO Country Code
- Port Flooding Detection – Per IP, per Port connection flooding detection and mitigation to help block DOS attacks
- WHM root access notification (cPanel servers only)
- lfd Clustering – allows IP address blocks to be automatically propagated around a group of servers running lfd. It allows allows cluster-wide allows, removals and configuration changes
- Quick start csf – deferred startup by lfd for servers with large block and/or allow lists
- Distributed Login Failure Attack detection
- Temporary IP allows (with TTL)
- IPv6 Support with ip6tables
- Integrated UI – no need for a separate Control Panel or Apache to use the csf configuration
- Integrated support for cse within the Integrated UI
- cPanel Reseller access to per reseller configurable options Unblock, Deny, Allow and Search IP address blocks
- System Statistics – Basic graphs showing the performance of the server, e.g. Load Averages, CPU Usage, Memory Usage, etc
- ipset support for large IP lists
- Integrated with the CloudFlare Firewall
- …lots more!

<br />

---

<br />

## Installation

<br />

### Step 1: Prerequisites
- A Linux server running CentOS, Debian, Ubuntu, or any other compatible Linux distribution. 
- Root access or a user account with sudo privileges.
- Perl installed on your server. If Perl is not installed, you can install it by running the following commands:
  - For CentOS/RHEL:
    ```shell
    sudo yum install perl 
    ```

  - For Debian/Ubuntu:

    ```shell
    sudo apt-get update 
    sudo apt-get install perl 
    ```

<br />

### Step 2: Download and Install CSF
To download and install CSF, follow these steps:

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

CSF will now be installed on your server, along with its Web UI (ConfigServer Firewall & Security) if you have a control panel like cPanel or DirectAdmin installed.

<br />

### Step 3: Testing the Firewall
Before enabling and configuring CSF, it is crucial to test whether it is compatible with your server. Run the following command to initiate the test:

```shell
sudo perl /usr/local/csf/bin/csftest.pl
```

The test will check for any potential issues or conflicts. If the test completes successfully, you will see the message “RESULT: csf should function on this server.” If there are any problems, the test will provide information on how to resolve them.

<br />

### Step 4: Configuring CSF
Now that CSF is installed, you can start configuring it to suit your server’s requirements. The main configuration file for CSF is located at /etc/csf/csf.conf. You can use your preferred text editor to modify the file, such as nano or vim:

```shell
sudo nano /etc/csf/csf.conf
```

Some essential settings you may want to modify include:
- `TESTING`: Set this value to 0 to disable testing mode and activate the firewall.
- `TCP_IN` and `TCP_OUT`: These settings define the allowed incoming and outgoing TCP ports, respectively. Add or remove ports as required, separated by commas.
- `UDP_IN` and `UDP_OUT`: These settings define the allowed incoming and outgoing UDP ports, respectively. Add or remove ports as required, separated by commas.
- `DENY_IP_LIMIT`: This setting defines the maximum number of IP addresses that can be listed in the /etc/csf/csf.deny file. Adjust this limit as needed.
- `CT_LIMIT`: This setting controls the number of connections from a single IP address that are allowed before the IP is temporarily blocked. Adjust this value according to your server’s requirements.

These are just a few of the numerous configuration options available in CSF. Make sure to review the configuration file and adjust the settings to suit your server’s needs. After making changes to the configuration file, save and exit the text editor.

<br />

### Step 5: Enabling CSF Firewall
Once you have configured the CSF firewall, it is time to enable it. To do so, run the following command:

```shell
sudo csf -e
```

This command will restart the CSF and LFD (Login Failure Daemon) services, applying your configuration changes and activating the firewall.

<br />

### Step 6: Managing the Firewall
CSF provides several commands to manage the firewall, such as:

#### Start Firewall

```shell
sudo csf -s
```

#### Stop Firewall

```shell
sudo csf -f
```

#### Restart Firewall

```shell
sudo csf -r
```

#### List Firewall Rules

```shell
sudo csf -l
```

#### Add IP to Allow List

```shell
sudo csf -a IP_ADDRESS
```

#### Remove IP to Allow List

```shell
sudo csf -ar IP_ADDRESS
```

#### Add IP to Deny List

```shell
sudo csf -d IP_ADDRESS
```

#### Remove IP from Deny List

```shell
sudo csf -dr IP_ADDRESS
```

#### Add Temp Block IP

```shell
sudo csf -td IP_ADDRESS
```

#### Remove Temp Block IP

```shell
sudo csf -tr IP_ADDRESS
```

These commands can help you manage your server’s security and monitor incoming and outgoing traffic.

<br />

### Step 7: Uninstalling CSF (Optional)
If you decide to uninstall CSF for any reason, follow these steps:

1. Navigate to the CSF directory:
    ```shell
    cd /etc/csf
    ```
2. Run the uninstallation script:
    ```shell
    sudo sh uninstall.sh
    ```

The script will remove CSF and its associated files from your server.

<br />

---

<br />

## Enable CSF Firewall Web UI
ConfigServer Security & Firewall (CSS) is an iptables based firewall for Linux systems. In our previous tutorial read installation tutorial of CSF on Linux system. CSF also provides in-built web UI for the managing firewall from the web interface. In this tutorial, you will find how to enable CSF Firewall Web UI on your system.

<br />

### Step 1 – Install Required Perl Modules:
CSF UI required some of Perl modules to be installed on your system. Use the following commands to install required modules as per your operating system.

**Debian based systems:**
```shell
sudo apt-get install libio-socket-ssl-perl libcrypt-ssleay-perl \
                    libnet-libidn-perl libio-socket-inet6-perl libsocket6-perl
```

**Redhat based systems:**
```shell
sudo yum install perl-IO-Socket-SSL.noarch perl-Net-SSLeay perl-Net-LibIDN \
               perl-IO-Socket-INET6 perl-Socket6
```

<br />

## Step 2 – Enable CSF Firewall Web UI:
To enable CSF web UI edit /etc/csf/csf.conf file in your favorite text editor and update the following values.

```shell
sudo vim /etc/csf/csf.conf
```

```conf
# 1 to enable, 0 to disable web ui 
UI = "1"

# Set port for web UI. The default port is 6666, but
# I change this to 1025 to easy access. Default port create some issue
# with popular chrome and firefox browser (in my case) 

UI_PORT = "1025"

# Leave blank to bind to all IP addresses on the server 
UI_IP = ""

# Set username for authetnication 
UI_USER = "admin"

# Set a strong password for authetnication 
UI_PASS = "admin"
```

<br />

Change the following values to your own:
- `UI_PORT`
- `UI_USER`
- `UI_PASS`

After making changes, edit `/etc/csf/ui/ui.allow` configuration file and add your public IP to allow access to CSF UI. Change `YOUR_PUBLIC_IP_ADDRESS` with your public IP address.

```shell
sudo echo "YOUR_PUBLIC_IP_ADDRESS" >>  /etc/csf/ui/ui.allow
```

Web UI works under lfd daemon. So restart the lfd daemon on your system using the following command.

```shell
sudo service lfd restart
```

<br />

## Step 3 – Access and Use Web UI:
Now, access CSF UI on your browser with the specified port. For this tutorial, I have used 1025 port. This will prompt for user authentication first. After successful login, you will find the screen like below.

<p align="center"><img style="width: 100%;text-align: center;" src="https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/Docs/images/csf-ui.png"></p>

**Allow IP Address** – You can use below option to allow any IP quickly. This add the entry in /etc/csf/csf.allow file.

<p align="center"><img style="width: 100%;text-align: center;" src="https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/Docs/images/csf-quick-allow.png"></p>

**Deny IP Address** – You can use below option to deny any IP quickly. This add the entry in /etc/csf/csf.deny file.

<p align="center"><img style="width: 100%;text-align: center;" src="https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/Docs/images/csf-quick-deny.png"></p>

**Unblock IP Address** – You can use below option to quickly unblocked any IP which is already blocked by CSF.

<p align="center"><img style="width: 100%;text-align: center;" src="https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/Docs/images/csf-unblock-ip.png"></p>

