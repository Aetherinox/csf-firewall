---
title: "Cheatsheet › Structure"
tags:
  - cheatsheet
  - configure
---

# Cheatsheet: Structure <!-- omit from toc -->

This page provides a summary of the files and folders associated with **ConfigServer Firewall & Security (CSF)**. Use it as a reference to locate and edit specific configuration files or resources.

<br />

## 📁 Directory Structure

Directories associated with ConfigServer Filewall which house all of the files used to configure and manage CSF.

| Folder                                  | Description                                                                                                                                   |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `/etc/csf/`                             | CSF configuration files, blocklists, whitelists, etc                                                                                          |
| `/var/lib/csf/`                         | Runtime data, temporary files, and logs for CSF and LFD                                                                                       |
| `/var/lib/csf/ui`                       | Runtime data and cache for the CSF WebUI.                                                                                                     |
| `/usr/local/csf/bin/`                   | Pre & post initialzation scripts `csfpre.sh` and `csfpost.sh`, test script `csftest.pl`, and csf uninstaller `uninstall.sh`                   |
| `/usr/local/csf/lib/`                   | Perl modules and static data                                                                                                                  |
| `/usr/local/csf/profiles/`              | Pre-configured CSF setup profiles                                                                                                             |
| `/usr/local/csf/tpl/`                   | Email alert templates                                                                                                                         |
| `/usr/local/include/csf/pre.d/`         | Scripts to execute when CSF started. Runs **before** CSF configures iptables. These are triggered by `/usr/local/csf/bin/csfpre.sh`           |
| `/usr/local/include/csf/post.d/`        | Scripts to execute when CSF started. Runs **after** CSF configures iptables. These are triggered by `/usr/local/csf/bin/csfpost.sh`           |

<br />

---

<br />

## 📄 File Structure

Files associated with ConfigServer Firewall configuration and management.

| File                                    | Description                                                                                                                                   |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `/etc/csf/changelog.txt`                | List of changes made to each release of CSF / LFD                                                                                             |
| `/etc/csf/csf.allow`                    | List of IP's & CIDR addresses allowed through the firewall                                                                                    |
| `/etc/csf/csf.blocklists`               | URLs for external blocklists used by CSF to block malicious IPs                                                                               |
| `/etc/csf/csf.cloudflare`               | Contains configuration elements for the `CF_ENABLE` CloudFlare feature                                                                        |
| `/etc/csf/csf.conf`                     | Main configuration file                                                                                                                       |
| `/etc/csf/csf.deny`                     | IP's and CIDR addresses that should never be allowed through the firewall                                                                     |
| `/etc/csf/csf.dirwatch`                 | Directories & files you want to be alerted when changed. Must specify full paths for entries                                                  |
| `/etc/csf/csf.dyndns`                   | IPs & hostnames of systems that are dynamically updated (like via a dynamic DNS service)                                                      |
| `/etc/csf/csf.fignore`                  | Files that lfd directory watching will ignore. You must specify the full path to the file                                                     |
| `/etc/csf/csf.ignore`                   | IP's & CIDR addresses that the login failure daemon should ignore and not not block if detected                                               |
| `/etc/csf/csf.logfiles`                 | Log files for the `LOGSCANNER` feature                                                                                                        |
| `/etc/csf/csf.logignore`                | Regular expressions for the `LOGSCANNER` feature. If a line matches it will be ignored, otherwise it will be reported                         |
| `/etc/csf/csf.mignore`                  | Usernames and local IP addresses that `RT_LOCALRELAY_ALERT` will ignore                                                                       |
| `/etc/csf/csf.pignore`                  | Processes LFD should ignore (for example, trusted services).                                                                                  | 
| `/etc/csf/csf.rblconf`                  | Optional entries for the IP checking against RBLs within csf                                                                                  |
| `/etc/csf/csf.redirect`                 | Port and/or IP address assignments to direct traffic to alternative ports/IP addresses                                                        |
| `/etc/csf/csf.resellers`                | Reseller accounts to allow access to limited csf functionality.                                                                               |
| `/etc/csf/csf.rignore`                  | Domains & partial domain that lfd process tracking will ignore based on reverse & forward DNS lookups                                         |
| `/etc/csf/csf.signore`                  | Files that `LF_SCRIPT_ALERT` will ignore. Specify the full path to the directory containing the script                                        |
| `/etc/csf/csf.sips`                     | List any server configured IP addresses for which you don't want to allow any incoming or outgoing traffic                                    |
| `/etc/csf/csf.smtpauth`                 | Will allow EXIM to advertise SMTP AUTH. One IP address per line.                                                                              | 
| `/etc/csf/csf.suignore`                 | Usernames that are ignored during the `LF_EXPLOIT` SUPERUSER check                                                                            |
| `/etc/csf/csf.syslogs`                  | Log files for the UI System Log Watch and Search features. IF they exists they will apear in the drop-down lists                              |
| `/etc/csf/csf.syslogusers`              | Usernames which should be allowed to log via syslog/rsyslog                                                                                   |
| `/etc/csf/csf.uidignore`                | User ID's (UID) that are ignored by the User ID Tracking feature                                                                              |
| `/etc/csf/downloadservers`              | Servers that will be pinged to fetch updates for CSF                                                                                          |
| `/etc/csf/ui/ui.allow`                  | IPs allowed to access the CSF WebUI. IPs in this file bypass CSF's IP restrictions for the web ui                                             |
| `/etc/csf/ui/ui.ban`                    | IPs that are explicitly denied access to the CSF WebUI                                                                                        |
| `/lib/systemd/system/csf.service`       | Service file for csf (Login Failure Daemon)                                                                                                   |
| `/lib/systemd/system/lfd.service`       | Service file for lfd (ConfigServer Firewall)                                                                                                  |
| `/usr/local/csf/bin`                    | CSF scripts and utilities used to manage firewall rules.                                                                                      |
| `/usr/local/csf/uid`                    | Scripts and files related to CSF user interface.                                                                                              |
| `/var/lib/csf/lfd.log`                  | Main LFD log file recording login attempts, blocked IPs, and alerts.                                                                          |
| `/var/lib/csf/lfd.pid`                  | PID file for Login Failure Daemon (LFD).                                                                                                      |

<br />

---

<br />

## Patcher Files

The following files are associated with the ConfigServer Firewall scripts located in this repo's `extras/scripts` folder. These scripts add special iptable rules so that CSF can communicate with Docker & OpenVPN.

| File                                        | Description                                                                                                     |
| ------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `/usr/local/csf/bin/csfpre.sh`              | Patcher **pre** script. Runs before CSF configures iptables                                                     |
| `/usr/local/csf/bin/csfpost.sh`             | Patcher **post** script. Runs after CSF configures iptables                                                     |
| `/usr/local/include/csf/post.d/docker.sh`   | Docker patch for CSF which adds firewall rules for Docker and CSF                                               |
| `/usr/local/include/csf/post.d/openvpn.sh`  | OpenVPN patch for CSF which adds firewall rules for OpenVPN and CSF                                             |

<br />

---

<br />
