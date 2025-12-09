---
title: Advanced › CSGet
tags:
    - advanced
    - csget
---

# Advanced › CSGet
<!-- md:requires /etc/cron.daily/csget --> <!-- md:fileSourceCode https://github.com/Aetherinox/csf-firewall/blob/main/src/csget.pl -->

The **CSGet module** is a core component of the CSF update system used by the CSF web interface. Its primary role is to keep every installation of ConfigServer Security and Firewall informed of new releases. CSGet runs quietly in the background, requiring no user interaction while monitoring for updates.

When CSF is installed, the `install.sh` script automatically copies the CSGet module to the client system in `/etc/cron.daily/csget`.

Once the install script copies the CSGet module file, the `install.sh` script runs CSGet **once in the foreground** to ensure the system starts with the latest version. The install script runs the command `/etc/cron.daily/csget --nodaemon --response`.

After that initial run, CSGet is managed in the future by your system's **cron service**. It runs as a cron job at a randomized interval between **0 and 6 hours** [^1]. Each execution makes contact with the official CSF update servers, which does the following:

- **Fetch the latest version information** from the remote servers and saves that version number locally to the file `/var/lib/configserver/csf.txt` using `wget`, `curl`, or `get`.
- **Compares the fetched version** in `/var/lib/configserver/csf.txt` against your installed CSF version in `/etc/csf/version.txt`.
- **Notifies the CSF system** if a newer release is available.

This automated process allows the CSF web interface to alert administrators about updates and provide upgrade options whenever a new version is detected.

<br />

---

<br />

## Activation

CSGet can be activated one of two ways:

