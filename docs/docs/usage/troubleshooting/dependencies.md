---
title: Usage › Troubleshooting › Dependencies
tags:
    - usage
    - configure
    - troubleshoot
    - dependencies
    - packages
status: new
---

# Troubleshooting › Dependencies

This page provides an overview of common dependency-related errors and issues that may occur during the installation or use of ConfigServer Firewall.

<br />

## Introduction

By default, when ConfigServer Firewall starts, it automatically checks that the following dependencies are installed on your system:

=== ":aetherx-axs-file-code: /usr/sbin/csf"

    ```perl
    my @binaries = (
        "IPTABLES",
        "IPTABLES_SAVE",
        "IPTABLES_RESTORE",
        "MODPROBE",
        "SENDMAIL",
        "PS",
        "VMSTAT",
        "LS",
        "MD5SUM",
        "TAR",
        "CHATTR",
        "UNZIP",
        "GUNZIP",
        "DD",
        "TAIL",
        "GREP",
        "HOST"
    );
    ```

<br />

??? note "Note: Sendmail Binary"

    The dependency `SENDMAIL` will be **skipped** if you have the setting `LF_ALERT_SMTP` enabled in 
    your `/etc/csf/csf.conf`.

<br />

If you enable the setting `IPV6` in your `/etc/csf/csf.conf`, the following dependencies will be loaded:

- :aetherx-axd-box-open:{ .icon-clr-yellow } IP6TABLES
- :aetherx-axd-box-open:{ .icon-clr-yellow } IP6TABLES_SAVE
- :aetherx-axd-box-open:{ .icon-clr-yellow } IP6TABLES_RESTORE

<br />

If you he enable the setting `LF_IPSET` in your `/etc/csf/csf.conf`, the following dependencies will be loaded:

- :aetherx-axd-box-open:{ .icon-clr-yellow } IPSET

<br />

If you enable the settings `IP` or `IFCONFIG` in your `/etc/csf/csf.conf`, the following dependencies will be loaded:

- :aetherx-axd-box-open:{ .icon-clr-yellow } IP
- :aetherx-axd-box-open:{ .icon-clr-yellow } IFCONFIG

<br />

If you set `ST_ENABLE = "1"` in your `/etc/csf/csf.conf`, the following dependencies will be loaded:

- :aetherx-axd-box-open:{ .icon-clr-yellow } GD::Graph

    === ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

        ``` shell
        sudo apt-get update && sudo apt-get install -y \
          libgd-dev \
          libgd-graph-perl
        ```

    === ":aetherx-axb-redhat: CentOS/RHEL (yum/dnf)"

        ``` shell
        sudo yum makecache && sudo yum install -y \
          gd-devel \
          perl-GDGraph
        ```

<br />

If you set `CF_ENABLE = "1"` in your `/etc/csf/csf.conf`, the following dependencies will be loaded:

- :aetherx-axd-box-open:{ .icon-clr-yellow } LWP::Protocol::https

    === ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

        ``` shell
        sudo apt-get update && sudo apt-get install -y \
          libwww-perl \
          liblwp-protocol-https-perl \
          libnet-ssleay-perl \
          libio-socket-ssl-perl
        ```

    === ":aetherx-axb-redhat: CentOS/RHEL (yum/dnf)"

        ``` shell
        sudo yum makecache && sudo yum install -y \
          perl-libwww-perl \
          perl-LWP-Protocol-https \
          perl-Net-SSLeay \
          perl-IO-Socket-SSL
        ```

<br />

Most dependencies are automatically installed with the majority of Linux distributions. However, certain packages, such as `sendmail`, may require manual installation. The exact requirements can vary depending on the type of installation performed for your distribution. For example, a "Minimal" installation of AlmaLinux includes only the core system components and does not install additional dependencies.

<br />

---

<br />

## Troubleshooting

The following is a list of common errors or issues you may possibility receive while installing or operating CSF. These are to guide you on how to fix these issues.

