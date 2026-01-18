---
title: "Usage › Integration › Traefik"
tags:
    - 3rd-party
    - usage
    - configure
    - integration
    - traefik
---


# Traefik Integration

This section of the guide covers setting up CSF with Traefik as a reverse proxy. It explains your options for using a public domain or a private unofficial pseudo-domain such as `.local`/`.lan` which is accessible only to you. We’ll also provide resources for generating and managing your own SSL certificates.

<br />

---

<br />

## What is Traefik?

Traefik is a modern reverse proxy and load balancer that makes it easier to manage how traffic flows to your applications and services. Instead of exposing each service directly to the internet, Traefik acts as a gateway, routing requests securely and efficiently to the correct destination. This setup is especially useful for servers running multiple web-based tools or dashboards, since Traefik helps organize and protect all of them under one entry point.

One of the biggest advantages of Traefik is its support for middleware. Middleware are modular features you can “attach” to your routes. For example, you can use IP whitelisting middleware to ensure only trusted addresses can access your CSF web interface. You could also add geo-blocking rules to limit access based on country, or integrate with external identity providers like [Authentik](../integrations/authentik.md) to require secure authentication before anyone can reach your [firewall web interface / dashboard](../../install/webui.md).

With Traefik handling these protections, you don’t need to open sensitive ports directly to the outside world. Instead, Traefik listens on your chosen ports (like 80 or 443) and enforces the security rules you define before traffic ever reaches your applications. This layered approach not only reduces your attack surface, but also gives you fine-grained control over who can connect, from where, and under what conditions.

<br />

---

<br />

## Domain Name

Before you begin, you’ll need to decide how you want to access Traefik and CSF from your browser. There are three main options:

1. **Use the server’s IP address**  
   Access services directly by memorizing and entering their IP addresses.  

2. **Purchase a valid domain name**  
   Register a real TLD (e.g., `.com`, `.org`, `.net`, `.io`) for public access.  

3. **Use a local domain**  
   Configure a `.local` or `.lan` domain for internal access only.  
   ⚠️ These domains cannot be reached from outside your local network.

The main reason for choosing how you will access Traefik will determine how you generate the correct **SSL certificate**. SSL certificates allow you to securely access Traefik and the CSF web interface over the `https` protocol. Without a valid certificate, you would be limited to using the insecure `http` protocol.

We will outline the differences in the options below:

<br />
<br />

### Purchase Domain

This option involves you buying your own TLD / domain name from a valid domain regisrar online.

<br />

#### How To Obtain

If you plan to go the route of purchasing a valid TLD / domain, you can find a relatively cheap domain through registrars online. We've listed a few recommendations, but you can pick whichever company you want to go with:

