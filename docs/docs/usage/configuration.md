---
title: "Usage › Configuration"
tags:
  - usage
  - configure
---

# Usage › Configuration

This section introduces the main CSF configuration file, which controls how CSF operates and determines which features are active on your server.

<br />

---

<br />


## Location

The main configuration file for CSF is located in `/etc/csf/csf.conf`. You can use your preferred text editor to modify the file, such as nano or vim:

=== ":aetherx-axd-command: Command"

      ```
      sudo nano /etc/csf/csf.conf
      ```

<br />

---

<br />

## Essential Config Properties

This section outlines some of the most important settings that you may want to review. Each one is listed below:

<br />

### TESTING

<!-- md:flag required --> <!-- md:file https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/extras/example_configs/etc/csf/csf.conf https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/extras/example_configs/etc/csf/csf.conf --> <!-- md:source /etc/csf/csf.conf --> <!-- md:default `1` -->

<br />

Testing mode is a feature built into CSF and LFD which does the following when enabled:

- Allows safe configuration of CSF without enforcing firewall rules or banning IPs.
- Reads configuration files like `/etc/ssh/sshd_config` to detect service ports. Detected ports (SSH, IPv6, TCP/UDP) are added to CSF config variables such as `TCP_IN`, `TCP6_IN`, `UDP_IN` in `/etc/csf/csf.conf`.
- LFD does not run as a daemon.
- Adds a cron job to periodically reload CSF rules for testing, but no actual blocking occurs.
- IPs in `csf.allow` and `csf.deny` are processed for testing but **not enforced**.
- Displays currently listening ports to sysadmin; helps safely configure CSF before enabling enforcement.

```ini
# #
#   Testing flag - enables a CRON job that clears iptables incase of
#   configuration problems when you start csf. This should be enabled until you
#   are sure that the firewall works - i.e. incase you get locked out of your
#   server! Then do remember to set it to 0 and restart csf when you're sure
#   everything is OK. Stopping csf will remove the line from /etc/crontab
#   
#   lfd will not start while this is enabled
# #

TESTING = "0"
```

<br />
<br />

### TCP_IN, TCP_OUT

<!-- md:flag required --> <!-- md:file https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/extras/example_configs/etc/csf/csf.conf https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/extras/example_configs/etc/csf/csf.conf --> <!-- md:source /etc/csf/csf.conf --> <!-- md:default `22,53,80,110,143,443,465,587,993,995` -->

<br />

Define the allowed incoming and outgoing TCP ports, respectively. Add or remove ports as required, separated by commas.

=== ":aetherx-axs-file: Config"

      ```ini
      # Allow incoming TCP ports
      TCP_IN = "22,53,80,110,143,443,465,587,993,995"

      # Allow outgoing TCP ports
      TCP_OUT = "22,53,80,110,143,443,465,587,993,995"
      ```

=== ":aetherx-axs-square-list: Common Ports"

      The following are a list of the most common ports that you may find useful allowing traffic through.

      | Port | Description |
      |------|-------------|
      | 20   | FTP data transfer (active mode) |
      | 21   | FTP control/commands |
      | 22   | SSH / SFTP (secure shell and file transfer) |
      | 25   | SMTP (sending email between mail servers) |
      | 53   | DNS (Domain Name System queries) |
      | 80   | HTTP (web traffic, insecure) |
      | 110  | POP3 (downloading emails, insecure) |
      | 113  | Ident / AUTH (rarely used identification service) |
      | 139  | Samba (legacy) (SMB over NetBIOS) |
      | 143  | IMAP (retrieving/syncing emails, insecure) |
      | 443  | HTTPS (secure web traffic) |
      | 445  | Samba (modern - preferred) (SMB over TCP) |
      | 465  | SMTP over SSL (secure sending of emails) |
      | 587  | SMTP submission (secure client-to-server email sending) |
      | 853  | DNS over TLS (secure DNS queries) |
      | 993  | IMAP over SSL (secure email retrieval) |
      | 995  | POP3 over SSL (secure email download) |

=== ":aetherx-axs-note-sticky: Notes"

      <h3>Samba Users</h3>

      You must have the following `TCP` ports unblocked:

      ``` shell
      TCP_IN = "445,139"
      TCP_OUT = "445,139"
      ```

      <br />

      You must have the following `UDP` ports unblocked:

      ``` shell
      UDP_IN = "137,138,445"
      UDP_OUT = "137,138,445"
      ```

<br />
<br />

### UDP_IN, UDP_OUT

