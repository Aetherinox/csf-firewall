---
title: Usage › IPSETs
tags:
    - usage
    - configure
status: new
---

# Introduction to IPSETs

This section explains the purpose of IPSETs, and how they benefit you as a server administrator compared to using file-based allow, deny, or blocklists.

<br />

## About IPSETs

When managing a firewall with CSF, you’ll often need to block or allow large numbers of IP addresses or networks. Traditionally, this has been done through file-based lists. When CSF is started, those lists are read into memory, and each IP or CIDR is added as a separate rule in the iptables firewall. As an example:

```shell title="/etc//csf/csf.deny"
# #
#   Example /etc/csf/csf.deny
# #

# Block a single IP
192.0.2.15

# Block a range of IPs
203.0.113.0/24

# Block with a comment
198.51.100.42 # Suspicious SSH brute force

# Block an entire subnet
10.0.0.0/8
```

<br />

If you were to configure the IP addresses listed in the example above within the file `/etc//csf/csf.deny` and then started up CSF, then CSF would automatically convert that list into iptable rules, and would run the following:

``` bash
# Block a single IP
iptables -A INPUT -s 192.0.2.15 -j DROP

# Block a range of IPs
iptables -A INPUT -s 203.0.113.0/24 -j DROP

# Block with a comment (the comment is ignored by iptables, shown here for clarity)
iptables -A INPUT -s 198.51.100.42 -j DROP  # Suspicious SSH brute force

# Block an entire subnet
iptables -A INPUT -s 10.0.0.0/8 -j DROP
```

<br />

While this method works, it becomes inefficient when the list grows large. Every incoming or outgoing connection must be checked against each iptables rule, and once the list reaches thousands of entries, it can noticeably slow down your server’s networking performance.

This is where IPSETs come in. An ipset is a special data structure in the Linux kernel that allows you to group many IP addresses, networks, or ranges together, and then reference that group with a single firewall rule. Instead of adding thousands of rules into iptables, CSF can load all of those addresses into an ipset and apply them collectively. This approach is dramatically more efficient, reduces CPU usage, and speeds up packet filtering even when working with massive blocklists.

The key difference is in how the firewall stores and processes the data. A traditional blocklist tells the firewall: _“check this IP against every single rule until you find a match.”_ An ipset, on the other hand, works more like a fast lookup table: _“check if this IP is in the set; if so, apply the rule.”_ This makes IPSETs especially useful for country-level bans, abuse IP feeds, or any large-scale list that would otherwise overwhelm a rule-based blocklist.

For many users, blocklists are still perfectly fine if you only manage a handful of entries or want to manually add or remove individual IPs. But if you plan to use automated feeds, block entire regions, or maintain thousands of entries, IPSETs are the better option. They give you the same control as blocklists, but with far less overhead and much better scalability.

It is also recommended that you enable IPSET if you plan on using any of the settings within the CSF config file `/etc/csf/csf.conf` listed below:

- `CC_DENY`
- `CC_ALLOW`
- `CC_ALLOW_FILTER` 

<br />

??? warning "Notice to Virtuozzo & OpenVZ Users"

    It's highly unlikely that ipset will function on Virtuozzo/OpenVZ containers even if it has been installed

<br />
<br />

## Install

Before you can begin using IPSETs with CSF, you’ll need to ensure the ipset package is installed on your server. Many modern Linux distributions already include IPSET support in the kernel by default, and in some cases the user-space tools (ipset command) are installed out of the box. If not, you can easily install them using your system’s package manager. Or you can build the source from http://ipset.netfilter.org/.

On Debian and Ubuntu systems, you can install IPSET with the following commands:

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

Once installed, you can verify that IPSET is available by running:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo ipset -v
      ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      ipset v7.19, protocol version: 7
      ```

<br />

If installation was successful, this command will display the current running version number. This confirms that your system is ready to start creating and managing IPSETs for CSF.

<br />

---

<br />

## Enable

Once the ipset package is installed, the next step is to enable IPSET support within CSF. By default, CSF ships with IPSETs disabled, so you’ll need to update the configuration file to turn it on.

Open the CSF configuration file in your preferred text editor:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo nano /etc/csf/csf.conf
      ```

<br />

