---
title: Advanced › Services › download.configserver.dev
tags:
  - services
  - download.configserver.dev
---

# download.configserver.dev <!-- omit from toc -->

The subdomain [download.configserver.dev](https://download.configserver.dev) provides a convenient way to download the latest version of CSF without needing to look up the name of the current release. Downloads can be accessed directly through your web browser, or from the command line using tools such as `wget` or `curl`. Below, we outline the basic usage to help you quickly obtain the latest version of CSF.

This mirrors the service originally offered by the CSF developers, which was the standard method of obtaining fresh copies of CSF for many years. Our version works the same way, with a few additional features that are described in the [Usage](#usage) section.

<br />

## Usage  <!-- omit from toc -->

This section explains how to utilize the CSF download service.

<br />

### Using Browser  <!-- omit from toc -->

The simplest way to use this service is through your web browser. Just open Firefox, Chrome, or any browser of your choice and navigate to [https://download.configserver.dev](https://download.configserver.dev). Within a few seconds, the latest version of CSF will automatically download as either a `.zip` or `.tgz`, depending on the archive format provided by the developer.  

All downloads from this service are delivered with the filename `csf`, making it easy to integrate into your own scripts without needing to determine the latest version name. If you do need the exact version, you can open the downloaded archive and check the `version.txt` file inside.

<br />

### Using CLI  <!-- omit from toc -->

Our download service also supports the use of command-line tools such as `wget` and `curl`. Read both sections below, as we offer two ways to use curl and wget to obtain the latest version of CSF.

- [With Filename](#with-filename)
- [Without Filename](#without-filename)

<br />

If you want to download the latest version of CSF in the easiest manner, utilize the method [With Filename](#with-filename).

<br />

#### With Filename

If you add `csf.zip` or `csf.tgz` to the end of the url, it is pretty straight-forward when downloading the newest version of CSF. It functions the same way the original download servers did.

=== ":aetherx-axs-box: wget"

    ``` shell
    wget https://download.configserver.dev/csf.zip
    ```

=== ":aetherx-axs-box: curl"

    ``` shell
    curl -O https://download.configserver.dev/csf.zip
    ```

<br />

#### Without Filename

If you want to use curl or wget to download the latest version of CSF, but **not** place the filename on the end of the url; please read these notes.

When using `wget` or `curl` with our download service without explicitly including a filename (for example, https://download.configserver.dev/ instead of https://download.configserver.dev/csf.zip), the server decides which file to serve from the latest release. To help users, it automatically provides the correct archive (.zip or .tgz) and sends a `Content-Disposition` header with the proper filename.

By default, `wget` will ignore this header unless you pass `--content-disposition`. Without it, the file is saved under a generic name like `index.html`, even though the correct archive was downloaded. 

Similarly, `curl` requires the flags `-JLO`:

* `-J` tells curl to respect the server’s Content-Disposition header.
* `-L` follows redirects until it reaches the actual file.
* `-O` writes the file using the server-provided name instead of dumping it to stdout.

If you don’t use these options, the tools won’t know the intended filename and will either mislabel the file or refuse to save it. This is why **wget** `--content-disposition` and **curl** `-JLO` are the recommended ways to pull the latest CSF package without specifying the filename directly.

=== ":aetherx-axs-box: wget"

    ``` shell
    wget --content-disposition https://download.configserver.dev/
    ```

=== ":aetherx-axs-box: curl"

    ``` shell
    curl -JLO https://download.configserver.dev/
    ```

