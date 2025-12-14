---
title: Usage › Blocklists
tags:
    - usage
    - configure
    - blocklists
    - ipset
---

# Blocklists

This section outlines the purpose of CSF’s blocklist and how it helps server administrators control which IP addresses are allowed to access the server while rejecting unwanted connection attempts.

<br />

## :aetherx-axj-bell:{ .icon-tldr } Summary

The following is a summary of what this page explains:

- CSF includes support for a feature known as **Blocklists**.
- A blocklist is a file that contains thousands (or even millions) of IP addresses that CSF can import to automatically deny access to your server.
- These IP addresses are gathered and maintained by third-party services that monitor IP reputation, tracking malicious behavior such as port scans, brute-force login attempts, and other abusive activity.
- When an IP is repeatedly reported for malicious actions, it is added to a blocklist. You can then find these generated blocklists online, and import the IPs from those lists into your firewall.
- Taffic from the IPs within these blocklists are blocked from accessing your server if they ever attempt to target you.
- While blocklists are effective, very large blocklists come with a drawback: each IP address must be added as its own firewall rule.
- Creating thousands of individual firewall rules can significantly impact server performance and increase memory usage.
- To solve this problem, CSF also supports **IPSETs**.
- IPSETs serve the same purpose as blocklists, but are handled much more efficiently by the firewall. Instead of creating one rule per IP address, IPSETs store large collections of IPs in optimized sets that the firewall can check instantly.
- This allows you to block vastly larger numbers of IP addresses without degrading performance or exhausting system memory.
- This page covers blocklists, but only covers IPSETs very briefly. For a complete guide on how to set up IPSETs, [read the IPSET guide here](../usage/ipset.md).

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

To view or edit your current blocklists, open the file ++"/etc/csf/csf.blocklists"++. An explaination of how the blocklist file works will be given in the sections below.

<br />

---

<br />

## How Blocklists Work

CSF supports **two** different methods for handling blocklists, and the choice depends on how large your lists are and the efficiency you want.  

<br />

### :aetherx-axd-1: <!-- md:option IPSET Disabled -->

Blocklists are processed line-by-line, and each entry becomes its own rule in iptables. This option should be selected if you plan to have very small lists that do not contain more than a few thousand entries.
  
  - :aetherx-axd-thumbs-up:{ .icon-clr-green } **Pros**: Simple, no extra dependencies, works out of box.
  - :aetherx-axd-thumbs-down:{ .icon-clr-red } **Cons**: Becomes slow and inefficient with large blocklists.

<br />

### :aetherx-axd-2: <!-- md:option IPSET Enabled -->

Blocklists are imported into kernel-managed sets, allowing CSF to check connections against a single set rather than thousands of rules.  This option is acceptable if your blocklist contains thousands of entries.

  - :aetherx-axd-thumbs-up:{ .icon-clr-green } **Pros**: Extremely efficient and scalable, can handle very large lists.
  - :aetherx-axd-thumbs-down:{ .icon-clr-red } **Cons**: Extra package dependency `ipset` must be installed.

<br />

