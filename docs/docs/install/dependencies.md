---
title: CSF › Dependencies
tags:
  - install
  - dependencies
---

# Dependencies <!-- omit from toc -->

To ensure ConfigServer Firewall & Security (CSF) functions correctly, all required dependencies must be installed. Some dependencies are essential for the core operation of CSF, while others are only necessary if you plan to use specific optional features.


<br />

## Optional Features
- To enable **Statistics** `ST_ENABLE = "1"`, you must install:
    - GB Graphics Library
    - GD::Graph Perl Module


<br />

## Install

For our documentation, we are going to include all packages you will need in order to run all functionality within CSF. A lot of the packages listed below will be installed along with the base `perl` package; however, we've included them to ensure nothing gets left behind.

Depending on your distro, pick your preferred installation method below:

=== "Debian/Ubuntu (apt-get)"

    ```bash
    apt-get update
    apt-get install -y perl \
      libio-socket-ssl-perl \
      libwww-perl \
      libjson-perl \
      libnet-ssleay-perl \
      libcrypt-ssleay-perl \
      liblwp-protocol-https-perl \
      libgd-graph-perl \
      libio-socket-inet6-perl \
      libsocket6-perl \
      libnet-libidn-perl \
      libtime-hires-perl \
      sendmail-bin \
      dnsutils \
      unzip \
      wget
    ```

=== "CentOS/RHEL (yum/dnf)"

    ```bash
    yum install -y perl \
      perl-libwww-perl \
      perl-IO-Socket-SSL.noarch \
      perl-JSON \
      perl-Net-SSLeay \
      perl-Net-LibIDN \
      perl-Crypt-SSLeay \
      perl-LWP-Protocol-https.noarch \
      perl-GDGraph \
      perl-Math-BigInt \
      perl-Time-HiRes \
      perl-Socket \
      perl-Socket6 \
      perl-IO-Socket-Inet6 \
      wget \
      unzip \
      net-tools \
      ipset \
      bind-utils
    ```

=== "Perl (CPAN)"

    ```bash
    perl -MCPAN -eshell
    cpan> install IO::Socket::SSL IO::Socket::INET6 Socket6 Net::LibIDN \
    LWP LWP::Protocol::https LWP::UserAgent JSON Net::SSLeay \
    Crypt::SSLeay Digest::MD5 Digest::SHA Email::Valid \
    GD::Graph Time::HiRes Socket
    ```

<br />

---

<br />

## Next Steps <!-- omit from toc -->

{==

Select what documentation you would like to proceed with next ...

==}

<div class="grid cards" markdown>

-   :material-file: &nbsp; __[Download & Install CSF](./install.md)__

    ---

    After installing the required dependencies, proceed to the setup instructions to download 
    and install **ConfigServer Firewall & Security (CSF)**.

</div>
