---
title: "Usage › Pre/Post Loader Scripts"
tags:
  - usage
  - configure
  - pre-loader
  - post-loader
  - scripts
  - bash
---

# Usage › Pre and Post Loader Scripts

CSF includes dedicated directories where you can place custom Bash scripts to run at specific stages of the firewall’s startup process. This allows you to easily maintain persistent, custom firewall rules that are automatically applied each time the CSF service starts or restarts.

<br />

## :aetherx-axj-bell:{ .icon-tldr } Summary

The following is a summary of what this page explains:

- When you install CSF, two files will be placed on your server. These are known as the `pre` and `post` loader scripts:
    1. **Preloader**: `/usr/local/csf/bin/csfpre.sh`
    2. **Postloader**: `/usr/local/csf/bin/csfpost.sh`
- These loader scripts scan two different folders on your server to see if you have added any custom bash scripts you want ran when CSF starts. You can place your custom bash scripts in two different folders:
    1. `/usr/local/include/csf/pre.d/`
          - Place your bash scripts in this folder if you want your scripts to run **BEFORE** CSF imports the default rules into your server.
    2. `/usr/local/include/csf/post.d/`
          - Place your bash scripts in this folder if you want your scripts to run **AFTER** CSF imports the default rules into your server.
- Once the scripts are added, restart CSF with `sudo csf -ra`

<br />

---

<br />

## Location and Structure

This section outlines exactly how the pre and post scripts are initialized and loaded.

<br />

### Loader Scripts

- When CSF is installed for the first time, two files :aetherx-axd-file: `/usr/local/csf/bin/csfpre.sh` and :aetherx-axd-file: `/usr/local/csf/bin/csfpost.sh` are automatically created on your system _(they will not overwrite existing copies)_. These files are  loader scripts, giving you the ability to add your own custom bash scripts.
    - You must create the pre-loader folder :aetherx-axd-folder: `/usr/local/include/csf/pre.d/` and post-loader folder :aetherx-axd-folder: `/usr/local/include/csf/post.d/`
- If you already have existing pre/post loader files in place, CSF will respect this and **NOT** overwrite your existing files. Your existing setup will not be touched.

<br />

:aetherx-axd-file: <!-- md:option /usr/local/csf/bin/csfpre.sh -->

:   - The file `csfpre.sh` installed with CSF loads every custom bash script you drop in the :aetherx-axd-folder: `/usr/local/include/csf/pre.d/` folder.
    - If making your own `csfpre.sh` loader, there are **two allowed locations** to place this script — either one is valid:
        - [x] `/usr/local/csf/bin/csfpre.sh` <small>:aetherx-axd-note-sticky: _(default)_</small>
        - [x] `/etc/csf/csfpre.sh` <small>:aetherx-axd-note-sticky: _(alternative)_</small>
    - Runs **before** all default iptables rules are applied; allows you to add custom rules which persist alongside CSF's defaults.

:aetherx-axd-file: <!-- md:option /usr/local/csf/bin/csfpost.sh -->

:   - The file `csfpost.sh` installed with CSF loads every custom bash script you drop in the :aetherx-axd-folder: `/usr/local/include/csf/post.d/` folder.
    - If making your own `csfpost.sh` loader, there are **two allowed locations** to place this script — either one is valid:
        - [x] `/usr/local/csf/bin/csfpost.sh` <small>:aetherx-axd-note-sticky: _(default)_</small>
        - [x] `/etc/csf/csfpost.sh` <small>:aetherx-axd-note-sticky: _(alternative)_</small>
    - Runs **after** all default iptables rules are applied, allowing you to add custom rules which persist alongside CSF's defaults.

??? note "**pre.sh & post.sh:** Multiple Locations Allowed"

    By default, installing CSF will create the loader files `csfpre.sh` and `csfpost.sh`, and place them in the folder `/usr/local/csf/bin/`.  
    However, this location is **not strict**; you can place these loader files in one of two allowed locations:

      - :aetherx-axd-file: **csfpre.sh**
        - `/usr/local/csf/bin/csfpre.sh`
        - `/etc/csf/csfpre.sh`
      - :aetherx-axd-file: **csfpost.sh**
        - `/usr/local/csf/bin/csfpost.sh`
        - `/etc/csf/csfpost.sh`

<br />

### Loader Folders

