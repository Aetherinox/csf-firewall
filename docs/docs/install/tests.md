---
title: Diagnostic Tests
tags:
  - install
  - setup
  - tests
  - diagnostics
---

# Diagnostic Tests <!-- omit from toc -->

ConfigServer Firewall & Security includes a few diagnostic tests which you can run and will output the current status of your CSF installation, including whether or not it is operating normally.

<br />
<br />

## csftest.pl

The `csftest.pl` script is a diagnostic tool included with CSF. Its primary purpose is to check whether your server environment is compatible with CSF and LFD (Login Failure Daemon) before or after installation. When you run csftest.pl, it performs a series of tests to verify:

- That required Perl modules are installed and available
- That essential system commands and binaries (such as iptables, ip6tables, and others) can be found and executed
- That your operating system and kernel support the necessary firewall features
- That no conflicting firewall rules or services prevent CSF from running correctly

<br />

If any issues are detected, the script will report them so you can fix missing dependencies or adjust your system configuration. Running this script is a recommended step after installing dependencies and downloading CSF to your server, as it ensures that your server is properly prepared for firewall deployment.

<br />

To run these tests; ensure you have the package `perl` installed on your system as explained in the previous step [Dependencies](../install/dependencies.md). After you have perl installed, run the command:

```shell
sudo perl /usr/local/csf/bin/csftest.pl
```

<br />

After the tests run; you should see the following:

```terminal
Testing ip_tables/iptable_filter...OK
Testing ipt_LOG...OK
Testing ipt_multiport/xt_multiport...OK
Testing ipt_REJECT...OK
Testing ipt_state/xt_state...OK
Testing ipt_limit/xt_limit...OK
Testing ipt_recent...OK
Testing xt_connlimit...OK
Testing ipt_owner/xt_owner...OK
Testing iptable_nat/ipt_REDIRECT...OK
Testing iptable_nat/ipt_DNAT...OK

RESULT: csf should function on this server
```

<br />

### Fixing "unknown option --dport" (CSF requires legacy iptables)

If you see this error during CSF tests, your system is using the nftables backend for iptables. CSF requires the legacy iptables backend. Check the current setting with:

```shell
sudo update-alternatives --display iptables
```

<br />

If you see `link currently points to /usr/sbin/iptables-nft`, you need to change this over to `/usr/sbin/iptables-legacy`. Two methods are listed below for doing this, **pick one**:

<br />


=== "Method 1"

      To switch over to `/usr/sbin/iptables-legacy`, run the command:

      ```shell
      sudo update-alternatives --config iptables
      ```

      <br />

      You will see the following:

      ```console
      There are 2 choices for the alternative iptables (providing /usr/sbin/iptables).

        Selection    Path                       Priority   Status
      ------------------------------------------------------------
      * 0            /usr/sbin/iptables-nft      20        auto mode
        1            /usr/sbin/iptables-legacy   10        manual mode
        2            /usr/sbin/iptables-nft      20        manual mode
      ```

      <br />

      There may be an asterisk next to `selection` ++0++, you need to press ++1++ and press ++enter++ to switch over to `/usr/sbin/iptables-legacy`. Then repeat these steps for IPv6

      ```shell
      sudo update-alternatives --config ip6tables
      ```

      <br />

      Along with ipv4 and ipv6, there are two other tables you can switch, which are `arptables` and `ebtables`. 
      
    ??? note "arptables & ebtables"

        - `arptables`: Works on Layer 2 (link layer), specifically for the ARP protocol.
            - Lets you control ARP traffic (who can send ARP requests/replies, block spoofing, etc.).
            - Example: prevent ARP spoofing in a local network.
        - `ebtables`: Works on Ethernet bridge frames (Layer 2).
            - Lets you filter traffic based on MAC addresses, Ethernet types, or VLAN tags before IP-level filtering happens.
            - Used when the system is acting as a bridge or switch.

      <br />

      If you need to switch the other options over to legacy, those commands are:

      ```shell
      sudo update-alternatives --config arptables
      sudo update-alternatives --config ebtables
      ```

=== "Method 2"

      To switch over to `/usr/sbin/iptables-legacy`, run the command:

      **On Debian/Ubuntu:**

      ```shell
      sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
      sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
      sudo update-alternatives --set arptables /usr/sbin/arptables-legacy
      sudo update-alternatives --set ebtables /usr/sbin/ebtables-legacy
      ```

      <br />

      **On CentOS/RHEL:** If `alternatives` is used, the same commands work. Otherwise:

      ```shell
      sudo alternatives --config iptables
      sudo alternatives --config ip6tables
      sudo alternatives --config arptables
      sudo alternatives --config ebtables
      ```

      <br />

      Select the `legacy` version for each prompt.



<br />

You can confirm your changes by running the command:

```shell
iptables -V
```

<br />

Which should return:

```console
$ iptables -V
iptables v1.8.7 (legacy)
```

<br />

You can also run:

```shell
sudo update-alternatives --display iptables
```

<br />

Which should output:

```shell
link currently points to /usr/sbin/iptables-legacy
```

<br />

You can always switch back to `iptables-nft` by running:

```shell
sudo update-alternatives --set iptables /usr/sbin/iptables-nft
```

<br />

---

<br />

## Next Steps <!-- omit from toc -->

{==

Select what documentation you would like to proceed with next ...

==}

<div class="grid cards" markdown>

-   :material-file: &nbsp; __[Enable Web Interface (Optional)](./webui.md)__

    ---

    In the next section, we’ll demonstrate how to enable the **ConfigServer 
    Firewall (CSF) web interface**, which provides a graphical user 
    interface to help you manage your firewall.  

    Enabling the web interface is entirely **optional**. If you prefer not 
    to enable it, you can still manage CSF using terminal commands.

-   :material-file: &nbsp; __[Configuring CSF](webui.md)__

    ---

    Now that you have CSF up and running, you can proceed to our guide 
    which explains how to use CSF for the first time, and covers some
    of the settings that you can adjust.

</div>
