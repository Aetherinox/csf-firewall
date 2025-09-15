---
title: Download & Install
tags:
  - install
  - setup
---

# Download & Install <!-- omit from toc -->

In the previous section, we explained how to install all the required dependencies for CSF. Now, we’ll guide you through downloading the latest version of ConfigServer Firewall & Security, and installing it to your server. CSF offers several ways to obtain the most recent release, which we’ll outline below.

<br />
<br />


## Installer Scripts

Before we download CSF, we'll explain the different installer scripts that you can access once you download and extract CSF to your server. We have provided a list of the files below, and what platform they are for:

| File | Requires | Platform |
| --- | --- | --- |
| `install.sh` | | Generic installer script, detects what platform you are running on and re-reroutes your installation request to the correct installer file listed below |
| `install.generic.sh` | | Baremetal / Generic installer |
| `install.cpanel.sh` | `/usr/local/cpanel/version` | cPanel / WHM |
| `install.cwp.sh` | `/usr/local/cwpsrv` | CentOS Web Panel (CWP) |
| `install.cyberpanel.sh` | `/usr/local/CyberCP` | CyberPanel |
| `install.directadmin.sh` | `/usr/local/directadmin/directadmin` | DirectAdmin |
| `install.interworx.sh` | `/usr/local/interworx` | Interworx |
| `install.vesta.sh` | `/usr/local/vesta` | VestaCP |

<br />

### install.sh

The `install.sh` script serves as a launcher that directs you to the appropriate installation script for your platform. It can be run on any system, automatically detects your environment, and executes the correct installer from the options listed above. Before running it, make sure the script is executable by running chmod +x install.sh. We’ll cover this in the steps below.

<br />

### install.generic.sh

This is the generic bare-metal installer for CSF. You should use this script when installing CSF on a server that does not have WHM, cPanel, DirectAdmin, or other control panels installed. If you run `install.sh`  and it does not detect any supported control panels, it will automatically start `install.generic.sh` to begin the installation.

<br />

### install.cpanel.sh
<!-- md:requires `/usr/local/cpanel/version` -->

The `install.cpanel.sh` script is ran in order to integrate CSF with an existing cPanel/WHM installation. This file triggers if you run `install.sh` and it detects that you have the file `/usr/local/cpanel/version` on your server. 

<br />

### install.cwp.sh
<!-- md:requires `/usr/local/cwpsrv` -->

