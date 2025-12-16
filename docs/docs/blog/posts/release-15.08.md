---
date: 2025-12-11
authors:
    - aetherinox
categories:
    - release
    - changelog
    - v15.x
    - cyberpanel
description: >
    Details regarding CSF release v15.08
title: >
    Release v15.08
comments: true
---

# Release: v15.08

Our **v15.08** update delivers a cleaner, more reliable experience with a strong focus on bug fixes, third-party integration improvements, optimizations, and clearer user feedback during both installation and day-to-day operation.

This release includes significant fixes for **CyberPanel** and **Control Web Panel**, along with automatic Webmin module installation. This means that Webmin users no longer need to manually import the CSF module. It is now handled automatically as part of the installation process.

<!-- more -->

<br />

---

<br />

## Changelog

A list of the most important changes are listed below.

<br />

### Webmin Automated Installation

Prior to **CSF v15.08**, Webmin users were required to manually import the file  
`/usr/local/csf/csfwebmin.tgz` to enable the CSF Webmin module. Although the process was rather simple, it introduced an additional manual step during installation.

As of **CSF v15.08**, this step has been fully automated for both new installations and version upgrades. The Webmin module is now imported automatically, without the need for manual installation. Simply run the CSF `install.sh` script, and Webmin integration is handled automatically.

<br />
<br />

### New CSGet Module

This update includes an entirely re-written CSGet perl module.

The [CSGet](../../advanced/csget/index.md) module is a core component of the CSF update system used by the CSF web interface. Its primary role is to keep every installation of ConfigServer Security and Firewall informed of new releases. CSGet runs quietly in the background, requiring no user interaction while monitoring for updates.

When CSF is installed for the first time, the `csget.pl` file will automatically be installed to your system. The script will initially be ran once to confirm that you are using the latest version. After that initial run, your system's cron service will take over the task of running CSGet multiple times a day in order to notify you of updates.

Along with its base functionality, we have now included the ability to trigger the script manually, with optional flags which can be specified from your terminal. For basic use, you can run CSGet as a foreground process which executes once and then exits the process. A manual execution can be accomplished with one of the commands below _(both bash and perl command variants available)_:

=== ":aetherx-axb-bash: Bash"

    ``` shell
    sudo /etc/cron.daily/csget --nodaemon
    ```

=== ":aetherx-axb-perl: Perl"

    ``` shell
    sudo perl /etc/cron.daily/csget --nodaemon
    ```

<br />

CSGet now includes numerous flags which are outlined below:

| Flag                                          | Description                                                                 |
| --------------------------------------------- | --------------------------------------------------------------------------- |
| <!-- md:command 110 `-d,  --debug` -->        | CSGet script runs immediately once and exits, no forked background process / daemonization.   |
| <!-- md:command 110 `-r,  --response` -->     | Runs CSGet in the foreground once and then exits with a numerical response.<br/>Returns `0` on Success <br /> Returns `1` on Failures                               |
| <!-- md:command 110 `-k,  --kill` -->         | Kills all running processes of CSGet.                                 |
| <!-- md:command 110 `-l,  --list` -->         | Lists all running processes of CSGet.                                 |
| <!-- md:command 110 `-d,  --diag` -->         | Show diagnostic information.                                          |
| <!-- md:command 110 `-D,  --debug` -->        | Show verbose logs and additional details; disables forked child process daemonization.  |
| <!-- md:command 110 `-v,  --version` -->      | Show version information about CSGet and CSF.                         |
| <!-- md:command 110 `-h,  --help` -->         | Show help menu, list of commands, and usage examples.                 |

<br />

{==

Our documentation has been updated to explain CSGet in detail, as well as provide examples on how to utilize it, and the list of available flags. 
[You can read more about CSGet here](../../advanced/csget/index.md)

==}

<br />
<br />

### Detailed Installation Wizard

Historically, one of the biggest challenges with ConfigServer was the installation process. If an installation failed, many users struggled to identify exactly where things went wrong.

The installation workflow has been fully segmented, with nearly every major step being monitored. Each stage now provides clear status reporting, indicating whether it **passed** or **failed**.

This improvement makes it significantly easier to diagnose issues as they occur and provides users with clearer insight into any problems that may arise during installation.

There are additional changes coming in the future, but this current phase of the revamp will dramatically help with any potential issues.

<br />
<br />

### Control Web Panel Links

This update fixes a bug in Control Web Panel where the ConfigServer Firewall navigation menu would display a blank page instead of redirecting users to the appropriate CSF configuration page.

Previously, the second navigation link _(stock CSF interface)_ would trigger an error. It now correctly redirects users to the URL:

- https://127.0.0.1:2031/admin/index.php?module=csfofficial

<br />

The Control Web Panel allows you to access CSF through two different navigation links. The main difference between them is that one uses a custom theme developed by the Control Web Panel team _(link 1)_, while the second link displays the stock CSF theme _(link 2)_.

1. **CWP Menu** › **Security** › **CSF Firewall**
      - Provided by Control Web Panel. Custom colors and stylesheet
      - https://127.0.0.1:2031/admin/index.php?module=csf
2. **CWP Menu** › **ConfigServer Firewall**
      - Provided by CSF. Original appearance shipped with all downloads.
      - https://127.0.0.1:2031/admin/index.php?module=csfofficial

<br />

