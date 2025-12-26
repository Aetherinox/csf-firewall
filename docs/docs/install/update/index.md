---
title: "Updates › Getting Started"
tags:
  - update
  - legacy
---

## About Versioning

This repository categorizes **ConfigServer Security & Firewall (CSF)** into two distinct development eras:

| Version Range                                 | Developer                     | Description                           |
| --------------------------------------------- |------------------------------ |-------------------------------------- |
| [v15.01 and Newer](#v1501-and-newer)         | Aetherinox                    | Maintained after August 2025          |
| [v15.00 and Older](#v1500-and-older)         | Way to the Web                | Legacy releases prior to August 2025  |

<br />

The final release of CSF **v15.00** by *Way to the Web* removed all automatic update functionality as a result of the company shutting down. Consequently, automatic updates no longer work on that version.

[CSF **v15.01**](https://github.com/Aetherinox/csf-firewall/releases/tag/15.01) was the first release maintained by this [:aetherx-axb-github: repository](https://github.com/Aetherinox/csf-firewall/releases/), which restored automatic update support by introducing new servers.

To regain automatic update functionality, any server running CSF **v15.00 and older** by the company **Web to the Web**, must be migrated to this repository’s maintained version of [CSF **v15.01**](https://github.com/Aetherinox/csf-firewall/releases/tag/15.01) and newer.

<br />

---

<br />

## v15.01 and Newer

If you are currently running Aetherinox's version of CSF and wish to update to a newer version, you can read the following guide:

<div class="grid cards" markdown>

-   :aetherx-axb-abuseipdb: &nbsp; __[Update from v15.01 to Newer](../../install/update/v1501-to-newer.md)__

    ---

    Provides instructions on updating CSF v15.01 to newer versions.

</div>

<br />
<br />

## v15.00 and Older

If you are currently running the original CSF release developed by Way to the Web, and want to switch over to Aetherinox's [CSF **v15.01**](https://github.com/Aetherinox/csf-firewall/releases/tag/15.01) or newer, view the guide below:

<div class="grid cards" markdown>

-   :aetherx-axb-abuseipdb: &nbsp; __[Update from v15.00 Legacy to v15.01](../../install/update/v1500-to-v1501.md)__

    ---

    Provides instructions on updating from Way To The Web CSF v15.00 or older over to this new repository.

</div>

<br />

---

<br />

## Next Steps <!-- omit from toc -->

{==

Select what documentation you would like to proceed with next ...

==}

<div class="grid cards" markdown>

-   :aetherx-axs-gear-complex: &nbsp; __[Start System Services](../install/services.md)__

    ---

    Starting CSF requires disabling testing mode and enabling the firewall so it
    runs normally.  

    This chapter explains how to start both CSF and LFD services and ensure they
    launch on boot.  

    You’ll also find troubleshooting tips for common startup errors and how to
    fix them quickly.  

-   :aetherx-axs-browser: &nbsp; __[Enable Web Interface](../install/webui.md)__

    ---

    The web interface lets you manage your firewall through a browser instead
    of a command line.  

    This chapter covers installation of dependencies, enabling the interface,
    and whitelisting your IP for security.  

</div>

<br />

<br />