The `install.cwp.sh` script is ran in order to integrate CSF with an existing copy of [CentOS Web Panel (CWP)](https://centos-webpanel.com/). This file triggers when you run `install.sh` and it detects that you have the file `/usr/local/cwpsrv` on your server.

<br />

### install.cyberpanel.sh
<!-- md:requires `/usr/local/CyberCP` -->

The `install.cyberpanel.sh` script is ran in order to integrate CSF with an existing copy of [Cyber Panel](https://cyberpanel.net/). This file triggers when you run `install.sh` and it detects that you have the file `/usr/local/CyberCP` on your server.

<br />

### install.directadmin.sh
<!-- md:requires `/usr/local/directadmin/directadmin` -->

The `install.directadmin.sh` script is ran in order to integrate CSF with an existing copy of [DirectAdmin](https://directadmin.com/). This file triggers when you run `install.sh` and it detects that you have the file `/usr/local/directadmin/directadmin` on your server.

<br />

### install.interworx.sh
<!-- md:requires `/usr/local/interworx` -->

The `install.interworx.sh` script is ran in order to integrate CSF with an existing copy of [Interworx](https://interworx.com/). This file triggers when you run `install.sh` and it detects that you have the file `/usr/local/interworx` on your server.

<br />

### install.vesta.sh
<!-- md:requires `/usr/local/vesta` -->

The `install.vesta.sh` script is ran in order to integrate CSF with an existing copy of [VestaCP](https://vestacp.com/). This file triggers when you run `install.sh` and it detects that you have the file `/usr/local/vesta` on your server.

<br />

---

<br />

## Standard / General

These instructions are intended for users who do not have server management software such as cPanel, WHM, or DirectAdmin. In this case, you will need to manually download the CSF files to your server and perform the installation yourself.

??? note "Finding the Latest Version"

    You can find out what the latest version of CSF is by visiting our [Github Releases](https://github.com/Aetherinox/csf-firewall/releases) page. 

<br />
<br />

Download the latest version of CSF. You can either download a specific version, or download the repositories' current version.

=== "Download Specific Version"

    ```shell
    wget -O /tmp/csf-firewall-latest.zip \
      https://github.com/Aetherinox/csf-firewall/releases/download/15.00/csf-firewall-v15.00.zip
    ```

=== "Download Latest Version"

    ```shell
    wget -O /tmp/csf-firewall-latest.zip "$(
      curl -s https://api.github.com/repos/Aetherinox/csf-firewall/releases/latest \
        | grep 'browser_download_url.*csf-firewall-v[0-9]\+\.[0-9]\+\.zip"' \
        | grep -v 'helpers' \
        | cut -d '"' -f 4
    )"
    ```

<br />

Next, we need to extract the `.zip` to a folder on our server. We are egoing to unzip the CSF zip to `/tmp/csf`:

```shell
unzip /tmp/csf-firewall-latest.zip \
  -d /tmp/csf
```

<br />

After you extract the `.zip`, change to the folder:

```shell
cd /tmp/csf
```

<br />

You now need to set the `install.sh` script to have `+x` executable permissions by running the command:

```shell
sudo chmod +x install.sh
```

<br />

You may get warnings that certain packages are not installed; which is fine as long as you don't see `FATAL` errors. CSF has additional features that you can install later with dependencies that are not required to get up and running.

<br />

Finally, run the install script:

```shell
sh install.sh
```

<br />

Follow any on-screen instructions and ConfigServer Firewall will install.


<br />
<br />


## cPanel & WHM

If you are hosting a server with your own managed license for cPanel & WHM, this means that you will need to manually install ConfigServer Firewall onto your server to utilize it. First, log in to your server as the root user via SSH.

You will need to download the latest version of CSF. You can either download a specific version, or download the repositories' current version.

=== "Download Specific Version"

    ```shell
    wget -O ./csf-firewall-latest.zip \
      https://github.com/Aetherinox/csf-firewall/releases/download/15.00/csf-firewall-v15.00.zip
    ```

=== "Download Latest Version"

    ```shell
    wget -O ./csf-firewall-latest.zip "$(
      curl -s https://api.github.com/repos/Aetherinox/csf-firewall/releases/latest \
        | grep 'browser_download_url.*csf-firewall-v[0-9]\+\.[0-9]\+\.zip"' \
        | grep -v 'helpers' \
        | cut -d '"' -f 4
    )"
    ```

<br />

Unzip / decompress the downloaded file to your server. We have provided instructions for extracting both the newer `.zip` format, and the older `tar .tgz` format:

=== ".zip"

    ```bash
    unzip csf-firewall-latest.zip
    ```

=== ".tgz"

    ```bash
    tar -xzf csf-firewall-latest.tgz
    ```


<br />

Change over to the folder you just extracted:

```shell
cd csf-firewall-latest
```

<br />

Make sure the setup file has the proper permissions by setting it to be `+x` executable:

```shell
sudo chmod +x install.cpanel.sh
```

<br />

Finally, run the installation script:

=== "Option 1"

    ```bash
    ./install.cpanel.sh
    ```

=== "Option 2"

    ```bash
    sh install.cpanel.sh
    ```

<br />

To access CSF, use WHM’s **ConfigServer Security & Firewall interface**

  - WHM » Home » Plugins » `ConfigServer Security & Firewall`

<br />

A more detailed explanation of how to configure CSF will be explained elsewhere in this guide.

<br />

---

<br />

## Next Steps <!-- omit from toc -->



{==

Select what documentation you would like to proceed with next ...

==}

<div class="grid cards" markdown>

-   :material-file: &nbsp; __[Run Diagnostic Tests](tests.md)__

    ---

    Select this option to see documentation on how
    to run diagnostic tests for your install of CSF. 
    
    Tests will confirm whether or not CSF is running
    properly on your server.

-   :material-file: &nbsp; __[Enable Web Interface](webui.md)__

    ---

    Enable and access the CSF web interface via your 
    browser.

    This is an optional step and is not required in
    order to use CSF.

</div>

<br />

<br />
