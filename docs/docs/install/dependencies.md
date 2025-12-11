---
title: CSF › Dependencies
tags:
    - install
    - dependencies
    - apt
    - apt-get
    - dnf
    - cpan
    - cpanm
    - yum
---

# Dependencies <!-- omit from toc -->

To ensure ConfigServer Security & Firewall (CSF) functions correctly, all required dependencies must be installed. Some dependencies are essential for the core operation of CSF, while others are only necessary if you plan to use specific optional features.

<br />

## Install

For our documentation, we are going to include all packages you will need in order to run all functionality within CSF. A lot of the packages listed below will be installed along with the base `perl` package; however, we've included them to ensure nothing gets left behind.

<br />

### Minimal Dependencies

The following are a list of the minimal dependencies required for CSF to function. This does not include packages such as gd library which are required if you plan to make use of the statistics feature which is enabled in the `/etc/csf/csf.conf` with the setting `ST_ENABLE = "1"`.

<br />

=== ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

    ``` shell
    # #
    #   Minimum Dependencies
    # #

    sudo apt-get update && sudo apt-get install -y \
      ipset \
      libcrypt-ssleay-perl \
      libio-socket-inet6-perl \
      libio-socket-ssl-perl \
      libnet-libidn-perl \
      libsocket6-perl \
      perl \
      wget
    ```

=== ":aetherx-axb-redhat: CentOS/RHEL (yum/dnf)"

    ``` shell
    # #
    #   Minimum Dependencies
    # #

    sudo yum makecache && sudo yum install -y \
      ipset \
      perl \
      perl-IO-Socket-INET6 \
      perl-IO-Socket-SSL.noarch \
      perl-libwww-perl \
      perl-Net-LibIDN2 \
      perl-Net-SSLeay \
      perl-Socket6 \
      wget
    ```

=== ":aetherx-axs-onion: Perl (CPAN)"

    ``` shell
    # #
    #   Debian/Ubuntu
    # #

    sudo apt-get update && sudo apt-get install -y perl build-essential

    # #
    #   CentOS/RHEL
    # #

    sudo yum makecache && sudo yum groupinstall 'Development Tools' && sudo yum install -y perl cpan

    # #
    #   Minimum Dependencies
    # #

    sudo cpan -i \
      IO::Socket::INET6 \
      IO::Socket::SSL \
      LWP \
      Net::LibIDN \
      Net::SSLeay \
      Socket6
    ```

=== ":aetherx-axs-onion: Perl (CPANMINUS)"

    ``` shell
    # #
    #   Debian/Ubuntu
    # #

    sudo apt-get update && sudo apt-get install -y perl cpanminus

    # #
    #   CentOS/RHEL
    # #

    sudo yum makecache && sudo yum install -y perl perl-App-cpanminus

    # #
    #   Minimum Dependencies
    # #

    sudo cpanm \
      IO::Socket::INET6 \
      IO::Socket::SSL \
      LWP \
      Net::LibIDN \
      Net::SSLeay \
      Socket6
    ```

<br />

### Full Dependencies

The following commands allow you to install the full list of dependencies for CSF. This includes all optional features such as the statistics module, and `sendmail`.

<br />

=== ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

    ```bash
    # #
    #   Full Dependencies
    # #

    sudo apt-get update && sudo apt-get install -y \
      dnsutils \
      ipset \
      libcrypt-ssleay-perl \
      libgd-graph-perl \
      libio-socket-inet6-perl \
      libio-socket-ssl-perl \
      libjson-perl \
      liblwp-protocol-https-perl \
      libnet-libidn-perl \
      libnet-ssleay-perl \
      libsocket6-perl \
      libtime-hires-perl \
      libwww-perl \
      perl \
      sendmail \
      wget
    ```

