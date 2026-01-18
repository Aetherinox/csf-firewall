---
title: "Updates › Getting Started"
tags:
  - update
  - legacy
---

This section provides guidance on updating your CSF installation. The update process you should follow
depends on the version of CSF currently installed on your system.

Before proceeding, review the [About Versioning](#about-versioning) section below to understand how CSF
releases are divided into different eras and to determine the correct update path for your installation.

<br />

---

<br />

## About Versioning

These docs break CSF up into **two** distinct development eras:

| Version Range                                                                       | Codename              | Developer           | Description                       |
| ----------------------------------------------------------------------------------- | --------------------- | ------------------- | --------------------------------- |
| :aetherx-axb-csf-fill-stable:{ .csf-logo } [v15.01 and Newer](#v1501-to-newer)      | Modern                | Aetherinox          | Maintained after August 2025      |
| :aetherx-axb-csf-legacy-02:{ .csf-logo } [v15.00 and Older](#v1500-to-newer)        | Legacy                | Way to the Web      | Maintained prior to August 2025   |

<br />

The final release of CSF **v15.00** by *Way to the Web Ltd.* removed all automatic update functionality. After this 
release, the company shut down their website, rendering all versions of CSF prior to August 2025 (_v15.00 and older_) 
unable to perform automatic updates.

[CSF **v15.01**](https://github.com/Aetherinox/csf-firewall/releases/tag/15.01) is the first version maintained by 
[:aetherx-axb-github: our repository](https://github.com/Aetherinox/csf-firewall/releases/), which restores automatic update 
functionality by introducing new servers.

Any server using CSF **v15.00 and older**, should be migrated to this repository’s maintained version of 
[CSF **v15.01**](https://github.com/Aetherinox/csf-firewall/releases/tag/15.01) and newer, if you want automatic updates to 
function again.

<br />

---

<br />

## v15.01 to Newer

Use the guide below if all of the following apply to your setup:

- [x] You are currently running **CSF v15.01 or newer**.
- [x] Your current installation is **not** the legacy **v15.00** release from *Way to the Web*.
- [x] You want to update your existing CSF installation to a newer version.

<div class="grid cards" markdown>

-   :aetherx-axb-csf-fill-stable:{ .csf-logo } &nbsp; __[Update from v15.01 to Newer](../../install/update/v1501-to-newer.md)__

    ---

    Explains how to update your CSF installation when running **CSF v15.01 or newer**, and how to 
    upgrade to the latest available release.

</div>

<br />
<br />

## v15.00 to Newer

Use the guide below if all of the following apply to your setup:

- [x] You are currently running **CSF v15.00 or earlier**, released by the original developer (*Way to the Web Ltd.*).
- [x] You want to migrate from the original developer’s version over to this maintained version.

<div class="grid cards" markdown>

-   :aetherx-axb-csf-legacy-02:{ .csf-logo } &nbsp; __[Update from v15.00 legacy to Newer](../../install/update/v1500-to-newer.md)__

    ---

    Describes the process for updating your CSF installation from the legacy versions developed by **Way to the Web**.
    This includes all versions developed before August 2025 (14.x, 13.x, etc.)

</div>

<br />

<br />
