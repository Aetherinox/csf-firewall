---
title: "Install › Start Services"
tags:
  - install
  - setup
  - service
  - systemctl
---

# Start Services <!-- omit from toc -->

After you have installed CSF, we can now start the services required for CSF and LFD to run properly. This section covers the basics of getting the services up and running. However, it does not go into detailed configurations.

<br />
<br />

## Disable Testing Mode

Testing mode is a feature built into CSF and LFD which does the following when **TESTING** is enabled:

- Allows safe configuration of CSF without enforcing firewall rules or banning IPs.
- Reads configuration files like `/etc/ssh/sshd_config` to detect service ports. Detected ports (SSH, IPv6, TCP/UDP) are added to CSF config variables such as `TCP_IN`, `TCP6_IN`, `UDP_IN` in `/etc/csf/csf.conf`.
- LFD does not run as a daemon.
- Adds a cron job to periodically reload CSF rules for testing, but no actual blocking occurs.
- IPs in `csf.allow` and `csf.deny` are processed for testing but **not enforced**.
- Displays currently listening ports to sysadmin; helps safely configure CSF before enabling enforcement.

??? warning "Testing Mode Disables LFD"

    If you plan to utilize our `LFD` service; you **MUST** disable `TESTING MODE`.

<br />

Out of box, CSF enables `TESTING MODE`. If this mode is enabled, the LFD daemon service will not start.  To disable testing mode, we need to open `/etc/csf/csf.conf` and locate the following:

```bash title="/etc/csf/csf.conf"
# #
#   SECTION:Initial Settings
# #
#   Testing flag - enables a cron job that clears iptables if there are
#   configuration problems when csf starts. Keep this enabled until you are
#   confident the firewall is working correctly. This helps prevent getting
#   locked out of your server.
#   
#   Once confirmed, set this flag to 0 and restart csf. Stopping csf will
#   remove the cron job from /etc/crontab.
#   
#   Note:       lfd will not start while this flag is enabled.
# #

TESTING = "1"
```

<br />

Flip the value of `TESTING` from `1` to `0`:

=== ":aetherx-axs-file-magnifying-glass: Find"

    ``` bash title="/etc/csf/csf.conf"
    TESTING = "1"
    ```

=== ":aetherx-axs-file-pen: Change To"

    ``` bash title="/etc/csf/csf.conf"
    TESTING = "0"
    ```

<br />

If you already skipped ahead and started CSF up, you'll need to perform a restart of the services with the command:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo csf -ra
      ```

<br />

After disabling `TESTING` mode, you can now start the services up. Proceed to the section [Enable & Disable CSF](#enable-and-disable-csf).

<br />
<br />

---

<br />
<br />

## Enable and Disable CSF

CSF and LFD can be set to `enabled` or `disabled`. Once you complete this section and enable csf, you can then confirm that [CSF](#csf-service) and [LFD](#lfd-service) are running.

<br />

<!-- md:option enable -->

:   <!-- md:control toggle_on -->
    Enable csf and lfd if previously disabled

    ``` shell
    sudo csf --enable
    ```

<!-- md:option disable -->

:   <!-- md:control toggle_off -->
    Disable csf and lfd completely

    ``` shell
    sudo csf --disable
    ```

<br />
<br />

---

<br />
<br />

## CSF Service

This section outlines how to ensure the CSF service is operating correctly. First, let's start up the CSF service:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo systemctl start csf
      sudo csf -ra
      ```

<br />

Check the current status of CSF by running the command:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo systemctl status csf
      ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      ● csf.service - ConfigServer Security & Firewall - csf
          Loaded: loaded (/lib/systemd/system/csf.service; enabled; vendor preset: enabled)
          Active: active (exited) since Mon 2025-09-15 23:45:04 UTC; 14 seconds ago
        Main PID: 597 (code=exited, status=0/SUCCESS)
              CPU: 0min 14.956s

      Notice: journal has been rotated since unit was started, output may be incomplete.
      ```

<br />

If you notice that CSF is not running or has the status `inactive (dead)` like the following:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo systemctl status csf
      ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      ○ csf.service - ConfigServer Security & Firewall - csf
          Loaded: loaded (/usr/lib/systemd/system/csf.service; enabled; preset: enabled)
          Active: inactive (dead)
      ```

<br />

We must enable the services to ensure they are running. Execute the commands below in your terminal:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo systemctl start csf
      sudo csf -ra
      ```

<br />

Confirm that the service is up and running:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo systemctl status csf
      ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      ● csf.service - ConfigServer Security & Firewall - csf
          Loaded: loaded (/usr/lib/systemd/system/csf.service; enabled; preset: enabled)
          Active: active (exited) since Sun 2025-09-21 01:35:45 UTC; 4s ago
          Process: 449564 ExecStart=/usr/sbin/csf --initup (code=exited, status=0/SUCCESS)
        Main PID: 449564 (code=exited, status=0/SUCCESS)
              CPU: 621ms
      ```

