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

Download the latest version of CSF. You can either download a specific version, or download the repositories' current version.

??? note "Finding the Latest Version"

    You can find out what the latest version of CSF is by visiting our [Github Releases](https://github.com/Aetherinox/csf-firewall/releases) page. 

=== ":aetherx-axs-box: Download Specific Version"

    ```shell
    wget -O /tmp/csf-firewall-latest.zip \
      https://github.com/Aetherinox/csf-firewall/releases/download/15.00/csf-firewall-v15.00.zip
    ```

=== ":aetherx-axs-box-arrow-down-magnifying-glass: Download Latest Version"

    ```shell
    wget -O /tmp/csf-firewall-latest.zip "$(
      curl -s https://api.github.com/repos/Aetherinox/csf-firewall/releases/latest \
        | grep 'browser_download_url.*csf-firewall-v[0-9]\+\.[0-9]\+\.zip"' \
        | grep -v 'helpers' \
        | cut -d '"' -f 4
    )"
    ```

<br />

Next, we need to extract the `.zip` to a folder on our server. We are going to unzip the CSF zip to `/tmp/csf`:

=== ":aetherx-axs-file-zip: .zip"

    ```bash
    unzip /tmp/csf-firewall-latest.zip \
      -d /tmp/csf
    ```

=== ":aetherx-axs-file-zipper: .tgz"

    ```bash
    tar -xzf /tmp/csf-firewall-latest.tgz \
      -C /tmp/csf
    ```

<br />

After you extract the `.zip`, you can now change over to the folder where the extracted CSF files are located:

```shell
cd /tmp/csf
```

<br />

Set the `install.sh` script to have `+x` executable permissions by running the command:

```shell
sudo chmod +x /tmp/csf/install.sh
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

You will need to download the latest version of CSF. You can either download a specific version, or download the repositories' current version.

=== ":aetherx-axs-box: Download Specific Version"

    ```shell
    wget -O /root/csf-firewall-latest.zip \
      https://github.com/Aetherinox/csf-firewall/releases/download/15.00/csf-firewall-v15.00.zip
    ```

=== ":aetherx-axs-box-arrow-down-magnifying-glass: Download Latest Version"

    ```shell
    wget -O /root/csf-firewall-latest.zip "$(
      curl -s https://api.github.com/repos/Aetherinox/csf-firewall/releases/latest \
        | grep 'browser_download_url.*csf-firewall-v[0-9]\+\.[0-9]\+\.zip"' \
        | grep -v 'helpers' \
        | cut -d '"' -f 4
    )"
    ```

<br />

Unzip / decompress the downloaded file to your server. We have provided instructions for extracting both the newer `.zip` format, and the older tar `.tgz` format:

=== ":aetherx-axs-file-zip: .zip"

    ```bash
    unzip /root/csf-firewall-latest.zip \
      -d /root/csf
    ```

=== ":aetherx-axs-file-zipper: .tgz"

    ```bash
    tar -xzf /root/csf-firewall-latest.tgz \
      -C /root/csf
    ```

<br />

After you extract the `.zip`, you can now change over to the folder where the extracted CSF files are located:

```shell
cd /root/csf
```

<br />

Set the `install.sh` script to have `+x` executable permissions by running the command:

```shell
sudo chmod +x /root/csf/install.sh
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
