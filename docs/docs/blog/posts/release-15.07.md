---
date: 2025-10-23
authors:
    - aetherinox
categories:
    - release
    - changelog
    - v15.x
    - cyberpanel
description: >
    Details regarding CSF release v15.07
title: >
    Release v15.07
comments: true
---

# Release: v15.07

This update publicly launches our [Insiders Program](../../insiders/index.md), offering early access to upcoming features and exclusive benefits.  

It also resolves a CyberPanel integration issue that caused errors when saving your **Firewall Configuration**, alongside several minor bug fixes, maintenance improvements, and code refactoring.

<!-- more -->

<br />

---

<br />

## Changelog

A list of the most important changes are listed below.

<br />

### Introducing the Insiders Program

The ConfigServer Security & Firewall <!-- md:sponsor --> **Insiders Program** is designed for users who want to actively support, test, and shape the future of CSF. As an Insider, you’ll gain **early access** to new features and experimental functionality before they’re released publicly.

We’ll never place essential security features behind a paywall — your protection should never depend on your wallet. The Insiders Program simply gives you the opportunity to contribute to development by testing new versions, supporting the project, and helping us identify issues before public release.  

If you’re unable to donate, no problem. You’ll still have access to the same core features as our Insiders, and the project will remain fully open-source.

By joining our Insiders Program as a sponsor, you’ll receive the following benefits:

- **Exclusive early access** to the ConfigServer Security & Firewall release channel  
- **Sponsor role** on our [Discord](https://discord.configserver.dev) server  
- Your GitHub avatar featured on our [Sponsors](../../insiders/sponsors.md) page  
- The opportunity to **suggest new perks** and help shape the future of the program  

<br />
<br />

### Launched Discord Server

We have launched a Discord server for users who wish to sit back and communicate with others who share the same interests. Stop by and join us in discussion about CSF, as well as other topics such as firewalls, self-hosted software, and homelabs.

<br />

<div class="valign-buttons" markdown>

[![View](https://img.shields.io/discord/1428601317361848412?style=for-the-badge&color=de1f68)](https://discord.configserver.dev)[![View](https://img.shields.io/badge/Join%20Discord-2d5e97?style=for-the-badge&logo=discord&logoColor=FFFFFF)](https://discord.configserver.dev)

</div>

<br />
<br />

### Removed Spamhaus edrop list 

The **Spamhaus edrop** list has been removed from `/etc/csf/csf.blocklists`. All edrop entries have been moved into the `drop` list:

- http://spamhaus.org/drop/drop.txt

<br />
<br />

### Fixed Cyberpanel error: Data supplied is not accepted - forbidden characters

We have fixed an issue which triggered the following error to occur when accessing the CSF **Firewall Configuration** page and attempting to save any changes made to the application:

```
{"error_message": "Data supplied is not accepted, following characters are not allowed in the input ` $ & ( ) [ ] { } ; : 
  \u2018 < >.", "errorMessage": "Data supplied is not accepted, following characters are not allowed in the input 
  ` $ & ( ) [ ] { } ; : \u2018 < >."}
```

<br />

To resolve this issue, you must run the installation script `src/install.sh` for CSF `v15.07` or newer, which applies the necessary fixes to allow you to save your CSF settings correctly.

The alternative to this is that all input fields within your settings must not contain a ++colon++, this includes the following settings:

- DROP_NOLOG
- PT_APACHESTATUS
- PS_PORTS
- UID_PORTS
- UI_CIPHER
- UI_SSL_VERSION
- DOCKER_NETWORK6

<br />
<br />

### Fixed whitespace breaking ipsets

A bug has been resolved that previously caused IPSet-based blocklists to fail loading when the blocklist definitions in `/etc/csf/csf.blocklists` were formatted with extra whitespace for readability.  

For example, the following style would previously break IPSet loading:

```ini
CSF_HIGHRISK        |43200      | 5 |   http://blocklist.configserver.dev/highrisk.ipset
```

<br />

Many users prefer to align entries for clarity, such as:

```ini
CSF_MASTER      | 43200 | 0 | http://blocklist.configserver.dev/master.ipset
CSF_HIGHRISK    | 43200 | 5 | http://blocklist.configserver.dev/highrisk.ipset
```

<br />

This issue has now been fixed — you can safely use aligned or “pretty-print” your blocklist definitions without affecting IPSet loading.

<br />
<br />

### Added Privacy Policy

We’ve introduced a new [Privacy Policy](../../about/privacy.md) that clearly explains how we collect and use information in a minimal and transparent way to operate our services.

We remain committed to collecting **only what’s necessary** — nothing more. Here’s how we protect your privacy:

- We **do not** log IP addresses, geographic data, or any other identifying metadata when you access our services, such as [download.configserver.dev](https://download.configserver.dev) or [blocklist.configserver.dev](https://blocklist.configserver.dev).  
- We **do not** route or proxy connections from servers running CSF through our infrastructure. Even if our servers were to go offline, your server would continue to operate without interruption.  
- We **do not** store donation or payment information on our servers. All transactions are securely handled by trusted third parties like [GitHub Sponsors](https://github.com/sponsors/Aetherinox) and [BuyMeACoffee](https://buymeacoffee.com/aetherinox). We only use their REST APIs to verify Insiders status linked to your license key.  
- We **do not** use analytics cookies or tracking scripts in your browser when visiting any of our services.

<br />

---

<br />

## Full Changelog

The full changelog is available [here](../../about/changelog.md).

<br />
<br />