<!-- md:flag required --> <!-- md:fileDownload https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/extras/example_configs/etc/csf/csf.conf --> <!-- md:source /etc/csf/csf.conf --> <!-- md:default `20,21,53,853,80,443` -->

<br />

Define the allowed incoming and outgoing UDP ports, respectively. Add or remove ports as required, separated by commas.

=== ":aetherx-axs-file: Config"

      ```ini
      # Allow incoming UDP ports
      UDP_IN = "20,21,53,853,80,443"

      # Allow outgoing UDP ports
      # To allow outgoing traceroute add 33434:33523 to this list 
      UDP_OUT = "20,21,53,853,113,123"
      ```

=== ":aetherx-axs-square-list: Common Ports"

      The following are a list of the most common ports that you may find useful allowing traffic through.

      | Port        | Description |
      |------------|-------------|
      | 20         | FTP data transfer (rarely UDP, mostly TCP) |
      | 21         | FTP control/commands (rarely UDP, mostly TCP) |
      | 53         | DNS queries (UDP is standard; TCP fallback for large responses) |
      | 80         | HTTP (UDP not standard; TCP is primary) |
      | 113        | Ident / AUTH (rarely used) |
      | 123        | NTP (Network Time Protocol) |
      | 443        | HTTPS (UDP can be used with QUIC protocol) |
      | 853        | DNS over TLS (UDP fallback possible) |
      | 67         | DHCP server (receives client requests) |
      | 68         | DHCP client (receives server responses) |
      | 137        | Samba / NetBIOS Name Service (NBNS) |
      | 138        | Samba / NetBIOS Datagram Service (NBDS) |
      | 161        | SNMP (Simple Network Management Protocol) |
      | 162        | SNMP traps (from agents to manager) |
      | 500        | IKE (IPsec key exchange) |
      | 514        | Syslog (UDP logging) |
      | 1900       | SSDP (Simple Service Discovery Protocol, used in UPnP) |
      | 4500       | IPsec NAT traversal |
      | 33434–33523 | Traceroute / ICMP UDP probe ports |

=== ":aetherx-axs-note-sticky: Notes"

      <h3>Samba Users</h3>

      You must have the following `TCP` ports unblocked:

      ``` shell
      TCP_IN = "445,139"
      TCP_OUT = "445,139"
      ```

      <br />

      You must have the following `UDP` ports unblocked:

      ``` shell
      UDP_IN = "137,138,445"
      UDP_OUT = "137,138,445"
      ```

<br />
<br />

### DENY_IP_LIMIT

<!-- md:flag required --> <!-- md:fileDownload https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/extras/example_configs/etc/csf/csf.conf --> <!-- md:source /etc/csf/csf.conf --> <!-- md:default `200` -->

<br />

This setting controls the **maximum number of IP addresses** that can be listed in the `/etc/csf/csf.deny` file. You can increase or decrease this limit depending on your server’s needs.  

Keep in mind that raising the limit on servers with low memory (such as Virtuozzo or OpenVZ) may cause network slowdowns if thousands of rules are loaded.  

When the limit is reached, CSF will automatically rotate the entries; meaning that the oldest entries (at the top of the file) are removed, and the newest ones are added. This check only happens when using `csf -d`, which is also what `lfd` relies on. Setting this value to `0` disables the limit entirely.  

If you need to allow a much larger number of blocked IPs or CIDRs, it’s recommended to use CSF's [IPSETs](../usage/ipset.md) integration instead for better performance.

``` cfg
# #
#   Limit the number of IP's kept in the /etc/csf/csf.deny file
#   
#   Care should be taken when increasing this value on servers with low memory
#   resources or hard limits (such as Virtuozzo/OpenVZ) as too many rules (in the
#   thousands) can sometimes cause network slowdown
#   
#   The value set here is the maximum number of IPs/CIDRs allowed
#   if the limit is reached, the entries will be rotated so that the oldest
#   entries (i.e. the ones at the top) will be removed and the latest is added.
#   The limit is only checked when using csf -d (which is what lfd also uses)
#   Set to 0 to disable limiting
#   
#   For implementations wishing to set this value significantly higher, we
#   recommend using the IPSET option
# #

DENY_IP_LIMIT = "200"
```

<br />
<br />

### CT_LIMIT

<!-- md:flag required --> <!-- md:fileDownload https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/extras/example_configs/etc/csf/csf.conf --> <!-- md:source /etc/csf/csf.conf --> <!-- md:default `0` -->

<br />

