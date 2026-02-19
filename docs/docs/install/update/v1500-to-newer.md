---
title: "Update › 15.00 to Newer"
tags:
  - waytotheweb
  - update
  - legacy
  - codename-legacy
---

This page explains how to update CSF from any legacy version (v15.00 and older) maintained by 
**Way to the Web Ltd** to the modern **v15.01+ releases**.

When Way to the Web ceased developing CSF, the built-in automatic update system in v15.00 and older 
stopped working. As a result, upgrading past v15.00 requires a one-time manual update.

By installing **v15.01**, you restore full automatic update functionality. CSF will again be able to 
fetch and install all future releases without requiring any manual intervention.

<br />
<br />

---

<br />
<br />

## About Versioning <!-- omit from toc -->

These docs break CSF up into **two** distinct development eras:

| Version Range                                                                                             | Codename              | Developer           | Description             | This Page Covers              |
| --------------------------------------------------------------------------------------------------------- | --------------------- | ------------------- | ----------------------- | ----------------------------- |
| :aetherx-axb-csf-fill-stable:{ .csf-logo } [v15.01 & Newer](../../install/update/v1501-to-newer.md)       | Modern                | Aetherinox          | After August 2025       | :aetherx-axd-square:          |
| :aetherx-axb-csf-legacy-02:{ .csf-logo } [v15.00 & Older](#perform-update)                                | Legacy                | Way to the Web      | Before August 2025      | :aetherx-axs-square-check:    |

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

## Perform Update <!-- omit from toc -->

??? Notes "Before You Update …"

    Make sure to back up any important configuration files located in :aetherx-axd-folder: `/etc/csf/`.

    Although existing files are never overwritten during the update process, it is strongly recommended
    to create backups before proceeding, as a general best practice.

To update CSF from legacy releases v15.00 and older, over to v15.01, download the latest version and run the 
installation script. This process replaces the old CSF files with the updated codebase, including the restored 
automatic update system.

If you don’t already have the latest version of CSF downloaded, grab it using one of the commands below:

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

Follow any instructions on-screen. If prompted for any additional information, enter it.

Once the install script is finished, confirm if CSF is installed and functioning by accessing your server via 
SSH, and running the CSF version command:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo csf -v
      ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      csf: v15.10 (generic)
      ```

<br />

The final required step is to open your :aetherx-axd-file:{ .icon-clr-tree-file } `/etc/csf/csf.conf` config 
file and ensure that the setting :aetherx-axd-gear: `TESTING` is set to `0`.

??? warning "Testing Mode Disables LFD"

    If you do not disable testing mode in the file :aetherx-axd-file:{ .icon-clr-tree-file } `/etc/csf/csf.conf`, 
    lfd will be unable to start.

=== ":aetherx-axs-file-magnifying-glass: Find"

    ``` bash title="/etc/csf/csf.conf"
    # #
    #   SECTION:Initial Settings
    # #
    #   Testing flag - enables a cron job that clears iptables if there are
    #   configuration problems when csf starts. Keep this enabled until you are
    #   confident the firewall is working correctly. This helps prevent getting
    #   locked out of your server.
    #   
    #   Once confirmed, set this flag to 0 and restart csf. Stopping csf will
    #   remove the cron job from /etc/crontab.
    #   
    #   Note:       lfd will not start while this flag is enabled.
    # #

    TESTING = "1"
    ```

=== ":aetherx-axs-file-pen: Change To"

    ``` bash title="/etc/csf/csf.conf"
    # #
    #   SECTION:Initial Settings
    # #
    #   Testing flag - enables a cron job that clears iptables if there are
    #   configuration problems when csf starts. Keep this enabled until you are
    #   confident the firewall is working correctly. This helps prevent getting
    #   locked out of your server.
    #   
    #   Once confirmed, set this flag to 0 and restart csf. Stopping csf will
    #   remove the cron job from /etc/crontab.
    #   
    #   Note:       lfd will not start while this flag is enabled.
    # #

    TESTING = "0"
    ```

<br />

After you have modified the above setting, restart the `csf` and `lfd` services:

=== ":aetherx-axs-command: Command"

    ``` shell
    sudo csf -ra
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

If you see the status of CSF listed as `Active`, you are ready to go.

<br />
<br />

---

<br />
<br />

## Future Updates

After you have migrated from Way to the Web's v15.00 to v15.01 or newer, this will give you the ability to utilize 
CSF's automatic update functionality for any future updates you wish to apply.

From this point forward, follow the update instructions located on the page 
[v15.01 to Newer](../../install/update/v1501-to-newer.md).

<br />
<br />

---

<br />
<br />

## Troubleshooting

The following is a list of questions a user may have regarding updates to CSF, and information about certain 
issues that may arise:

<br />

??? faq "Why do I need to perform a manual update from "Way to the Web" v15.00, to version 15.01+?"

    <div class="details-content">

    The last release of CSF from the original developer, Way to the Web, was **v15.00**. In this version, 
    all connectivity to their hosted update servers was completely removed.

    As a result, the built-in update functionality can no longer locate update servers and will simply time 
    out when checking for updates.

    When migrating to CSF **v15.01**, a manual upgrade is required to configure the software to use the new 
    update servers provided by this repository.

    After completing the manual upgrade, CSF can resume using its built-in update functionality to 
    automatically detect and install future releases.

    </div>

??? faq "Will the update process remain the same?"

    <div class="details-content">

    Yes. This version of CSF was designed to maintain familiarity for existing users.

    All update procedures, including first-time installations and subsequent updates, follow the same steps 
    used in CSF **v15.00**, the final release developed by Way to the Web Ltd.

    </div>

??? faq "Browser says **access restricted** when I access the CSF web interface using port `6666`"

    <div class="details-content">

    Out-of-box, Firefox and Chromium-based browsers block access to port `6666`.

    To access the CSF web interface, you either need to configure your browser to allow access
    to this port; OR you must change the port assigned to the web interface.

    To allow port `6666` in your browser, follow the instructions on the page 
    [Troubleshooting › Address Restricted](../../usage/troubleshooting/webui.md#browser-this-address-is-restricted)

    To change the port used for the CSF web interface, follow the instructions on the page 
    [Install › Web Interface › Setup](../../install/webui.md#step-2-enable-web-ui).

    </div>

<br />
<br />

---

<br />
<br />

## Next Steps <!-- omit from toc -->

{==

Select what documentation you would like to proceed with next ...

==}

<div class="grid cards" markdown>

-   :aetherx-axs-gear-complex: &nbsp; __[Start System Services](../../install/services.md)__

    ---

    Starting CSF requires disabling testing mode and enabling the firewall so it
    runs normally.  

    This chapter explains how to start both CSF and LFD services and ensure they
    launch on boot.  

    You’ll also find troubleshooting tips for common startup errors and how to
    fix them quickly.  

-   :aetherx-axs-browser: &nbsp; __[Enable Web Interface](../../install/webui.md)__

    ---

    The web interface lets you manage your firewall through a browser instead
    of a command line.  

    This chapter covers installation of dependencies, enabling the interface,
    and whitelisting your IP for security.  

</div>

[^1]:
    Modern web browsers will not let you directly access anything using port `6666`. You must force 
    Firefox and Chomium based browsers to accept connections to this port by following the instructions
    described in the chapter 
    [Troubleshooting › Address Restricted](../../usage/troubleshooting/webui.md#browser-this-address-is-restricted).

<br />
<br />
