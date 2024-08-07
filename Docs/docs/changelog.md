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

### <!-- md:version stable- --> 2.0.0 <small>Aug 07, 2024</small> { id="2.0.0" }

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

### <!-- md:version stable- --> 1.0.0 <small>Jun 06, 2024</small> { id="1.0.0" }

- Initial release

<br />

---

<br />