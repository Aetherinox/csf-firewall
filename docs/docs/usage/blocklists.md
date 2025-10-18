---
title: Usage › Blocklists
tags:
    - usage
    - configure
    - blocklists
status: new
---

# Blocklists

This section outlines the purpose of CSF’s blocklist and how it helps server administrators control which IP addresses are allowed to access the server while rejecting unwanted connection attempts.

<br />

---

<br />

## About Blocklists

A blocklist is a collection of IP addresses or entire networks (CIDRs) that you don’t want accessing your server. When an IP on the blocklist attempts to connect, CSF blocks the request, helping to protect your system from unwanted or malicious traffic.

Blocklists are powerful because they let you deny connections from known bad actors automatically. This includes IPs flagged for brute-force attacks, spam, port scanning, or other suspicious activity. Instead of manually adding rules for each offender, CSF can apply a list of rules that you maintain or import from external sources.

Many blocklists are published and maintained by security organizations that track malicious activity worldwide. By subscribing to these maintained blocklists, you can keep your server automatically protected from known threats without the need for constant manual intervention.

There are numerous popular choices for maintained blocklists such as:

- [Official CSF Repository](https://github.com/Aetherinox/csf-firewall/tree/main/blocklists)
- [Spamhaus](http://spamhaus.org/drop/drop.txt)
- [DShield](https://dshield.org/block.txt)
- [TOR Exit Nodes](https://trac.torproject.org/projects/tor/wiki/doc/TorDNSExitList)
- [BOGON](http://team-cymru.org/Services/Bogons/)
- [Project Honey Pot](http://projecthoneypot.org)
- [C.I. Army Malicious IP List](http://ciarmy.com)
- [BruteForceBlocker](http://danger.rulez.sk/index.php/bruteforceblocker/)
- [MaxMind GeoIP Anonymous Proxies](https://maxmind.com/en/anonymous_proxies)
- [Blocklist.de](https://blocklist.de)
- [Stop Forum Spam](http://stopforumspam.com/downloads/)
- [GreenSnow Hack List](https://greensnow.co)

<br />

---

<br />

## Location

To view or edit your current blocklists, open the file `/etc/csf/csf.blocklists`. An explaination of how the blocklist file works will be given in the sections below.

<br />

---

<br />

## How Blocklists Work

CSF supports **two** different methods for handling blocklists, and the choice depends on how large your lists are and how much efficiency you need.  

<br />

### :aetherx-axd-1: <!-- md:option IPSETs Enabled -->

Blocklists are processed line-by-line, and each entry becomes its own rule in iptables. This option should be selected if you plan to have very large lists containing thousands of entries in your blocklist
  
  - :aetherx-axd-thumbs-up:{ .icon-clr-green } **Pros**: Extremely efficient and scalable, can handle very large lists.
  - :aetherx-axd-thumbs-down:{ .icon-clr-red } **Cons**: Extra dependencies required such as `ipset`.
  - :aetherx-axd-note-sticky:{ .icon-clr-yellow } **Requires**: installing package `ipset`.

<br />

### :aetherx-axd-2: <!-- md:option IPSETs Disabled -->

Blocklists are imported into kernel-managed sets, allowing CSF to check connections against a single set rather than thousands of rules.  This option is acceptable if your blocklists contain less than a thousand entries in your blocklist.

  - :aetherx-axd-thumbs-up:{ .icon-clr-green } **Pros**: Simple, no extra dependencies, works out of box.
  - :aetherx-axd-thumbs-down:{ .icon-clr-red } **Cons**: Becomes slow and inefficient with large blocklists.

<br />

If you wish to utilize option :aetherx-axd-1: and enable IPSET, please review our documentation regarding the installation and configuration of IPSET on your server.

<br />

<div class="grid cards" markdown>

-   :aetherx-axs-network-wired: &nbsp; __[Introduction to IPSETs](../usage/ipset.md)__

    ---

    Improve firewall efficiency in CSF by enabling IPSET integration to manage
    large blocklists.  

    This chapter covers installing the IPSET package and configuring CSF to use
    it for handling blocklists.  

    Using IPSET allows CSF to group IP addresses into sets, reducing the number
    of iptables rules and improving overall performance.

</div>

<br />

---

<br />

## Configure Blocklists

Subscribed blocklists can be managed by opening the file `/etc/csf/csf.blocklists`.

By default, every list is commented out with a `#` symbol at the beginning of the line. Leave the line commented if you do not wish to use that blocklist. To enable a blocklist, simply remove the `#` and save the file.

??? note "Uncomment the blocklists you want ..."

    Out of box, all blocklists are commented with the character `#` at the front of every line. To use a blocklist, remove the command character `#` and save the file.

``` ini title="/etc/csf/csf.blocklists"
# #
#   @blocklist              Official CSF Blocklists
#   @details:               https://aetherinox.github.io/csf-firewall/usage/blocklists/#official-blocklists
#                           https://aetherinox.github.io/csf-firewall/advanced/services/blocklist.configserver
#   
#   The official CSF blocklists contain a large number of IPs which range from various 
#   different services, including AbuseIPDB (100% confidency).
#   
#   You can also use our blocklist service:
#       http://blocklist.configserver.dev/master.ipset
#       http://blocklist.configserver.dev/highrisk.ipset
#   
#   We offer many others, but these two are the primary ones.
#   
#   Requires you to edit /etc/csf/csf.conf setting:
#       LF_IPSET_MAXELEM = "4000000"
# #

#   CSF_MASTER|43200|0|http://blocklist.configserver.dev/master.ipset
#   CSF_HIGHRISK|43200|0|http://blocklist.configserver.dev/highrisk.ipset

# #
#   @blocklist              Spamhaus Don't Route Or Peer List (DROP)
#   @details:               http://spamhaus.org/drop
# #

#   SPAMDROP|86400|0|http://www.spamhaus.org/drop/drop.txt

# #
#   @blocklist              Spamhaus IPv6 Don't Route Or Peer List (DROPv6)
#   @details:               http://spamhaus.org/drop
# #

#   SPAMDROPV6|86400|0|https://www.spamhaus.org/drop/dropv6.txt

# #
#   @blocklist              Spamhaus Extended DROP List (EDROP)
#   @details:               http://spamhaus.org/drop
# #

#   SPAMEDROP|86400|0|http://www.spamhaus.org/drop/edrop.txt

# #
#   @blocklist              DShield.org Recommended Block List
#   @details:               https://dshield.org
# #

#   DSHIELD|86400|0|https://www.dshield.org/block.txt

# #
#   @blocklist              TOR Exit Nodes List
#   @details:               https://trac.torproject.org/projects/tor/wiki/doc/TorDNSExitList
#   @notes                  Set URLGET in csf.conf to use LWP as this list
#                           uses an SSL connection
# #

#   TOR|86400|0|https://check.torproject.org/cgi-bin/TorBulkExitList.py?ip=1.2.3.4

# #
#   @blocklist              BOGON list
#   @details:               http://team-cymru.org/Services/Bogons
# #

#   BOGON|86400|0|http://www.cymru.com/Documents/bogon-bn-agg.txt

# #
#   @blocklist              Project Honey Pot Directory of Dictionary Attacker IPs
#   @details:               http://projecthoneypot.org
# #

#   HONEYPOT|86400|0|https://www.projecthoneypot.org/list_of_ips.php?t=d&rss=1

# #
#   @blocklist              C.I. Army Malicious IP List
#   @details:               https://ciarmy.com
# #

#   CIARMY|86400|0|http://www.ciarmy.com/list/ci-badguys.txt

# #
#   @blocklist              BruteForceBlocker IP List
#   @details:               http://danger.rulez.sk/index.php/bruteforceblocker
# #

#   BFB|86400|0|http://danger.rulez.sk/projects/bruteforceblocker/blist.php

# #
#   @blocklist              MaxMind GeoIP Anonymous Proxies
#   @details:               https://maxmind.com/en/anonymous_proxies
#   @notes:                 Set URLGET in csf.conf to use LWP as this list
#                           uses an SSL connection
#   
#   This first list only retrieves the IP addresses added in the last hour
# #

#   MAXMIND|86400|0|https://www.maxmind.com/en/anonymous_proxies

# #
#   @blocklist              Blocklist.de
#   @details:               https://blocklist.de
#   @notes:                 Set URLGET in csf.conf to use LWP as this list
#                           uses an SSL connection
#   
#   This first list only retrieves the IP addresses added in the last hour
# #

#   BDE|3600|0|https://api.blocklist.de/getlast.php?time=3600

# #
#   This second list retrieves all the IP addresses added in the last 48 hours
#   and is usually a very large list (over 10000 entries), so be sure that you
#   have the resources available to use it
# #

#   BDEALL|86400|0|http://lists.blocklist.de/lists/all.txt

# #
#   @blocklist              Stop Forum Spam
#   @details:               http://stopforumspam.com/downloads
#   @notes:                 Many of the lists available contain a vast number of
#                           IP addresses so special care needs to be made when
#                           selecting from their lists
# #

#   STOPFORUMSPAM|86400|0|http://www.stopforumspam.com/downloads/listed_ip_1.zip

# #
#   @blocklist              Stop Forum Spam IPv6
#   @details:               http://stopforumspam.com/downloads
#   @notes:                 Many of the lists available contain a vast number of
#                           IP addresses so special care needs to be made when
#                           selecting from their lists
# #

#   STOPFORUMSPAMV6|86400|0|http://www.stopforumspam.com/downloads/listed_ip_1_ipv6.zip

# #
#   @blocklist              GreenSnow Hack List
#   @details:               https://greensnow.co
# #

#   GREENSNOW|86400|0|https://blocklist.greensnow.co/greensnow.txt
```

<br />

We will use the first blocklist in the example above to explain the format. 

``` ini title="/etc/csf/csf.blocklists"
# #
#   Example Blocklists
#   NAME   | INTERVAL | MAX_IPS | BLOCKLIST_URL
# #

SPAMDROP      |   86400   |    0    |  https://spamhaus.org/drop/drop.txt
CSF_HIGHRISK  |   43200   |    0    |  https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/highrisk.ipset
DSHIELD       |   86400   |    0    |  https://dshield.org/block.txt
----------------------------------------------------------------------------------------------------------------------------------
    ^NAME^     ^INTERVAL^  ^MAX_IPS^              ^BLOCKLIST_URL^              
```

<!-- md:option NAME -->

:   List name with all uppercase alphabetic characters with no spaces and a maximum of 25 characters - this will be used as the iptables chain name

<!-- md:option INTERVAL -->

:   Refresh interval to download the list, must be a minimum of 3600 seconds (an hour).

      - 43200: 12 hours
      - 86400: 24 hours

<!-- md:option MAX_IPS -->

:   This is the maximum number of IP addresses to use from the list, a value of `0` means all IPs (see note below).
        If you add an ipset with 50,000 IPs, and you set this value to 20,000; then you will only block the first 20,000.

<!-- md:option URL -->

:   The URL to download the ipset from

<br />

---

<br />

## Official Blocklists

While there are many blocklists available on the internet — including repositories on GitHub — CSF also provides official blocklists maintained directly in our repository. These lists are curated, updated regularly, and designed to minimize false positives while providing protection against common threats.

<br />

These lists are refreshed approximately every `6 hours` to ensure up-to-date protection. They include IP addresses flagged for abusive behavior such as:

- SSH brute-forcing  
- Port scanning  
- DDoS attacks  
- IoT exploitation  
- Phishing attempts  

<br />

For most users, the `master.ipset` and `highrisk.ipset` lists are sufficient. They contain large collections of high-confidence IPs (100% confidence level) to reduce the chance of false positives.

In addition to the primary lists, the CSF repository also offers specialized blocklists for categories like privacy, spam, and geographic restrictions. These allow you to further tailor your firewall rules, such as blocking traffic from specific countries.

<br />

The primary blocklists can be added to your `/etc/csf/csf.blocklists` file. Open the blocklist file and add the following:

``` ini
# #
#   @blocklist              Official CSF Blocklists
#   @details:               https://aetherinox.github.io/csf-firewall/usage/blocklists/#official-blocklists
#                           https://aetherinox.github.io/csf-firewall/advanced/services/blocklist.configserver
#   
#   The official CSF blocklists contain a large number of IPs which range from various 
#   different services, including AbuseIPDB (100% confidency).
#   
#   You can also use our blocklist service:
#       http://blocklist.configserver.dev/master.ipset
#       http://blocklist.configserver.dev/highrisk.ipset
#   
#   We offer many others, but these two are the primary ones.
#   
#   Requires you to edit /etc/csf/csf.conf setting:
#       LF_IPSET_MAXELEM = "4000000"
# #

CSF_MASTER   | 43200 | 0      | http://blocklist.configserver.dev/master.ipset
CSF_HIGHRISK | 43200 | 0      | http://blocklist.configserver.dev/highrisk.ipset
```

<br />

??? danger "Master blocklist without IPSET enabled can cause server instability & increased memory usage"

    The official `master.ipset` blocklist contains millions of IP addresses. 

    We strongly recommend [enabling IPSET](#enable) before using this list. Without IPSET, CSF will create a separate iptables rule for every IP, which can drastically increase memory usage and slow down firewall operations.

    Using this list without IPSET may lead to performance issues or even system instability on servers with limited resources.

<br />

The blocklists you added from above should give you the entire collection for each main blocklist. All that is needed is to restart CSF to ensure that the blocklists take affect:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo csf -ra
      ```

<br />

When CSF restarts, these blocklists will be loaded into CSF, and if someone from one of the IP addresses in these lists attempt to connect to your server in any way, they'll be timed out and unable to communicate with your server. You can confirm that these blocklists are loaded by running the command:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo ipset --list -n
      ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      chain_DENY
      chain_6_DENY
      chain_ALLOW
      chain_6_ALLOW
      bl_CSF_HIGHRISK
      bl_6_CSF_HIGHRISK
      bl_CSF_MASTER
      bl_6_CSF_MASTER
      ```

<br />

In the `Output` tab above, you are looking for the following to show up in your list:

| Blocklist | List Name | Protocol Version | Description |
| --- | --- | --- | --- |
| **Master** | `bl_CSF_MASTER` | IPv4 | List of all IPv4 addresses to restrict |
| **Master** | `bl_6_CSF_MASTER` | IPv6 | List of all IPv6 addresses to restrict |
| **High Risk** | `bl_CSF_HIGHRISK` | IPv4 | List of all IPv4 addresses to restrict |
| **High Risk** | `bl_6_CSF_HIGHRISK` | IPv6 | List of all IPv6 addresses to restrict |

<br />

To view a list of all IP addresses within a specific blocklist, run the command:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo ipset --list bl_CSF_HIGHRISK
      ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      Name: bl_CSF_HIGHRISK
      Type: hash:net
      Revision: 7
      Header: family inet hashsize 1024 maxelem 4000000 bucketsize 12 initval 0x5f263e28
      Size in memory: 24024
      References: 1
      Number of entries: 630
      Members:
      XX.XX.XX.XXX
      XX.XX.XX.XXX
      [ ... ]
      ```

<br />

Now that you have our official blocklists loaded within your `/etc/csf/csf.blocklists`, we need to ensure that the setting `LF_IPSET_MAXELEM` is set to the proper value, otherwise, not all of the blocked IP addresses we provide will be loaded. That is explained in the section below.

??? warning "Official master blocklist requires increased `LF_IPSET_MAXELEM`"

    If you decide to use our official blocklist `master.ipset`, you **must** increase the value of the setting `LF_IPSET_MAXELEM` in `/etc/csf/csf.conf` to at least `4000000`.

    Instructions for doing this are available in the next section [Increase Max Limit](#increase-max-limit)

<br />

---

<br />

## Increase Max Limit

By default, CSF places a cap on the number of IP addresses that can be loaded into a single IPSET. This is controlled by the setting `LF_IPSET_MAXELEM` inside your CSF configuration file `/etc/csf/csf.conf`.  

Out of the box, this value is set to **65536** (around sixty-five thousand IPs). That means if a blocklist tries to load more than that, the extra entries will be ignored — even if you set the blocklist `MAX_IPS` value to `0` (unlimited) or a number greater than 65536.

For servers that rely on multiple large blocklists, this default limit is often too low. To raise the maximum number of IPs that can be stored inside a set, you’ll need to increase the `LF_IPSET_MAXELEM` value.

=== ":aetherx-axs-file-magnifying-glass: Find"

    ``` bash title="/etc/csf/csf.conf"
    LF_IPSET_MAXELEM = "65536"
    ```

=== ":aetherx-axs-file-pen: Change To"

    ``` bash title="/etc/csf/csf.conf"
    LF_IPSET_MAXELEM = "4000000"
    ```

<br />

Once you have the setting changed in your CSF config, give CSF a restart:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo csf -ra
      ```

<br />

After the new setting has been applied, you can go back to your blocklists within the file `/etc/csf/csf.blocklists` and increase the limit as needed:

=== ":aetherx-axs-file-magnifying-glass: Find"

    The blocklist below is has the `MAX_IPS` set to `65536`, which is very low for this blocklist. This one contains about 2 million blocked IP addresses. With the below setting, we will only be able to load 65,536 out of those 2,000,000 IP addresses.

    ``` bash title="/etc/csf/csf.blocklists"
    CSF_HIGHRISK|43200|65536|https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/highrisk.ipset
    ```

=== ":aetherx-axs-file-pen: Change To"

    We changed the `MAX_IP` value from the default `65536` to `0` for unlimited. Since this particular
    blocklist only gives us about 2 million blocked IP addresses, and we've set our `LF_IPSET_MAXELEM` to 4 million.

    ``` bash title="/etc/csf/csf.blocklists"
    CSF_HIGHRISK|43200|0|https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/highrisk.ipset
    ```

<br />

If you are using our [Official Blocklists](#official-blocklists), you can confirm the increased limit by running the command:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo ipset --list bl_CSF_HIGHRISK
      ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      Name: bl_CSF_HIGHRISK
      Type: hash:net
      Revision: 7
      Header: family inet hashsize 1024 maxelem 4000000 bucketsize 12 initval 0x5f263e28
      Size in memory: 24024
      References: 1
      Number of entries: 630
      Members:
      XX.XX.XX.XXX
      XX.XX.XX.XXX
      [ ... ]
      ```

<br />

You will see the new max limit value listed next `maxelem`.

```shell
Header: family inet hashsize 1024 maxelem 4000000 bucketsize 12 initval 0x5f263e28
```

<br />

---

<br />

## Next Steps <!-- omit from toc -->

{==

Select what documentation you would like to proceed with next ...

==}

<div class="grid cards" markdown>

-   :aetherx-axd-earth-europe: &nbsp; __[Geographical IP Block Integration](../usage/geoip.md)__

    ---

    Configure geographical restrictions in CSF to whitelist or blacklist specific
    regions from accessing your server.
    
    This chapter covers enabling the GeoIP blocklist feature using third-party
    services such as MaxMind (requires an API key), db-ip, ipdeny, or iptoasn.
    
    These services allow you to control access based on location while keeping
    your server secure.

</div>

<br />

---

<br />
