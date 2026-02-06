---
date: 2025-12-16
authors:
    - aetherinox
categories:
    - release
    - changelog
    - v15.x
    - cyberpanel
description: >
    Details regarding CSF release v15.09
title: >
    Release v15.09
comments: true
---

# Release: v15.09

Release **v15.09** enhances support for [DirectAdmin](https://directadmin.com), including a major bug fix, an updated module interface, enables automatic updates for the CSF DirectAdmin web interface,, and a newly added [DirectAdmin Installation Guide](https://docs.configserver.dev/install/install/#install-directadmin).

This release also resolves a few issues regarding the installation process, and includes multiple performance improvements that significantly increase file read efficiency.

<!-- more -->

<br />

---

<br />

## Changelog

A list of the most important changes are listed below.

<br />

### Introducing AbuseIPDB

<br />

<p align="center">
    <img src="../../../assets/images/blog/release-1509/abuseipdb.png" alt="AbuseIPDB">
</p>

<br />

We have added a new **AbuseIPDB integration** to the file `/etc/csf/csf.blocklists`. When enabled, this integration allows CSF to automatically block known malicious IP addresses before they can reach your server.

=== ":material-file: /etc/csf/csf.blocklists"

    ```ini
    # #
    #   @blocklist              AbuseIPDB
    #   @details:               https://abuseipdb.com/account/api
    #   @notes:                 Requires you to create an account.
    #                           Requires you to generate an API key.
    #                           Add your generated API key in the URL below by 
    #                               replacing `YOUR_API_KEY`.
    #                           Change the 3rd field `10000` to a higher number
    #                               if you are on a paid plan.
    #   
    #                           Full documentation at:
    #                               https://docs.configserver.dev/install/integrations/abuseipdb/
    # #

    #   ABUSEIPDB|86400|10000|https://api.abuseipdb.com/api/v2/blacklist?key=YOUR_API_KEY&plaintext
    ```

<br />

Think of AbuseIPDB like the classic arcade game **Asteroids**: hostile attackers and abusive IPs are the incoming asteroids, and your server’s firewall is the laser cannon. As soon as a threat gets too close, it’s eliminated, along with 100 points per hit.

By leveraging AbuseIPDB’s real-time threat intelligence, you gain a proactive defense layer that helps keep your server protected in the ongoing battle against malicious activity across the digital cosmos.

We’ve also added a dedicated documentation page that explains the AbuseIPDB integration in detail. You can read more about it here:  

- [AbuseIPDB Integration Documentation](https://docs.configserver.dev/install/integrations/abuseipdb/)

<br />

Review our list of curated guides related to AbuseIPDB below:

<div class="grid cards" markdown>

-   :aetherx-axb-abuseipdb: &nbsp; __[CSF: AbuseIPDB Integration Guide](https://docs.configserver.dev/install/integrations/abuseipdb/)__

    ---

    Our official documentation for integrating AbuseIPDB into CSF.

-   :aetherx-axb-abuseipdb: &nbsp; __[AbuseIPDB: CSF Integration](https://abuseipdb.com/csf)__

    ---

    CSF Integration guide provided by AbuseIPDB.

-   :aetherx-axb-abuseipdb: &nbsp; __[AbuseIPDB: API Docs](https://docs.abuseipdb.com/#introduction)__

    ---

    Full API documentation for AbuseIPDB.

-   :aetherx-axb-abuseipdb: &nbsp; __[AbuseIPDB: Create API Key](https://abuseipdb.com/account/api)__

    ---

    Create an AbuseIPDB and generate an API key.

</div>

<br />
<br />

### Sponsor Icon

We have decided to make slight adjustments to the **Sponsor** icon that rests within the footer of the CSF interface:

- [x] Removed heartbeat animation.
- [x] Sponsor icon no longer shows if you are a sponsor with a valid license.
- [x] Added new setting `SPONSOR_ICON_HIDE` to file `/etc/csf/csf.conf` which will hide the icon.
- [x] Added new setting `SPONSOR_ICON_ANIM` to file `/etc/csf/csf.conf` which will stop icon animation.

<br />

We have added the following new settings to the `/etc/csf/csf.conf`:

=== ":material-file: /etc/csf/csf.conf"

    ```perl
    # #
    #   This will enable or disable the beating heart animation
    #   for the footer sponsor icon.
    #   
    #   0       = No animation          (default)
    #   1       = Show animatin
    #   empty   = Uses default
    # #

    SPONSOR_ICON_ANIM = "0"

    # #
    #   This will hide the heart icon in the footer which leads
    #   to the sponsor website if clicked.
    #   
    #   If you remove this, please consider sponsoring to help
    #   support the project. Even five dollars helps.
    #   
    #   0       = Show                  (default)
    #   1       = Hide
    #   empty   = Uses default
    # #

    SPONSOR_ICON_HIDE = "0"
    ```

<br />
<br />

### DirectAdmin: New Docs

We have added a new section to our documentation that walks through the process of installing DirectAdmin alongside CSF on a server.

This completes our installation guides, as DirectAdmin was the last remaining supported control panel without dedicated documentation.

To view this documentation, visit:

<div class="grid cards" markdown>

-   :aetherx-axb-directadmin: &nbsp; __[CSF: Install DirectAdmin](../../install/install.md#install-directadmin)__

    ---

    Official CSF documentation for installing DirectAdmin and CSF integration.
</div>

<br />
<br />

### DirectAdmin: Install Error

We have resolved an installation issue affecting the [DirectAdmin](https://directadmin.com/) control panel that could cause the installation process to fail completely.

Previously, users may have encountered the following error during installation:

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      ./install.directadmin.sh: line 1196: syntax error: unexpected end of file
      ```

<br />

After the `v15.09` update, the ability to install CSF integration into DirectAdmin should be restored.

<br />
<br />

### CyberPanel: Fixed Vertical Scrollbar

[CyberPanel](https://cyberpanel.net/) previously had a bug that caused a small vertical scrollbar to appear at the top of each CSF page. This meant that when navigating to a new page, users had to scroll slightly further than expected for the page content to display correctly.

We have now removed this unnecessary internal scrollbar. The embedded iframe automatically adjusts its height to match the loaded CSF page, providing a smoother and more seamless scrolling experience.

We have provided a gif of the bug as it was:

<figure markdown="span">
    ![Cyberpanel › Verticle Scrollbar](../../assets/images/blog/release-1509/cyberpanel_scrollbar.gif){ width="500" }
    <figcaption>Cyberpanel › Verticle Scrollbar</figcaption>
</figure>

<br />
<br />

### CWP: Rebranding

Across various areas of the CSF codebase and documentation, the control panel now known as [Control Web Panel](https://control-webpanel.com/) was previously referred to as **CentOS Web Panel**.

This update corrects those references by rebranding all mentions of **CentOS Web Panel** to **Control Web Panel**, ensuring consistency with the panel’s current and official name.

**Why the change:**  
The control panel was originally named *CentOS Web Panel*, but was later renamed to *Control Web Panel* to avoid naming conflicts. Our updates simply reflect this change and do not alter functionality.

<br />
<br />

### CWP: Output Sanitization

During routine bug fixes related to Control Web Panel (CWP) integration, we identified an opportunity to further enhance security at the interface level.

To improve overall safety and reliability, we have updated our code to sanitize all data exchanged between CSF and Control Web Panel. This ensures that any information sent to or received from the control panel is properly filtered and validated before being processed or displayed.

**What this means:**
Output sanitization prevents unexpected or unsafe data from being interpreted by the control panel. This reduces the risk of malformed input, unintended behavior, or potential abuse; without affecting normal functionality or the user experience.

<br />
<br />


### CWP: Fixed Terminal Output

In update `v15.08`, we introduced a newly formatted output style for commands related to CSF. While this improved the terminal experience, it unintentionally affected [Control Web Panel](https://control-webpanel.com/) users.

As a result, the **Firewall Manager** section within the Control Web Panel displayed raw ANSI color codes instead of clean, readable output. This behavior was not intended and has now been corrected, ensuring the output is properly formatted when viewed through the control panel.

<br />

<figure markdown="span">
    ![Control Web Panel › Firewall Manager › Solution](../../assets/images/blog/release-1509/cwp_firewall_manager_problem.png){ width="500" }
    <figcaption>Control Web Panel › Firewall Manager › Problem</figcaption>
</figure>

<br />

We have added new logic which differentiates between CSF commands accessed via a GUI, and commands that have been triggered via TTY.

<figure markdown="span">
    ![Control Web Panel › Firewall Manager › Solution](../../assets/images/blog/release-1509/cwp_firewall_manager_fix.png){ width="500" }
    <figcaption>Control Web Panel › Firewall Manager › Solution</figcaption>
</figure>

<br />
<br />

### Webmin: Firewall Button Restored

In Webmin’s Authentic theme (dark mode), built-in JavaScript caused the **Firewall Configuration** button on the home page to be hidden when the page loaded.

The **Firewall Configuration** button provides direct access to CSF’s internal configuration page, allowing users to modify `/etc/csf/csf.conf` through a graphical interface instead of editing the file manually.

Although Webmin replaced the hidden button with a small icon in the top-left corner of the CSF home page that links to the same configuration area, the original button was no longer visible.

This update restores the **Firewall Configuration** button while retaining the icon added by Webmin, ensuring both access methods remain available.

<figure markdown="span">
    ![Webmin › Firewall Configuration](../../assets/images/blog/release-1509/webmin_firewall_configuration.png){ width="600" }
    <figcaption>Webmin › Firewall Configuration</figcaption>
</figure>

<br />
<br />

### OpenVPN and Docker Integration

As we have worked toward making all bash related scripts POSIX compliant; this change in standards caused our Docker and OpenVPN integration scripts to break.

We have now re-worked the scripts to be fully POSIX compliant, and also updated the code to be more optimized and clean.

Along with these changes, we have also introduced flags that are available for these scripts.

To view the scripts, you can download them from our :aetherx-axd-folder: `extras` folder within our [repository](https://github.com/Aetherinox/csf-firewall/tree/main/extras/scripts).

<br />

You have two ways to activate these scripts

1. Drop them in your CSF pre/post folder via :aetherx-axd-folder: `/usr/local/include/csf/post.d/openvpn.sh`, and automatically load them by restarting CSF.
2. Manually activate the scripts directly.

<br />

#### Automatic 

To activate these scripts automatically, drop them inside the folder:

<div class="icon-tree" markdown>
<code>
└── :aetherx-axs-folder:{ .icon-clr-tree-folder } usr  
    └── :aetherx-axs-folder:{ .icon-clr-tree-folder } local  
        └── :aetherx-axs-folder:{ .icon-clr-tree-folder } include  
            └── :aetherx-axs-folder:{ .icon-clr-tree-folder } csf  
                └── :aetherx-axs-folder:{ .icon-clr-tree-folder } pre.d  
                └── :aetherx-axs-folder:{ .icon-clr-tree-folder } post.d  
                    └── :aetherx-axd-file:{ .icon-clr-tree-file } docker.sh  
                    └── :aetherx-axd-file:{ .icon-clr-tree-file } openvpn.sh  
        └── :aetherx-axs-folder:{ .icon-clr-tree-folder } csf  
            ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } bin  
            │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } csfpre.sh  
            │   └── :aetherx-axd-file:{ .icon-clr-tree-file } csfpost.sh  
</code>
</div>

<br />

Once the scripts are added to the correct path, restart CSF using the command:

=== ":aetherx-axs-command: Command"

    ``` shell
    sudo csf -ra
    ```

<br />

#### Manual

You can activate the `docker.sh` and `openvpn.sh` integration scripts manually. First you will need to download them from our [repository](https://github.com/Aetherinox/csf-firewall/tree/main/extras/scripts) and place them somewhere on your server.

Once you have them on your server, set the permissions to be **executable**:

=== ":aetherx-axs-command: Command"

    ```bash
    sudo chmod +x /path/to/docker.sh
    sudo chmod +x /path/to/openvpn.sh
    ```

<br />

Finally, you can run the scripts with the commands:

=== ":aetherx-axs-command: Command"

    ```bash
    sudo sh /usr/local/include/csf/post.d/openvpn.sh
    ```

<br />

You should see the following output:

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      PASS               Found installed package CSF + LFD  
      PASS               Found installed package OpenVPN    
      PASS               Found installed package iptables   
      PASS               Declared iptables4 binary /usr/sbin/iptables 
      PASS               Declared iptables6 binary /usr/sbin/ip6tables 
      INFO               Using the following values:                  
                            Ethernet Adapter         eth0
                            Public IP                XX.XX.XX.XX
                            VPN Tunnel Adapter       tun0
      INFO               Starting OpenVPN integration with CSF 
                            + RULES [ADD] -A INPUT -i tun+ -j ACCEPT 
                            + RULES [ADD] -A FORWARD -i tun+ -j ACCEPT 
                            + RULES [ADD] -A FORWARD -o tun0 -j ACCEPT 
                            + RULES [ADD] -t nat -A POSTROUTING -o eth0 -j MASQUERADE 
                            + RULES [ADD] -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE 
                            + RULES [ADD] -A INPUT -i eth0 -m state --state NEW -p udp --dport 1194 -j ACCEPT 
                            + RULES [ADD] -A FORWARD -i tun+ -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT 
                            + RULES [ADD] -A FORWARD -i eth0 -o tun+ -m state --state RELATED,ESTABLISHED -j ACCEPT 
                            + RULES [ADD] -t nat -A POSTROUTING -j SNAT --to-source XX.XX.XX.XX 
                            + RULES [ADD] -A OUTPUT -o tun+ -j ACCEPT 
      ```

<br />

You can also activate the `--help` flag:

=== ":aetherx-axs-command: Command"

    ```bash
    sudo sh /usr/local/include/csf/post.d/openvpn.sh --help
    ```

<br />

Which will output:

=== ":aetherx-axs-square-terminal: Output"

      ```console
      ConfigServer Firewall - Docker Patch - v15.0.9
      https://github.com/Aetherinox/csf-firewall
      Sets up your firewall rules t work alongside OpenVPN.
      This script requires that you have iptables installed on your system.
      The required packages will be installed if you do not have them.
      openvpn.sh [ --restart | --flush | --detect | --dryrun | --version | --help ]

      Syntax:                                         
            Command            openvpn.sh [ --option [ arg ] ]
            Options            openvpn.sh [ -h | --help ]
                -A                required                        
                -A...             required; multiple can be specified
                [ -A ]            optional                        
                [ -A... ]         optional; multiple can be specified
                { -A | -B }       one or the other; do not use both
            Examples           openvpn.sh --detect 
                                openvpn.sh --dryrun 
                                openvpn.sh --version 
                                openvpn.sh --help | -h | /?

      Flags:                                         
            -D,  --detect                       lists the detected values for ethernet adapter, tunnel, and public ip
            -r,  --restart                      restart csf and lfd services        
            -f,  --flush                        flush all iptable rules from server 
            -d,  --dryrun                       simulates installation, does not install csf <default> false 
            -v,  --version                      current version of this utilty <current> 15.0.9 
            -h,  --help                         show this help menu          
      ```

<br />

<br />
<br />


<br />

---

<br />

## Full Changelog

The full changelog is available [here](../../about/changelog.md).

<br />
<br />