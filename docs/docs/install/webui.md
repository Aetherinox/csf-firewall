---
title: Install › Enable CSF Web Interface
tags:
  - install
  - setup
---

# Enable Web Interface <!-- omit from toc -->

ConfigServer Firewall provides an optional web-based interface that lets you manage CSF from your browser. With it, you can configure settings, and blacklist or whitelist IPs without using commands or editing configuration files manually. If you choose not to enable the interface, all management must be done directly through the CSF config files, or by running commands through your shell.

<br />

---

<br />

## Setup

This section covers the initial setup of the CSF web interface with only the essential requirements. Follow these steps to get the web interface up and running quickly.

<br />

### Step 1: Install Perl Modules

CSF's web interface requires several Perl modules. If you followed our [dependencies](./dependencies.md) guide, these modules may already be installed. If not, run one of the commands below on your server.

<br />

#### Installation Options

You only need to **choose one** of the methods below. We provide multiple options for your convenience:

- :aetherx-axb-debian: **Debian/Ubuntu** › using `apt-get`
- :aetherx-axb-redhat: **CentOS/RHEL** › using `yum` or `dnf`
- :aetherx-axs-onion: **Perl CPAN** › using the stock `cpan` client
- :aetherx-axs-onion: **Perl CPANM** › using `cpanm` (recommended for faster, non-interactive installs)

<br />

#### Dependency Levels

Each installation method below provides two options:

<!-- md:option Full Dependencies -->
: Installs **all modules** required to run every aspect of CSF.

<!-- md:option Minimum Dependencies -->
: Installs only the **core modules** needed for the web interface to function.

<br />

=== ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

    ```bash
    # #
    #   Full Dependencies
    # #

    sudo apt-get update && sudo apt-get install -y \
      perl \
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

    # #
    #   Minimum Dependencies
    # #

    sudo apt-get update && sudo apt-get install -y \
      libio-socket-ssl-perl \
      libcrypt-ssleay-perl \
      libnet-libidn-perl \
      libio-socket-inet6-perl \
      libsocket6-perl
    ```

=== ":aetherx-axb-redhat: CentOS/RHEL (yum/dnf)"

    ```bash
    # #
    #   Full Dependencies
    # #

    sudo yum install -y \
      perl \
      perl-IO-Socket-SSL.noarch \
      perl-Net-SSLeay \
      perl-Net-LibIDN \
      perl-IO-Socket-Inet6 \
      perl-Socket6 \
      perl-libwww-perl \
      perl-JSON \
      perl-Crypt-SSLeay \
      perl-LWP-Protocol-https.noarch \
      perl-GDGraph \
      perl-Math-BigInt \
      perl-Time-HiRes \
      perl-Socket \
      net-tools \
      ipset \
      bind-utils \
      wget \
      unzip

    # #
    #   Minimum Dependencies
    # #

    sudo yum makecache && sudo yum install -y \
      perl-IO-Socket-SSL.noarch \
      perl-Net-SSLeay \
      perl-Net-LibIDN \
      perl-IO-Socket-INET6 \
      perl-Socket6
    ```

=== ":aetherx-axs-onion: Perl (CPAN)"

    ```bash
    # #
    #   Full Dependencies
    # #

    sudo cpan -i \
      IO::Socket::SSL \
      IO::Socket::INET6 \
      Socket6 \
      Net::LibIDN \
      LWP \
      LWP::Protocol::https \
      LWP::UserAgent \
      JSON \
      Net::SSLeay \
      Crypt::SSLeay \
      Digest::MD5 \
      Digest::SHA \
      Email::Valid \
      GD::Graph \
      Time::HiRes \
      Socket

    # #
    #   Minimum Dependencies
    # #

    sudo cpan -i \
      IO::Socket::SSL \
      Net::SSLeay \
      Net::LibIDN \
      IO::Socket::INET6 \
      Socket6
    ```

=== ":aetherx-axs-onion: Perl (CPANMINUS)"

    ```bash
    # #
    #   Debian/Ubuntu
    # #

    sudo apt-get update && sudo apt-get install -y cpanminus

    # #
    #   CentOS/RHEL
    # #

    sudo yum makecache && sudo yum install -y perl-App-cpanminus

    # #
    #   Full Dependencies
    # #

    sudo cpanm \
      IO::Socket::SSL \
      IO::Socket::INET6 \
      Socket6 \
      Net::LibIDN \
      LWP \
      LWP::Protocol::https \
      LWP::UserAgent \
      JSON \
      Net::SSLeay \
      Crypt::SSLeay \
      Digest::MD5 \
      Digest::SHA \
      Email::Valid \
      GD::Graph \
      Time::HiRes \
      Socket

    # #
    #   Minimum Dependencies
    # #

    sudo cpanm \
      IO::Socket::SSL \
      Net::SSLeay \
      Net::LibIDN \
      IO::Socket::INET6 \
      Socket6
    ```