??? faq "Perl Dependencies: Using Minimal Distro Releases"

    <div class="details-content">

    If you are running a light-weight distro such as :aetherx-axb-alma-linux-2: [AlmaLinux (Minimal)](https://almalinux.org/get-almalinux/),
    your distro may include a copy of Perl, but may not have many of the core modules required
    for a program written in perl to function.

    You can run the commands listed on this page to install the required dependencies, or you can
    install `perl-core` with one of the following commands:

    === ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

        Use the following to install Perl and its main dependencies on:

        - :aetherx-axb-debian: Debian
        - :aetherx-axb-ubuntu: Ubuntu
        - :aetherx-axb-linux-mint: Mint
        - :aetherx-axb-pop-linux: Pop!
        - :aetherx-axb-elementary-linux: Elementary

        ```bash
        sudo apt-get update && sudo apt-get install -y \
          perl perl-modules \
          perl-base \
          libwww-perl \
          liblwp-protocol-https
        ```

    === ":aetherx-axb-redhat: RHEL/CentOS (yum/dnf)"

        Use the following to install Perl and its main dependencies on:
        
        - :aetherx-axb-redhat: RHEL
        - :aetherx-axb-centos: CentOS
        - :aetherx-axb-alma-linux: AlmaLinux
        - :aetherx-axb-rocky-linux: Rocky
        - :aetherx-axb-fedora: Fedora

        ```bash
        sudo yum makecache && sudo yum install perl \
          perl-core \
          perl-libwww-perl \
          perl-LWP-Protocol-https \
          perl-URI
        ```

    </div>


??? faq "URLGET set to use LWP but perl module is not installed, reverting to HTTP::Tiny"

    <div class="details-content">

    <h3>Problem</h5>

    When accessing the [Web Interface](../../install/webui.md), the following error may appear at the top of the page:

    ```shell
    *WARNING* URLGET set to use LWP but perl module is not installed, fallback to using CURL/WGET
    ```

    <figure markdown="span">
        ![CSF Web Interface › Perl `GETURL` Dependency Error](../../assets/images/usage/troubleshooting/dependencies/01.png){ width="700" }
        <figcaption>CSF Web Interface › Perl `GETURL` Dependency Error</figcaption>
    </figure>

    <br />

    This error triggers when your workstation has not satisfied all of the perl dependencies required for CSF to run.

    <br />

    <h3>Solution</h5>

    Open your workstation's :aetherx-axd-rectangle-terminal:{ .icon-clr-yellow } terminal, and run one of the following commands:

    === ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

        ``` shell
        sudo apt-get update && sudo apt-get install -y \
          libwww-perl
        ```

    === ":aetherx-axb-redhat: CentOS/RHEL (yum/dnf)"

        ``` shell
        sudo yum makecache && sudo yum install -y \
          perl-libwww-perl
        ```
  
    </div>


??? faq "Can't locate lib.pm in @INC"

    <div class="details-content">

    <h3>Problem</h5>

    ```shell
    Can't locate lib.pm in @INC (you may need to install the lib module)
        (@INC contains:   /usr/local/lib64/perl5/5.32
                          /usr/local/share/perl5/5.32
                          /usr/lib64/perl5/vendor_perl
                          /usr/share/perl5/vendor_perl
                          /usr/lib64/perl5
                          /usr/share/perl5) at /usr/sbin/csf line 30.

    BEGIN failed--compilation aborted at /usr/sbin/csf line 30.
    ```

    <figure markdown="span">
        ![CSF Web Interface › Perl `lib.pm` Error](../../assets/images/usage/troubleshooting/dependencies/04.png){ width="700" }
        <figcaption>CSF Web Interface › Perl `lib.pm` Error</figcaption>
    </figure>

    <br />

    This error typically indicates that you are missing major parts of the perl infastructure.

    <br />

    <h3>Solution</h5>

    Open your workstation's :aetherx-axd-rectangle-terminal:{ .icon-clr-yellow } terminal, and run one of the following commands:

    === ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

        ``` shell
        sudo apt-get update && sudo apt-get install -y \
          perl-modules-5.32 \
          build-essential \
          autoconf \
          automake \
          libtool \
          linux-headers-$(uname -r)
        ```

    === ":aetherx-axb-redhat: CentOS/RHEL (yum/dnf)"

        ``` shell
        sudo yum makecache && sudo yum install -y \
          perl \
          perl-core \
          perl-devel \
          perl-lib \
          perl-CPAN \
          gcc \
          make \
          autoconf \
          automake \
          libtool \
          glibc-headers \
          kernel-headers
        ```

    <br />

    You can confirm if the packages installed above work by opening your :aetherx-axd-rectangle-terminal:{ .icon-clr-yellow } terminal and running the command:

    ``` shell
    perl -Mlib -e 'print "lib.pm OK\n"'
    ```

    <br />

    You will get one of the following two possible outputs:

    === ":aetherx-axs-square-check: Success"

          ```shell
          $ perl -Mlib -e 'print "lib.pm OK\n"'

          lib.pm OK
          ```

    === ":aetherx-axs-square-x: Failure"

          ```shell
          $ perl -Mlib -e 'print "lib.pm OK\n"'

          Can't locate lib.pm in @INC (you may need to install the lib module)
              (@INC contains:   /usr/local/lib64/perl5/5.32
                                /usr/local/share/perl5/5.32
                                /usr/lib64/perl5/vendor_perl
                                /usr/share/perl5/vendor_perl
                                /usr/lib64/perl5
                                /usr/share/perl5).

          BEGIN failed--compilation aborted.
          ```

    <br />

    If you get the output `lib.pm OK`, the perl module should now be functioning properly.

    </div>


??? faq "Can't locate LWP/UserAgent.pm in @INC"

    <div class="details-content">

    <h3>Problem</h5>

    ```shell
    Can't locate LWP/UserAgent.pm in @INC (you may need to install the LWP::UserAgent module)
        (@INC contains:   /usr/local/test/lib
                          /usr/local/cpanel
                          /usr/local/lib64/perl5/5.32
                          /usr/local/share/perl5/5.32
                          /usr/lib64/perl5/vendor_perl
                          /usr/share/perl5/vendor_perl
                          /usr/lib64/perl5
                          /usr/share/perl5) at /usr/local/csf/lib/ConfigServer/CloudFlare.pm line 36.

    BEGIN failed--compilation aborted at /usr/local/csf/lib/ConfigServer/CloudFlare.pm line 36.
    ```

    <figure markdown="span">
        ![CSF Web Interface › Perl `LWP/UserAgent.pm` Error](../../assets/images/usage/troubleshooting/dependencies/03.png){ width="700" }
        <figcaption>CSF Web Interface › Perl `LWP/UserAgent.pm` Error</figcaption>
    </figure>

    <br />

    This error can be triggered from any of the following actions:

    - Accessing CSF Web Interface
        - Using the **Cloudflare** module.
        - Performing an update to CSF.
    - In :aetherx-axd-rectangle-terminal:{ .icon-clr-yellow } terminal when running `sudo csf -ra`

    <br />

    <h3>Solution</h5>

    Open your workstation's :aetherx-axd-rectangle-terminal:{ .icon-clr-yellow } terminal, and run one of the following commands:

    === ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

        ``` shell
        sudo apt-get update && sudo apt-get install -y \
          libwww-perl \
          liblwp-protocol-https-perl
        ```

    === ":aetherx-axb-redhat: CentOS/RHEL (yum/dnf)"

        ``` shell
        sudo yum makecache && sudo yum install -y \
          perl-libwww-perl \
          perl-LWP-Protocol-https
        ```

    <br />

    You can confirm if the packages installed above work by opening your :aetherx-axd-rectangle-terminal:{ .icon-clr-yellow } terminal and running the command:

    ``` shell
    perl -MLWP::UserAgent -e 'print "LWP OK\n"'
    ```

    <br />

    You will get one of the following two possible outputs:

    === ":aetherx-axs-square-check: Success"

          ```shell
          $ perl -MLWP::UserAgent -e 'print "LWP OK\n"'

          LWP OK
          ```

    === ":aetherx-axs-square-x: Failure"

          ```shell
          $ perl -MLWP::UserAgent -e 'print "LWP OK\n"'

          Can't locate LWP/UserAgent.pm in @INC (you may need to install the LWP::UserAgent module)
            (@INC contains:   /usr/local/lib64/perl5/5.32
                              /usr/local/share/perl5/5.32
                              /usr/lib64/perl5/vendor_perl
                              /usr/share/perl5/vendor_perl
                              /usr/lib64/perl5
                              /usr/share/perl5).
            BEGIN failed--compilation aborted.
          ```

    <br />

    If you get the output `LWP OK`, the perl module should now be functioning properly.

    </div>


??? faq "Protocol scheme 'https' is not supported (LWP::Protocol::https not installed)"

    <div class="details-content">

    <h3>Problem</h5>

    ```shell
    Protocol scheme 'https' is not supported (LWP::Protocol::https not installed)

    Can't locate LWP/Protocol/https.pm in @INC (you may need to install the LWP::Protocol::https module)
        (@INC contains:   /usr/local/lib64/perl5/5.32
                          /usr/local/share/perl5/5.32
                          /usr/lib64/perl5/vendor_perl
                          /usr/share/perl5/vendor_perl
                          /usr/lib64/perl5 /usr/share/perl5).

    BEGIN failed--compilation aborted.
    ```

    <figure markdown="span">
        ![CSF Web Interface › Perl `LWP::Protocol::https` Error](../../assets/images/usage/troubleshooting/dependencies/02.png){ width="700" }
        <figcaption>CSF Web Interface › Perl `LWP::Protocol::https` Error</figcaption>
    </figure>

    <br />

    This error can be triggered from any of the following actions:

    - Accessing CSF Web Interface
        - Using the **Cloudflare** module.
        - Performing an update to CSF.
    - In :aetherx-axd-rectangle-terminal:{ .icon-clr-yellow } terminal when running `sudo csf -ra`

    <br />

    <h3>Solution</h5>

    Open your workstation's :aetherx-axd-rectangle-terminal:{ .icon-clr-yellow } terminal, and run one of the following commands:

    === ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

        ``` shell
        sudo apt-get update && sudo apt-get install -y \
          libwww-perl \
          liblwp-protocol-https-perl \
          libnet-ssleay-perl \
          libio-socket-ssl-perl
        ```

    === ":aetherx-axb-redhat: CentOS/RHEL (yum/dnf)"

        ``` shell
        sudo yum makecache && sudo yum install -y \
          perl-libwww-perl \
          perl-LWP-Protocol-https \
          perl-Net-SSLeay \
          perl-IO-Socket-SSL
        ```

    <br />

    You can confirm if the packages installed above work by opening your :aetherx-axd-rectangle-terminal:{ .icon-clr-yellow } terminal and running the command:

    ``` shell
    perl -MLWP::Protocol::https -e 'print "HTTPS OK\n"'
    ```

    <br />

    You will get one of the following two possible outputs:

    === ":aetherx-axs-square-check: Success"

          ```shell
          $ perl -MLWP::Protocol::https -e 'print "HTTPS OK\n"'

          HTTPS OK
          ```

    === ":aetherx-axs-square-x: Failure"

          ```shell
          $ perl -MLWP::Protocol::https -e 'print "HTTPS OK\n"'

          Protocol scheme 'https' is not supported (LWP::Protocol::https not installed)
          ```

    <br />

    If you get the output `HTTPS OK`, the perl module should now be functioning properly.

    </div>

??? faq "Binary location for [SENDMAIL] [/usr/sbin/sendmail] in /etc/csf/csf.conf is either incorrect, is not installed or is not executable"

    <div class="details-content">

    <h3>Problem</h5>

    When starting up CSF, you may receive the following error in your :aetherx-axd-rectangle-terminal:{ .icon-clr-yellow } terminal related to `SENDMAIL`:

    ```shell
    *WARNING* Binary location for [SENDMAIL] [/usr/sbin/sendmail] in /etc/csf/csf.conf is either incorrect, is not installed or is not executable
    ```

    <br />

    This error triggers when you do not have the binary `SENDMAIL` installed, and nothing defined for the setting `LF_ALERT_SMTP` in your `/etc/csf/csf.conf`.

    <br />

    <h3>Solution</h5>

    Open your workstation's :aetherx-axd-rectangle-terminal:{ .icon-clr-yellow } terminal, and run one of the following commands:

    === ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

        ``` shell
        sudo apt-get update && sudo apt-get install -y \
          sendmail
        ```

    === ":aetherx-axb-redhat: CentOS/RHEL (yum/dnf)"

        ``` shell
        sudo yum makecache && sudo yum install -y \
          sendmail sendmail-cf

        sudo systemctl enable --now sendmail
        ```

    <br />

    Refresh the CSF web interface and the error should be gone.

    </div>


??? faq "Browser: Secure Connection Failed"

    <div class="details-content">

    <h3>Problem</h5>

    Some users may attempt to access the CSF web interface, and will be given the following error:

    ```shell
    Secure Connection Failed

    The connection to the server was reset while the page was loading.
        The page you are trying to view cannot be shown because the authenticity of the received data could not be verified.
        Please contact the website owners to inform them of this problem.
    ```

    <figure markdown="span">
        ![CSF Web Interface › Perl `Secure Connection Failed` Error](../../assets/images/usage/troubleshooting/dependencies/05.png){ width="700" }
        <figcaption>CSF Web Interface › Perl `Secure Connection Failed` Error</figcaption>
    </figure>

    <br />

    This error triggers when you do not have the package `perl-Net-SSLeay` installed.

    <br />

    <h3>Solution</h5>

    Open your workstation's :aetherx-axd-rectangle-terminal:{ .icon-clr-yellow } terminal, and run one of the following commands:

    === ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

        ``` shell
        sudo apt-get update && sudo apt-get install -y \
          perl-Net-SSLeay
        ```

    === ":aetherx-axb-redhat: CentOS/RHEL (yum/dnf)"

        ``` shell
        sudo yum makecache && sudo yum install -y \
          perl-Net-SSLeay
        ```

    <br />

    Refresh the CSF web interface and the error should be gone.

    </div>



<br />
<br />
