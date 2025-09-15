---
title: Enable CSF Web Interface
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

To enable CSF web UI, edit the file `/etc/csf/csf.conf` in your favorite text editor:

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

1.  :aetherx-axdr-lightbulb:{ .pulsate .icon-clr-yellow } Defines if the csf web interface is enabled or not. Will be
    accessible via your web browser.
    <div class='red right'><small>Required</small></div>
    <div class='yellow right'><small>Values: `0`, `1`</small></div>
2.  :aetherx-axdr-lightbulb:{ .pulsate .icon-clr-yellow } Defines the port to assign for the csf web interface.
    This should be set to a value of `1023` or higher.
    <div class='red right'><small>Required</small></div>
    <div class='yellow right'><small>Values: `> 1023`</small></div>
3.  :aetherx-axdr-lightbulb:{ .pulsate .icon-clr-yellow } Defines the IP address to bind to the csf web interface.
    If you plan to route this through Traefik, you should set this to your docker subnet such as `::ffff:172.17.0.1`.
    <div style='padding-top:15px'>Leave blank if you want to bind to all IP addresses on server.</div>
    <div class='red right'><small>Required</small></div>
    <div class='yellow right'><small>Values: `blank`, `::IPv6:IPv4`</small></div>
4.  :aetherx-axdr-lightbulb:{ .pulsate .icon-clr-yellow } Defines the username that will be required in order to
    sign into the csf web interface. This should be alphabetic or numerical characters.
    <div class='red right'><small>Required</small></div>
    <div class='yellow right'><small>Values: `A-Z,a-z,0-9`</small></div>
5.  :aetherx-axdr-lightbulb:{ .pulsate .icon-clr-yellow } Defines the password that will be required in order to
    sign into the csf web interface. This should alphabetic, numerical, or special characters.
    <div class='red right'><small>Required</small></div>
    <div class='yellow right'><small'>Values: `A-Z,a-z,0-9`</small></div>

<br />

Once you have edited the file, save and exit. Next, opoen the file `/etc/csf/ui/ui.allow` and add your public IP to allow access to CSF UI. Ensure you only add one IP address per line:

=== ":material-file: /etc/csf/ui/ui.allow"

    ```shell
    xx.xx.xx.xx
    ```

=== ":aetherx-axs-square-terminal: Command"

    ```shell
    sudo echo "YOUR_PUBLIC_IP_ADDRESS" >>  /etc/csf/ui/ui.allow
    ```


<br />

The CSF web interface works under the `lfd daemon`. We need to restart the lfd daemon on your system using the following command:

```shell
sudo service lfd restart
```

<br />

In order to gain access to the online admin panel; you must ensure lfd and csf are running. You can check by running the commands:

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

Next, confirm csf service is also running:

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

Alternatively, you can restart `csf` and `lfd` at the same time by running:

```shell
sudo csf -ra
```

<br />
<br />

### Step 3: Access Web UI

Now, access CSF UI on your browser with the specified port. For this tutorial; we used 1025 port and accessed the CSF admin panel by opening our browser and going to:

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

## Traefik Integration

This section of the guide explains how to set up ConfigServer Firewall & Security along with Traefik reverse proxy integration.


<br />
<br />

### Domain Name

To set up the CSF web interface with Traefik, you will need a domain. You have two options:

