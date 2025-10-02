---
title: Changelog
tags:
  - changelog
---

# Changelog

<p align="center" markdown="1">

![Version](https://img.shields.io/github/v/tag/Aetherinox/csf-firewall?logo=GitHub&label=version&color=ba5225)
![Downloads](https://img.shields.io/github/downloads/Aetherinox/csf-firewall/total)
![Repo Size](https://img.shields.io/github/repo-size/Aetherinox/csf-firewall?label=size&color=59702a)
![Last Commit)](https://img.shields.io/github/last-commit/Aetherinox/csf-firewall?color=b43bcc)

</p>

<br />

### <!-- md:version stable- --> 15.10.0 <small>October, 2025</small> { id="15.10.0" }

- `feat`: Register new domain https://configserver.dev
- `feat`: Added new pre and post startup scripts
- `feat`: Added new theme switcher
- `feat`: Added new dedicated javascript library
- `feat`: Added new icon font library
- `feat`: Added new login interface for web interface
- `feat`: Added new static footer to web interface
- `feat`: Integrated dark theme addon into csf with light theme
- `feat`: New blocklist service at https://blocklist.configserver.dev
- `chore`: Bring new update server online at https://download.configserver.dev
- `refactor`: Changed csf update server code to point to new csf domain
- `refactor`: Migrated css over to template structure and theme variables
- `fix`: `All` tab not properly displaying correct sections in web interface
- `fix`: Invalid sessions still being able to access backend web interface assets

### <!-- md:version stable- --> 15.0.0 <small>Aug 28, 2025</small> { id="15.0.0" }

- `chore`: Download and update servers taken offline
- `chore`: Disabled automatic updates within csf
- `chore`: Added country code validation and warning output
- `refactor`: Updated regex to extract client ip from logs
- `docs`: Changed license to GPLv3

<br />

### <!-- md:version stable- --> 14.24.0 <small>Aug 02, 2025</small> { id="14.24.0" }

- `fix`: regression bug in v14.23 "Modified UI HTTP header checks to be case agnostic"

<br />

### <!-- md:version stable- --> 14.23.0 <small>July 21, 2025</small> { id="14.23.0" }

- `change`: Modify Apache regex to detect "remote" or "client" as the IP trigger
- `change`: Mdified UI HTTP header checks to be case agnostic

<br />

### <!-- md:version stable- --> 14.22.0 <small>Sep 20, 2024</small> { id="14.22.0" }

- `build`: Updates ConfigServer Firewall to v14.22
  - `remove`: session IP match check from DA login
  - `added`: example spamassassin temp file regex to csf.fignore for new installations

<br />

### <!-- md:version stable- --> 14.21.1 <small>Aug 30, 2024</small> { id="14.21.1" }

- `change`: add header animations, app name returns user home
- `change`: clicking app logo or name now returns user to home page
- `change`: add favicon
- `change`: silence curl in openvpn patch
- `change`: removal of `NETWORK_MANUAL_MODE`, `NETWORK_ADAPT_NAME`
- `fix`: docker inspect error when container has more than one network [#1](https://github.com/Aetherinox/csf-firewall/issues/1)
- `docs`: removal of manual mode values no longer needed

<br />

### <!-- md:version stable- --> 14.21.0 <small>Aug 29, 2024</small> { id="14.21.0" }

- `change`: new animated checkbox input for firewall profiles
- `change`: clicking logo in header now re-directs user to home
- `change`: enhanced login screen animations
- `change`: enhanced mobile view
- `build`: update main source release to CSF v14.21
- `build`: dark theme now compatible with CSF v14.21
- `fix`: extended sized buttons with text cutting off

<br />

### <!-- md:version stable- --> 14.20.2 <small>Aug 28, 2024</small> { id="14.20.2" }

- `feat`: added new login page to dark theme
- `change`: optimizations to load order
- `change`: updated toggle switches for various setting pages
- `change`: start migration of in-line style properties over to stylesheet
- `fix`: interface bug which existed in light theme which caused certain divs to break

<br />

### <!-- md:version stable- --> 14.20.1 <small>Aug 27, 2024</small> { id="14.20.1" }

- `feat`: add dark theme
- `feat`: add traefik integration
- `feat`: add authentik integration
- `change`: new ruleset for openvpn integration
- `change`: auto disable csf TESTING mode when patch ran
- `change`: add `-r, --report` to display status of dependencies and setup
- `fix`: openvpn ip detection
- `ci`: dark theme now included with all releases as .zip
- `ci`: auto-update /docs/ on push to repo
- `docs`: update to include traefik and authentic integration

<br />

### <!-- md:version stable- --> 14.20.0 <small>Aug 07, 2024</small> { id="14.20.0" }

- `feat`: add new patch `openvpn`
- `feat`: add new command-line arguments:
    - add `-d, --dev` for advanced logging
    - add `-f, --flush` to completely remove iptable rules
    - add `-r, --report` to display dependency stats, app information, etc.
    - add `-v, --version` to display patcher version
- `enhance`: docker patch now allows for multiple ip blocks to be whitelisted
- `refactor`: re-write of script
- `refactor`: merge all scripts into one
- `bug`: fixed issue with manual mode being disabled - #1
- `bug`: fixed error `"docker network inspect" requires at least 1 argument.` - #1
- `bug`: fixed error `invalid port/service '-j' error`
- `docs`: rewrite documentation to include better instructions
- `ci`: add workflow to automatically grab latest version of ConfigServer Firewall and append to each release

<br />

---

<br />

### <!-- md:version stable- --> 14.19.0 <small>May 06, 2024</small> { id="14.19.0" }

- `change`: switch to using iptables-nft if it exists in `/usr/sbin/iptables-nft`
- `added`: `IO::Handle::clearerr()` call before reading data from a log file
- `added`: "Require all granted" to the MESSENGER .htaccess file
- `added` UID/GID rules to IPv6 if enabled
- `modified`: dovecot regex to look for "failed: Connection reset by peer"

<br />

---

<br />