<br />
<br />

### Step 2: Enable Web UI

To enable CSF web interface, edit the file `/etc/csf/csf.conf` in a text editor:

```shell
sudo nano /etc/csf/csf.conf
```

<br />

We need to update the following values. Click :material-plus-circle: to see information about each setting.

```ini title="<span>/etc/csf/csf.conf</span>"
# #
#   1 to enable, 0 to disable web ui 
# #

UI = "1" # (1)!

# #
#   Set port for web UI. The default port is 6666, but
#   I change this to 1025 to easy access. Default port create some issue
#   with popular chrome and firefox browser (in my case) 
# #

UI_PORT = "1025" # (2)!

# #
#   Leave blank to bind to all IP addresses on the server 
# #

UI_IP = "" # (3)!

# #
#   Set username for authentication 
# #

UI_USER = "admin" # (4)!

# #
#   Set a strong password for authentication 
# #

UI_PASS = "admin" # (5)!
```

1.  :aetherx-axdr-lightbulb:{ .pulsate .icon-clr-yellow } Defines if the CSF web interface is enabled or not. Will be
    accessible via your web browser.
    <div class='red right'><small>Required</small></div>
    <div class='yellow right'><small>Values: `0`, `1`</small></div>
2.  :aetherx-axdr-lightbulb:{ .pulsate .icon-clr-yellow } Defines the port to assign for the CSF web interface.
    This should be set to a value of `1023` or higher.
    <div class='red right'><small>Required</small></div>
    <div class='yellow right'><small>Values: `> 1023`</small></div>
3.  :aetherx-axdr-lightbulb:{ .pulsate .icon-clr-yellow } Defines the IP address to bind to the CSF web interface.
    If you plan to route this through Traefik, you should set this to your docker subnet such as `::ffff:172.17.0.1`.
    <div style='padding-top:15px'>Leave blank if you want to bind to all IP addresses on server.</div>
    <div class='red right'><small>Required</small></div>
    <div class='yellow right'><small>Values: `blank`, `::IPv6:IPv4`</small></div>
4.  :aetherx-axdr-lightbulb:{ .pulsate .icon-clr-yellow } Defines the username that will be required in order to
    sign into the CSF web interface. This should be alphabetic or numerical characters.
    <div class='red right'><small>Required</small></div>
    <div class='yellow right'><small>Values: `A-Z,a-z,0-9`</small></div>
5.  :aetherx-axdr-lightbulb:{ .pulsate .icon-clr-yellow } Defines the password that will be required in order to
    sign into the CSF web interface. This should alphabetic, numerical, or special characters.
    <div class='red right'><small>Required</small></div>
    <div class='yellow right'><small'>Values: `A-Z,a-z,0-9,!@#$%^&*()-_=+`</small></div>

<br />

Save and exit. Then open the file `/etc/csf/ui/ui.allow` and add your client IP to allow access to the CSF web interface. Ensure you only add one IP address per line:

=== ":material-file: /etc/csf/ui/ui.allow"

    This is an example of how your `ui.allow` file should look.

    ```shell
    10.10.0.6           # example LAN ip
    40.159.100.6        # example WAN ip
    ```

=== ":aetherx-axs-square-terminal: Command"

    If you want to add a new IP without having to open `ui.allow`, run the following:

    ```shell
    echo "YOUR_PUBLIC_IP_ADDRESS" | sudo tee -a /etc/csf/ui/ui.allow
    ```

<br />

The CSF web interface works under the `lfd daemon` _LFD_. We need to restart the LFD on your system using the command:

```shell
sudo service lfd restart
```

<br />

In order to gain access to the online admin panel; you must ensure LFD and CSF are running. You can check by running the commands:

```shell
sudo service lfd status
```

<br />

You should see the following:

```console
● lfd.service - ConfigServer Firewall & Security - lfd
     Loaded: loaded (/lib/systemd/system/lfd.service; enabled; preset: enabled)
     Active: active (running) since Mon 2025-19-21 11:59:38 UTC; 1s ago
    Process: 46393 ExecStart=/usr/sbin/lfd (code=exited, status=0/SUCCESS)
   Main PID: 46407 (lfd - sleeping)
      Tasks: 8 (limit: 4613)
     Memory: 121.7M
        CPU: 2.180s
     CGroup: /system.slice/lfd.service
```

