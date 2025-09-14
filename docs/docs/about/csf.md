---
title: About ConfigServer Firewall Suite
tags:
  - info
---

# About ConfigServer Firewall & Security

**ConfigServer Firewall & Security** (_CSF_) is a comprehensive security suite for Linux servers, first released in 2005. At its core, CSF is a **Stateful Packet Inspection** (_SPI_) firewall and intrusion detection system that works as a front-end to iptables or nftables, the standard Linux firewall frameworks.

<br />

---

<br />

## About

**ConfigServer Firewall & Security**, also known as _CSF_, is a **Stateful Packet Inspection** (_SPI_) firewall and Login/Intrusion Detection and Security application for Linux servers which started back in 2005. CSF works as a front-end to iptables or nftables, configuring your server’s firewall rules to lock down public access to services while allowing only approved connections. This provides better security for your server while giving you an advanced, easy-to-use interface for managing firewall settings. With CSF in place, you can safely permit activities such as logging in via FTP or SSH, checking email, and loading websites, while unauthorized access attempts are blocked.

<br />

As part of the ConfigServer Firewall suite, CSF includes the companion service **Login Failure Daemon** (_LFD_). LFD continuously monitors authentication activity on your server to detect excessive login failures, a common sign of brute force attacks. When repeated failures are detected from the same IP address, LFD will automatically and temporarily block that IP from accessing any services on your server. These blocks expire after a set period, but they can also be manually removed through the ConfigServer interface. You can also extend the duration of a blocked IP address, or block an IP indefinitely.

<br />

Beyond automated blocking, CSF provides tools to whitelist trusted IPs, blacklist unwanted IPs, and monitor real-time activity of LFD’s actions. Detailed instructions for configuring these features are covered in Managing Your CSF Firewall.

<br />

When you install the CSF suite on your server; you will be provided with two services:

| Service | Description |
| --- | --- |
| `csf` | **ConfigServer Firewall** (csf): SPI iptables firewall which allows you to restrict what is allowed to communicate with your server. |
| `lfd` |  **Login Failure Daemon** (lfd): Process that runs all the time and periodically (every X seconds) scans the latest log file entries for login attempts against your server that continually fail within a short period of time. |

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