=== ":aetherx-axb-redhat: CentOS/RHEL (yum/dnf)"

    ```bash
    # #
    #   Full Dependencies
    # #

    sudo yum makecache && sudo yum install -y \
      bind-utils \
      ipset \
      net-tools \
      perl \
      perl-Crypt-SSLeay \
      perl-GDGraph \
      perl-IO-Socket-INET6 \
      perl-IO-Socket-SSL.noarch \
      perl-JSON \
      perl-libwww-perl \
      perl-LWP-Protocol-https.noarch \
      perl-Math-BigInt \
      perl-Net-LibIDN2 \
      perl-Net-SSLeay \
      perl-Socket \
      perl-Socket6 \
      perl-Time-HiRes \
      sendmail \
      wget
    ```

=== ":aetherx-axs-onion: Perl (CPAN)"

    For the **Statistics** feature, ensure GD C library headers are installed first:

    * Debian/Ubuntu: `sudo apt-get install -y libgd-dev`
    * RHEL/CentOS: `sudo yum install -y gd-devel`

    ```bash

    # #
    #   Debian/Ubuntu
    # #

    sudo apt-get update && sudo apt-get install -y perl libgd-dev

    # #
    #   CentOS/RHEL
    # #

    sudo yum makecache && sudo yum install -y epel-release perl gd-devel

    # #
    #   Full Dependencies
    # #

    sudo cpan -i \
      Crypt::SSLeay \
      Digest::MD5 \
      Digest::SHA \
      Email::Valid \
      GD::Graph \
      IO::Socket::INET6 \
      IO::Socket::SSL \
      JSON \
      LWP \
      LWP::Protocol::https \
      LWP::UserAgent \
      Net::LibIDN \
      Net::SSLeay \
      Socket \
      Socket6 \
      Time::HiRes
    ```

=== ":aetherx-axs-onion: Perl (CPANMINUS)"

    For the **Statistics** feature, ensure GD C library headers are installed first:

    * Debian/Ubuntu: `sudo apt-get install -y libgd-dev`
    * RHEL/CentOS: `sudo yum install -y gd-devel`

    ```bash
    # #
    #   Debian/Ubuntu
    # #

    sudo apt-get update && sudo apt-get install -y perl libgd-dev cpanminus

    # #
    #   CentOS/RHEL
    # #

    sudo yum makecache && sudo yum install -y epel-release perl gd-devel perl-App-cpanminus

    # #
    #   Full Dependencies
    # #

    sudo cpanm \
      Crypt::SSLeay \
      Digest::MD5 \
      Digest::SHA \
      Email::Valid \
      GD::Graph \
      IO::Socket::INET6 \
      IO::Socket::SSL \
      JSON \
      LWP \
      LWP::Protocol::https \
      LWP::UserAgent \
      Net::LibIDN \
      Net::SSLeay \
      Socket \
      Socket6 \
      Time::HiRes
    ```

<br />

### Optional Dependencies

