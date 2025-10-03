---
title: "Usage › Pre.d/Post.d Scripts"
tags:
  - usage
  - configure
---

# Usage › Pre and Post Scripts

CSF provides special folders where you can place your own bash scripts to be executed at specific points during the firewall startup process. These scripts make it easy to maintain custom, persistent firewall rules that are automatically applied every time the CSF service is restarted.

<br />

---

<br />

## Location and Structure

This section outlines exactly how the pre and post scriptsare initialized and loaded.

<br />

### Loader Scripts

When CSF is installed for the first time, two loader files are added to your system. These files are described below:

:aetherx-axd-file: <!-- md:option /usr/local/csf/bin/csfpre.sh -->

:   - This file is responsible for iterating over your `/usr/local/include/csf/pre.d/` folder and loading any scripts located in that directory.
    - Runs **before** any iptables rules are added by CSF, allowing you to prepare the environment or add rules that must exist prior to CSF’s standard rules.

:aetherx-axd-file: <!-- md:option /usr/local/csf/bin/csfpost.sh -->

:   - This file is responsible for iterating over your `/usr/local/include/csf/post.d/` folder and loading any scripts located in that directory.
    - Runs **after** all iptables rules are applied, letting you append custom rules that should persist alongside CSF's configuration. 

<br />

### Loader Folders

When the [loader scripts](#loader-scripts) above are run, they will scan their respective folders. These folders are where you should place your custom scripts, allowing you to create persistent firewall rules that are automatically applied each time CSF starts or restarts.

:aetherx-axd-folder: <!-- md:option /usr/local/include/csf/pre.d/ -->

:   - Stores scripts that are executed **before** CSF applies its default iptables rules.
    - Any scripts placed in this folder will run automatically every time CSF is started or restarted, allowing you to configure custom rules or settings prior to CSF’s standard firewall rules.
    - Files in this folder are initialized and loaded by the script `/usr/local/csf/bin/csfpre.sh`

:aetherx-axd-folder: <!-- md:option /usr/local/include/csf/post.d/ -->

:   - Stores scripts that are executed **after** CSF applies its default iptables rules.
    - Any scripts placed in this folder will run automatically every time CSF is started or restarted, allowing you to configure custom rules or settings after to CSF’s standard firewall rules.
    - Files in this folder are initialized and loaded by script `/usr/local/csf/bin/csfpost.sh`

<br />

We have provided an example structure of how your scripts should be stored. When creating your script files, they can be any name you want.

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

<br />

---

<br />

## Writing Custom Rules

As outlined earlier, the `pre.d` and `post.d` folders allow you to drop your own custom bash scripts inside the folders which will be responsible for any iptable rules you need to add to CSF every time the service is started or restarted. 

We will provide an example script below just to outline what can be done. In our example, we will create `/usr/local/include/csf/post.d/ports-blacklist.sh`. The script will do the following:

- Defines a list of blacklisted ports using a JSON array in `BLACKLIST_PORTS`. Each entry includes a port number and a comment describing it.
- Iterates over each port in the blacklist using `jq` to parse the JSON.
- For each port:
    - Extracts the port number `ENTRY_PORT` and its description/comment `ENTRY_COMMENT`.
    - Checks if a **UDP** rule already exists in iptables for that port:
        - Sets `DELETE_INPUT_UDP=1` if the rule does not exist.
    - Checks if a **TCP** rule already exists in iptables for that port:
        - Sets `DELETE_INPUT_TCP=1` if the rule does not exist.
    - Adds the firewall rules if they are not already present:
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

The script itself is very easy to use. We make sure to edit the list `BLACKLIST_PORTS` and populate it with ports we absolutely do not want giving access to:

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

After you edit the list of ports, simply restart CSF's services and the script will be automatically re-loaded:

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

We can now view iptables to confirm our rules were added. Iptables will resolve whatever service is associated with a port, which means port `111` will show as `sunrpc`. If you wish to show just the port number, append `-n` to your iptables command:

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

From this point forward, you can create any number of pre and post scripts for your own firewall setup. Simply drop the scripts in the folders specified in the section [Location and Structure](#location-and-structure).

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
