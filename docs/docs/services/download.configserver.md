---
title: Advanced › Services › download.configserver.dev
tags:
  - services
  - download.configserver.dev
---

# download.configserver.dev <!-- omit from toc -->

The subdomain [download.configserver.dev](https://download.configserver.dev) provides a convenient way to download the latest version of CSF without needing to look up the name of the current release. Downloads can be accessed directly through your web browser, or from the command line using tools such as `wget` or `curl`. Below, we outline the basic usage to help you quickly obtain the latest version of CSF.

This mirrors the service originally offered by the CSF developers, which was the standard method of obtaining fresh copies of CSF for many years. Our version works the same way, with a few additional features that are described in the [Advanced](#advanced-options) section.

??? note "`.zip` vs `.tgz` format"

    Our documentation frequently mentions both `.zip` and `.tgz` releases of CSF. 

    When we initially developed addons for CSF, we pushed all of our releases in a `.zip` archive. 
    
    However, after taking over full development of CSF, we opted to migrate back to the `.tgz` format to keep conformity with how the original developer packaged releases. This is why our scripts mention both extensions, and why CSF supports both.

<br />

## Usage  <!-- omit from toc -->

This section explains how to utilize the CSF download service.

<br />
<br />

<div align="center" class="icon-container" markdown>

  [:aetherx-axb-chrome:](https://google.com/chrome/){ .icon-size-48 .icon-dim target="_blank" }
  [:aetherx-axb-brave:](https://brave.com/download){ .icon-size-48 .icon-dim target="_blank" }
  [:aetherx-axb-firefox-browser:](https://mozilla.org/firefox/download/){ .icon-size-48 .icon-dim target="_blank" }
  [:aetherx-axb-opera:](https://opera.com/download){ .icon-size-48 .icon-dim target="_blank" }
  [:aetherx-axb-edge:](https://microsoft.com/edge){ .icon-size-48 .icon-dim target="_blank" }

</div>

### Using Browser  <!-- omit from toc -->

The simplest way to use this service is via your browser. Visit [https://download.configserver.dev](https://download.configserver.dev) to download the latest CSF as a `.zip` or `.tgz`, depending on the release.

By default, all downloads are named `csf.ext`, making them easy to use in scripts without worrying about the version number.  

If you do need the exact version of the release you downloaded:

- Open the downloaded archive and check the `version.txt` file, OR;
- Append `?name=preserve` to the URL, for example: [https://download.configserver.dev?name=preserve](https://download.configserver.dev?name=preserve), OR;
- Query our api, and get a json response which contains the latest version number by using `https://download.configserver.dev/?output=json`

<br />
<br />

<div align="center" markdown>

:aetherx-axs-square-terminal:{ .icon-size-48 .icon-dim } 

</div>

### Using CLI  <!-- omit from toc -->

You can use command-line tools like `wget` or `curl` to fetch the latest CSF release. For the simplest download method, see [With Filename](#with-filename).

- [With Filename](#with-filename)
- [Without Filename](#without-filename)

<br />

#### With Filename

When downloading CSF from the CLI, you can append `csf.zip` or `csf.tgz` to the URL. This works just like the original download servers.

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

You can also use `wget` or `curl` without adding a filename. In this mode, the server automatically selects `.zip` or `.tgz`, but your commands must support `content-disposition`. See the note below for details.

??? note "Get latest version from CLI without filename"

    If you want to use curl or wget to download the latest version of CSF, but **not** place the filename on the end of the url; please read these notes.

    When using `wget` or `curl` with our download service without explicitly including a filename (for example, https://download.configserver.dev/ instead of https://download.configserver.dev/csf.zip), the server decides which file to serve from the latest release. To help users, it automatically provides the correct archive (.zip or .tgz) and sends a `Content-Disposition` header with the proper filename.

    By default, `wget` will ignore this header unless you pass `--content-disposition`. Without it, the file is saved under a generic name like `index.html`, even though the correct archive was downloaded. 

    Similarly, `curl` requires the flags `-JLO`:

    * `-J` tells curl to respect the server’s Content-Disposition header.
    * `-L` follows redirects until it reaches the actual file.
    * `-O` writes the file using the server-provided name instead of dumping it to stdout.

    If you don’t use these options, the tools won’t know the intended filename and will either mislabel the file or refuse to save it. This is why **wget** `--content-disposition` and **curl** `-JLO` are the recommended ways to pull the latest CSF package without specifying the filename directly.

<br />

=== ":aetherx-axs-box: wget"

    ``` shell
    wget --content-disposition https://download.configserver.dev/
    ```

=== ":aetherx-axs-box: curl"

    ``` shell
    curl -JLO https://download.configserver.dev/
    ```

<br />

---

<br />

## Advanced Options

Our download service includes a few advanced features that may interest certain users.

<br />

### Download API

Our API provides a structured JSON response, which can be used in your own scripts to retrieve information about the latest release. Below are some examples of how to use this feature. 

<br />

#### Fetch JSON Response

To request a JSON response from our API, append `?output=json` to the end of your URL, for example:

- https://download.configserver.dev/?output=json

<br />

#### Fetch Latest Release File

You can use our API to download the latest CSF release directly. This command retrieves the download URL and filename from the JSON response, and then downloads the file with the correct name.

1. Gets the latest CSF release info from the API in JSON.
2. Extracts the download URL and filename.
3. Downloads the file using the URL and saves it as the correct filename.

=== ":aetherx-axs-box: curl"

    ``` shell
    curl -s "https://download.configserver.dev/?output=json" \
      | jq -r '.download_url + " " + .file_name' \
      | xargs -n2 sh -c 'curl -L -o "$1" "$0"'
    ```

=== ":aetherx-axs-box: wget + curl"

    ``` shell
    eval $(curl -s "https://download.configserver.dev/?output=json" | \
      jq -r '"wget -O \(.file_name) \(.download_url)"') 
    ```

<br />

#### Retrieve Only the Download URL

If you just need the direct URL for the latest release, you can pull it from the JSON response. This will output the URL as a plain string, without downloading the file.

1. Gets the latest CSF release info from the API in JSON.
2. Extracts the download URL and returns the string in terminal.

=== ":aetherx-axd-command: Command"

      ```shell
      curl -s "https://download.configserver.dev/?output=json" | jq -r '.download_url'
      ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      https://github.com/Aetherinox/csf-firewall/releases/download/15.00/csf-firewall-v15.00.zip
      ```

<br />
<br />
<br />

### Preserve Filename

By default, the download service fetches the latest CSF release and renames it to `csf.zip` or `csf.tgz`.  If you prefer, you can keep the original release name, such as `csf-firewall-vXX.XX.zip` or `csf-firewall-vXX.XX.tar` by appending `?name=preserve` to your url, such as:

- https://download.configserver.dev/?name=preserve

<br />
<br />