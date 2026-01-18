---
title: Advanced › Services › get.configserver.dev
tags:
  - services
  - get.sh
  - get.configserver.dev
---

# get.configserver.dev <!-- omit from toc -->

The subdomain [get.configserver.dev](https://get.configserver.dev) provides a simple online service for downloading the latest version of CSF using a Bash script.  

By default, running the script downloads the latest CSF release to the current directory. Optional arguments allow you to extend its functionality, including automatically extracting the archive and installing CSF immediately after download.

??? note "`.zip` vs `.tgz` format"

    Our documentation frequently mentions both `.zip` and `.tgz` releases of CSF. 

    When we initially developed addons for CSF, we pushed all of our releases in a `.zip` archive. 
    
    However, after taking over full development of CSF, we opted to migrate back to the `.tgz` format to keep conformity with how the original developer packaged releases. This is why our scripts mention both extensions, and why CSF supports both.

<br />

## Usage

This section explains how the [get.sh](https://get.configserver.dev) script can be utilized when obtaining the latest version of CSF from our servers.

### Examples

<div class="table-nowrap" markdown>

| Command                                                                                       | Description                                                                                           |
| --------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `bash <(wget -qO - https://get.configserver.dev)`                                             | Download CSF w/ filename `csf.zip` or `csf.tgz`                                                      |
| `bash <(wget -qO - https://get.configserver.dev) --preserve-name`                             | Download CSF w/ filename `csf-firewall-vXX.XX.zip` or `csf-firewall-vXX.XX.tgz`                      |
| `bash <(wget -qO - https://get.configserver.dev) --extract`                                   | Download CSF w/ filename `csf.zip` or `csf.tgz`, extract to `csf`                                    |
| `bash <(wget -qO - https://get.configserver.dev) --extract --folder csftest`                  | Download CSF w/ filename `csf.zip` or `csf.tgz`, extract to `csftest`                                |
| `bash <(wget -qO - https://get.configserver.dev) --install`                                   | Download CSF w/ filename `csf.zip` or `csf.tgz`, extract to `csf`, install CSF                       |
| `bash <(wget -qO - https://get.configserver.dev) --install --folder csftest`                  | Download CSF w/ filename `csf.zip` or `csf.tgz`, extract to `csftest`, install CSF                   |
| `bash <(wget -qO - https://get.configserver.dev) --install --dryrun`                          | Download CSF w/ filename `csf.zip` or `csf.tgz`, extract to `csf`, simulate install CSF              |
| `bash <(wget -qO - https://get.configserver.dev) --install --folder csftest --dryrun`         | Download CSF w/ filename `csf.zip` or `csf.tgz`, extract to `csftest`, simulate install CSF          |
| `bash <(wget -qO - https://get.configserver.dev) --install-only`                              | No download, install existing local folder `csf`                                               |
| `bash <(wget -qO - https://get.configserver.dev) --install-only --folder csftest`             | No download, install existing local folder `csftest`                                           |
| `bash <(wget -qO - https://get.configserver.dev) --install-only --dryrun`                     | No download, simulate install existing local folder `csf`                                      |
| `bash <(wget -qO - https://get.configserver.dev) --install-only --folder csftest --dryrun`    | No download, simulate install existing local folder `csftest`                                  |
| `bash <(wget -qO - https://get.configserver.dev) --clean`                                     | Delete existing `csf.zip` or `csf.tgz`, remove folder `csf`                            |
| `bash <(wget -qO - https://get.configserver.dev) --clean --folder csftest`                    | Delete existing `csf.zip` or `csf.tgz`, remove folder `csftest`                        |

</div>

<br />

### Standard

The command below will download the latest version of CSF and place the archive file on your machine in the folder where you ran the command. The archive file will either be `csf.zip` or `csf.tgz`, depending on which release is available.

=== ":aetherx-axs-box: wget"

    ``` shell
    bash <(wget -qO - https://get.configserver.dev)
    ```

=== ":aetherx-axs-box: curl"

    ``` shell
    bash <(curl -sL https://get.configserver.dev)
    ```

<br />
<br />

### Advanced

The [get.sh](https://get.configserver.dev) script has additional arguments that you can pass which expands on its functionality. 


<br />

#### Download Only

To download the latest version of CSF and do nothing else; pass no arguments.

=== ":aetherx-axs-box: wget"

    ``` shell
    bash <(wget -qO - https://get.configserver.dev)
    ```

=== ":aetherx-axs-box: curl"

    ``` shell
    bash <(curl -sL https://get.configserver.dev)
    ```

<br />
<br />
<br />

#### Download + Extract

Downloads the latest version of CSF to your local machine as the file `csf.zip` or `csf.tgz` and extracts to :aetherx-axd-folder: `csf`

=== ":aetherx-axs-box: wget"

    ``` shell
    bash <(wget -qO - https://get.configserver.dev) --extract
    ```

=== ":aetherx-axs-box: curl"

    ``` shell
    bash <(curl -sL https://get.configserver.dev)  --extract
    ```

<br />

Out of box, this script extracts CSF to the folder :aetherx-axd-folder: `csf`; you can change the default extraction folder with:

=== ":aetherx-axs-command: Command"

    ``` shell
    bash <(wget -qO - https://get.configserver.dev) --extract --folder csf-folder
    ```

<br />
<br />
<br />

#### Download + Extract + Install

Downloads the latest version of CSF to your local machine as the file `csf.zip` or `csf.tgz`, extracts to :aetherx-axd-folder: `csf`, and installs by running :aetherx-axd-file: `csf/install.sh`

=== ":aetherx-axs-box: wget"

    ``` shell
    bash <(wget -qO - https://get.configserver.dev) --install
    ```

=== ":aetherx-axs-box: curl"

    ``` shell
    bash <(curl -sL https://get.configserver.dev)  --install
    ```

<br />

Out of box, this script extracts CSF to the folder :aetherx-axd-folder: `csf`, and then installs by running the file :aetherx-axd-file: `csf/install.sh`. You can change the default folder with:

=== ":aetherx-axs-command: Command"

    ``` shell
    bash <(wget -qO - https://get.configserver.dev) --install --folder csf-folder
    ```

<br />
<br />
<br />

#### Download + Extract + Install (Dryrun)

Downloads the latest version of CSF to your local machine as the file `csf.zip` or `csf.tgz`, extracts to :aetherx-axd-folder: `csf`, and does a dry-run install without actually installing anything

=== ":aetherx-axs-box: wget"

    ``` shell
    bash <(wget -qO - https://get.configserver.dev) --install --dryrun
    ```

=== ":aetherx-axs-box: curl"

    ``` shell
    bash <(curl -sL https://get.configserver.dev)  --install --dryrun
    ```

<br />

Out of box, this script extracts CSF to the folder :aetherx-axd-folder: `csf`, and then installs by running the file :aetherx-axd-file: `csf/install.sh`. You can change the default folder with:

=== ":aetherx-axs-command: Command"

    ``` shell
    bash <(wget -qO - https://get.configserver.dev) --install --folder csf-folder --dryrun
    ```

<br />
<br />
<br />

#### Install Local Folder

Does not download or extract CSF. Installs an existing local copy of CSF contained within the folder :aetherx-axd-folder: `csf`. This will error if you attempt to pass this argument and the file :aetherx-axd-file: `csf/install.sh` does not exist.

=== ":aetherx-axs-box: wget"

    ``` shell
    bash <(wget -qO - https://get.configserver.dev) --install-only
    ```

=== ":aetherx-axs-box: curl"

    ``` shell
    bash <(curl -sL https://get.configserver.dev)  --install-only
    ```

<br />

Out of box, this script looks for the install file :aetherx-axd-file: `csf/install.sh`; you can change the folder with the command below. You must have the file :aetherx-axd-file: `csf-folder/install.sh`:

=== ":aetherx-axs-command: Command"

    ``` shell
    bash <(wget -qO - https://get.configserver.dev) --install-only --folder csf-folder
    ```

<br />
<br />
<br />

#### Install Local Folder (Dryrun)

Does a dry-run installs on an existing local copy of CSF contained within the folder :aetherx-axd-folder: `csf`, but does not actually install CSF. This will error if you attempt to pass this argument and the file :aetherx-axd-file: `csf/install.sh` does not exist.

=== ":aetherx-axs-box: wget"

    ``` shell
    bash <(wget -qO - https://get.configserver.dev) --install-only --dryrun
    ```

=== ":aetherx-axs-box: curl"

    ``` shell
    bash <(curl -sL https://get.configserver.dev)  --install-only --dryrun
    ```

<br />

Out of box, this script looks for the install file :aetherx-axd-file: `csf/install.sh`; you can change the folder with the command below. You must have the path :aetherx-axd-file: `csf-folder/install.sh`:

=== ":aetherx-axs-command: Command"

    ``` shell
    bash <(wget -qO - https://get.configserver.dev) --install-only --folder csf-folder --dryrun
    ```

<br />
<br />
<br />

#### Clean

Removes any existing `.zip` and `.tgz` files, removes local :aetherx-axd-folder: `csf` folders.

=== ":aetherx-axs-box: wget"

    ``` shell
    bash <(wget -qO - https://get.configserver.dev) --clean
    ```

=== ":aetherx-axs-box: curl"

    ``` shell
    bash <(curl -sL https://get.configserver.dev)  --clean
    ```

<br />
<br />
<br />

#### Preserve Preserve Filename

Out of box, the get.sh script finds the latest version of CSF. When it downloads the archive `.zip` or `.tgz` to your machine, it automatically re-names the archive file :aetherx-axd-file: `csf.xxx`. 

You can skip the re-name to :aetherx-axd-file: `csf.zip/tgz` and preseve the original release's archive name, which is typically `csf-firewall-vXX.XX.zip` or `csf-firewall-vXX.XX.tgz`.

=== ":aetherx-axs-box: wget"

    ``` shell
    bash <(wget -qO - https://get.configserver.dev) --preserve-name
    ```

=== ":aetherx-axs-box: curl"

    ``` shell
    bash <(curl -sL https://get.configserver.dev)  --preserve-name
    ```

<br />

We have provided examples of what each command does:

=== ":aetherx-axs-toggle-off: Without Parameter"

    Running this command will download the latest CSF release, and name the archive file `csf.zip` or `csf.tgz`.

    ``` shell
    bash <(wget -qO - https://get.configserver.dev)
    ```

=== ":aetherx-axs-toggle-on: With Parameter"

    Running this command will download the latest CSF release, and name the archive file `csf-firewall-vXX.XX.zip` or `csf-firewall-vXX.XX.tgz`.

    ``` shell
    bash <(wget -qO - https://get.configserver.dev)  --preserve-name
    ```

<br />

---

<br />

## Arguments

The [get.sh](https://get.configserver.dev) script includes numerous arguments that can be passed to expand the functionality. The available arguments are listed below.

<br />

### Extract
<!-- md:version stable-15.09 --> <!-- md:fileDLExt https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/get.sh -->  <!-- md:source get.sh --> <!-- md:command `-e,  --extract` --> 

Downloads the latest version of CSF, saves it to your machine as `csf.zip` or `csf.tgz`, extracts it to a local folder.

<br />
<br />

### Install
<!-- md:version stable-15.09 --> <!-- md:fileDLExt https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/get.sh -->  <!-- md:source get.sh --> <!-- md:command `-i,  --install` --> 

Downloads the latest version of CSF, saves it to your machine as `csf.zip` or `csf.tgz`, extracts it to a local folder., and then run the CSF `install.sh` installation wizard.

<br />
<br />

### Install Only
<!-- md:version stable-15.09 --> <!-- md:fileDLExt https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/get.sh -->  <!-- md:source get.sh --> <!-- md:command `-I,  --install-only` --> 

Requires an existing local extracted version of CSF which resides in a folder (defaults to :aetherx-axd-folder: `csf`). Default folder can be changed with `-f`, `--folder`

<br />
<br />

### Folder
<!-- md:version stable-15.09 --> <!-- md:fileDLExt https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/get.sh -->  <!-- md:source get.sh --> <!-- md:command `-f,  --folder` --> 

Allows you to override the default extraction and installation folder :aetherx-axd-folder: `csf`. Can be used in combination with:

- [Install](#install)
- [Install Only](#install-only)

<br />
<br />

### Preserve Original Filename
<!-- md:version stable-15.09 --> <!-- md:fileDLExt https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/get.sh -->  <!-- md:source get.sh --> <!-- md:command `-p,  --preserve-name` --> 

When downloading the latest version of CSF, the script automatically re-names the latest release archive file from `csf-firewall-vXX.XX.zip` to `csf.zip`. Passing this parameter skips the re-name, and downloads the file to your system as `csf-firewall-vXX.XX.zip`.

<br />
<br />

### Dryrun
<!-- md:version stable-15.09 --> <!-- md:fileDLExt https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/get.sh -->  <!-- md:source get.sh --> <!-- md:command `-D,  --dryrun` --> 

When `--install` or `--install-only` are passed, this arguments simulations installation, but does not actually install CSF to your system.

<br />
<br />

### Clean
<!-- md:version stable-15.09 --> <!-- md:fileDLExt https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/get.sh -->  <!-- md:source get.sh --> <!-- md:command `-c,  --clean` --> 

Removes any `csf.zip` or `csf.tgz` files lintering within the folder. Also removes any extracted csf files and folders.

<br />
<br />

### Help
<!-- md:version stable-15.09 --> <!-- md:fileDLExt https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/get.sh -->  <!-- md:source get.sh --> <!-- md:command `-h,  --help` --> 

Shows the help menu for the [get.sh](https://get.configserver.dev) script. Performs no other actions.

<br />
<br />

### Version
<!-- md:version stable-15.09 --> <!-- md:fileDLExt https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/get.sh -->  <!-- md:source get.sh --> <!-- md:command `-v,  --version` --> 

Shows the current version of the [get.sh](https://get.configserver.dev) script being used.

<br />

---

<br />

## Source Code

The source code for [get.configserver.dev](https://get.configserver.dev) can be found within the official CSF repository below:

<div class="grid cards" markdown>

-   :aetherx-axs-download: &nbsp; __[Get.sh Source Code](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/get.sh)__

</div>

``` bash title="get.sh"
--8<-- "https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/get.sh"
```

<br />
<br />