**Connection Tracking** lets the firewall keep track of how many connections each IP address makes to your server. If an IP opens more connections than the set limit, it will be automatically blocked. This can help protect against certain types of DoS (Denial of Service) attacks.  

Be cautious when enabling this option. Some services like **FTP**, **IMAP**, and **HTTP** naturally create many connections, including ones left in `TIME_WAIT`, which can lead to false positives. On busy servers, it’s easy for legitimate traffic to hit the limit. For servers at higher risk of DoS attacks, however, this feature can be very useful. A practical starting value is usually around `300` connections.

To disable this feature, set this to 0

```ini
# #
#   Connection Tracking. This option enables tracking of all connections from IP
#   addresses to the server. If the total number of connections is greater than
#   this value then the offending IP address is blocked. This can be used to help
#   prevent some types of DOS attack.
#
#   Care should be taken with this option. It's entirely possible that you will
#   see false-positives. Some protocols can be connection hungry, e.g. FTP, IMAPD
#   and HTTP so it could be quite easy to trigger, especially with a lot of
#   closed connections in TIME_WAIT. However, for a server that is prone to DOS
#   attacks this may be very useful. A reasonable setting for this option might
#   be around 300.
#   
#   To disable this feature, set this to 0
# #

CT_LIMIT = "0"
```

<br />
<br />

### UI_BLOCK_PRIVATE_NET

<!-- md:flag required --> <!-- md:fileDownload https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/extras/example_configs/etc/csf/csf.conf --> <!-- md:source /etc/csf/csf.conf --> <!-- md:default `1` --> <!-- md:version stable-15.01 -->

<br />

This option determines whether login attempts to the CSF/LFD web interface (UI) from the server’s **own local network interfaces** are allowed or blocked.  Local interfaces include any IPs bound to the system’s network devices, as discovered by `getethdev`. These typically cover private IP ranges such as:

- **192.168.x.x**
- **172.16–31.x.x**
- **10.x.x.x**
- addresses assigned to **Docker bridges**, **virtual adapters**, or **loopback interfaces**.

When this setting is enabled with the value `1`, CSF will block access attempts originating from local network IPs. This helps prevent unauthorized access from internal containers, proxy bridges, or other services running within the same host environment. It’s a useful safeguard against loopback-style attacks or accidental internal exposure.

If you intentionally access the CSF web interface through a local bridge such as a Docker container using a proxy IP like 172.18.0.2; you may need to disable this feature by setting the value to `0`.

Keeping this feature enabled is recommended for most setups, as it adds an extra layer of protection against internal or bridged network access. When blocked, the browser will typically display an error such as `PR_CONNECT_RESET_ERROR` when attempting to connect.

```ini
# #
#   Connection Tracking. This option enables tracking of all connections from IP
#   addresses to the server. If the total number of connections is greater than
#   this value then the offending IP address is blocked. This can be used to help
#   prevent some types of DOS attack.
#
#   Care should be taken with this option. It's entirely possible that you will
#   see false-positives. Some protocols can be connection hungry, e.g. FTP, IMAPD
#   and HTTP so it could be quite easy to trigger, especially with a lot of
#   closed connections in TIME_WAIT. However, for a server that is prone to DOS
#   attacks this may be very useful. A reasonable setting for this option might
#   be around 300.
#   
#   To disable this feature, set this to 0
# #

CT_LIMIT = "0"
```


<br />
<br />

<br />

---

<br />

## Next Steps <!-- omit from toc -->

{==

Select what documentation you would like to proceed with next ...

==}

<div class="grid cards" markdown>

-   :aetherx-axs-network-wired: &nbsp; __[Introduction to IPSETs](../usage/ipset.md)__

    ---

    Improve firewall efficiency in CSF by enabling IPSET integration to manage
    large blocklists.  

    This chapter covers installing the IPSET package and configuring CSF to use
    it for handling blocklists.  

    Using IPSET allows CSF to group IP addresses into sets, reducing the number
    of iptables rules and improving overall performance.

-   :aetherx-axs-ban: &nbsp; __[Setting Up Blocklists](../usage/blocklists.md)__

    ---

    Blocklists in CSF allow you to automatically block connections from known
    malicious IP addresses, helping to protect your server from abusive traffic.  

    This chapter explains how to configure and use blocklists, including CSF’s
    official blocklist and third-party sources.  

    You’ll also learn how to enable blocklists with or without IPSET, ensuring
    they work efficiently no matter the size of the list.

</div>

<br />
<br />