1. Purchase a domain from a registrar such as [Porkbun](https://porkbun.com), then use Traefik’s built-in ACME Certificates Resolver to generate a free SSL certificate from Let’s Encrypt.
2. Use a local domain like `myserver.lan` and create a self-signed certificate.

Typically people choose to purchase a domain as it is easier to obtain an SSL certificate. If you go with the fake local domain, you'll be responsible for generating your own using [OpenSSL](https://github.com/openssl/openssl).

We will explain these options briefly, but we will not go into great detail as that goes beyond the scope of this guide.

<br />

#### Purchase Domain

If you plan to go the route of purchasing a domain, you can find a relatively cheap domain through registrars online. We've listed a few recommendations, but you can pick whichever company you want to go with:

??? note "Our Recommendation"
    
    We make no money from this recommendation, and there is no affiliate link included.  

    That said, we personally recommend [Porkbun](https://porkbun.com) as a reliable domain registrar. They offer competitive pricing and include free WHOIS privacy with any domain purchase.  

    We have interacted with their support in the past and have been impressed with their professionalism. Of course, you are free to choose whichever registrar you prefer. We only
    recommend them because we have been an actual customer for over six years, and have never had a negative experience.

    Plus, the comedy on their website is fun to read.

- [Porkbun](https://porkbun.com)
- [Cloudflare](https://cloudflare.com/products/registrar/)
- [NameSilo](https://www.namesilo.com/)

<br />

Once you get your domain purchased, you'll need to set up the domain name to point to your server. You could also decide to set up your domain name to run through [Cloudflare](https://cloudflare.com).

<br />
<br />


#### Local Domain

If you decide to not [purchase a domain](#purchase-domain), your other option is to set up your local server so that it is accessible via a locally made up domain name. This usually entails editing your operating system host file so that when you type a fake name in your browser, your computer re-directs you to the IP address for your Traefik docker container.

=== ":aetherx-axb-windows: C:\Windows\system32\drivers\etc\hosts"

    ```shell
    172.18.0.2 fakedomain.lan
    ```

=== ":aetherx-axb-linux: /etc/hosts"

    ```shell
    172.18.0.2 fakedomain.lan
    ```

<br />

The other requirement for having a local fake domain is that you must generate your own self-signed SSL certificates, which you can do with the application [OpenSSL](https://github.com/openssl/openssl):

- :aetherx-axb-windows: [Windows](https://slproweb.com/products/Win32OpenSSL.html)
- :aetherx-axb-linux: [Linux](https://docs.openiam.com/docs-4.2.1.3/appendix/2-openssl)

<br />

In the next section [Setup Traefik](#setup-traefik), there is a link to a guide explaining how to generate your own self-signed certificate.

<br />
<br />


### Setup Traefik

After you have your domain ready to go, you need to now install [Traefik Reverse Proxy](https://doc.traefik.io/traefik/setup/docker/) on your server. Traefik allows you to install their software on a few different platforms:

1. [Binary Distribution](https://doc.traefik.io/traefik/getting-started/install-traefik/#use-the-binary-distribution)
2. [Docker](https://doc.traefik.io/traefik/setup/docker/)
3. [Docker Swarm](https://doc.traefik.io/traefik/setup/swarm/)
4. [Kubernetes](https://doc.traefik.io/traefik/setup/kubernetes/)

<br />

If you opted to use a [local domain](#local-domain) that you did not purchase, you will need to generate a self-signed certificate and install it in Traefik. This allows you to access your server securely over `https` rather than the insecure `http` protocol.  

For guidance on generating a self-signed SSL certificate, refer to Traefik’s documentation [creating a self-signed certificate](https://doc.traefik.io/traefik/expose/docker/#create-a-self-signed-certificate).

<br />
<br />

### Setup Traefik with CSF

By this point in the guide, you should have:

- A registered domain or a local/LAN domain name
- A Let's Encrypt or self-signed SSL certificate
- A running installation of Traefik Reverse Proxy
- An installed copy of ConfigServer Firewall & Security (CSF)

<br />

Next, we’ll configure CSF so it can be accessed through Traefik.  

Open `/etc/csf/csf.conf` and update the `UI_IP` setting. This defines the IP address that the CSF web interface will bind to.  By default, the value is empty, which means CSF’s web interface binds to all IPs on the server.

When setting `UI_IP`, we will use the IP address of our docker network, which is formatted as `::ffff:172.17.0.1`. This is an **IPv6-mapped IPv4 address** which consists of:

| Value | Description |
| --- | --- |
| `::` | shorthand for “all zeros” in IPv6. |
| `ffff:` | a marker that indicates the address is an IPv4-mapped address |
| `172.17.0.1` | the actual IPv4 address being represented (in this case, the Docker bridge gateway) |

In short, `::ffff:172.17.0.1` is just another way of writing the IPv4 address `172.17.0.1`, but inside the IPv6 address space.  

```
UI_IP = "::ffff:172.17.0.1"
```

<br />

The above change will ensure that your CSF web interface is not accessible via your public IP address. We're going to allow access to it through our docker network and domain name.

<br />
<br />

Next, we need to edit the Traefik config files to add a few things:

  - Middleware
  - Routers
  - Entrypoints
  - Services

<br />

We will also define **Middleware**, which adds an extra layer of security to the CSF web interface.  Users must pass through this middleware before they can successfully access the CSf web interface.

??? note "What Is Middleware?"

    **Middleware** allow you to adjust or filter requests before they reach your service, or to modify responses before they are sent back to the client.  

    Traefik provides a wide range of middleware: some modify requests or headers, others handle redirections, add authentication, apply access controls, and more.  

    Adding middleware for Traefik is completely optional. The middleware listed below offer additional security to help ensure that nobody can access your CSF web interface.

    - `authentik:` middleware requires that you have [Authentik](https://docs.goauthentik.io/install-config/install/docker-compose/) installed on your server. If you do not wish to use this app for authentication, you can skip implementing this.
    - `geoblock:` middleware requires that you install the Traefik plugin [Geoblock](https://plugins.traefik.io/plugins/62d6ce04832ba9805374d62c/geo-block) before it will function properly.
    - `whitelist:` middleware is built into [Traefik](https://doc.traefik.io/traefik/getting-started/install-traefik/) and does not require any additional plugins. It works out-of-the-box.

    <br />

    :aetherx-axs-link: [Full Traefik documentation for middleware can be found here](https://doc.traefik.io/traefik/middlewares/overview/).

<br />

In the two code block tabs below, we give the code that you should add to two important Traefik config files:

- `dynamic.yml`: Traefik's dynamic configuration file
- `traefik.yml`: Traefik's static configuration file

<br />

=== ":aetherx-axs-file: dynamic.yml (Traefik Dynamic File)"

    The code contained within this codeblock should go inside your Traefik dynamic file, usually named `dynamic.yml`.

    ```yaml

    # #
    #   Protocol › http
    # #

    http:

        # #
        #   http › Middleware
        # #

        middlewares:

            # #
            #   Middleware › Http redirect
            #   Redirect http to https
            # #

            https-redirect:
                redirectScheme:
                    scheme: "https"
                    permanent: true

            # #
            #   Middleware › Authentik
            # #

            authentik:
                forwardauth:
                    address: http://authentik-server:9000/outpost.goauthentik.io/auth/traefik
                    trustForwardHeader: true
                    authResponseHeaders:
                        - X-authentik-username
                        - X-authentik-groups
                        - X-authentik-email
                        - X-authentik-name
                        - X-authentik-uid
                        - X-authentik-jwt
                        - X-authentik-meta-jwks
                        - X-authentik-meta-outpost
                        - X-authentik-meta-provider
                        - X-authentik-meta-app
                        - X-authentik-meta-version

            # #
            #   Middleware › Geoblock
            # #

            geoblock:
                plugin:
                    GeoBlock:
                        allowLocalRequests: "true"
                        allowUnknownCountries: "false"
                        blackListMode: "false"
                        api: https://get.geojs.io/v1/ip/country/{ip}
                        ipGeolocationHttpHeaderField: "Cf-Ipcountry"
                        xForwardedFor: "X-Forwarded-For"
                        apiTimeoutMs: "150"
                        cacheSize: "15"
                        addCountryHeader: "true"
                        forceMonthlyUpdate: "true"
                        logAllowedRequests: "true"
                        logApiRequests: "true"
                        logLocalRequests: "true"
                        silentStartUp: "false"
                        unknownCountryApiResponse: nil
                        countries:
                            - US

            # #
            #   Middleware › IP White/Allow List
            # #

            whitelist:
                ipAllowList:
                    sourceRange:
                        - "127.0.0.0/8"
                    ipStrategy:
                        excludedIPs:
                            # Cloudflare IP List
                            # These will be ignored and the next IP in line will be checked
                            - 173.245.48.0/20
                            - 103.21.244.0/22
                            - 103.22.200.0/22
                            - 103.31.4.0/22
                            - 141.101.64.0/18
                            - 108.162.192.0/18
                            - 190.93.240.0/20
                            - 188.114.96.0/20
                            - 197.234.240.0/22
                            - 198.41.128.0/17
                            - 162.158.0.0/15
                            - 104.16.0.0/13
                            - 104.24.0.0/14
                            - 172.64.0.0/13
                            - 131.0.72.0/22
                            - 2400:cb00::/32
                            - 2606:4700::/32
                            - 2803:f800::/32
                            - 2405:b500::/32
                            - 2405:8100::/32
                            - 2a06:98c0::/29
                            - 2c0f:f248::/32

        # #
        #   http › Routers
        # #

        routers:
            csf-http:
                service: "csf"
                rule: "Host(`csf.domain.com`)" # (1)!
                entryPoints:
                    - "http" # (2)!
                middlewares:
                    - https-redirect@file # (3)!

            csf-https:
                service: "csf"
                rule: "Host(`csf.domain.com`)" # (4)!
                entryPoints:
                    - "https" # (5)!
                middlewares:
                    - authentik@file # (6)!
                    - whitelist@file # (7)!
                    - geoblock@file # (8)!
                tls:
                    certResolver: cloudflare # (9)!
                    domains:
                        - main: "domain.com"
                          sans:
                              - "*.domain.com"

        # #
        #   http › Services
        # #

        services:
            csf:
                loadBalancer:
                    servers:
                        - url: "https://172.17.0.1:1025/" # (10)!
    ```

    1.  :aetherx-axdr-lightbulb:{ .pulsate .icon-clr-yellow } The `subdomain.domain.ext` you will use to access the 
        CSF web interface over the insecure `http` protocol.  
        <div class='red right para'><small>Required</small></div>
    2.  :aetherx-axdr-lightbulb:{ .pulsate .icon-clr-yellow } Defines the Traefik **entrypoint** that this Docker 
        container will use for the insecure `http` protocol routed through `csf-http`. 
        <div class="para">This entrypoint is defined in the Traefik  `traefik.yml` static file.</div>
        <div class="para">:aetherx-axs-link: [Traefik **entrypoints** docs](https://doc.traefik.io/traefik/reference/install-configuration/entrypoints/)</div>
        <div class='red right para'><small>Required</small></div>
    3.  :aetherx-axdr-lightbulb:{ .pulsate .icon-clr-yellow } This **middleware** ensures that any connections made over 
        the insecure `http` protocol to the router `csf-http` are automatically redirected to the secure `https` (SSL) protocol
        router `csf-https`. 
        <div class="para">This middleware is defined in the Traefik `dynamic.yml` dynamic file.</div>
        <div class='red right para'><small>Required</small></div>
    4.  :aetherx-axdr-lightbulb:{ .pulsate .icon-clr-yellow } The `subdomain.domain.ext` you will use to access the CSF 
        web interface over the secure `https` protocol.  
        <div class='red right para'><small>Required</small></div>
    5.  :aetherx-axdr-lightbulb:{ .pulsate .icon-clr-yellow } Defines the Traefik **entrypoint** that this Docker 
        container will use for the secure `https` protocol.
        <div class="para">This entrypoint is defined in the Traefik  `traefik.yml` static file.</div>
        <div class="para">:aetherx-axs-link: [Traefik **entrypoints** docs](https://doc.traefik.io/traefik/reference/install-configuration/entrypoints/)</div>
        <div class='red right para'><small>Required</small></div>
    6.  :aetherx-axdr-lightbulb:{ .pulsate .icon-clr-yellow } Specifies the **middleware** `Authentik` when a user attempts 
        to access the CSF web interface over the secure `https` protocol.  
        <div class="para">With this middleware, the user must authenticate through `Authentik` before proceeding and gaining access to 
        the web interface.</div>
        <div class="para">This middleware is defined in the Traefik `dynamic.yml` dynamic file.</div>
        <div class="para">:aetherx-axs-link: [Traefik **middleware** `Authentik` docs](https://docs.goauthentik.io/add-secure-apps/providers/proxy/server_traefik/)</div>
        <div class='blue right para'><small>Optional</small></div>
    7.  :aetherx-axdr-lightbulb:{ .pulsate .icon-clr-yellow } Specifies the **middleware** `IP Whitelist` when a user 
        attempts to access the CSF web interface over the secure `https` protocol.  
        <div class="para">With this middleware, only users connecting from whitelisted IP addresses are allowed to access the web interface.</div>
        <div class="para">This middleware is defined in the Traefik `dynamic.yml` dynamic file.</div>
        <div class="para">:aetherx-axs-link: [Traefik **middleware** `IPAllowList` docs](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/ipallowlist/)</div>
        <div class='blue right para'><small>Optional</small></div>
    8.  :aetherx-axdr-lightbulb:{ .pulsate .icon-clr-yellow } Specifies the **middleware** `Geo-block` when a user 
        attempts to access the CSF web interface over the secure `https` protocol.  
        <div class="para">With this middleware, users from blacklisted geographical locations are denied access to the web interface.</div>
        <div class="para">This middleware is defined in the Traefik `dynamic.yml` dynamic file.</div>
        <div class="para">:aetherx-axs-link: [Traefik **middleware** `Geoblock Plugin` docs](https://plugins.traefik.io/plugins/62d6ce04832ba9805374d62c/geo-block)</div>
        <div class='blue right para'><small>Optional</small></div>
    9.  :aetherx-axdr-lightbulb:{ .pulsate .icon-clr-yellow } If you purchased a domain name, you can configure which
        certificate resolver you generate SSL certificate from.
        <div class="para">:aetherx-axs-link: [view `certResolver` docs](https://doc.traefik.io/traefik/reference/install-configuration/entrypoints/#http-tls-certResolver)</div>
        <div class='blue right para'><small>Optional</small></div>
    10. :aetherx-axdr-lightbulb:{ .pulsate .icon-clr-yellow } This line defines the Traefik `service` / `loadbalancer` rules. 
        <div class="para">`ip` is the IP address assigned to your Traefik container through your Docker network. In our example, Traefik is assigned to 
        `172.17.0.1`. You can also use the Traefik container name instead of the IP.</div>
        <div class="para">`port` should be set to the port assigned to the ConfigServer Firewall web interface. This is defined by the `UI_PORT` 
        setting in `/etc/csf/csf.conf`. In our example, we use `1025`.</div>
        <div class="para">:aetherx-axs-link: [view `loadbalancer` docs](https://doc.traefik.io/traefik/reference/routing-configuration/http/load-balancing/service/)</div>
        <div class='red right para'><small>Required</small></div>
  
    After adding the above lines to your Traefik `dynamic.yml`, you will also need to update the Traefik static configuration file, usually named `traefik.yml`.  

    The **static file** defines key settings such as the **file provider**, the **entrypoints** used to access your web service, and any **plugins** that Traefik should load.

=== ":aetherx-axs-file: traefik.yml (Traefik Static File)"

    The code contained within this codeblock should go inside your Traefik static file, usually named `traefik.yml`.

    ```yaml
    # #
    #   Global
    # #

    global:
        checkNewVersion: false
        sendAnonymousUsage: false

    # #
    #   Logs
    #   
    #   filePath must match volume mounted in docker-compose.yml
    # #

    log:
        level: DEBUG
        format: "common"

    # #
    #   Access Logs
    #   
    #   filePath must match volume mounted in docker-compose.yml
    # #

    accessLog:
        filePath: "/var/log/traefik/access.log"

    # #
    #   Api
    # #

    api:
        dashboard: true
        insecure: true
        debug: true

    # #
    #   Entry Points
    # #

    entryPoints:

        # #
        #   Port › HTTP
        #   
        #   *trustedIps     : List of Cloudflare Trusted IP's above for HTTPS requests
        # #

        http:
            address: :80
            forwardedHeaders:
                trustedIPs: &trustedIps
                    # Cloudlare Public IP List > Start > for HTTP requests, remove this if you don't use it; https://cloudflare.com/de-de/ips/
                    - 103.21.244.0/22
                    - 103.22.200.0/22
                    - 103.31.4.0/22
                    - 104.16.0.0/13
                    - 104.24.0.0/14
                    - 108.162.192.0/18
                    - 131.0.72.0/22
                    - 141.101.64.0/18
                    - 162.158.0.0/15
                    - 172.64.0.0/13
                    - 173.245.48.0/20
                    - 188.114.96.0/20
                    - 190.93.240.0/20
                    - 197.234.240.0/22
                    - 198.41.128.0/17
                    - 2400:cb00::/32
                    - 2606:4700::/32
                    - 2803:f800::/32
                    - 2405:b500::/32
                    - 2405:8100::/32
                    - 2a06:98c0::/29
                    - 2c0f:f248::/32
            http:
                redirections:
                    entryPoint:
                        to: https
                        scheme: https

        # #
        #   Port › HTTPS
        #   
        #   *trustedIps     : List of Cloudflare Trusted IP's above for HTTPS requests
        # #

        https:
            address: :443
            http3: {}
            forwardedHeaders:
                trustedIPs: *trustedIps
            transport:
                keepAliveMaxRequests: 0
                keepAliveMaxTime: 0s
                lifeCycle:
                  requestAcceptGraceTimeout: 0
                  graceTimeOut: 120s
                respondingTimeouts:
                  readTimeout: 0
                  writeTimeout: 0
                  idleTimeout: 0

    # #
    #   Plugins
    # #

    experimental:
        plugins:
            GeoBlock:
                moduleName: "github.com/PascalMinder/geoblock"
                version: "v0.2.8"

    # #
    #   Providers
    #   
    #   file:
    #       filename: must match volume mounted in docker-compose.yml
    #   
    #   docker:
    #       exposedByDefault = true
    #       all docker-compose.yml files will automatically create a new traefik provider. 
    #   
    #       this means if you are using file provider in dynamic file, each container 
    #       will show up twice. x1 @docker and x1 @file
    #   
    #       if exposedByDefault = false, you must manually add `trafik.enable=true` to each container in the docker-compose.yml
    # #

    providers:
        docker:
            endpoint: "unix:///var/run/docker.sock"
            exposedByDefault: false
            network: traefik
            watch: true
        file:
            filename: "/etc/traefik/dynamic.yml"
            watch: true
    ```

<br />

In the code blocks above, we attached multiple Traefik **middlewares** to `routers`:  

- [Authentik Middleware](https://docs.goauthentik.io/add-secure-apps/providers/proxy/server_traefik/)
    - Require authentication through Authentik before allowing access.  
- [IP AllowList](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/ipallowlist/)
    - Restrict access to the CSF web interface by whitelisted IP addresses.  
- [Geoblocking](https://plugins.traefik.io/plugins/62d6ce04832ba9805374d62c/geo-block)
    - Restrict access based on Geographical location


<br />
<br />

### Restart Traefik

Once you configure these changes in Traefik, you can restart your Traefik docker container. The command for that depends on how you set up the container. If you used docker-compose.yml, you can cd into the folder with the `docker-compose.yml` file and then execute:

```shell
docker compose down && docker compose up -d
```



<div style="opacity: 0.5" markdown>

</div>


<br />
<br />