1. [Automatically](#automated)
2. [Manual Activation](#manual)

<br />

### Automated

The CSGet module is installed automatically when CSF is first installed via the CSF `install.sh` script. CSGet is ran once in the foreground (no daemon) automatically by the install script. From that point forward, CSGet is executed by your system's cron services.

The workflow is as follows:

1. **Initial Execution / Foreground**: Immediately after installation, CSGet runs once to confirm whether the user is already on the latest version of CSF.
2. **Cron Mode / Background Daemon**: After the initial run, the module is placed into cron mode and ran as a forked daemon, where it continues to operate on a periodic schedule with randomized intervals. [^1]

<br />

### Manual

Along with CSGet being activated automatically by CSF, you can also force the module to run whenever you need it to. While most users should have no need for manual activation, an advanced user may wish to test the system in order to diagnose update issues.

For basic runs, you can run CSGet as a foreground process which runs once and then exits via the command:

=== ":aetherx-axb-bash: Bash"

    ``` shell
    sudo /etc/cron.daily/csget --nodaemon
    ```

=== ":aetherx-axb-perl: Perl"

    ``` shell
    sudo perl /etc/cron.daily/csget --nodaemon
    ```

<br />

Or you can force CSGet to run as a forked background daemon by using the command:

=== ":aetherx-axb-bash: Bash"

    ``` shell
    sudo /etc/cron.daily/csget
    ```

=== ":aetherx-axb-perl: Perl"

    ``` shell
    sudo perl /etc/cron.daily/csget
    ```

<br />

A full list of available [flags](#flags) and [commands](#commands) are listed further down on this page in the [Usage](#usage) section.

<br />

---

<br />

## Logs

This module includes a detailed logging system. When the module is ran, logs will be stored within one of two files.

1. `/var/log/csf/csget_daemon.log`
2. `/var/log/csf/csget_debug.log`

<br />

### csget_daemon.log
<!-- md:source /var/log/csf/csget_daemon.log -->

This log file will be used under normal operations, including during CSGet's default behavior of running in the background as a daemon process.

<br />

### csget_debug.log
<!-- md:source /var/log/csf/csget_daemon.log -->

This log file is only used if you start CSGet manually and append the `--debug` flag to the startup command. You can read more about the [debug flag here](#debug).

<br />

---

<br />

## Usage

CSGet includes a variety of flags and commands which allow you to control how the module operates and how much feedback it provides during execution. These options make it easy to run CSGet manually, review its behavior, or adjust how updates are handled.

All commands may be run **with or without the `perl` binary**.  

Since the script includes a proper `#!/usr/bin/perl` shebang, explicitly calling `perl` is optional. For clarity, each command example will show both forms.

Review the available [flags](#flags) and [commands](#commands) below.

<br />

### Flags

Any of the following flags can be appended on to a command you wish to run. Read the description of each flag below.

| Flag                                    | Description                                                                 |
| --------------------------------------- | --------------------------------------------------------------------------- |
| <!-- md:command 110 `-d,  --debug` -->      | CSGet script runs immediately once and exits, no forked background process / daemonization.   |
| <!-- md:command 110 `-r,  --response` -->   | Runs CSGet in the foreground once and then exits with a numerical response.<br/>Returns `0` on Success <br /> Returns `1` on Failures                               |
| <!-- md:command 110 `-k,  --kill` -->       | Kills all running processes of CSGet.             |
| <!-- md:command 110 `-l,  --list` -->       | Lists all running processes of CSGet.             |
| <!-- md:command 110 `-d,  --diag` -->       | Show diagnostic information.                      |
| <!-- md:command 110 `-D,  --debug` -->      | Show verbose logs and additional details; disables forked child process daemonization.  |
| <!-- md:command 110 `-v,  --version` -->    | Show version information about CSGet and CSF.     |
| <!-- md:command 110 `-h,  --help` -->       | Show help menu, list of commands, and usage examples. |

<br />
<br />

### Commands

If you wish to trigger the CSGet cron manually, you can utilize the following list of commands, combined with [flags](#flags), to make CSGet behave differently depending on your needs.

<br />

#### Run In Background
<!-- md:version stable-15.01 -->

You can start the CSGet module and force it to function in the background. Since this is the default behavior of the module, no special flags are required in order to start the process. As soon as CSGet is started; it will create a forked daemon and continue to run in the background.

=== ":aetherx-axb-bash: Bash"

    ``` shell
    sudo /etc/cron.daily/csget
    ```

=== ":aetherx-axb-perl: Perl"

    ``` shell
    sudo perl /etc/cron.daily/csget
    ```

<br />
<br />

#### Run Once
<!-- md:version stable-15.08 -->

The command below allows you to start CSGet once and then immediately exit after it has performed its tasks. By supplying the `--nodaemon` flag, a forked daemon background process will **not** be created, and the script will exit immediately.

=== ":aetherx-axb-bash: Bash"

    ``` shell
    sudo /etc/cron.daily/csget --nodaemon
    ```

=== ":aetherx-axb-perl: Perl"

    ``` shell
    sudo perl /etc/cron.daily/csget --nodaemon
    ```

<br />
<br />

#### Monitor Response
<!-- md:version stable-15.08 -->

By default, the CSGet module was developed to be a background daemon which returns nothing once it has started. In some instances, you may wish to monitor the progress of the job to determine if the tasks were completed or have failed.

To get a valid response from CSGet, you can append the flag `--response` to the end of the command:

=== ":aetherx-axb-bash: Bash"

    ``` shell
    sudo /etc/cron.daily/csget --nodaemon --response
    ```

=== ":aetherx-axb-perl: Perl"

    ``` shell
    sudo perl /etc/cron.daily/csget --nodaemon  --response
    ```

<br />

The command above will make CSGet  run once, return a response, and then exit. The following responses will be returned:

| Response              | Description                                                                             |
| --------------------- | --------------------------------------------------------------------------------------- |
| `0`                   | Job completed successfully                                                              |
| `1`                   | Job failed and not could download the latest version info from the CSF update servers   |

<br />

If you wish to call the CSGet module from a bash script, you can use an example similar to the following:

=== ":aetherx-axb-bash: Bash"

    ``` bash
    "/etc/cron.daily/csget" --nodaemon --response
    CSF_CRON_CSGET_STATUS=$?

    if [ "$CSF_CRON_CSGET_STATUS" -eq 0 ]; then
        print "    CSGET successfully ran"
    else
        print "    CSGET failed to run"
    fi
    ```

<br />
<br />

#### Debug
<!-- md:version stable-15.08 -->

This module includes a debug mode which is activated by appending `--debug`. This allows for you to see additional information about the process, as well as certain things that you can not see normally in the logs.

When using this flag, logs will be stored in the file `/var/log/csf/csget_debug.log`.

=== ":aetherx-axb-bash: Bash"

    ``` shell
    sudo /etc/cron.daily/csget --nodaemon --debug
    ```

=== ":aetherx-axb-perl: Perl"

    ``` shell
    sudo perl /etc/cron.daily/csget --nodaemon  --debug
    ```

<br />
<br />

#### List Active Processes
<!-- md:version stable-15.08 -->

You can list any active instances of CSGet with the `--list` flag.

=== ":aetherx-axb-bash: Bash"

    ``` shell
    sudo /etc/cron.daily/csget --list
    ```

=== ":aetherx-axb-perl: Perl"

    ``` shell
    sudo perl /etc/cron.daily/csget --list
    ```

<br />

You will see the following output:

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      CSGet processes currently running:
      The following is a list of processes attached to CSGet

      root      817980  0.0  0.1 227176  3824 ?        SN   03:43   0:00 ConfigServer Version Check
      ```

<br />
<br />

#### Kill Active Processes
<!-- md:version stable-15.08 -->

You can terminate any running CSGet background daemons using the `--kill` flag. When invoked, CSGet automatically scans for all active processes associated with the module and shuts them down, without the need to manually locate or provide PIDs.

=== ":aetherx-axb-bash: Bash"

    ``` shell
    sudo /etc/cron.daily/csget --kill
    ```

=== ":aetherx-axb-perl: Perl"

    ``` shell
    sudo perl /etc/cron.daily/csget --kill
    ```

<br />

You will see the following output:

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      CSGet processes terminated: 817980
      ```

<br />
<br />

#### View Diagnostic Info
<!-- md:version stable-15.08 -->

By providing the flag `--diag`, CSGet will output various pieces of information related to the module and how it is set up on your system. 

=== ":aetherx-axb-bash: Bash"

    ``` shell
    sudo /etc/cron.daily/csget --diag
    ```

=== ":aetherx-axb-perl: Perl"

    ``` shell
    sudo perl /etc/cron.daily/csget --diag
    ```

<br />

You will see the following output:

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      CSF CSGET Perl Updater
      A perl script which allows for automated update checks for the official CSF servers.
      https://github.com/Aetherinox/csf-firewall

      Process Name          ConfigServer Version Check
      Process Path          /etc/cron.daily/csget
      Server URL            https://download.configserver.dev/csf/version.txt
      Fetch Package         curl
      Command (Base)        /usr/bin/curl -skLf -m 120 -o
      Command (Out)         /usr/bin/curl -skLf -m 120 -o /var/lib/configserver/csf.txt https://download.configserver.dev/csf/version.txt
      Config Path           /etc/csf/csf.conf (Found)
      Log Folder            /var/log/csf
      Log Daemon            /var/log/csf/csget_daemon.log
      Log Debug             /var/log/csf/csget_debug.log
      ```

<br />
<br />

#### Version
<!-- md:version stable-15.01 -->

The `--version` flag simply returns version information about the CSGet module.

=== ":aetherx-axb-bash: Bash"

    ``` shell
    sudo /etc/cron.daily/csget --version
    ```

=== ":aetherx-axb-perl: Perl"

    ``` shell
    sudo perl /etc/cron.daily/csget --version
    ```

<br />

You will see the following output:

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      CSF CSGET Perl Updater
      ConfigServer Security & Firewall v15.08
      A perl script which allows for automated update checks for the official CSF servers.
      https://github.com/Aetherinox/csf-firewall
      ```

<br />
<br />

#### Help
<!-- md:version stable-15.05 -->

The `--help` flag displays all of the command information that is contained on this page, but in a much more compact format.

=== ":aetherx-axb-bash: Bash"

    ``` shell
    sudo /etc/cron.daily/csget --help
    ```

=== ":aetherx-axb-perl: Perl"

    ``` shell
    sudo perl /etc/cron.daily/csget --help
    ```

<br />

You will see the following output:

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      CSF CSGET Perl Updater
      A perl script which allows for automated update checks for the official CSF servers.
      https://github.com/Aetherinox/csf-firewall

      Syntax:                                         
            Command                              /etc/cron.daily/csget [ --option [ arg ] ]
            Options                              /etc/cron.daily/csget [ -h | --help ]
                -A                                  required                      
                -A...                               required; multiple can be specified
                [ -A ]                              optional                      
                [ -A... ]                           optional; multiple can be specified
                { -A | -B }                         one or the other; do not use both
            Examples                             /etc/cron.daily/csget  
                                                  /etc/cron.daily/csget --nodaemon
                                                  /etc/cron.daily/csget --debug
                                                  /etc/cron.daily/csget --nodaemon --response
                                                  /etc/cron.daily/csget --diag
                                                  /etc/cron.daily/csget --list

      Options:                                         
            -r,  --response                      Run in foreground and show logs. Useful with bash scripts.
                                                      disables forked daemonization
            -n,  --nodaemon                      Run task immediately, do not start on timed delay.
                                                      no forked daemonization
            -k,  --kill                          Kills all processes associated with csget.
            -l,  --list                          Lists all csget processes except this command.
            -d,  --diag                          Show diagnostic information.        
            -D,  --debug                         Show verbose logs and additional details; disables forked child process daemonization.
                                                      disables forked daemonization
            -v,  --version                       Show version information about csget and csf.
            -h,  --help                          Show this help menu.                

      Tips:                                         
            Run CSGet once                       $ sudo /etc/cron.daily/csget --nodaemon
            Start CSGet cron                     $ sudo /etc/cron.daily/csget
            Run using perl (normal)              $ sudo perl /etc/cron.daily/csget
            Run using perl (+w warnings)         $ sudo perl -w /etc/cron.daily/csget
            Run using perl (+d debugger)         $ sudo perl -d /etc/cron.daily/csget
            Run using perl (+d:Trace)            $ sudo perl -d:Trace /etc/cron.daily/csget
      ```


<br />

---

<br />

## FAQ

The following is a list of questions a user may have, and includes additional information abouve the CSGet component.

<br />

??? faq "Is CSGet Required?"

    No. You absolutely do not need to run CSGet as a cron. You may decide
    to manually check for updates yourself and apply them whenever they
    become available. 

    This feature is simply to make life easier with a little automation.

??? faq "Why Random Interval Checks?"

    Instead of running on a fixed schedule, CSGet’s randomized 0–6 hour interval serves as an important safeguard. By staggering update checks across all CSF installations, it prevents large numbers of systems from contacting the update servers simultaneously. This helps:

    - Reduce server load
    - Improve performance and reliability across the update network
    - Ensure fast and consistent access to update checks

??? faq "I ran `--debug`, but it says I am missing perl modules."

    Using CSGet's `--debug` flag requires you to install the **Diagnostics**
    perl module. You can install it by using one of the commands below:

    ```shell
    # RHEL/AlmaLinux
    sudo dnf install perl-Diagnostics

    # Debian/Ubuntu
    sudo apt install libdiagnostics-perl
    ```

[^1]:
    CSGet’s randomized 0–6 hour interval serves as an important safeguard which 
    prevents large numbers of connections to the update server simultaneously.
    This helps with server managing the server loads and ensures connectivity.

<br />
<br />