Once you get the config file opened, locate `LF_IPSET` and change the value from 0 to `1`:

=== ":aetherx-axs-file-magnifying-glass: Find"

    ``` bash title="/etc/csf/csf.conf"
    LF_IPSET = "0"
    ```

=== ":aetherx-axs-file-pen: Change To"

    ``` bash title="/etc/csf/csf.conf"
    LF_IPSET = "1"
    ```

<br />

After saving your changes, give CSF a restart:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo csf -ra
      ```

<br />

Enabling IPSETs allows CSF to offload large blocklists into efficient kernel-managed sets, significantly improving performance compared to standard iptables rules. This step is essential before you can begin adding and managing IPSET-based blocklists.

<br />

---

<br />

## Manage Lists

Once you have IPSET installed and enabled within CSF, it's time to populate your IPSET lists. These lists determine which connections are allowed to access your server and which ones will be denied. Populating your IPSET lists correctly helps ensure your firewall operates efficiently while providing strong protection.

There are two primary ways to add IPs to your IPSET lists:

1. [Using Blocklists](#using-blocklists)
       1. Pre-compiled lists of known malicious IPs.
       2. See the [Blocklists section](../usage/blocklists.md) for more information about blocklists.

2. [Using Manual Additions](#using-manual-additions)
       1. Adding specific IPs or subnets you want to allow or deny.

<br />
<br />

### Using Blocklists

Blocklists are precompiled lists of IP addresses or networks known to be malicious or unwanted. They allow you to automatically deny or restrict traffic from these IPs without having to add each one manually.

For instructions on using official CSF blocklists or custom external blocklists to populate your IPSETs automatically, please refer to the [Blocklists section](../usage/blocklists.md). These lists can contain thousands or even millions of IP addresses and are automatically loaded into your IPSETs to save memory and improve firewall performance.

<div class="grid cards" markdown>

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
<br />

### Using Manual Additions

Unlike [Blocklists](#using-blocklists) which are a pre-compiled list of IPs you want to allow / deny, the other option is to manually add your own IP addresses to a list. To manually compile your own list, you can do so using the `ipset` command. This is useful for whitelisting trusted IPs or blocking specific addresses.

To do this, you need to:

- [Create a list](#create-list), this is where all of the IP addresses will be stored
- [Add an IP](#add-ip-to-list) to the list which is who will be allowed or denied access to your server

<br />
<br />
<br />

#### Create List

Create a custom IPSET (if it doesn’t already exist):

=== ":aetherx-axs-check:{ .icon-clr-green } Whitelist"

      ```shell
      sudo ipset create my_whitelist hash:ip
      ```

=== ":aetherx-axs-ban:{ .icon-clr-red } Blacklist"

      ```shell
      sudo ipset create my_blacklist hash:ip
      ```

<br />

You can also expand on this command and specify that you want to store comments, or set a maximum allowed number of IPs in your list.

=== ":aetherx-axs-check:{ .icon-clr-green } Whitelist"

      ```shell
      sudo ipset create my_whitelist hash:ip comment hashsize 6553
      ```

=== ":aetherx-axs-ban:{ .icon-clr-red } Blacklist"

      ```shell
      sudo ipset create my_blacklist hash:ip comment hashsize 6553
      ```

<br />

The following are some of the options you can use when creating your list:

<!-- md:option my_whitelist -->

:   - Name list / set you are creating.
    - You will reference it later in commands like `ipset add`, `ipset list`, or in `iptables` rules.

<!-- md:option hash:ip -->

:   - Specifies the type of IP set.
    - Other types: `hash:net` for networks, or `list:set` for nested sets.

<!-- md:option comment -->

:   - Allows each entry in the set to store a comment.
    - Without this option, attempting to add a comment will fail.

<!-- md:option hashsize 6553 -->

:   - Defines the initial size of the hash table.
    - Determines how many “buckets” the hash table will initially have for storing IPs.
    - Setting this properly improves performance for large sets:
        - too small = collisions
        - too large = slightly more memory used
    - You can scale it based on the expected number of entries in the set.

<br />
<br />
<br />

#### Add IP to List

These commands let you add **single IP addresses** to your whitelist or blacklist:

??? tip "Overlapping IP addresses"

    Even single IPs can overlap with ranges. Always ensure that whitelists are prioritized in your firewall rules so they aren’t accidentally blocked by broader blacklist ranges.

<br />

=== ":aetherx-axs-check:{ .icon-clr-green } Whitelist"

      Adds the IP `192.0.2.15` to your whitelist, granting access to this single address.

      ```shell
      sudo ipset add my_whitelist 192.0.2.15
      ```

      If you created your IPSET list with the `comment` parameter, you can also add a comment to your entry.

      ```shell
      sudo ipset add my_whitelist 192.0.2.15 comment "Localhost device"
      ```

=== ":aetherx-axs-ban:{ .icon-clr-red } Blacklist"

      Adds the IP `203.0.113.42` to your blacklist, blocking access from this single address.

      ```shell
      sudo ipset add my_blacklist 203.0.113.42
      ```

      If you created your IPSET list with the `comment` parameter, you can also add a comment to your entry.

      ```shell
      sudo ipset add my_blacklist 203.0.113.42 comment "Suspicious SSH activity"
      ```

<br />
<br />
<br />

#### Add Subnet Range to List

These commands let you add a **range of IP addresses** to either your whitelist or blacklist. This is especially useful when the source server owns multiple IPs within a network block.

??? tip "Overlapping IP addresses"

    When working with ranges, overlapping IPs may exist between your whitelist and blacklist. The order of rules in your firewall matters—whitelisted IPs should be checked before blacklist rules to ensure access is correctly allowed.

<br />

=== ":aetherx-axs-check:{ .icon-clr-green } Whitelist"

      Adds the entire `198.51.100.0/24` subnet to your whitelist, allowing all IPs in this range to access your server.

      ```shell
      sudo ipset add my_whitelist 198.51.100.0/24
      ```

=== ":aetherx-axs-ban:{ .icon-clr-red } Blacklist"

      Adds the `203.0.113.0/24` subnet to your blacklist, blocking all IPs in this range from connecting.

      ```shell
      sudo ipset add my_blacklist 203.0.113.0/24
      ```

<br />
<br />
<br />

#### Check IP in List

These commands allow you to confirm whether or not an IP already exists in one of your lists. It will return one of two responses:

1. `192.0.2.15` is in set `my_whitelist`
2. `192.0.2.11` is NOT in set `my_whitelist`

=== ":aetherx-axs-check:{ .icon-clr-green } Whitelist"


      ```shell
      sudo ipset test my_whitelist 192.0.2.15
      ```

=== ":aetherx-axs-ban:{ .icon-clr-red } Blacklist"

      ```shell
      sudo ipset test my_blacklist 203.0.113.42
      ```

<br />

You can also use a more complex command to search for an IP in any list. Change `1.2.3.4` to the IP you are looking for.

=== ":aetherx-axd-command: Command"

      The below command will return `IP in set: my_listname` if it exists

      ```shell
      for s in $(sudo ipset list -n); do sudo ipset test "$s" 203.0.113.42 2>/dev/null && echo "IP in set: $s"; done
      ```

<br />
<br />
<br />

#### Show List

Once you have your lists created, you can print information about the lists or the number of IP addresses within the list by list name.  To list all of your IPSET lists, run the command:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo ipset list -n
      ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      my_whitelist
      my_blacklist
      ```

