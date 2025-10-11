---
title: Changelog
tags:
  - changelog
  - releases
  - history
---

# Changelog

<p align="center" markdown="1">

![Version](https://img.shields.io/github/v/tag/Aetherinox/csf-firewall?logo=GitHub&label=version&color=ba5225)
![Downloads](https://img.shields.io/github/downloads/Aetherinox/csf-firewall/total)
![Repo Size](https://img.shields.io/github/repo-size/Aetherinox/csf-firewall?label=size&color=59702a)
![Last Commit)](https://img.shields.io/github/last-commit/Aetherinox/csf-firewall?color=b43bcc)

</p>

<br />

### <!-- md:version stable- --> 15.02 <small>Coming Soon</small> { id="15.02" }

- This version has not been released yet

<br />

---

<br />

### <!-- md:version stable- --> 15.01 <small>Oct 06 2025</small> { id="15.01" }

- `feat`: Register new domain https://configserver.dev
- `feat`: New blocklist service at https://blocklist.configserver.dev
- `chore`: Bring new update server online at https://download.configserver.dev
- `refactor`: Changed csf update server code to point to new csf domain
- `fix`: Invalid sessions still being able to access backend web interface assets

<br />

---

<br />

### <!-- md:version stable- --> 15.00 <small>Aug 28 2025</small> { id="15.00" }

- `chore`: Download and update servers taken offline
- `chore`: Disabled automatic updates within csf
- `chore`: Added country code validation and warning output
- `refactor`: Updated regex to extract client ip from logs
- `docs`: Changed license to GPLv3

<br />

---

<br />

### <!-- md:version stable- --> 14.24 <small>Aug 02 2025</small> { id="14.24" }

- `fix`: regression bug in v14.23 "Modified UI HTTP header checks to be case agnostic"

<br />

---

<br />

### <!-- md:version stable- --> 14.23 <small>July 21 2025</small> { id="14.23" }

- `change`: Modify Apache regex to detect "remote" or "client" as the IP trigger
- `change`: Mdified UI HTTP header checks to be case agnostic

<br />

---

<br />

### <!-- md:version stable- --> 14.22 <small>Sep 20 2024</small> { id="14.22" }

- `build`: Updates ConfigServer Firewall to v14.22
  - `remove`: session IP match check from DA login
  - `added`: example spamassassin temp file regex to csf.fignore for new installations

<br />

---

<br />

### <!-- md:version stable- --> 14.21 <small>Aug 30 2024</small> { id="14.21" }

- `change`: add header animations, app name returns user home
- `change`: clicking app logo or name now returns user to home page
- `change`: add favicon
- `change`: silence curl in openvpn patch
- `change`: removal of `NETWORK_MANUAL_MODE`, `NETWORK_ADAPT_NAME`
- `change`: new animated checkbox input for firewall profiles
- `change`: clicking logo in header now re-directs user to home
- `change`: enhanced login screen animations
- `change`: enhanced mobile view
- `build`: update main source release to CSF v14.21
- `build`: dark theme now compatible with CSF v14.21
- `fix`: docker inspect error when container has more than one network [#1](https://github.com/Aetherinox/csf-firewall/issues/1)
- `fix`: extended sized buttons with text cutting off
- `docs`: removal of manual mode values no longer needed

<br />

---

<br />

### <!-- md:version stable- --> 14.20 <small>Aug 28 2024</small> { id="14.20" }

- `feat`: add new patch `openvpn`
- `feat`: add new command-line arguments:
    - add `-d, --dev` for advanced logging
    - add `-f, --flush` to completely remove iptable rules
    - add `-r, --report` to display dependency stats, app information, etc.
    - add `-v, --version` to display patcher version
- `feat`: added new login page to dark theme
- `feat`: add dark theme
- `feat`: add traefik integration
- `feat`: add authentik integration
- `change`: docker patch now allows for multiple ip blocks to be whitelisted
- `change`: optimizations to load order
- `change`: updated toggle switches for various setting pages
- `change`: start migration of in-line style properties over to stylesheet
- `change`: new ruleset for openvpn integration
- `change`: auto disable csf TESTING mode when patch ran
- `change`: add `-r, --report` to display status of dependencies and setup
- `refactor`: re-write of script
- `refactor`: merge all scripts into one
- `fix`: interface bug which existed in light theme which caused certain divs to break
- `fix`: openvpn ip detection
- `fix`: issue with manual mode being disabled - #1
- `fix`: error `"docker network inspect" requires at least 1 argument.` - #1
- `fix`: error `invalid port/service '-j' error`
- `ci`: dark theme now included with all releases as .zip
- `ci`: auto-update /docs/ on push to repo
- `ci`: add workflow to automatically grab latest version of ConfigServer Firewall and append to each release
- `docs`: update to include traefik and authentic integration
- `docs`: rewrite documentation to include better instructions

<br />

---

<br />

### <!-- md:version stable- --> 14.19 <small>May 06 2024</small> { id="14.19" }

- `change`: switch to using iptables-nft if it exists in `/usr/sbin/iptables-nft`
- `added`: `IO::Handle::clearerr()` call before reading data from a log file
- `added`: "Require all granted" to the MESSENGER .htaccess file
- `added` UID/GID rules to IPv6 if enabled
- `modified`: dovecot regex to look for "failed: Connection reset by peer"

<br />

---

<br />