<br />

Next, confirm CSF service is also running:

```shell
sudo service csf status
```

<br />

Check the output for any errors; which there should be none.

```console
● csf.service - ConfigServer Firewall & Security - csf
     Loaded: loaded (/lib/systemd/system/csf.service; enabled; preset: enabled)
     Active: active (exited) since Mon 2024-08-05 12:04:09 UTC; 1s ago
    Process: 46916 ExecStart=/usr/sbin/csf --initup (code=exited, status=0/SUCCESS)
   Main PID: 46916 (code=exited, status=0/SUCCESS)
        CPU: 12.692s
```

<br />

If you see the following error; you must install `ipset` on your system:

```shell
csf[46313]: open3: exec of /sbin/ipset flush failed: No such file or directory at /usr/sbin/csf line 5650.
```

<br />

=== ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

    ```bash
    sudo apt-get update 
    sudo apt-get install -y ipset
    ```

=== ":aetherx-axb-redhat: CentOS/RHEL (yum/dnf)"

    ```bash
    sudo yum makecache
    sudo yum install -y ipset
    ```

<br />

Alternatively, you can restart `CSF` and `LFD` at the same time by running:

```shell
sudo csf -ra
```

<br />
<br />

### Step 3: Access Web UI

Access the CSF interface in your browser with the specified IP and port. For these docs; we used port `1025`. 

```shell
http://127.0.0.1:1025
```

<br />

??? danger "Default Web Interface Username & Password"

    You cannot keep the web interface username and password defaulted to `admin`; you will get an error that the credentials must be changed within `/etc/csf/csf.conf`.

    Ggo back to the `/etc/csf/csf.conf` set `UI_USER` and `UI_PASS` to something else.

<br />

<figure markdown="span">
    ![CSF Login Interface](../assets/images/install/webui/1.png){ width="700" }
    <figcaption>CSF Login Interface</figcaption>
</figure>

<br />

After successful login, you should see the following:

<figure markdown="span">
    ![CSF Main Dashboard](../assets/images/install/webui/2.png){ width="700" }
    <figcaption>CSF Main Dashboard</figcaption>
</figure>

<br />

We will cover how to actually use the CSF web interface in another section. As of right now you should at least be able to access the web interface by going to `http://127.0.0.1:1025` in your browser. Or whatever IP and port you assigned within the `/etc/csf/csf.conf`.

<br />

---

<br />

## Conclusion

By this point in the guide, you should have:

- CSF installed and functioning
- Access to the CSF web interface via an IP and port

---

The next section will show you how to put the CSF web interface behind third-party apps such as [Traefik Reverse Proxy](../install/traefik.md) and secure it with [Authentik](../install/authentik.md).  

These steps are **optional**. They enhance the security of your web interface and help prevent unauthorized access, but you do not need to perform them to continue using CSF.

<br />

---

<br />

## Next Steps <!-- omit from toc -->

{==

Select what documentation you would like to proceed with next ...

==}

<div class="grid cards" markdown>

-   :aetherx-axb-traefikproxy: &nbsp; __[Traefik Integration](../install/traefik.md)__

    ---

    Protect your CSF installation by placing it behind a **Traefik Reverse Proxy**.
    
    This setup lets you filter and control traffic to the CSF web interface using
    Traefik’s middleware, all with the added bonus that you do not need to expose
    or open the ports to your server.
    
    With middleware, you can whitelist your own IP for secure access and enforce
    geographic restrictions to allow or block traffic from specific countries.

-   :aetherx-axb-authentik: &nbsp; __[Authentik Integration](../install/authentik.md)__

    ---

    Enhance the security of CSF by placing it behind the **Authentik** identity 
    provider using a forward proxy. 
    
    This ensures that all traffic to the CSF web interface passes through Authentik, 
    giving you centralized control over authentication and access.
    
    With this setup, CSF is protected by modern authentication methods such as
    passwords, two-factor authentication (2FA), or passkeys.

-   :material-file: &nbsp; __[Usage Introduction](../usage/getting-started.md)__

    ---

    If you don’t plan to set up Traefik or Authentik with the CSF web interface, 
    you can skip ahead to the [Usage](../usage/getting-started.md) section. 
    
    The next chapter covers CSF’s core features, basic configuration, available
    commands, folder structure, and everything you need to get started.

    You will be taken on a more detailed dive of how CSF can benefit you and
    what options you have for securing your server.

</div>



<div style="opacity: 0.5" markdown>

</div>


<br />
<br />