<br />

You can also show all of the IPs associated with a specific list, or return the total count.

=== ":aetherx-axs-check:{ .icon-clr-green } Whitelist"

      ```shell
      # #
      #   List all IPs in a specific set
      # #

      $ sudo ipset list my_whitelist

      Name: my_whitelist
      Type: hash:ip
      Revision: 6
      Header: family inet hashsize 8192 maxelem 65536 comment bucketsize 12 initval 0x8d108d64
      Size in memory: 448
      References: 0
      Number of entries: 1
      Members:
      192.0.2.15 comment "Localhost device"

      # #
      #   Count entries
      # #

      $ sudo ipset list my_whitelist -o save | awk '/add/ {print $3}' | wc -l

      1
      ```

=== ":aetherx-axs-ban:{ .icon-clr-red } Blacklist"

      ```shell
      # #
      #   List all IPs in a specific set
      # #
  
      $ sudo ipset list my_blacklist

      Name: my_blacklist
      Type: hash:ip
      Revision: 6
      Header: family inet hashsize 8192 maxelem 65536 comment bucketsize 12 initval 0x65606406
      Size in memory: 448
      References: 0
      Number of entries: 1
      Members:
      203.0.113.42 comment "Suspicious SSH activity"

      # #
      #   Count entries
      # #

      $ sudo ipset list my_blacklist -o save | awk '/add/ {print $3}' | wc -l

      1
      ```

