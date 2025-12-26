---
title: "Update › v15.01 to Newer"
tags:
  - waytotheweb
  - update
  - legacy
---

## About Versioning

This repository categorizes **ConfigServer Security & Firewall (CSF)** into two distinct development eras:

| Version Range                                 | Developer                     | Description                           | This Page Covers  |
| --------------------------------------------- |------------------------------ |-------------------------------------- | ----------------- |
| [v15.01 and Newer](../../install/update/v1501-to-newer.md)         | Aetherinox                    | Maintained after August 2025          | :aetherx-axs-square-check: |
| [v15.00 and Older](../../install/update/v1500-to-v1501.md)         | Way to the Web                | Legacy releases prior to August 2025  | :aetherx-axd-square: |

<br />

The final release of CSF **v15.00** by *Way to the Web* removed all automatic update functionality as a result of the company shutting down. Consequently, automatic updates no longer work on that version.

[CSF **v15.01**](https://github.com/Aetherinox/csf-firewall/releases/tag/15.01) was the first release maintained by this [:aetherx-axb-github: repository](https://github.com/Aetherinox/csf-firewall/releases/), which restored automatic update support by introducing new servers.

To regain automatic update functionality, any server running CSF **v15.00 and older** by the company **Web to the Web**, must be migrated to this repository’s maintained version of [CSF **v15.01**](https://github.com/Aetherinox/csf-firewall/releases/tag/15.01) and newer.

<br />

## Update from v15.x to Newer <!-- omit from toc -->

This page outlines the process for updating **ConfigServer Security & Firewall (CSF)** after you have completed the initial installation on your server.

These instructions assume that you currently have CSF v15.x or newer installed on your server, and are looking to update to the latest version.

If you are already running CSF v15.x by Aetherinox, updating to the latest version is extremely simple.

There are two methods you can use for updating CSF:

1. [Automatic using the built-in update utility](#automatic).
2. [Manually by downloading the latest CSF files and running the `install.sh` script](#manually).

<br />

### Automatic

To update CSF automatically, you can run the terminal command to check for updates:

=== ":aetherx-axs-square-terminal: Terminal `-c`"

    ```shell
    sudo csf -c
    ```

=== ":aetherx-axs-square-terminal: Terminal `--check`"

    ```shell
    sudo csf --check
    ```

<br />

You should see one of the following depending on if an update is available or not:

=== ":aetherx-axs-square-terminal: Terminal (Update Available)"

    ```console
    A newer version of csf is available - Current:v15.09 New:v15.10
    ```

=== ":aetherx-axs-square-terminal: Terminal (No Update Available)"

    ```console
    csf is already at the latest version: v15.10
    ```

<br />

If you want CSF to automatically update without performing a check first, use the command below. If a newer version is available, it will install it immediately without any prior notification.

=== ":aetherx-axs-square-terminal: Terminal `-u`"

    ```shell
    sudo csf -u
    ```

=== ":aetherx-axs-square-terminal: Terminal `--update`"

    ```shell
    sudo csf --update
    ```

<br />

You can also run a forced update, which installs the latest available version of CSF regardless of whether an update is detected. This command will overwrite the current installation files even if you’re already up to date.

=== ":aetherx-axs-square-terminal: Terminal"

    ```shell
    sudo csf -uf
    ```

<br />
<br />

### Manually

To update CSF manually, verify the current running version with the command below:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo csf -v
      ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      csf: v15.09 (generic)
      ```

<br />

Once you have established the current running version, you can check our official [:aetherx-axb-github: repository](https://github.com/Aetherinox/csf-firewall/releases/) releases page for the latest version available.

To download the latest version, grab it using one of the commands below:

=== ":aetherx-axs-file-zipper: .tgz"

    ```shell
    # Using wget (tgz)
    wget https://download.configserver.dev/csf.tgz

    # Using curl (tgz)
    curl -O https://download.configserver.dev/csf.tgz
    ```

=== ":aetherx-axs-file-zip: .zip"

    ```shell
    # Using wget (zip)
    wget https://download.configserver.dev/csf.zip

    # Using curl (zip)
    curl -O https://download.configserver.dev/csf.zip
    ```

<br />

Decompress / unzip the downloaded archive file:

=== ":aetherx-axs-file-zipper: .tgz"

    ```bash
    tar -xzf csf.tgz -C /tmp
    ```

=== ":aetherx-axs-file-zip: .zip"

    ```bash
    unzip csf.zip -d /tmp
    ```

<br />

Run the CSF installation script:

=== ":aetherx-axd-command: Command"

      ```bash
      sudo sh /tmp/csf/install.sh
      ```

<br />

Follow any instructions on-screen. If prompted for any additional information, enter it. Once the wizard completes, you can confirm if CSF is installed and functioning by accessing your server via SSH, and running the CSF version command:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo csf -v
      ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      csf: v15.10 (generic)
      ```

<br />

Confirm the status of `csf` by running:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo systemctl status csf
      ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      ● csf.service - ConfigServer Security & Firewall - csf
          Loaded: loaded (/lib/systemd/system/csf.service; enabled; vendor preset: enabled)
          Active: active (exited) since Mon 2025-11-19 23:45:04 UTC; 14 seconds ago
        Main PID: 597 (code=exited, status=0/SUCCESS)
              CPU: 0min 14.956s

      Notice: journal has been rotated since unit was started, output may be incomplete.
      ```

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
