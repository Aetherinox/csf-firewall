---
title: "Install › Download CSF"
tags:
  - install
  - setup
  - download
---

# Download CSF <!-- omit from toc -->

In the previous section, we explained how to install all the required dependencies for CSF. Now, we’ll guide you through downloading the latest version of ConfigServer Firewall & Security.

<br />

## Generic Environment

These instructions are primarily written for servers **without a control panel** (such as cPanel, DirectAdmin, etc.).  However, most users can still follow along since the installation process is largely the same across all environments.  

The main difference comes **after installation** — the way you access and manage CSF will vary depending on the control panel in use.

<br />
<br />

Download the latest version of CSF. Two methods are provided below, and you can pick either one. Most users will want to opt for the :aetherx-axs-box: `Direct Download`.

=== ":aetherx-axs-box: Direct Download"

    ```shell
    # Using wget
    wget https://download.configserver.dev/csf.zip

    # Using curl
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

Next, we need to extract the `.zip` to a folder on our server. We are going to unzip the CSF zip to `/tmp/csf`:

=== ":aetherx-axs-file-zip: .zip"

    ```bash
    unzip csf.zip -d /tmp/csf
    ```

=== ":aetherx-axs-file-zipper: .tgz"

    ```bash
    tar -xzf csf.tgz -C /tmp/csf
    ```


<br />

After you extract the `.zip` or `.tgz`, you can now change over to the folder where the extracted CSF files are located:

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

=== ":aetherx-axs-box: Direct Download"

    ```shell
    # Using wget
    wget https://download.configserver.dev/csf.zip

    # Using curl
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

Unzip / decompress the downloaded file to your server. We have provided instructions for extracting both the newer `.zip` format, and the older tar `.tgz` format:

=== ":aetherx-axs-file-zip: .zip"

    ```bash
    unzip csf.zip -d /root/csf
    ```

=== ":aetherx-axs-file-zipper: .tgz"

    ```bash
    tar -xzf csf.tgz -C /root/csf
    ```

<br />

After you extract the `.zip` or `.tgz`, you can now change over to the folder where the extracted CSF files are located:

```shell
cd /root/csf
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