<br />
<br />
<br />

#### Enable or Disable List

Once you have your IPSET list created and have populated it with the addresses you want, it's time to enforce the list and add it to our iptable rules.

=== ":aetherx-axs-check:{ .icon-clr-green } Whitelist"

      The following will enforce your whitelist, ensuring that all IPs within `my_whitelist` will be :aetherx-axs-check:{ .icon-clr-green } allowed through the `INPUT` and `FORWARD` chains.

      ```shell
      sudo iptables -I INPUT -m set --match-set my_whitelist src -j ACCEPT
      sudo iptables -I FORWARD -m set --match-set my_whitelist src -j ACCEPT
      ```

      <br />

      If you want to **remove** the rules and stop enforcing your whitelist, run the same command with the `-D` flag:

      ```shell
      sudo iptables -D INPUT -m set --match-set my_whitelist src -j ACCEPT
      sudo iptables -D FORWARD -m set --match-set my_whitelist src -j ACCEPT
      ```

=== ":aetherx-axs-ban:{ .icon-clr-red } Blacklist"

      The following will enforce your blacklist, ensuring that all IPs within `my_whitelist` will be :aetherx-axs-ban:{ .icon-clr-red } denied through the `INPUT` and `FORWARD` chains.

      ```shell
      sudo iptables -I INPUT -m set --match-set my_blacklist src -j DROP
      sudo iptables -I FORWARD -m set --match-set my_blacklist src -j DROP
      ```
  
      <br />

      If you want to **remove** the rules and stop enforcing your whitelist, run the same command with the `-D` flag:

      ```shell
      sudo iptables -D INPUT -m set --match-set my_blacklist src -j DROP
      sudo iptables -D FORWARD -m set --match-set my_blacklist src -j DROP
      ```

<br />

From this point forward, your IPSET lists will be enforced.

- If a user with the IP `192.0.2.15` tries to access your server; :aetherx-axs-check:{ .icon-clr-green } allow them
- If a user with the IP `203.0.113.42` tries to access your server; :aetherx-axs-ban:{ .icon-clr-red } deny them

<br />
<br />
<br />

#### Delete IP from List

If you decide to remove an IP from your whitelist or blacklist, you can use the following commands:

=== ":aetherx-axs-check:{ .icon-clr-green } Whitelist"

      ```shell
      sudo ipset del my_whitelist 198.51.100.0/24
      ```

=== ":aetherx-axs-ban:{ .icon-clr-red } Blacklist"

      ```shell
      sudo ipset del my_blacklist 203.0.113.0/24
      ```

<br />
<br />
<br />

#### Delete List

If you have decided that you no longer need an IPSET list, you need to remove the iptables rule, and then delete the IPSET list itself.

=== ":aetherx-axs-check:{ .icon-clr-green } Whitelist"

      The following will remove your whitelist iptables rule

      ```shell
      sudo iptables -D INPUT -m set --match-set my_whitelist src -j ACCEPT
      sudo iptables -D FORWARD -m set --match-set my_whitelist src -j ACCEPT
      ```

=== ":aetherx-axs-ban:{ .icon-clr-red } Blacklist"

      The following will remove your blacklist iptables rule

      ```shell
      sudo iptables -D INPUT -m set --match-set my_blacklist src -j DROP
      sudo iptables -D FORWARD -m set --match-set my_blacklist src -j DROP
      ```

<br />

After deleting the iptables rule, we can delete the IPSET list:

=== ":aetherx-axs-check:{ .icon-clr-green } Whitelist"

      ```shell
      sudo ipset destroy my_whitelist
      ```

=== ":aetherx-axs-ban:{ .icon-clr-red } Blacklist"

      ```shell
      sudo ipset destroy my_blacklist
      ```