<br />

After you have confirmed that the CSF service is running, we need to ensure that the [LFD](#lfd-service) is also operating normally.

<br />
<br />

---

<br />
<br />

## LFD Service

This section outlines how to ensure the LFD service is operating correctly. First, let's start up the LFD service:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo systemctl start lfd
      sudo csf -ra
      ```

<br />

Check the current status of LFD by running the command:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo systemctl status lfd
      ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      ● lfd.service - ConfigServer Security & Firewall - lfd
          Loaded: loaded (/usr/lib/systemd/system/lfd.service; enabled; preset: enabled)
          Active: active (running) since Sun 2025-09-21 01:11:21 UTC; 1min 17s ago
          Process: 335736 ExecStart=/usr/sbin/lfd (code=exited, status=0/SUCCESS)
        Main PID: 335770 (lfd - sleeping)
            Tasks: 1 (limit: 4546)
          Memory: 38.8M (peak: 55.0M)
              CPU: 4.375s
          CGroup: /system.slice/lfd.service
                  └─335770 "lfd - sleeping"
      ```

<br />

If you see the status `failed` like the following example, this could be for any number of reasons. We will review below:

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      × lfd.service - ConfigServer Security & Firewall - lfd
          Loaded: loaded (/usr/lib/systemd/system/lfd.service; enabled; preset: enabled)
          Active: failed (Result: signal) since Sun 2025-09-21 01:52:34 UTC; 20min ago
          Process: 115504 ExecStart=/usr/sbin/lfd (code=killed, signal=KILL)
              CPU: 186ms
      ```

<br />

Ensure CSF and LFD are both enabled:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo csf -e
      ```

<br />

Another option to check the reason for the failure is to read out the lfd logs located at `/var/log/lfd.log`:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo tail -n 50 /var/log/lfd.log
      ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      Sep 21 01:44:34 server lfd[99819]: *Error* lfd will not run with TESTING enabled in /etc/csf/csf.conf, at line 98
      Sep 21 01:44:34 server lfd[99819]: daemon stopped
      Sep 21 01:47:24 server lfd[105308]: *Error* lfd will not run with TESTING enabled in /etc/csf/csf.conf, at line 98
      Sep 21 01:47:24 server lfd[105308]: daemon stopped
      Sep 21 01:47:56 server lfd[101396]: *Error* lfd will not run with TESTING enabled in /etc/csf/csf.conf, at line 98
      Sep 21 01:47:56 server lfd[101396]: daemon stopped
      Sep 21 01:50:39 server lfd[111685]: *Error* lfd will not run with TESTING enabled in /etc/csf/csf.conf, at line 98
      Sep 21 01:50:39 server lfd[111685]: daemon stopped
      Sep 21 01:52:07 server lfd[114496]: *Error* lfd will not run with TESTING enabled in /etc/csf/csf.conf, at line 98
      Sep 21 01:52:07 server lfd[114496]: daemon stopped
      Sep 21 01:52:34 server lfd[115504]: *Error* lfd will not run with TESTING enabled in /etc/csf/csf.conf, at line 98
      Sep 21 01:52:34 server lfd[115504]: daemon stopped
      Sep 21 01:55:17 server lfd[120584]: *Error* lfd will not run with TESTING enabled in /etc/csf/csf.conf, at line 98
      Sep 21 01:55:17 server lfd[120584]: daemon stopped
      ```

<br />

As our logs above show, it is complaining that `TESTIN` mode is enabled. You must ensure this mode is disabled before you will be able to enable the lfd service. Check that `TESTING = "0"` is set in your `/etc/csf/csf.conf`. Flip the value of `TESTING` from `1` to `0`:

=== ":aetherx-axs-file-magnifying-glass: Find"

    ``` bash title="/etc/csf/csf.conf"
    TESTING = "1"
    ```

=== ":aetherx-axs-file-pen: Change To"

    ``` bash title="/etc/csf/csf.conf"
    TESTING = "0"
    ```

<br />

Attempt to start LFD again:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo systemctl start lfd
      sudo csf -ra
      ```

<br />

You should now be able to confirm that LFD is running:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo systemctl status lfd
      ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      ● lfd.service - ConfigServer Security & Firewall - lfd
          Loaded: loaded (/usr/lib/systemd/system/lfd.service; enabled; preset: enabled)
          Active: active (running) since Sun 2025-09-21 01:44:00 UTC; 53min ago
          Process: 335736 ExecStart=/usr/sbin/lfd (code=exited, status=0/SUCCESS)
        Main PID: 335770 (lfd - sleeping)
            Tasks: 1 (limit: 4546)
          Memory: 39.2M (peak: 63.3M)
              CPU: 15.090s
          CGroup: /system.slice/lfd.service
                  └─335770 "lfd - sleeping"
      ```

<br />
<br />

---

<br />
<br />

## Troubleshooting

Refer to the following troubleshooting tips if you have issues with installing and starting CSF or the LFD daemon.

<br />

### lfd.service will not start (inactive (dead))

First, let's ensure `TESTING` mode is **disabled**. Run the following `tail` command to look at the lfd logs located in `/var/log/lfd.log`:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo tail -n 50 /var/log/lfd.log
      ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      Sep 21 01:44:34 server lfd[99819]: *Error* lfd will not run with TESTING enabled in /etc/csf/csf.conf, at line 98
      Sep 21 01:44:34 server lfd[99819]: daemon stopped
      Sep 21 01:47:24 server lfd[105308]: *Error* lfd will not run with TESTING enabled in /etc/csf/csf.conf, at line 98
      Sep 21 01:47:24 server lfd[105308]: daemon stopped
      Sep 21 01:47:56 server lfd[101396]: *Error* lfd will not run with TESTING enabled in /etc/csf/csf.conf, at line 98
      Sep 21 01:47:56 server lfd[101396]: daemon stopped
      Sep 21 01:50:39 server lfd[111685]: *Error* lfd will not run with TESTING enabled in /etc/csf/csf.conf, at line 98
      Sep 21 01:50:39 server lfd[111685]: daemon stopped
      Sep 21 01:52:07 server lfd[114496]: *Error* lfd will not run with TESTING enabled in /etc/csf/csf.conf, at line 98
      Sep 21 01:52:07 server lfd[114496]: daemon stopped
      Sep 21 01:52:34 server lfd[115504]: *Error* lfd will not run with TESTING enabled in /etc/csf/csf.conf, at line 98
      Sep 21 01:52:34 server lfd[115504]: daemon stopped
      Sep 21 01:55:17 server lfd[120584]: *Error* lfd will not run with TESTING enabled in /etc/csf/csf.conf, at line 98
      Sep 21 01:55:17 server lfd[120584]: daemon stopped
      ```

<br />

If you see the above logs, this means that `TESTING` mode is enabled. In order for the LFD daemon to start, you must disable testing mode. Open `/etc/csf/csf.conf` and change the following:

=== ":aetherx-axs-file-magnifying-glass: Find"

    ``` bash title="/etc/csf/csf.conf"
    TESTING = "1"
    ```

=== ":aetherx-axs-file-pen: Change To"

    ``` bash title="/etc/csf/csf.conf"
    TESTING = "0"
    ```

<br />

You can also try to run LFD with `strace`:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo strace -f /usr/sbin/lfd --check
      ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      rt_sigaction(SIGRT_25, NULL, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
      rt_sigaction(SIGRT_26, NULL, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
      rt_sigaction(SIGRT_27, NULL, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
      rt_sigaction(SIGRT_28, NULL, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
      rt_sigaction(SIGRT_29, NULL, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
      rt_sigaction(SIGRT_30, NULL, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
      rt_sigaction(SIGRT_31, NULL, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
      rt_sigaction(SIGRT_32, NULL, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
      rt_sigaction(SIGABRT, NULL, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
      rt_sigaction(SIGCHLD, NULL, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
      rt_sigaction(SIGIO, NULL, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
      exit_group(0)                           = ?
      +++ exited with 0 +++
      ```

<br />

Sometimes `strace` will give you hints as to what went wrong. In the example above, lfd is exiting with `error code 0`, which means “success / no error”. The program is choosing to shut itself down and telling the OS “I finished cleanly.”. This tells us that it's not due to something failing. 

When a daemon exits cleanly (exit code 0), you usually have to look inside lfd's own logs, not just systemd’s.

In our example above, we clearly see in the `/var/log/lfd.log` file that it was due to us having `TESTING` enabled.

<br />

Another option for checking failure reasons is to run the following command:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo dmesg -T | tail -n 20
      ```

<br />

You can also check `journalctl` for any errors:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo journalctl -xeu lfd.service
      ```

<br />

All of the listed methods above will help you narrow down exactly why CSF or LFD are not starting properly.

<br />

---

<br />

## Next Steps <!-- omit from toc -->

{==

Select what documentation you would like to proceed with next ...

==}

<div class="grid cards" markdown>

-   :aetherx-axs-browser: &nbsp; __[Enable Web Interface](../install/webui.md)__

    ---

    The web interface lets you manage your firewall through a browser instead
    of a command line.  

    This chapter covers installation of dependencies, enabling the interface,
    and whitelisting your IP for security.  

    You’ll also learn how to access the interface safely and protect it from
    unauthorized users.  

-   :material-file: &nbsp; __[Usage Introduction](../usage/getting-started.md)__

    ---

    If you don’t plan to set up Traefik or Authentik with the CSF web interface, 
    you can skip ahead to the [Usage](../usage/getting-started.md) section. 
    
    The next chapter covers CSF’s core features, basic configuration, available
    commands, folder structure, and everything you need to get started.

    You will be taken on a more detailed dive of how CSF can benefit you and
    what options you have for securing your server.

</div>

<br />

<br />
