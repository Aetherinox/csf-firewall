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

To get the CSF web interface functioning on your server, you must first ensure that you have a few perl modules installed. If you followed our [dependencies](./dependencies.md) guide, you should already have these [dependencies](./dependencies.md) satisfied. If you have not yet installed them, run one of the following commands in your server's terminal:

=== ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

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

=== ":aetherx-axb-redhat: CentOS/RHEL (yum/dnf)"

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

=== ":aetherx-axs-onion: Perl (CPAN)"

    ```bash
    perl -MCPAN -eshell
    cpan> install IO::Socket::SSL IO::Socket::INET6 Socket6 Net::LibIDN \
    LWP LWP::Protocol::https LWP::UserAgent JSON Net::SSLeay \
    Crypt::SSLeay Digest::MD5 Digest::SHA Email::Valid \
    GD::Graph Time::HiRes Socket
    ```

<br />
<br />

### Step 2: Enable Web UI

To enable CSF web interface, edit the file `/etc/csf/csf.conf` in your favorite text editor:

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
#   Set username for authetnication 
# #

UI_USER = "admin" # (4)!

# #
#   Set a strong password for authetnication 
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
    <div class='yellow right'><small'>Values: `A-Z,a-z,0-9`</small></div>

<br />

Once you have edited the file, save and exit. Next, open the file `/etc/csf/ui/ui.allow` and add your public IP to allow access to the CSF web interface. Ensure you only add one IP address per line:

=== ":material-file: /etc/csf/ui/ui.allow"

    ```shell
    10.10.0.6           # example LAN ip
    40.159.100.6        # example WAN ip
    ```

=== ":aetherx-axs-square-terminal: Command"

    ```shell
    sudo echo "YOUR_PUBLIC_IP_ADDRESS" >>  /etc/csf/ui/ui.allow
    ```


<br />

The CSF web interface works under the `lfd daemon _LFD_`. We need to restart the LFD on your system using the following command:

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
     Active: active (exited) since Mon 2024-08-05 12:04:09 MST; 1s ago
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

Now, access the CSF interface in your browser with the specified port. For this tutorial; we used 1025 port and accessed the CSF admin panel by opening our browser and going to:

```shell
http://127.0.0.1:1025
```

<br />

??? danger "Default Username & Password"

    If you did not change the default username and password in `/etc/csf/csf.conf`, you will get an error about the default credentials not being changed. You need to go back to the `/etc/csf/csf.conf` 
    set `UI_USER` and `UI_PASS`

<br />

<figure markdown="span">
    ![Image title](../assets/images/install/webui/1.png){ width="700" }
    <figcaption>CSF Login Interface</figcaption>
</figure>

<br />

After successful login, you will find the screen like below.

<figure markdown="span">
    ![Image title](../assets/images/install/webui/2.png){ width="700" }
    <figcaption>CSF Main Dashboard</figcaption>
</figure>

<br />

We will cover how to actually use the CSF web interface in another section. As of right now you should at least be able to access the web interface by going to `http://127.0.0.1:1025` in your browser. Or whatever IP and port you assigned within the `/etc/csf/csf.conf`.

<br />

---

<br />

## Restart Traefik

Once you configure these changes in Traefik, you can restart your Traefik docker container. The command for that depends on how you set up the container. If you used docker-compose.yml, you can cd into the folder with the `docker-compose.yml` file and then execute:

```shell
docker compose down && docker compose up -d
```

<br />

---

<br />

## Next Steps <!-- omit from toc -->

{==

Select what documentation you would like to proceed with next ...

==}

<div class="grid cards" markdown>

-   :material-file: &nbsp; __[Usage › Getting Started](../usage/getting-started.md)__

    ---

    If you don’t plan to set up Traefik or Authentik 
    integration with the CSF web interface, you can skip 
    ahead to the [Usage](../usage/getting-started.md) section. 
    
    The next chapter covers the core features of CSF along
    with instructions for basic configuration, list of the 
    available commands, application folder structure, and 
    many other aspects of starting to use CSF.



-   :aetherx-axb-traefikproxy: &nbsp; __[Traefik Integration](../usage/traefik.md)__

    ---

    Protect your CSF installation by placing it behind a 
    Traefik reverse proxy. This configuration allows you
    to filter and control the traffic reaching the CSF
    web interface while taking advantage of Traefik’s
    middleware features. 
    
    With middleware, you can whitelist your own IP 
    address for secure access and enforce geographic 
    restrictions to block or allow traffic from 
    specific countries. 

-   :aetherx-axb-authentik: &nbsp; __[Authentik Integration](../usage/authentik.md)__

    ---

    Enhance the security of CSF by placing it 
    behind the Authentik identity provider using a 
    Forward Proxy. This ensures that all 
    traffic to the CSF web interface passes through 
    Authentik, giving you centralized control over 
    authentication and access management.  

    With this configuration, CSF is protected by 
    modern authentication methods such as passwords, 
    two-factor authentication (2FA), or passkeys. 
    
</div>



<div style="opacity: 0.5" markdown>

</div>


<br />
<br />