??? note "Our Recommendation"
    
    We make no money from this recommendation, and there is no affiliate link included.  

    That said, we personally recommend [Porkbun](https://porkbun.com) as a reliable domain registrar. They offer competitive pricing and include free WHOIS privacy with any domain purchase.  

    We have interacted with their support in the past and have been impressed with their professionalism. Of course, you are free to choose whichever registrar you prefer. We only
    recommend them because we have been an actual customer for over six years, and have never had a negative experience.

    Plus, the comedy on their website is fun to read.

- [Porkbun](https://porkbun.com)
- [Cloudflare](https://cloudflare.com/products/registrar/)
- [NameSilo](https://www.namesilo.com/)

Once you get your domain purchased, you'll need to set up the domain name to point to your server. You could also decide to set up your domain name to run through [Cloudflare](https://cloudflare.com) _(optional)_.

<br />
<br />

#### SSL Certificate

Generating an SSL certificate for a purchased domain is extremely simple, and you have a few options:

1. Create a [Cloudflare](https://cloudflare.com) account, link your domain with Cloudflare, and get a free SSL certificate
2. Your purchased domain name may include a free 1-year SSL certificate (check with your domain registrar).
3. When you set up your domain to run with Traefik, there are settings which allow you to have Traefik automatically generate an SSL certificate free of charge through [Let's Encrypt](https://doc.traefik.io/traefik/reference/install-configuration/tls/certificate-resolvers/acme/).
4. Generate a free SSL certificate using [certbot](https://certbot.eff.org/instructions)

<br />
<br />

#### Setup

After you have purchased a valid TLD, you will need to associate that domain with the IP address or nameservers that are assigned to your server where Traefik and CSF will be hosted. There are a multitude of tutorials online about configuring your domain, so we won't go into great detail. The process however, is simple.

We do recommend setting your domain up with [Cloudflare](https://cloudflare.com). This allows you to configure your domain name with your server, and also receive free services such as DNS management, SSL certificates, firewall rules, and DDoS protection. No extra cost.

<br />
<br />
<br />

### Local Domain

This option allows you to use a free local domain such as `.lan` or `.local` to generate a self-signed certificate and access services such as CSF and Traefik, however, on a local network only.

<br />

#### How To Obtain

If you decide not to [purchase a domain](#purchase-domain), another option is to configure your server so it can be accessed through a **local domain** (such as `.lan` or `.local`).  

- **`.local`** is an officially reserved *special-use domain name* defined in [RFC 6762](https://www.rfc-editor.org/rfc/rfc6762).  
  It is typically used with **Multicast DNS (mDNS)** and is only accessible within your **local network**.  
- **`.lan`** (and similar names like `.home` or `.internal`) are **unofficial pseudo-domains**.  
  They are commonly used for private networks but are not recognized or reserved by ICANN.  

Unlike a registered domain (e.g., `.com`, `.net`, `.org`), a local domain:

- Will not resolve on the public internet.
- Can only be accessed within your own LAN.
- May cause conflicts if the pseudo-domain is ever assigned as a real TLD in the future.

This setup works well if you only need access to CSF and Traefik on your **internal network**. However, if you need **external access** from an outside network, you’ll need to [purchase a domain](#purchase-domain).

<br />
<br />

#### SSL Certificate

Obtaining an SSL certificate for a local domain involves more work. You have the following options:

1. Self-generate your own SSL certificate using an app such as [OpenSSL](https://slproweb.com/products/Win32OpenSSL.html)
      - :aetherx-axb-windows: [Windows](https://slproweb.com/products/Win32OpenSSL.html)
      - :aetherx-axb-linux: [Linux](https://docs.openiam.com/docs-4.2.1.3/appendix/2-openssl)
2. Find an SSL Certificate authority which allows you to generate certificates for a public IP address.
      - Let's Encrypt [announced](https://letsencrypt.org/2025/07/01/issuing-our-first-ip-address-certificate) that IP based SSL certificates would be available in Q4 of 2025
3. Use an online self-signed certificate generator instead of OpenSSL.
      - One example: https://www.devglan.com/online-tools/generate-self-signed-cert
4. Traefik also provides quick documentation on how to generate your own self-signed certificate; follow that [tutorial here](https://doc.traefik.io/traefik/setup/docker/#create-a-selfsigned-certificate)

<br />
<br />

#### Setup

If you have decide to go with a `.local` or `.lan` self-hosted domain, you will need to tell your network / computers what domain you want to use, and where the domain / subdomains should go when you type it into your browser.

To configure local domain access, you’ll need to edit your operating system’s **hosts file**. This ensures that when you type a local domain into your browser, your computer redirects it to the IP address of your **Traefik Docker container**.  

Before you can do this, make sure Traefik is installed and running so you know which IP address has been assigned to the container. Once you have the container’s IP, open your OS hosts file and create entries like the following examples. For ours, Traefik is assigned the docker ip `172.18.0.2`:

=== ":aetherx-axb-windows: C:\Windows\system32\drivers\etc\hosts"

    ```shell
    172.18.0.2 myserver.local
    172.18.0.2 traefik.myserver.local
    ::1 myserver.local localhost
    ```

=== ":aetherx-axb-linux: /etc/hosts"

    ```shell
    172.18.0.2 myserver.local
    172.18.0.2 traefik.myserver.local
    ::1 myserver.local localhost
    ```

<br />

The host file changes above means that any time you go to `myserver.local` in your browser, the local domain will automatically try to establish a connection with your Traefik container via the IP `172.18.0.2`.

<br />
<br />
<br />

## Setup Traefik

Now that we have all of the domain information out of the way, we can now install [Traefik Reverse Proxy](https://doc.traefik.io/traefik/setup/docker/) on your server. Traefik allows you to install their software on a few different platforms:

1. [Binary Distribution](https://doc.traefik.io/traefik/getting-started/install-traefik/#use-the-binary-distribution)
2. [Docker](https://doc.traefik.io/traefik/setup/docker/)
3. [Docker Swarm](https://doc.traefik.io/traefik/setup/swarm/)
4. [Kubernetes](https://doc.traefik.io/traefik/setup/kubernetes/)

<br />

We are not going to provide detailed instructions on installing Traefik since that is outside the scope of this documentation, but there are many tutorials online, and we have linked several above next to each installation option.

If you opted to use a [local domain](#local-domain) that you did not purchase, you will need to generate a self-signed certificate and install it in Traefik. This allows you to access your server securely over `https` rather than the insecure `http` protocol.  

For guidance on generating a self-signed SSL certificate, refer to Traefik’s documentation [creating a self-signed certificate](https://doc.traefik.io/traefik/expose/docker/#create-a-self-signed-certificate).

<br />
<br />

## Setup Traefik with CSF

By this point in the guide, you should have:

- A registered domain or a local/LAN domain name
- A Let's Encrypt or self-signed SSL certificate
- A running installation of Traefik Reverse Proxy
- An installed copy of ConfigServer Security & Firewall (CSF)

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

In the code block above, we attached multiple Traefik **middlewares** `routers`:  

- [IP AllowList](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/ipallowlist/)
    - Restrict access to the CSF web interface by whitelisted IP addresses.
    - This middleware is included in Traefik; no additional plugins require being downloaded.
- [Authentik Middleware](https://docs.goauthentik.io/add-secure-apps/providers/proxy/server_traefik/)
    - Require authentication through Authentik before allowing access.  
- [Geoblocking](https://plugins.traefik.io/plugins/62d6ce04832ba9805374d62c/geo-block)
    - Restrict access based on Geographical location

<br />

---

<br />

## Restart Traefik

Once you configure these changes in Traefik, you can restart your Traefik docker container. The command for that depends on how you set up the container. If you used `docker-compose.yml`, you can cd into the folder with the `docker-compose.yml` file and then execute:

```shell
docker compose down && docker compose up -d
```

<br />

---

<br />

## Allow Traefik Container IP

The last step in allowing CSF's web interface to pass through Traefik is to add the IP address assigned to your Traefik container to CSF's allow file `/etc/csf/csf.allow`.  

=== ":aetherx-axs-file: /etc/csf/csf.allow"

    ```yaml
    172.18.0.2      # Traefik container IP
    ```

<br />

You **MUST** do this, otherwise when you attempt to access the CSF admin interface, you will get the browser error:

```
Gateway Timeout
```

<br />

---

<br />

## Conclusion

If you do all of the steps above, you should now be able to access the CSF web interface through your browser, with the added protection of Traefik. This will allow you to access the web interface from other locations, implement middleware such as IP whitelisting, and not expose the CSF web interface port to the world. You should **NOT** be allowing any connection to access the web interface, even if they don't have the username and password to sign in.

<br />

---

<br />

## Next Steps <!-- omit from toc -->

{==

Select what documentation you would like to proceed with next ...

==}

<div class="grid cards" markdown>

-   :aetherx-axb-authentik: &nbsp; __[Authentik Integration](../integrations/authentik.md)__

    ---

    Enhance the security of CSF by placing it behind the **Authentik** identity 
    provider using a forward proxy. 
    
    This ensures that all traffic to the CSF web interface passes through Authentik, 
    giving you centralized control over authentication and access.
    
    With this setup, CSF is protected by modern authentication methods such as
    passwords, two-factor authentication (2FA), or passkeys.

-   :aetherx-axd-earth-europe: &nbsp; __[Geographical IP Block Integration](../../usage/geoip.md)__

    ---

    Geographical IP blocking allows you to control access to your server based on
    the country or region an IP address originates from, rather than individual
    IP reputation or blocklist entries.

    This section explains what geographical IP blocks are, how they differ from
    blocklists and IPSETs, and when it makes sense to use country-based filtering.

    You’ll also learn how to integrate CSF with GeoIP data providers to apply
    regional access rules safely and efficiently.

</div>

<br />
<br />