<figure markdown="span">
    ![Webmin › Bug › Footer](../../assets/images/blog/release-1508/cwp_01.png){ width="600" }
    <figcaption>Control Web Panel › Menu Differences</figcaption>
</figure>

<br />


<br />
<br />

### Control Web Panel Immutable Flags

Files in Control Web Panel are often protected with the immutable flag `+i`, which prevents any changes to the file's contents or metadata, including permissions, timestamps, ownership, and link count.

While this flag enhances security, it can make updating CSF slightly more complex. The Control Web Panel installation script now includes logic to detect whether your CWP files have the `+i` flag and ensures that it is preserved after installing or updating CSF to a newer version.

This change will **not** set the immutable flag on files that did not previously have it; it will only re-apply the flag for users who already had it enabled. We do not want to start enabling flags on a system that they did not have, and potentially cause the end-user unexpected trouble in the future.

<br />
<br />

### New Terminal Commands

New terminal commands have been added to CSF regarding **Port Management**. These commands will allow you to add and remove ports from your whitelist, without the need to open and edit your CSF config file `/etc/csf/csf.conf`. 

This release includes the following new commands:

| Command                                           | Description                                                                   |
| ------------------------------------------------  | ----------------------------------------------------------------------------- |
| <!-- md:command 110 `-ap,  --addport` -->         | Add a new port to your `/etc/csf/csf.conf` whitelist. <br /> Requires `<protocol>:<port>` |
| <!-- md:command 110 `-rp,  --removeport` -->      | Remove port from your `/etc/csf/csf.conf` whitelist. <br /> Requires `<protocol>:<port>` |
| <!-- md:command 110 `-lp,  --listports` -->       | List all ports and their protocols currently whitelisted in `/etc/csf/csf.conf`. |

<br />

#### Arguments

Two of the commands specified above `--addport` and `--removeport` require **two** additional arguments to be passed with each command. These arguments are required in order for these commands to execute successfully.

- `sudo csf --addport <protocol>:<port>`
- `sudo csf --removeport <protocol>:<port>`

<br />

The third command does not require any additional arguments, and can simply be ran with just the base command:

- `sudo csf --listports`

<br />

A detailed description of each argument is provided below:

<br />

<!-- md:argument `<protocol>` -->

:   A `<protocol>` must be specified when adding or removing ports. Failing to provide the correct protocol will result in an error. The following values are accepted for `<protocol>`:

    :   TCP_IN

        TCP_OUT

        UDP_IN

        UDP_OUT

<br />

<!-- md:argument `<port>` -->

:   The `<port>` parameter represents the port that you wish to 
    add or remove from your whitelist.
    
    Valid port numbers range from `0` to `65535`.

<br />

#### Commands

The following commands have been added in this release:

<br />

##### Add Port
<!-- md:version stable-15.08 --> <!-- md:command `csf --addport <protocol>:<port>` -->

The following command will allow you to **add** a new port to your whitelist.

<br />

=== ":aetherx-axb-bash: Command"

    ``` shell
    sudo csf --addport TCP_IN:21140
    ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      $ sudo csf --addport TCP_IN:21140

      PASS               Successfully added port TCP_IN:21140 in /etc/csf/csf.conf
      ```

<br />
<br />

##### Remove Port
<!-- md:version stable-15.08 --> <!-- md:command `csf --removeport <protocol>:<port>` -->

The following command will allow you to **remove** an existing port from your whitelist.

<br />

=== ":aetherx-axb-bash: Command"

    ``` shell
    sudo csf --removeport TCP_IN:21140
    ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      $ sudo csf --removeport TCP_IN:21140

      PASS               Successfully removed port TCP_IN:21140 from /etc/csf/csf.conf
      ```

<br />
<br />

##### List Ports
<!-- md:version stable-15.08 --> <!-- md:command `csf --listports` -->

This command will list all ports that have been whitelisted through CSF and actively
allow connections to pass through.

<br />

=== ":aetherx-axb-bash: Command"

    ``` shell
    sudo csf --listports
    ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      $ sudo csf --listports
                                                                            
          INFO              Configured CSF Ports:                           
                            The following are a list of the whitelisted ports configured in your /etc/csf/csf.conf
                                                                            
                            TCP_IN: 22,25,80,143,443
                            TCP_OUT: 22,25,80,113,443
                            UDP_IN: 53,80,443,853
                            UDP_OUT: 53,113,123,853
      ```

<br />
<br />

### SELinux Permission Conformity

To comply with SELinux security requirements, the ownership of CSF files is now adjusted during installation or updates. Specifically, the installed [CSGet](../../advanced/csget/index.md) cron job is now set to `root:root` rather than the user who initiated the installation.

<br />
<br />

### Blocklist Service Enhancements

The Blocklist service has been significantly improved for both performance and efficiency.

The scripts responsible for generating these blocklists have been optimized for speed. While this change is mostly behind the scenes, it ensures that blocklist generation completes on time without unnecessary delays.

We have also refined the [highrisk](https://blocklist.configserver.dev/highrisk.ipset) blocklist. Duplicate entries have been removed, dramatically reducing the total number of entries. This not only improves clarity for end-users but also reduces memory usage on your server.

We will soon be enhancing the Blocklist service by adding our own ASN IP sets. This feature will allow you to block entire service providers or organizations from accessing your server, giving you greater control and security.

<br />

---

<br />

## Full Changelog

The full changelog is available [here](../../about/changelog.md).

<br />
<br />