When the [loader scripts](#loader-scripts) `/usr/local/csf/bin/csfpre.sh` and `/usr/local/csf/bin/csfpost.sh` run, they check specific folders to see if you have placed any custom bash scripts inside. By placing custom bash scripts in these folders, you can write bash scripts which assist with setting up custom firewall rules which are automatically applied every time CSF starts or restarts, ensuring your custom rules persist.

<br />

:aetherx-axd-folder: <!-- md:option /usr/local/include/csf/pre.d/ -->

:   - Your custom bash scripts will run **before** CSF applies any default iptables rules.
    - Scripts placed here run automatically every time CSF starts or restarts.

:aetherx-axd-folder: <!-- md:option /usr/local/include/csf/post.d/ -->

:   - Your custom bash scripts will run **after** CSF applies any default iptables rules.
    - Scripts placed here run automatically every time CSF starts or restarts.

??? note "Defining A New Loader Folder"

    The CSF loader files `/usr/local/csf/bin/csfpre.sh` and `/usr/local/csf/bin/csfpost.sh` will look inside a specific folder for any custom bash scripts you have added.

    If you wish to change the folder name / path used for storing your custom bash scripts, open these loader files and change the assigned variable toward the top of each file:

    === ":aetherx-axd-command: /usr/local/csf/bin/csfpre.sh"

          ```shell
          path_csfpred="/usr/local/include/csf/pre.d"
          ```

    === ":aetherx-axd-command: /usr/local/csf/bin/csfpost.sh"

          ```shell
          path_csfpostd="/usr/local/include/csf/post.d"
          ```

<br />

### Loader Example

We have provided both example structures of how your scripts can be set up. Script names can be any name you want, no restrictions.

=== ":aetherx-axd-1: Option 1 (default)"

      This example stores your loader files in:

      - `/usr/local/csf/bin/csfpre.sh`
      - `/usr/local/csf/bin/csfpost.sh`

      ```
      📁 usr
        📁 local
            📁 csf
              📁 bin
                  📄 csfpre.sh
                  📄 csfpost.sh
            📁 include
              📁 csf
                  📁 pre.d
                    📄 my_rules_before.sh
                  📁 post.d
                    📄 my_docker_rules.sh
                    📄 openvpn_rules.sh
      ```

=== ":aetherx-axd-2: Option 2 (Alternative)"

      This example stores your loader files in:

      - `/etc/csf/csfpre.sh`
      - `/etc/csf/csfpost.sh`

      ```
      📁 etc
        📁 csf
            📄 csfpre.sh
            📄 csfpost.sh
      📁 usr
        📁 local
            📁 include
              📁 csf
                  📁 pre.d
                    📄 my_rules_before.sh
                  📁 post.d
                    📄 my_docker_rules.sh
                    📄 openvpn_rules.sh
      ```

<br />

---

<br />

## Writing Custom Rules

As outlined earlier, the `pre.d` and `post.d` folders allow you to drop your own custom bash scripts inside the folders which will be responsible for any iptable rules you need to add to CSF every time CSF is started or restarted. 

We will provide an example script below just to outline what can be done. In our example, we will create `/usr/local/include/csf/post.d/ports-blacklist.sh`. The script will do the following:

- Defines a list of blacklisted ports using a JSON array in `BLACKLIST_PORTS`. Each port we want to block will include the port number and a comment describing what that port is used for.
- Iterates over each port in the blacklist using `jq` to parse the JSON.
- For each port:
    - Extract the port number `ENTRY_PORT` and its description/comment `ENTRY_COMMENT`.
    - Check if a **UDP** rule already exists in iptables for that port:
        - Sets `DELETE_INPUT_UDP=1` if the rule does not exist.
    - Check if a **TCP** rule already exists in iptables for that port:
        - Sets `DELETE_INPUT_TCP=1` if the rule does not exist.
    - Add a firewall rule if it isn't already present:
        - Inserts a rule to drop **UDP** traffic to the port.
        - Inserts a rule to drop **TCP** traffic to the port.

<br />

Add the code below to your new file `/usr/local/include/csf/post.d/ports-blacklist.sh` and save.

```bash
#!/bin/sh

# #
#   Settings > Ports
# #

BLACKLIST_PORTS=$(cat <<EOF
[
    {"port":"111", "comment":"used by sunrpc/rpcbind, has vulnerabilities"}
]
EOF
)

# #
#   Define > Iptables
# #

path_iptables4=$(which iptables)
path_iptables6=$(which ip6tables)

# #
#   Loop blacklists, create if missing
# #

printf "\n"
printf "  + RESTRICT      Blacklisting Ports\n"

echo "$BLACKLIST_PORTS" | jq -c '.[]' | while IFS= read -r row; do

    ENTRY_PORT=$(echo "$row" | jq -r '.port')
    ENTRY_COMMENT=$(echo "$row" | jq -r '.comment')

    # #
    #   See if ports already exist in iptables
    # #

    DELETE_INPUT_UDP=0
    DELETE_INPUT_TCP=0

    $path_iptables4 -C INPUT -p udp --dport "$ENTRY_PORT" -j DROP >/dev/null 2>&1 || DELETE_INPUT_UDP=1
    $path_iptables4 -C INPUT -p tcp --dport "$ENTRY_PORT" -j DROP >/dev/null 2>&1 || DELETE_INPUT_TCP=1

    # #
    #   Drop Port > UDP
    # #

    if [ "$DELETE_INPUT_UDP" = "0" ]; then
        printf "                   ✓ Port already blacklisted\n"
    else
        sudo $path_iptables4 -I INPUT -p udp --dport "$ENTRY_PORT" -j DROP
        printf '%-17s %-50s %-55s\n' " " "├─ Blacklisting $ENTRY_PORT (UDP)" "$ENTRY_COMMENT"
    fi

    # #
    #   Drop Port > TCP
    # #

    if [ "$DELETE_INPUT_TCP" = "0" ]; then
        printf "                   ✓ Port already blacklisted\n"
    else
        sudo $path_iptables4 -I INPUT -p tcp --dport "$ENTRY_PORT" -j DROP
        printf '%-17s %-50s %-55s\n' " " "├─ Blacklisting $ENTRY_PORT (TCP)" "$ENTRY_COMMENT"
    fi

done
```

<br />

The script itself is very easy to use. We make sure to edit the list `BLACKLIST_PORTS` and populate it with ports we do not want the outside world being able to access.

``` bash
BLACKLIST_PORTS=$(cat <<EOF
[
    {"port":"111", "comment":"used by sunrpc/rpcbind, has vulnerabilities"}
    {"port":"21", "comment":"insecure ftp"}
]
EOF
)
```

<br />

After you edit the list of ports above, restart CSF and the script will be automatically re-loaded:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo csf -ra
      ```

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      LOGDROPOUT  all opt -- in * out !lo  0.0.0.0/0  -> 0.0.0.0/0  
      LOGDROPIN  all opt -- in !lo out *  0.0.0.0/0  -> 0.0.0.0/0  
      csf: FASTSTART loading DNS (IPv4)
      LOCALOUTPUT  all opt -- in * out !lo  0.0.0.0/0  -> 0.0.0.0/0  
      LOCALINPUT  all opt -- in !lo out *  0.0.0.0/0  -> 0.0.0.0/0  
      Running /usr/local/csf/bin/csfpost.sh
      Loading post-script: /usr/local/include/csf/post.d/ports-blacklist.sh

      + RESTRICT      Blacklisting Ports
                        ├─ Blacklisting 111 (UDP) used by sunrpc/rpcbind, has vulnerabilities
                        ├─ Blacklisting 111 (TCP) used by sunrpc/rpcbind, has vulnerabilities
                        ├─ Blacklisting 21 (UDP) insecure ftp
                        ├─ Blacklisting 21 (TCP) insecure ftp
      ```

<br />

We can now use the `iptables` command to confirm our rules were added. Iptables will resolve whatever service is associated with a port, which means port `111` will show as `sunrpc`. If you wish to show just the port number, append `-n` to your iptables command:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo iptables -L -n
      ```

=== ":aetherx-axs-square-terminal: Output"

      If you use the command `sudo iptables -L`

      ```shell
      Chain INPUT (policy DROP)
      target     prot opt source               destination         
      DROP       tcp  --  anywhere             anywhere             tcp dpt:sunrpc
      DROP       udp  --  anywhere             anywhere             udp dpt:sunrpc

      Chain LOGDROPIN (2 references)
      target     prot opt source               destination         
      DROP       tcp  --  anywhere             anywhere             tcp dpt:sunrpc
      DROP       udp  --  anywhere             anywhere             udp dpt:sunrpc
      ```

      <br />

      If you use the command `sudo iptables -L -n`

      ```shell
      Chain INPUT (policy DROP)
      target     prot opt source               destination         
      DROP       6    --  0.0.0.0/0            0.0.0.0/0            tcp dpt:111
      DROP       17   --  0.0.0.0/0            0.0.0.0/0            udp dpt:111

      Chain LOGDROPIN (2 references)
      target     prot opt source               destination         
      DROP       6    --  0.0.0.0/0            0.0.0.0/0            tcp dpt:111
      DROP       17   --  0.0.0.0/0            0.0.0.0/0            udp dpt:111
      ```

<br />

---

<br />

## Conclusion

From this point forward, you can create any number of pre and post bash scripts for your firewall. Simply drop any bash scripts you wish to load with CSF inside the folders `/usr/local/include/csf/pre.d/` and `/usr/local/include/csf/post.d/`. 

For a quick reference to the file and folder names, you can view the section [Location and Structure](#location-and-structure).

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
