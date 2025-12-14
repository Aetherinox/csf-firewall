---
title: "Install › Download CSF"
tags:
  - install
  - setup
  - download
---

# Download CSF <!-- omit from toc -->

In the previous section, we explained how to install all the required dependencies for CSF. Now, we’ll guide you through downloading the latest version of ConfigServer Security & Firewall.

<br />

## :aetherx-axj-bell:{ .icon-tldr } Summary

This page covers the following:

- Step-by-step instructions for installing CSF on a bare-metal or generic server without a control panel.
- Guidance for downloading and extracting CSF for cPanel & WHM environments.
- Instructions on this page cover both the `tgz` and `zip` archive, see the note below:

??? note "`.zip` vs `.tgz` format"

    Our documentation frequently mentions both `.zip` and `.tgz` releases of CSF. 

    When we initially developed addons for CSF, we pushed all of our releases in a `.zip` archive. 
    
    However, after taking over full development of CSF, we opted to migrate back to the `.tgz` format to keep conformity with how the original developer packaged releases. This is why our scripts mention both extensions, and why our scripts look for both.

<br />

## Generic Environment

These instructions are primarily written for servers **without a control panel** (such as cPanel, DirectAdmin, etc.).  However, most users can still follow along since the installation process is largely the same across all environments.  

The main difference comes **after installation** — the way you access and manage CSF will vary depending on the control panel in use.

<br />
<br />

Download the latest version of CSF. Two methods are provided below, and you can pick either one. Most users will want to opt for the :aetherx-axs-box: `Direct Download`.

=== ":aetherx-axs-file-zipper: Direct Download (tgz)"

    ```shell
    # Using wget (tgz)
    wget https://download.configserver.dev/csf.tgz

    # Using curl (tgz)
    curl -O https://download.configserver.dev/csf.tgz
    ```

=== ":aetherx-axs-file-zip: Direct Download (zip)"

    ```shell
    # Using wget (zip)
    wget https://download.configserver.dev/csf.zip

    # Using curl (zip)
    curl -O https://download.configserver.dev/csf.zip
    ```

=== ":aetherx-axs-box: Get.sh"

    ```shell
    # Using wget
    bash <(wget -qO - https://get.configserver.dev)

    # Using curl
    bash <(curl -sL https://get.configserver.dev)
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

After you extract the archive, you can now change over to the folder where the extracted CSF files are located:

```shell
cd /tmp/csf
```

<br />

At this point, we have CSF downloaded to your system and ready to install. However, we are going to first run [Diagnostic Tests](./tests.md) to ensure that our system is ready to handle CSF and has all required dependencies.

<br />

{==

Select what documentation you would like to proceed with next ...

==}

<div class="grid cards" markdown>

-   :material-file: &nbsp; __[Run Diagnostic Tests](tests.md)__

    ---

    Up next, we will explain how to run some diagnostic tests on your server before installing CSF.  These tests ensure that your server meets all requirements regarding perl [dependencies](./dependencies.md).  

    Running these checks will confirm whether CSF can function properly on your server.

</div>

<br />
<br />

## cPanel & WHM

If you have a server which you do not personally manage or do not have root access for, you will need to sign into WHM and see if your server provider has already pre-installed a copy of CSF which you can use. Without root access to the server, you will be unable to install CSF. Contact your hosting provider for additional information.

However, if you manage your own server with root shell access, and have a valid cPanel & WHM license, this means that you can manually install ConfigServer Firewall onto your server to utilize it.

<br />

First, log in to your server as the `root` user via SSH.

=== ":aetherx-axs-key: Using Password"

    ```shell
    ssh -vvv root@XX.XX.XX.XX -p 22
    ```

=== ":aetherx-axs-file: Using Private Key"

    ```shell
    ssh -i /path/to/private_key -vvv root@XX.XX.XX.XX -p 22
    ```

<br />

Download the latest version of CSF. Two methods are provided below, and you can pick either one. Most users will want to opt for the :aetherx-axs-box: `Direct Download`.

=== ":aetherx-axs-file-zipper: Direct Download (tgz)"

    ```shell
    # Using wget (tgz)
    wget https://download.configserver.dev/csf.tgz

    # Using curl (tgz)
    curl -O https://download.configserver.dev/csf.tgz
    ```

=== ":aetherx-axs-file-zip: Direct Download (zip)"

    ```shell
    # Using wget (zip)
    wget https://download.configserver.dev/csf.zip

    # Using curl (zip)
    curl -O https://download.configserver.dev/csf.zip
    ```

=== ":aetherx-axs-box: Get.sh"

    ```shell
    # Using wget
    bash <(wget -qO - https://get.configserver.dev)

    # Using curl
    bash <(curl -sL https://get.configserver.dev)
    ```

<br />

Decompress / unzip the downloaded archive file:

=== ":aetherx-axs-file-zipper: .tgz"

    ```bash
    tar -xzf csf.tgz -C /usr/src/
    ```

=== ":aetherx-axs-file-zip: .zip"

    ```bash
    unzip csf.zip -d /usr/src/
    ```

<br />

After you extract the archive, you can now change over to the folder where the extracted CSF files are located:

```shell
cd /usr/src/csf
```

<br />

At this point, we have CSF downloaded to your system and ready to install. However, we are going to first run [Diagnostic Tests](./tests.md) to ensure that our system is ready to handle CSF and has all required dependencies.

<br />

---

<br />

## Next Steps <!-- omit from toc -->

{==

Select what documentation you would like to proceed with next ...

==}

<div class="grid cards" markdown>

-   :aetherx-axs-stethoscope: &nbsp; __[Run Diagnostic Tests](tests.md)__

    ---

    Up next, we will explain how to run some diagnostic tests on your server before installing CSF.  These tests ensure that your server meets all requirements regarding perl [dependencies](./dependencies.md).  

    Running these checks will confirm whether CSF can function properly on your server.

</div>

<br />

<br />
