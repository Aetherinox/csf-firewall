---
title: "Install › Install CSF"
tags:
  - install
  - setup
---

# Install CSF <!-- omit from toc -->

In the previous section, we covered how to install the required dependencies for CSF, download and extract the necessary files, and run the [csftest.pl](tests.md#csftestpl) script.  

If your tests were successful, you are now ready to install CSF on your server and begin configuring your new firewall. This section focuses on the **basic installation process** — detailed configuration will be covered in a later chapter.

<br />

---

<br />

## Before You Begin

This page includes installation instructions for numerous control panels, however, the install script has been developed to be automatic in how it detects what distro you are on, and if you are using any control panels such as cPanel / WHM, VestaCP, etc.

Typically, all users are going to run the same `install.sh` file, and then the installation wizard will detect if it needs to do anything extra. However, individual platforms instructions have been provided on this page.

If your distro or control panel is not mentioned here, follow the [Install: Generic](#install-generic) instructions, and CSF will automatically detect anything extra that it needs to do.

<br />

---

<br />

## Install: Generic

In the previous [download](download.md) step; you were instructed to download a copy of CSF which comes in the form of a zip archive. You then extracted that zip to `/tmp/csf`, and set `+x` executable permissions on the `install.sh` file. 

We need to ensure that we don't have any existing firewalls that need to be disabled. Run the commands below to ensure they are disabled:

=== ":aetherx-axs-block-brick-fire: UFW"

    Stop and disable `ufw`

    ```bash
    sudo systemctl stop ufw
    sudo systemctl disable ufw
    ```

    Confirm `ufw` is disabled with:

    ```bash
    sudo systemctl status ufw
    ```

=== ":aetherx-axs-block-brick-fire: Firewalld"

    Stop and disable `firewalld`

    ```bash
    sudo systemctl stop firewalld
    sudo systemctl disable firewalld
    ```

    Confirm `firewalld` is disabled with:

    ```bash
    sudo systemctl status firewalld
    ```

<br />

Finally, run the installation script. You can either execute `/tmp/csf/install.sh` or `/tmp/csf/install.generic.sh`. Pick one of the run options below. Most users will use :aetherx-axd-circle-1:

=== ":aetherx-axd-circle-1: Option 1"

    :aetherx-axd-circle-1: Runs `install.sh` :aetherx-axd-dot: uses `sh` shell :aetherx-axd-dot: executable permission not required

    ```bash
    sudo sh /tmp/csf/install.sh
    ```

=== ":aetherx-axd-circle-2: Option 2"

    :aetherx-axd-circle-2: Runs `install.sh` :aetherx-axd-dot: uses shebang interpreter :aetherx-axd-dot: requires executable `+x` permission

    ```bash
    sudo chmod +x /tmp/csf/install.sh
    /tmp/csf/install.sh
    ```

=== ":aetherx-axd-circle-3: Option 3"

    :aetherx-axd-circle-3: Runs `install.generic.sh` :aetherx-axd-dot: uses `sh` shell :aetherx-axd-dot: executable permission not required

    ```bash
    sudo sh /tmp/csf/install.generic.sh
    ```

=== ":aetherx-axd-circle-4: Option 4"

    :aetherx-axd-circle-4: Runs `install.generic.sh` :aetherx-axd-dot: uses shebang interpreter :aetherx-axd-dot: requires executable `+x` permission

    ```bash
    sudo chmod +x /tmp/csf/install.generic.sh
    /tmp/csf/install.generic.sh
    ```

<br />

When you run the installer script, initially it will execute the code inside `/tmp/csf/install.sh`, however, it will then be passed off to the correct sub-script to complete the installation. If you are not running any control panels such as cPanel, VestaCP, etc, then the installation wizard will run the sub-script `/tmp/csf/install.generic.sh`.

Follow the instructions on-screen. If you are prompted for any additional information, enter it when asked. For the most part, the installation wizard is automated.

Once the wizard completes, you can confirm if CSF is installed and functioning by accessing your server via SSH, and running the CSF version command:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo csf -v
      ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      csf: v15.10 (generic)
      ```

<br />

You can also confirm the status of `csf` and `lfd` by running:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo systemctl status csf
      ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      ● csf.service - ConfigServer Firewall & Security - csf
          Loaded: loaded (/lib/systemd/system/csf.service; enabled; vendor preset: enabled)
          Active: active (exited) since Mon 2025-09-15 23:45:04 UTC; 14 seconds ago
        Main PID: 597 (code=exited, status=0/SUCCESS)
              CPU: 0min 14.956s

      Notice: journal has been rotated since unit was started, output may be incomplete.
      ```

<br />

If you recieve the correct response, you can skip the rest of this page and proceed to the section [Next Steps](#next-steps). A more detailed explanation of how to use CSF will be explained in the next chapter of this guide.

<br />
<br />

---

<br />
<br />

## Install: cPanel and WHM

Installing CSF for WHM is almost the same process outlined in the [Install: Generic](#install-generic) steps, just with different extraction paths, and how you will access the CSF web interface.

<br />

If you have not yet logged into your server, log in as the `root` user via SSH.

=== ":aetherx-axs-key: Using Password"

    ```shell
    ssh -vvv root@XX.XX.XX.XX -p 22
    ```

=== ":aetherx-axs-file: Using Private Key"

    ```shell
    ssh -i /path/to/private_key -vvv root@XX.XX.XX.XX -p 22
    ```

<br />

We need to ensure that we don't have any existing firewalls that need to be disabled. Run the commands below to ensure they are disabled:

=== ":aetherx-axs-block-brick-fire: UFW"

    Stop and disable `ufw`

    ```bash
    sudo systemctl stop ufw
    sudo systemctl disable ufw
    ```

    Confirm `ufw` is disabled with:

    ```bash
    sudo systemctl status ufw
    ```

=== ":aetherx-axs-block-brick-fire: Firewalld"

    Stop and disable `firewalld`

    ```bash
    sudo systemctl stop firewalld
    sudo systemctl disable firewalld
    ```

    Confirm `firewalld` is disabled with:

    ```bash
    sudo systemctl status firewalld
    ```

<br />

Finally, run the installation script. You can either execute `/root/csf/install.sh` or `/root/csf/install.cpanel.sh`. We recommend `install.sh`. Most users will use :aetherx-axd-circle-1:

<br />

Pick one of the run options below. 

=== ":aetherx-axd-circle-1: Option 1"

    :aetherx-axd-circle-1: Runs `install.sh` :aetherx-axd-dot: uses `sh` shell :aetherx-axd-dot: executable permission not required

    ```bash
    sudo sh /root/csf/install.sh
    ```

=== ":aetherx-axd-circle-2: Option 2"

    :aetherx-axd-circle-2: Runs `install.sh` :aetherx-axd-dot: uses shebang interpreter :aetherx-axd-dot: requires executable `+x` permission

    ```bash
    sudo chmod +x /root/csf/install.sh
    /root/csf/install.sh
    ```

=== ":aetherx-axd-circle-3: Option 3"

    :aetherx-axd-circle-3: Runs `install.cpanel.sh` :aetherx-axd-dot: uses `sh` shell :aetherx-axd-dot: executable permission not required

    ```bash
    sudo sh /root/csf/install.cpanel.sh
    ```

=== ":aetherx-axd-circle-4: Option 4"

    :aetherx-axd-circle-4: Runs `install.cpanel.sh` :aetherx-axd-dot: uses shebang interpreter :aetherx-axd-dot: requires executable `+x` permission

    ```bash
    sudo chmod +x /root/csf/install.cpanel.sh
    /root/csf/install.cpanel.sh
    ```

<br />

When you run the installer script `install.sh`, initially it will execute the code inside `/root/csf/install.sh`, however, it will then be passed off to the correct sub-script. For cPanel, it will run the sub-script `/root/csf/install.cpanel.sh`.

Follow the instructions on-screen. If you are prompted for any additional information, enter it when asked. For the most part, the installation wizard is automated.

Once the installation is complete, you can access CSF through the WHM control panel:

  - WHM » Home » Plugins » `ConfigServer Security & Firewall` 

<br />

If you see ConfigServer Security & Firewall within WHM, you can skip the rest of this page and proceed to the section [Next Steps](#next-steps). A more detailed explanation of how to configure and use CSF will be explained in the [Usage](../usage/getting-started.md) chapter.

<br />
<br />

---

<br />
<br />

## Installer File Summary

This section provides a list of the installer scripts included with CSF and what their role plays in the installation process. This is available within our docs for more advanced users who wish to understand the process.

The installation process for CSF is handled through a main script that triggers several sub-installer scripts.  
You will run the `install.sh` script, which automatically detects your platform and then executes the appropriate sub-script.  

Each sub-script follows the naming scheme `install.<PLATFORM>.sh`. We have provided a list of the files below:

| File                            | Requires                              | Platform                                                                                                                                  |
| ------------------------------- | ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `install.sh`                    |                                       | Main installer script, detects your platform and re-reroutes your installation request to the correct installer sub-script listed below   |
| `install.generic.sh`            |                                       | Baremetal                                                                                                                                 |
| `install.cpanel.sh`             | `/usr/local/cpanel/version`           | cPanel / WHM                                                                                                                              |
| `install.cwp.sh`                | `/usr/local/cwpsrv`                   | CentOS Web Panel (CWP)                                                                                                                    |
| `install.cyberpanel.sh`         | `/usr/local/CyberCP`                  | CyberPanel                                                                                                                                |
| `install.directadmin.sh`        | `/usr/local/directadmin/directadmin`  | DirectAdmin                                                                                                                               |
| `install.interworx.sh`          | `/usr/local/interworx`                | Interworx                                                                                                                                 |
| `install.vesta.sh`              | `/usr/local/vesta`                    | VestaCP                                                                                                                                   |

<br />

### install.sh

The `install.sh` script serves as a launcher that directs you to the appropriate installation script for your platform. It can be run on any system, automatically detects your environment, and executes the correct installer from the files listed above. Before running it, make sure the script is executable by running `chmod +x install.sh`. We’ll cover this in the steps below.

<br />

### install.generic.sh

This is the generic bare-metal installer for CSF. You should use this script when installing CSF on a server that does not have WHM, cPanel, DirectAdmin, or other control panels installed. If you run `install.sh`  and it does not detect any supported control panels, it will automatically start `install.generic.sh` to begin the installation.

<br />

### install.cpanel.sh
<!-- md:requires `/usr/local/cpanel/version` -->

The `install.cpanel.sh` script is ran in order to integrate CSF with an existing cPanel/WHM installation. This file triggers if you run `install.sh`, which checks to see if your server has the file `/usr/local/cpanel/version`. 

<br />

### install.cwp.sh
<!-- md:requires `/usr/local/cwpsrv` -->

The `install.cwp.sh` script is ran in order to integrate CSF with an existing copy of [CentOS Web Panel (CWP)](https://centos-webpanel.com/). This file triggers when you run `install.sh`, which checks to see if your server has the file `/usr/local/cwpsrv`.

<br />

### install.cyberpanel.sh
<!-- md:requires `/usr/local/CyberCP` -->

The `install.cyberpanel.sh` script is ran in order to integrate CSF with an existing copy of [Cyber Panel](https://cyberpanel.net/). This file triggers when you run `install.sh`, which checks to see if your server has the file `/usr/local/CyberCP`.

<br />

### install.directadmin.sh
<!-- md:requires `/usr/local/directadmin/directadmin` -->

The `install.directadmin.sh` script is ran in order to integrate CSF with an existing copy of [DirectAdmin](https://directadmin.com/). This file triggers when you run `install.sh`, which checks to see if your server has the file `/usr/local/directadmin/directadmin`.

<br />

### install.interworx.sh
<!-- md:requires `/usr/local/interworx` -->

The `install.interworx.sh` script is ran in order to integrate CSF with an existing copy of [Interworx](https://interworx.com/). This file triggers when you run `install.sh`, which checks to see if your server has the file `/usr/local/interworx`.

<br />

### install.vesta.sh
<!-- md:requires `/usr/local/vesta` -->

The `install.vesta.sh` script is ran in order to integrate CSF with an existing copy of [VestaCP](https://vestacp.com/). This file triggers when you run `install.sh`, which checks to see if your server has the file `/usr/local/vesta`.

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
