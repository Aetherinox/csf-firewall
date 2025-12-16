---
title: "Install › Diagnostic Tests"
tags:
  - install
  - setup
  - tests
  - diagnostics
---

# Diagnostic Tests <!-- omit from toc -->

ConfigServer Security & Firewall includes a few diagnostic tests which you can run and will output the current status of your CSF installation, including whether or not it is operating normally.

<br />
<br />

## csftest.pl

The `csftest.pl` script is a diagnostic tool included with CSF. Its primary purpose is to check whether your server environment is compatible with CSF and LFD (Login Failure Daemon) before and after installation. When you run `csftest.pl`, it performs a series of tests to verify:

- That required Perl modules are installed and available
- That essential system commands and binaries (such as iptables, ip6tables, and others) can be found and executed
- That your operating system and kernel support the necessary firewall features
- That no conflicting firewall rules or services prevent CSF from running correctly

<br />

If any issues are detected, the script will report them so you can fix missing dependencies or adjust your system configuration. Running this script is a recommended step before installing CSF to your server, as it ensures that your server is properly prepared for firewall deployment.

<br />

To run these tests; ensure you have the package `perl` installed on your system as explained in the previous step [Dependencies](../install/dependencies.md). You also need to have CSF extracted to your server. After these are complete, run the tests:

```shell
sudo perl csf/csftest.pl
```

??? note "Running Tests After Install"

    You can also run the tests again at any time with the command:

    ``` shell
    sudo perl /usr/local/csf/bin/csftest.pl
    ```

<br />

When the tests run; you should see the following:

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

:   :aetherx-axs-triangle-exclamation:{ .icon-clr-yellow } If the tests failed, proceed to the next step [Troubleshooting](#troubleshooting) to see if your error is listed and consult it for a possible fix.
:   :aetherx-axs-square-check:{ .icon-clr-green } If the tests succeed, proceed to the next part of the guide:

<br />

---

<br />

## Troubleshooting

If you received any errors during the process of running `csftest.pl`, review the list of possible errors and solutions below:

<br .>

### unknown option --dport: (CSF requires legacy iptables)

If you see this error during the CSF tests, your system is using the nftables backend for iptables. CSF requires the legacy iptables backend. Check the current setting with:

```shell
sudo update-alternatives --display iptables
```

<br />

If you see `link currently points to /usr/sbin/iptables-nft`, you need to change this over to `/usr/sbin/iptables-legacy`. Two methods are listed below for doing this, **pick one**:

<br />


=== ":aetherx-axd-circle-1: Method 1"

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

=== ":aetherx-axd-circle-2: Method 2"

      To switch over to `/usr/sbin/iptables-legacy`, run the commands listed below:

    === ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

        ??? warning "Error: Not registered; Not setting"
            On newer systems (Debian 11+, Ubuntu 20.04+, RHEL 8+), `ebtables` and `arptables` are often completely replaced by nftables, so there isn’t always a legacy version available. This means that
            you may not have any binaries installed for these two types and could receive the following error if you attempt to change `ebtables` and `arptables`:

            ```console
            update-alternatives: error: alternative /usr/sbin/ebtables-legacy for ebtables not registered; not setting
            update-alternatives: error: alternative /usr/sbin/arptables-legacy for arptables not registered; not setting
            ```

            If you receive the error(s) above; simply skip setting `ebtables` and `arptables`. Only focus on switching `iptables` and `ip6tables` over to `iptables-legacy`

          ```shell
          sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
          sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
          sudo update-alternatives --set arptables /usr/sbin/arptables-legacy
          sudo update-alternatives --set ebtables /usr/sbin/ebtables-legacy
          ```

    === ":aetherx-axb-redhat: CentOS/RHEL (yum/dnf)"

          ```shell
          sudo alternatives --config iptables
          sudo alternatives --config ip6tables
          sudo alternatives --config arptables
          sudo alternatives --config ebtables
          ```

      <br />

      You’ll be presented with a numbered list of installed binaries (usually nftables and legacy). You need to type the number corresponding to the legacy version so that `iptables-legacy` becomes the default.

      ```shell
      There are 2 choices for the alternative iptables (providing /usr/sbin/iptables).

        Selection    Path                       Priority   Status
      ------------------------------------------------------------
      * 0            /usr/sbin/iptables-nft      20        auto mode
        1            /usr/sbin/iptables-legacy   10        manual mode
        2            /usr/sbin/iptables-nft      20        manual mode

      Enter to keep the current selection[+], or type selection number: 1
      ```

<br />

Confirm your changes by running the command:

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
iptables - manual mode
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

-   :aetherx-axs-box-isometric: &nbsp; __[Install (Generic)](./install.md#install-generic)__

    ---
    
    Instructions for installing CSF on a bare-metal machine without a control
    panel.

-   :aetherx-axb-cpanel: &nbsp; __[Install (cPanel & WHM)](./install.md#install-cpanel-and-whm)__

    ---

    CSF will integrate directly into WHM and appear under the **Plugins** section
    for easy firewall management.

-   :aetherx-axb-webmin: &nbsp; __[Install (Webmin)](./install.md#install-webmin)__

    ---

    CSF will integrate with the Webmin interface, and will appear under the Webmin
    **System** category.

-   :aetherx-axb-vestacp: &nbsp; __[Install (VestaCP)](./install.md#install-vestacp)__

    ---

    CSF will integrate with the Vesta control panel while continuing to operate
    as a system-level firewall.

-   :aetherx-axb-cwp: &nbsp; __[Install (Control Web Panel)](./install.md#install-control-web-panel)__

    ---

    CSF will be installed with CWP compatibility, and a new navigation option will appear
    under Security › CSF Firewall.

-   :aetherx-axb-cyberpanel: &nbsp; __[Install (CyberPanel)](./install.md#install-cyberpanel)__

    ---

    CSF will be configured to work alongside CyberPanel, a new navigation option will appear
    within **Security** › **CSF**.

-   :aetherx-axb-directadmin: &nbsp; __[Install (DirectAdmin)](./install.md#install-directadmin)__

    ---

    CSF will integrate into the DirectAdmin interface, providing firewall controls
    directly within the panel.

-   :aetherx-axb-interworx: &nbsp; __[Install (Interworx)](./install.md#install-interworx)__

    ---

    CSF will integrate with the InterWorx control panel, creating a new menu category 
    listed as **ConfigServer Firewall Plugins**.

</div>