If you decided to opt for the [Full Dependencies](#full-dependencies) install above, you do not need to do this step since the full dependency instructions already include these packages.

<br />
<br />
<br />

#### <!-- md:feature Email Alerts -->

CSF can send email alerts for blocked IPs, login failures, or other events. To enable this functionality, you need a working Mail Transfer Agent (MTA) such as `sendmail` or `postfix`.

??? Notes "Important Notes to Remember"

    The following should be taken into consideration when installing the dependencies for email alerts:

    - After installing sendmail, ensure the MTA is enabled and running:
        - Debian/Ubuntu: `sudo systemctl enable --now sendmail`
        - RHEL/CentOS: `sudo systemctl enable --now sendmail`
    - You can also use `postfix` or another MTA if preferred — CSF will use whatever MTA is configured on the system.
    - This is optional if you do not need email alerts, but it is **highly recommended** for security monitoring.

<br />

=== ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

    ```bash
    sudo apt-get update && sudo apt-get install -y sendmail
    ```

=== ":aetherx-axb-redhat: CentOS/RHEL (yum/dnf)"

    ```bash
    sudo yum makecache && sudo yum install -y sendmail
    ```

<br />
<br />
<br />

#### <!-- md:feature Statistics / Graphs -->

CSF comes with an optional **Statistics** module which allows you to generate charts / graphs for various monitored aspects of CSF. To enable Statistics, you need the following:

  - :aetherx-axd-box-isometric:{ .icon-clr-purple } **CSF Config File**
      - Must open `/etc/csf/csf.conf` and set `ST_ENABLE = "1"`

  - :aetherx-axd-box-isometric:{ .icon-clr-purple } **GD Graphics Library (libgd)**
      - C library for creating and manipulating images (PNG, JPEG, GIF, etc.).  
      - Provides low-level graphics functions for CSF statistics.
      - :aetherx-axb-debian: **Debian/Ubuntu**: installing the Perl module `GD::Graph Perl Module` below will automatically pull in the necessary GD library.
      - :aetherx-axb-redhat: **RHEL/CentOS**: you may need `gd-devel`.

  - :aetherx-axd-box-isometric:{ .icon-clr-purple } **GD::Graph Perl Module**  
      - Perl module that depends on the GD library.  
      - Provides an API to draw charts and graphs (line, bar, pie, etc.) in Perl scripts.  
      - Used by CSF to render statistics graphs in the web interface.  
      - :aetherx-axb-debian: **Debian/Ubuntu**: install via (`libgd-graph-perl` or CPAN/CPANM.
      - :aetherx-axb-redhat: **RHEL/CentOS**: install via `perl-GDGraph` or CPAN/CPANM.

<br />

=== ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

    ``` shell
    # Install GD Graphics Library (C library) — usually pulled in automatically
    sudo apt-get update && sudo apt-get install -y libgd-dev

    # Install GD::Graph Perl module
    sudo apt-get install -y libgd-graph-perl
    ```

=== ":aetherx-axb-redhat: CentOS/RHEL (yum/dnf)"

    ``` shell
    # Install GD Graphics Library (C library) — usually pulled in automatically
    sudo yum makecache && sudo yum install -y gd-devel

    # Install GD::Graph Perl module
    sudo yum install -y perl-GDGraph
    ```

=== ":aetherx-axs-onion: Perl (CPAN)"

    ``` shell
    # Install GD::Graph Perl module (requires libgd-dev already installed)
    sudo cpan -i GD::Graph
    ```

=== ":aetherx-axs-onion: Perl (CPANMINUS)"

    ``` shell
    # Install GD::Graph Perl module (requires libgd-dev already installed)
    sudo cpanm GD::Graph
    ```

<br />
<br />
<br />

#### <!-- md:feature Blocklists -->

[Blocklists](../usage/blocklists.md) in CSF allow you to manage lists of IP addresses that should be denied access to your server. Blocklists can come from official CSF sources, or from third-party vendors. They help automate the process of blocking potentially harmful traffic from gaining access to your server.

Blocklists can be handled in two ways:

1. **Standard iptables rules:** Each IP in the blocklist generates its own iptables rule when CSF starts. This works well for small lists but can become resource-intensive for lists with thousands of entries.
2. **IPSET integration:** If IPSET is installed and enabled in the CSF configuration, each IP in the blocklist is added to an IPSET set. CSF then loads these IPSET lists instead of creating individual iptables rules. This method is much more efficient and reduces system resource usage for large blocklists.

<br />

If you would like to utilize CSF's built-in IPSET integration, you will need to install the following dependencies:

=== ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

    ``` shell
    sudo apt-get update
    sudo apt-get install -y ipset
    ```

=== ":aetherx-axb-redhat: CentOS/RHEL (yum/dnf)"

    ``` shell
    sudo yum install -y epel-release
    sudo yum makecache
    sudo yum install -y ipset
    ```

<br />

This section does not give detailed instructions on how to set up Blocklists or IPSETs, however, if you want to
read the full chapter on setting this up, see [Introduction to IPSETs](../usage/ipset.md) and 
[Setting Up Blocklists](../usage/blocklists.md).

<div class="grid" markdown>

:aetherx-axs-network-wired: &nbsp; __[Introduction to IPSETs](../usage/ipset.md)__
{ .card }

:aetherx-axs-ban: &nbsp; __[Setting Up Blocklists](../usage/blocklists.md)__
{ .card }

</div>

<br />
<br />
<br />

#### <!-- md:feature DNS Lookups -->

CSF supports optional DNS Lookups, which allow the firewall to resolve IP addresses into hostnames and perform reverse lookups. This can be useful for logging, reporting, or applying rules based on domain names rather than just IP addresses. For example, CSF can show resolved hostnames in alert emails or in the web interface, making it easier to understand who is connecting to your server.

Additionally, the `csf -g` and `csf -a` commands can use DNS lookups if the required packages are installed, allowing IP addresses to be automatically resolved to hostnames when searching or adding entries.

To enable DNS lookups, CSF requires the `dnsutils` package (on Debian/Ubuntu) or `bind-utils` (on RedHat/CentOS). These packages provide tools such as `dig` and `nslookup` that CSF uses to perform DNS queries.

=== ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

    ``` shell
    sudo apt-get update
    sudo apt-get install -y dnsutils
    ```

=== ":aetherx-axb-redhat: CentOS/RHEL (yum/dnf)"

    ``` shell
    sudo yum makecache
    sudo yum install -y bind-utils
    ```

<br />
<br />
<br />

#### <!-- md:feature GeoIP Blocking -->

[Geographical IP Blocks](../usage/geoip.md) in CSF allows you to block or allow traffic based on the country of origin. This is useful for restricting access to your server from certain regions or implementing geo-specific rules.  

This feature does **not require a traditional system package** to function. Instead, it relies on external databases that map IP addresses to countries. 

<br />

You have two options for providing these databases:

1. MaxMind GeoLite2 Databases
2. DB-IP, ipdeny.com, or iptoasn.com

If you opt to use `MaxMind`, you can automate the database updates by installing the following:

=== ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

    ``` shell
    sudo add-apt-repository ppa:maxmind/ppa
    sudo apt update
    sudo apt install geoipupdate
    ```

=== ":aetherx-axb-redhat: CentOS/RHEL (yum/dnf)"

    ``` shell
    sudo yum install -y epel-release
    sudo yum makecache
    sudo yum install -y geoipupdate
    ```

<br />

This section does not go into detailed instructions on how to set up Geographical IP blocking, 
however, if you want to read the full instructions for setting this up, review the chapter 
[Geographical IP Block Integration](../usage/geoip.md).

<div class="grid" markdown>

:aetherx-axd-earth-europe: &nbsp; __[Geographical IP Block Integration](../usage/geoip.md)__
{ .card }

</div>

<br />
<br />
<br />

#### <!-- md:feature CSGet -->

[CSGet](../advanced/csget/index.md) is a Perl-based script which runs as a system cron job. Its primary role is to 
communicate with the official CSF update servers and determine whether a new CSF version is available.

This component is used as an extension for the [CSF Web Interface](../install/webui.md).

<br />

Under normal operation, no additional Perl modules are required. However, if you choose to run CSGet in debug 
mode via the `--debug` flag; the perl module `diagnostics` must be installed.

=== ":aetherx-axb-redhat: RHEL/CentOS (yum/dnf)"

    Use the following to install Perl and its main dependencies on:
    
    - :aetherx-axb-redhat: RHEL
    - :aetherx-axb-centos: CentOS
    - :aetherx-axb-alma-linux: AlmaLinux
    - :aetherx-axb-rocky-linux: Rocky
    - :aetherx-axb-fedora: Fedora

    ```bash
    sudo dnf makecache
    sudo dnf install perl-Diagnostics
    ```

=== ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

    Use the following to install Perl and its main dependencies on:

    - :aetherx-axb-debian: Debian
    - :aetherx-axb-ubuntu: Ubuntu
    - :aetherx-axb-mint-linux: Mint
    - :aetherx-axb-pop-linux: Pop!
    - :aetherx-axb-elementary-linux: Elementary

    ```bash
    sudo apt update
    sudo apt install libdiagnostics-perl
    ```

<br />

More information about CSGet can be read in the chapter [Advanced › CSGet](../advanced/csget/index.md).

<div class="grid" markdown>

:aetherx-axs-block-brick-fire: &nbsp; __[Advanced › CSGet](../advanced/csget/index.md)__
{ .card }

</div>

<br />

---

<br />

## FAQ

The following is a list of questions a user may have regarding CSf dependencies, and information about certain issues that may arise:

<br />

??? faq "Perl: Can't locate XXXX/XXXX.pm in @INC"

    By installing all dependencies listed on this page, you should have everything required
    to run ConfigServer Firewall (CSF) correctly.

    If you attempt to run a CSF command such as `sudo csf -ra` and encounter an error
    similar to:

    === ":aetherx-axs-square-terminal: Output"

        ```shell
        Can't locate File/Copy.pm in @INC (you may need to install the File::Copy module) (@INC contains: /usr/local/csf/lib /usr/local/cpanel 
        /usr/local/lib64/perl5/5.32 /usr/local/share/perl5/5.32  /usr/lib64/perl5/vendor_perl /usr/share/perl5/vendor_perl 
        /usr/lib64/perl5 /usr/share/perl5) at /usr/local/csf/lib/ConfigServer/Messenger.pm line 34.
        ```

    This indicates that your system is still missing essential Perl modules required for
    CSF to operate.

    Make sure you've executed the installation commands provided on this page and that all
    required dependencies have been installed.

    Be aware that some Linux distributions include a bundled version of Perl which may be
    outdated or missing important core modules that modern versions provide. Such minimal
    Perl installations can prevent CSF from functioning until the missing components are
    manually installed.

??? faq "Perl: Using Minimal Distro Releases"

    If you are running a light-weight distro such as :aetherx-axb-alma-linux: [AlmaLinux (Minimal)](https://almalinux.org/get-almalinux/),
    your distro may include a copy of Perl, but may not have many of the core modules required
    for a program written in perl to function.

    You can run the commands listed on this page to install the required dependencies, or you can
    install `perl-core` with one of the following commands:

    === ":aetherx-axb-redhat: RHEL/CentOS (yum/dnf)"

        Use the following to install Perl and its main dependencies on:
        
        - :aetherx-axb-redhat: RHEL
        - :aetherx-axb-centos: CentOS
        - :aetherx-axb-alma-linux: AlmaLinux
        - :aetherx-axb-rocky-linux: Rocky
        - :aetherx-axb-fedora: Fedora

        ```bash
        sudo dnf makecache
        sudo dnf install perl-core
        ```

    === ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

        Use the following to install Perl and its main dependencies on:

        - :aetherx-axb-debian: Debian
        - :aetherx-axb-ubuntu: Ubuntu
        - :aetherx-axb-mint-linux: Mint
        - :aetherx-axb-pop-linux: Pop!
        - :aetherx-axb-elementary-linux: Elementary

        ```bash
        sudo apt update
        sudo apt install perl perl-modules perl-base
        ```

<br />

---

<br />

## Next Steps <!-- omit from toc -->

{==

Select what documentation you would like to proceed with next ...

==}

<div class="grid cards" markdown>

-   :aetherx-axd-download: &nbsp; __[Download CSF](./download.md)__

    ---

    The next part of the guide shows how to [download csf](./download.md) from
    our official sources, such as the GitHub repository, and place it on your
    server.
    
    It covers using `curl` or `wget` to fetch the files, as well as extracting
    them using either the traditional tar.gz method or the newer zip format.
    
    This step is essential to prepare your server for installing CSF and
    configuring the firewall.

</div>

<br />
<br />