<br />
<br />
<br />

#### Save List

You can save your entire IPSET list to a file which allows you to back it up and restore it later.

=== ":aetherx-axs-check:{ .icon-clr-green } Whitelist"

      ```shell
      sudo ipset save my_whitelist > whitelist.ipset
      ```

=== ":aetherx-axs-ban:{ .icon-clr-red } Blacklist"

      ```shell
      sudo ipset save my_blacklist > blacklist.ipset
      ```

<br />
<br />
<br />

#### Restore List

If you would like to restore a backed up IPSET list, you can do so with the following commands:

=== ":aetherx-axs-check:{ .icon-clr-green } Whitelist"

      ```shell
      sudo ipset restore < whitelist.ipset
      ```

=== ":aetherx-axs-ban:{ .icon-clr-red } Blacklist"

      ```shell
      sudo ipset restore < blacklist.ipset
      ```

<br />

??? warning "Overwriting Existing Rules"

    If you attempt to import white or blacklisted IPs which are already in a list; the import will fail. The list must first be destroyed, or the IP must be deleted from the list before the import of that rule will be successful.

    If you have an existing list that needs to be destroyed first and then import the list again; run the commands:

    === ":aetherx-axd-command: Command"

          ```shell
          # Destroy original blacklist
          sudo ipset destroy my_blacklist

          # Restore blacklist from file
          sudo ipset restore < blacklist.ipset
          ```

<br />

You can also restore, but ignore any errors that occur and continue importing the rest of the list. This means that duplicate IPs that already exist will be skipped, but any new IPs in the restore file that you may not already have, will be restored and added to the IPSET.

=== ":aetherx-axd-command: Command"

      ```shell
      sudo ipset restore -! < blacklist.ipset
      ```

<br />
<br />
<br />

#### Flush List

Flushing an IPSET list differs from [deleting](#delete-list). When you delete a list, you destroy the entire list and all IPs in the list. Flushing a list deletes all IPs in the list, but keeps the list itself intact so that you can add more IPs later. To flush a list:

=== ":aetherx-axs-check:{ .icon-clr-green } Whitelist"

      ```shell
      sudo ipset flush my_whitelist
      ```

=== ":aetherx-axs-ban:{ .icon-clr-red } Blacklist"

      ```shell
      sudo ipset flush my_blacklist
      ```

<br />
<br />
<br />

#### Rename List

You can change the name of a list with the following commands:

=== ":aetherx-axs-check:{ .icon-clr-green } Whitelist"

      ```shell
      sudo ipset rename my_whitelist my_new_whitelist
      ```

=== ":aetherx-axs-ban:{ .icon-clr-red } Blacklist"

      ```shell
      sudo ipset rename my_blacklist my_new_blacklist
      ```

<br />

---

<br />

## Troubleshooting

The following are a list of common issues or errors, and potential solutions for correcting these issues.

<br />

### open3: exec of /sbin/ipset flush failed: No such file or directory at /usr/sbin/csf

This error means that you have enabled IPSET within CSF, but do not have the package itself installed. Open terminal and run the command:

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
<br />

### Set cannot be destroyed: it is in use by a kernel component

This error appears when you try to delete an IPSET list while it’s still in use by iptables. Before removing the set itself, you must first delete any iptables rules that reference it. Run the following commands to detach the set from iptables:

``` shell
sudo iptables -D INPUT -m set --match-set my_list src -j DROP
sudo iptables -D FORWARD -m set --match-set my_list src -j DROP
```

<br />

Then try to delete the IPSET list again:

``` shell
sudo ipset destroy my_list
```

<br />

---

<br />

## Next Steps <!-- omit from toc -->

{==

Select what documentation you would like to proceed with next ...

==}

<div class="grid cards" markdown>

-   :aetherx-axs-ban: &nbsp; __[Setting Up Blocklists](../usage/blocklists.md)__

    ---

    Blocklists in CSF allow you to automatically block connections from known
    malicious IP addresses, helping to protect your server from abusive traffic.  

    This chapter explains how to configure and use blocklists, including CSF’s
    official blocklist and third-party sources.  

    You’ll also learn how to enable blocklists with or without IPSET, ensuring
    they work efficiently no matter the size of the list.

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
<br />