If you wish to utilize option :aetherx-axd-2: and enable IPSET, please review the section below [Large Blocklists and IPSET](#large-blocklists-and-ipset) regarding the installation and configuration of IPSET on your server related to blocklists.

<br />

<div class="grid cards" markdown>

-   :aetherx-axd-block-brick-fire: &nbsp; __[Introduction to IPSETs](../usage/ipset.md)__

    ---

    Blocklists and IPSETs are designed to work together. Blocklists provide a simple
    way to block unwanted traffic from reaching your server, but large blocklists
    can be inefficient and memory-intensive.

    If you plan to import blocklists containing more than a few thousand IP addresses,
    it is strongly recommended to enable CSF’s IPSET integration.

    IPSETs allow you to block significantly larger numbers of IP addresses in a far
    more efficient way, without the risk of excessive memory usage or performance
    degradation.

</div>

<br />

---

<br />

## Configure Blocklists

You can manage and define which blocklists you wish to use in CSF by opening the file ++"/etc/csf/csf.blocklists"++.

By default, every blocklist is commented out with a ++"#"++ symbol at the beginning of the line. Leave the line commented if you do not wish to use that blocklist. To enable a blocklist, simply remove the ++"#"++ and save the file.

??? note "All blocklists in CSF are disabled by default"

    Out of box, all blocklists are commented with the character ++"#"++ at the front of every line. To use a blocklist, remove the command character ++"#"++ and save the file.

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
#       https://blocklist.configserver.dev/master.ipset
#       https://blocklist.configserver.dev/highrisk.ipset
#   
#   We offer many others, but these two are the primary ones.
#   
#   Requires you to edit /etc/csf/csf.conf setting:
#       LF_IPSET_MAXELEM = "500000"
# #

#   CSF_MASTER      | 43200 | 0 | https://blocklist.configserver.dev/master.ipset
#   CSF_HIGHRISK    | 43200 | 0 | https://blocklist.configserver.dev/highrisk.ipset

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
#   NAME   | INTERVAL | MAX_ENTRIES | BLOCKLIST_URL
# #

SPAMDROP      |   86400   |      0      |  https://spamhaus.org/drop/drop.txt
CSF_HIGHRISK  |   43200   |      0      |  https://blocklist.configserver.dev/highrisk.ipset
DSHIELD       |   86400   |      0      |  https://dshield.org/block.txt
----------------------------------------------------------------------------------------------------------------------------------
    ^NAME^     ^INTERVAL^  ^MAX_ENTRIES^              ^BLOCKLIST_URL^              
```

<!-- md:option NAME -->

:   Blocklist name with all uppercase alphabetic characters with no spaces and a maximum of 25 characters - this will be used as the iptables chain name

<!-- md:option INTERVAL -->

:   Cache refresh interval (in seconds) to keep the list, must be a minimum of 3600 seconds (an hour). After this time has expired, entries in the blocklist will be refreshed.

      - `43200`: 12 hours
      - `86400`: 24 hours

<!-- md:option MAX_ENTRIES -->

:   This is the maximum number of entries to load from a list. A value of ++0++ means all entries will be loaded (see note below).
        If you add a blocklist with 50,000 entries, and you set this value to 20,000; then you will only load the first 20,000 entries within the blocklist.

<!-- md:option URL -->

:   The URL to download the ipset from

<br />

---

<br />

## Official Blocklists

While there are many blocklists available on the internet — including repositories on GitHub — CSF also provides official blocklists maintained directly by us. These lists are curated, updated regularly, and designed to minimize false positives while providing protection against common threats.

<br />

These lists are refreshed approximately every `12 hours` to ensure up-to-date protection. They include IP addresses flagged for abusive behavior such as:

- SSH brute-forcing  
- Port scanning  
- DDoS attacks  
- IoT exploitation  
- Phishing attempts  

<br />

While we provide a wide selection of blocklists, most users will find that the [master.ipset](https://blocklist.configserver.dev/master.ipset) and [highrisk.ipset](https://blocklist.configserver.dev/highrisk.ipset) lists are more than enough to maintain strong security. These lists include extensive collections of high-confidence IPs (100% confidence level), minimizing the risk of false positives.

In addition to the primary lists, the CSF repository also offers specialized blocklists for categories like privacy, spam, and geographic restrictions. These allow you to further tailor your firewall rules, such as blocking traffic from specific countries.

The main blocklists come pre-configured in your `/etc/csf/csf.blocklists` file. To activate a blocklist, simply remove the leading comment character ++"#"++.

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
#       https://blocklist.configserver.dev/master.ipset
#       https://blocklist.configserver.dev/highrisk.ipset
#   
#   We offer many others, but these two are the primary ones.
#   
#   Requires you to edit /etc/csf/csf.conf setting:
#       LF_IPSET_MAXELEM = "500000"
# #

CSF_MASTER   | 43200 | 0 | https://blocklist.configserver.dev/master.ipset
CSF_HIGHRISK | 43200 | 0 | https://blocklist.configserver.dev/highrisk.ipset
```

<br />

??? danger "Using the `master.ipset` blocklist without enabling IPSET can cause server instability & increased memory usage"

    The official [master.ipset](https://blocklist.configserver.dev/master.ipset) blocklist contains millions of IP addresses. 

    We strongly recommend [enabling IPSET](#enable) before using this list. Without IPSET, CSF will create a separate iptables rule for every IP, which will dramatically increase memory usage and slow down firewall operations.

    Using this list without IPSET may lead to performance issues or even system instability on servers with limited resources (memory).

<br />

Adding our [master.ipset](https://blocklist.configserver.dev/master.ipset) and [highrisk.ipset](https://blocklist.configserver.dev/highrisk.ipset) blocklists from above will give you the entire collection for each main blocklist and will offer great protection. All that is needed is to restart CSF to ensure that the blocklists take affect:

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
      Header: family inet hashsize 1024 maxelem 500000 bucketsize 12 initval 0x5f263e28
      Size in memory: 24024
      References: 1
      Number of entries: 630
      Members:
      XX.XX.XX.XXX
      XX.XX.XX.XXX
      [ ... ]
      ```

<br />

Now that you have our official blocklists defined in ++"/etc/csf/csf.blocklists"++, we need to ensure that the setting ++"LF_IPSET_MAXELEM"++ is set to the proper value, otherwise, not all of the blocked entries in the lists will be loaded. That is explained in the section below.

??? warning "Official master blocklist requires increased ++"LF_IPSET_MAXELEM"++"

    If you plan to use our official blocklist, [master.ipset](https://blocklist.configserver.dev/master.ipset), you **must** increase the ++"LF_IPSET_MAXELEM"++ setting in ++"/etc/csf/csf.conf"++. 
    
    The [master.ipset](https://blocklist.configserver.dev/master.ipset) file currently contains approximately 350,000 entries. To allow for future updates and ensure safe operation, set ++"LF_IPSET_MAXELEM"++ to around ++"500000"++.

    Instructions for doing this are available in the next section [Increase Max Limit](#increase-maximum-entry-limit).

<br />

---

<br />

## Large Blocklists and IPSET

When using large blocklists _(more than a few thousand entries in a list)_, such as our officially maintained [master.ipset](https://blocklist.configserver.dev/master.ipset), it is strongly recommended to enable ++"IPSET"++.

As described in the [How Blocklists Work](#how-blocklists-work) section, blocklists can be handled in **two ways**:

1. Each IP is applied as an individual iptables rule, **or**
2. With IPSET enabled, the entire blocklist is managed as a single set.

<br />

For blocklists containing thousands of entries, option **2** is significantly faster and consumes far fewer system resources, including memory. However, if you plan to go with the route of enabling IPSET, you must modify the settings ++"LF_IPSET"++ and ++"LF_IPSET_MAXELEM"++ located in ++"/etc/csf/csf.conf"++.

We have an entire chapter of our guide dedicated to [How IPSET Works](../usage/ipset.md), so we will not go into great detail here. 

<br />

### Enable IPSET

If you decide to use option **two** and enable IPSET, you need to ensure IPSET is installed on your server:

=== ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

    ```bash
    sudo apt-get update
    sudo apt-get install ipset
    ```

=== ":aetherx-axb-redhat: CentOS/RHEL (yum/dnf)"

    ```bash
    # using yum
    sudo yum install ipset

    #Using dnf
    sudo dnf install ipset
    ```

<br />

Next, open ++"/etc/csf/csf.conf"++ and enable the setting ++"LF_IPSET"++

=== ":aetherx-axs-file-magnifying-glass: Find"

    ``` bash title="/etc/csf/csf.conf"
    LF_IPSET = "0"
    ```

=== ":aetherx-axs-file-pen: Change To"

    ``` bash title="/etc/csf/csf.conf"
    LF_IPSET = "1"
    ```

<br />

This will enable IPSET support on your server. However, there is one final setting to mention which is the one responsible for limiting the use of large blocklists; which is ++"LF_IPSET_MAXELEM"++. Continue to the next section [Set LF_IPSET_MAXELEM](#set-lf_ipset_maxelem).

<br />

### Set LF_IPSET_MAXELEM

The setting ++"LF_IPSET_MAXELEM"++ defines how many entries are loaded within a blocklist. This is an important part of enabling large blocklists that contain tens of thousands of entries 

If you have decided to use CSF's official blocklists [master.ipset](https://blocklist.configserver.dev/master.ipset) and [highrisk.ipset](https://blocklist.configserver.dev/highrisk.ipset); this setting is **required** to be set according to how large the lists are.

On average, our [master.ipset](https://blocklist.configserver.dev/master.ipset) blocklist contains approximately ++"350,000"++ entries. While our [highrisk.ipset](https://blocklist.configserver.dev/highrisk.ipset) list contains approximately ++"10,000"++.

To support a blocklist this large, we must modify ++"LF_IPSET_MAXELEM"++ to a high enough value to support this, and also give us room in case the list grows larger in the future. We'll use the value ++"500,000"++ for this example.

Open ++"/etc/csf/csf.conf"++ and change the following:

=== ":aetherx-axs-file-magnifying-glass: Find"

    ``` bash title="/etc/csf/csf.conf"
    LF_IPSET_MAXELEM = "65536"
    ```

=== ":aetherx-axs-file-pen: Change To"

    ``` bash title="/etc/csf/csf.conf"
    LF_IPSET_MAXELEM = "500000"
    ```

<br />

By setting ++"/etc/csf/csf.conf"++ to ++"500000"++, this gives us enough to support our biggest blocklist [master.ipset](https://blocklist.configserver.dev/master.ipset) and its 350,000 entries, but also give us a buffer of 150,000 for future growth.

<br />

Also confirm that you have the blocklists themselves set to a value such as ++0++ within ++"/etc/csf/csf.blocklists"++ if you do not wish to limit the number of entries:

```shell
CSF_MASTER   | 43200 | 0 | https://blocklist.configserver.dev/master.ipset
CSF_HIGHRISK | 43200 | 0 | https://blocklist.configserver.dev/highrisk.ipset
```

<br />

Once you change the settings mentioned in this section, give CSF a restart:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo csf -ra
      ```

<br />

You should now have your blocklists confirmed within CSF, and have also enabled IPSET in order to manage these lists which increases performance.

If you want to learn more about IPSETs specifically, head over to the chapter [Introduction to IPSETs](../usage/ipset.md).

<br />

---

<br />

## Next Steps <!-- omit from toc -->

{==

Select what documentation you would like to proceed with next ...

==}

<div class="grid cards" markdown>

-   :aetherx-axd-block-brick-fire: &nbsp; __[Introduction to IPSETs](../usage/ipset.md)__

    ---

    Blocklists and IPSETs are designed to work together. Blocklists provide a simple
    way to block unwanted traffic from reaching your server, but large blocklists
    can be inefficient and memory-intensive.

    If you plan to import blocklists containing more than a few thousand IP addresses,
    it is strongly recommended to enable CSF’s IPSET integration.

    IPSETs allow you to block significantly larger numbers of IP addresses in a far
    more efficient way, without the risk of excessive memory usage or performance
    degradation.

-   :aetherx-axd-earth-europe: &nbsp; __[Geographical IP Block Integration](../usage/geoip.md)__

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

---

<br />
