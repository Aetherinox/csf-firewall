---
title: "Cheatsheet › Commands"
tags:
  - cheatsheet
  - commands
---

# Cheatsheet › Commands <!-- omit from toc -->

This section outlines all of the commands that can be run in your server’s terminal for **ConfigServer Security & Firewall (CSF)** which will allow you to:

- Manage your firewall  
- Add whitelisted IPs  
- Start or stop services  
- List your current rules  

<br />

## Manage Service

The following commands allow you to manage CSF and change its state:

<br />

### Enable
<!-- md:command `-e,  --enable` -->

Enable csf and lfd if previously disabled

```shell
sudo csf -e
```

<br />

### Disable
<!-- md:command `-x,  --disable` -->

Disable csf and lfd completely

```shell
sudo csf -x
```

<br />

### Start
<!-- md:command `-s,  --start` -->

Starts the firewall and applies any rules that have been configured at startup.

```shell
sudo csf -s
```

<br />

### Stop
<!-- md:command `-f,  --stop` -->

Flush/Stop firewall rules (Note: lfd may restart csf)

```shell
sudo csf -f
```

=== ":aetherx-axs-square-terminal: Terminal"

    ```console
    Flushing chain `INPUT'
    Flushing chain `FORWARD'
    Flushing chain `CC_ALLOWPORTS'
    [ ... ]
    Deleting chain `ALLOWIN'
    Deleting chain `ALLOWOUT'
    Deleting chain `CC_ALLOWP'
    Deleting chain `CC_ALLOWPORTS'
    [ ... ]
    ```

<br />

### Restart
<!-- md:command `-r,  --restart` -->

Restart firewall rules (csf)

```shell
sudo csf -r
```

=== ":aetherx-axs-square-terminal: Terminal"

    ```console
    Flushing chain `INPUT'
    Flushing chain `FORWARD'
    Flushing chain `OUTPUT'
    Flushing chain `ALLOWIN'
    Flushing chain `ALLOWOUT'
    Flushing chain `CC_ALLOWP'
    Flushing chain `CC_ALLOWPORTS'
    [ ... ]
    ```

<br />

### Quick Restart
<!-- md:command `-q,  --startq` -->

Quick restart (csf restarted by lfd)

```shell
sudo csf -q
```

=== ":aetherx-axs-square-terminal: Terminal"

    ```console
    lfd will restart csf within the next 5 seconds
    ```

<br />

### Force Restart
<!-- md:command `-sf, --startf` -->

Force CLI restart regardless of LFDSTART setting

```shell
sudo csf -sf
```

=== ":aetherx-axs-square-terminal: Terminal"

    ```console
    Flushing chain `INPUT'
    Flushing chain `FORWARD'
    Flushing chain `OUTPUT'
    Flushing chain `ALLOWIN'
    Flushing chain `ALLOWOUT'
    Flushing chain `CC_ALLOWP'
    Flushing chain `CC_ALLOWPORTS'
    [ ... ]
    ```

<br />

### Restart All
<!-- md:command `-ra, --restartall` -->

Restart firewall rules (csf) and then restart lfd daemon. Both csf and then lfd should be restarted after making	any  changes  to the configuration files

```shell
sudo csf -ra
```

=== ":aetherx-axs-square-terminal: Terminal"

    ```console
    Flushing chain `INPUT'
    Flushing chain `FORWARD'
    Flushing chain `OUTPUT'
    Flushing chain `ALLOWIN'
    Flushing chain `ALLOWOUT'
    Flushing chain `CC_ALLOWP'
    Flushing chain `CC_ALLOWPORTS'
    [ ... ]
    ```

<br />

### Cluster Restart
<!-- md:command `-crs, --crestart` -->

Cluster restart csf and lfd

```shell
sudo csf -crs
```

<br />

### Manage Lfd Daemon
<!-- md:command `--lfd [stop|start|restart|status]` -->

Actions to take with the lfd daemon

```shell
sudo csf --lfd stop
sudo csf --lfd start
sudo csf --lfd restart
sudo csf --lfd status
```

=== "stop"

    ```
    No output
    ```

=== "start"

    ```
    No output
    ```

=== "restart"

    ```
    ● lfd.service - ConfigServer Security & Firewall - lfd
        Loaded: loaded (/lib/systemd/system/lfd.service; enabled; preset: enabled)
        Active: active (running) since 15ms ago
        Process: 3769 ExecStart=/usr/sbin/lfd (code=exited, status=0/SUCCESS)
      Main PID: 3782 (lfd - starting)
          Tasks: 1 (limit: 4613)
        Memory: 38.7M
            CPU: 366ms
        CGroup: /system.slice/lfd.service
                ├─3782 "lfd - starting"
                └─3784 "lfd - starting"

    systemd[1]: Starting lfd.service - ConfigServer Security & Firewall - lfd...
    systemd[1]: Started lfd.service - ConfigServer Security & Firewall - lfd.
    ```

=== "status"

    ```
    ● lfd.service - ConfigServer Security & Firewall - lfd
        Loaded: loaded (/lib/systemd/system/lfd.service; enabled; preset: enabled)
        Active: active (running) since 1min 3s ago
        Process: 3769 ExecStart=/usr/sbin/lfd (code=exited, status=0/SUCCESS)
      Main PID: 3782 (lfd - sleeping)
          Tasks: 2 (limit: 4613)
        Memory: 45.2M
            CPU: 9.476s
        CGroup: /system.slice/lfd.service
                ├─3782 "lfd - sleeping"
                └─3791 "lfd UI"

    systemd[1]: Starting lfd.service - ConfigServer Security & Firewall - lfd...
    systemd[1]: Started lfd.service - ConfigServer Security & Firewall - lfd.
    ```

<br />

## Updates

The following commands allow you to check for updates, as well as update CSF to the latest version.

<br />

### Check for Updates
<!-- md:command `-c,  --check` -->

Check for updates to csf but do not upgrade

```shell
sudo csf -c
```

=== ":aetherx-axs-square-terminal: Terminal"

    ```console
    csf is already at the latest version: v14.20
    ```

<br />

### Update
<!-- md:command `-u,  --update` -->

Check for updates to csf and upgrade if available

```shell
sudo csf -u
```

<br />

### Update (Force)
<!-- md:command `-uf` -->

Force an update of csf whether and upgrade is required or not

```shell
sudo csf -uf
```

<br />

## Informational

The following commands display information regarding CSF.

<br />

### Version
<!-- md:command `-v,  --version` -->

Show csf version

=== ":aetherx-axu-rectangle-code: Syntax"

    ```shell
    sudo csf -v
    ```

=== ":aetherx-axs-square-terminal: Terminal"

    ```shell
    csf: v15.10 (generic)
    ```

<br />

### Insiders
<!-- md:command `-in,  --insiders` -->

Displays if your installation of CSF uses the Insiders release channel, or the Stable release channel.

=== ":aetherx-axu-rectangle-code: Syntax"

    ```shell
    sudo csf -in
    ```

=== ":aetherx-axs-square-terminal: Terminal"

    ```shell
    csf: v15.10 (generic)
    ```

<br />

## Rules

The following commands allow you to manage the IP addresses allowed and blocked within your firewall.

<br />

### List Firewall Rules (IPv4)
<!-- md:command `-l,  --status` -->

List/Show the IPv4 iptables configuration

=== ":aetherx-axu-rectangle-code: Syntax"

    ```shell
    sudo csf -l
    ```

=== ":aetherx-axs-square-terminal: Terminal"

    ```shell
    iptables filter table
    =====================
    Chain INPUT (policy DROP 0 packets, 0 bytes)
    num   pkts bytes target     prot opt in     out     source               destination         
    1       33  2492 ACCEPT     udp  --  *      *       0.0.0.0/0            0.0.0.0/0            multiport dports 4000,5353
    2      758 55610 ACCEPT     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            multiport dports 4000
    3        0     0 ACCEPT     udp  --  *      *       0.0.0.0/0            0.0.0.0/0            multiport dports 5353
    4    5209K   28G LOCALINPUT  all  --  !lo    *       0.0.0.0/0            0.0.0.0/0           
    13       3   180 ACCEPT     tcp  --  !lo    *       0.0.0.0/0            0.0.0.0/0            ctstate NEW tcp dpt:22
    14     998 56956 ACCEPT     tcp  --  !lo    *       0.0.0.0/0            0.0.0.0/0            ctstate NEW tcp dpt:25
    15     123  5612 ACCEPT     tcp  --  !lo    *       0.0.0.0/0            0.0.0.0/0            ctstate NEW tcp dpt:53
    16      16   680 ACCEPT     tcp  --  !lo    *       0.0.0.0/0            0.0.0.0/0            ctstate NEW tcp dpt:853
    17       2   100 ACCEPT     tcp  --  !lo    *       0.0.0.0/0            0.0.0.0/0            ctstate NEW tcp dpt:80
    18      74  3148 ACCEPT     tcp  --  !lo    *       0.0.0.0/0            0.0.0.0/0            ctstate NEW tcp dpt:110
    19     125  5624 ACCEPT     tcp  --  !lo    *       0.0.0.0/0            0.0.0.0/0            ctstate NEW tcp dpt:143
    ```

<br />

### List Firewall Rules (IPv6)
<!-- md:command `-l6, --status6` -->

List/Show the IPv6 ip6tables configuration

=== ":aetherx-axu-rectangle-code: Syntax"

    ```shell
    sudo csf -l6
    ```

=== ":aetherx-axs-square-terminal: Terminal"

    ```shell
    ip6tables filter table
    ======================
    Chain INPUT (policy DROP 0 packets, 0 bytes)
    num   pkts bytes target     prot opt in     out     source               destination         
    8        0     0 ACCEPT     all      !lo    *       ::/0                 ::/0                 ctstate RELATED,ESTABLISHED
    9        0     0 ACCEPT     tcp      !lo    *       ::/0                 ::/0                 ctstate NEW tcp dpt:20
    10       0     0 ACCEPT     tcp      !lo    *       ::/0                 ::/0                 ctstate NEW tcp dpt:21
    11       0     0 ACCEPT     tcp      !lo    *       ::/0                 ::/0                 ctstate NEW tcp dpt:22
    12       0     0 ACCEPT     tcp      !lo    *       ::/0                 ::/0                 ctstate NEW tcp dpt:25
    13       0     0 ACCEPT     tcp      !lo    *       ::/0                 ::/0                 ctstate NEW tcp dpt:53
    14       0     0 ACCEPT     tcp      !lo    *       ::/0                 ::/0                 ctstate NEW tcp dpt:853
    15       0     0 ACCEPT     tcp      !lo    *       ::/0                 ::/0                 ctstate NEW tcp dpt:80
    16       0     0 ACCEPT     tcp      !lo    *       ::/0                 ::/0                 ctstate NEW tcp dpt:110
    17       0     0 ACCEPT     tcp      !lo    *       ::/0                 ::/0                 ctstate NEW tcp dpt:143
    ```

<br />

### Add IP to Allow List
<!-- md:command `-a,  --add ip [comment]` -->

Allow an IP and add to `/etc/csf/csf.allow`

=== ":aetherx-axu-rectangle-code: Syntax"

    ```shell
    sudo csf -a <IP_ADDRESS>
    sudo csf -a 142.250.189.142
    ```

=== ":aetherx-axs-square-terminal: Terminal"

    ```shell
    Adding 142.250.189.142 to csf.allow and iptables ACCEPT...
    csf: IPSET adding [142.250.189.142] to set [chain_ALLOW]
    ```

<br />

### Remove IP to Allow List
<!-- md:command `-ar, --addrm ip` -->

Remove an IP from `/etc/csf/csf.allow` and delete rule

```shell
sudo csf -ar <IP_ADDRESS>
```

<br />

### Add IP to Deny List
<!-- md:command `-d,  --deny ip [comment]` -->

Deny an IP and add to `/etc/csf/csf.deny`

```shell
sudo csf -d <IP_ADDRESS>
```

<br />

### Remove IP from Deny List
<!-- md:command `-dr, --denyrm ip` -->

Unblock an IP and remove from `/etc/csf/csf.deny`

```shell
sudo csf -dr <IP_ADDRESS>
```

<br />

### Remove All IPs from Deny List
<!-- md:command `-df, --denyf` -->

Remove and unblock all entries in `/etc/csf/csf.deny`

=== ":aetherx-axu-rectangle-code: Syntax"

    ```shell
    sudo csf -df
    ```

=== ":aetherx-axs-square-terminal: Terminal"

    ```shell
    csf: all entries removed from csf.deny
    ```

<br />

### Grep Search for IP
<!-- md:command `-g,  --grep ip` -->

Search the iptables and ip6tables rules for a match (e.g. IP, CIDR, Port Number)

```shell
sudo csf -g <STRING>
sudo csf -g 22
sudo csf -g ACCEPT
```

<br />

### Lookup IP
<!-- md:command `-i,  --iplookup ip` -->

Lookup IP address geographical information using `CC_LOOKUPS` setting in `/etc/csf/csf.conf`

=== ":aetherx-axu-rectangle-code: Syntax"

    ```shell
    sudo csf -i <IP_ADDRESS>
    sudo csf -i 142.250.189.142
    ```

=== ":aetherx-axs-square-terminal: Terminal"

    ```shell
    142.250.189.142 (US/United States/mia09s26-in-f14.1e100.net)
    ```

<br />

### View Temp Allow/Ban List
<!-- md:command `-t,  --temp` -->

Displays the current list of temporary allow and deny IP entries with their TTL and comment

=== ":aetherx-axu-rectangle-code: Syntax"

    ```shell
    sudo csf -t
    ```

=== ":aetherx-axs-square-terminal: Terminal"

    ```shell
    A/D   IP address          Port    Dir     Time To Live     Comment
    ALLOW 142.250.189.142     *       inout   58m 56s          Manually added: 142.250.189.142 (US/United States/mia09s26-in-f14.1e100.net)
    ```

<br />

### Remove Temp Allow/Ban IP
<!-- md:command `-tr, --temprm ip` -->

Remove an IP from the temporary IP ban or allow list

=== ":aetherx-axu-rectangle-code: Syntax"

    ```shell
    sudo csf -tr <IP_ADDRESS>
    sudo csf -tr 142.250.189.142
    ```

=== ":aetherx-axs-square-terminal: Terminal"

    ```shell
    ACCEPT  all opt -- in !lo out *  142.250.189.142  -> 0.0.0.0/0  
    ACCEPT  all opt -- in * out !lo  0.0.0.0/0  -> 142.250.189.142  
    csf: 142.250.189.142 temporary allow removed
    ```

<br />

### Remove Temp Ban IP
<!-- md:command `-trd, --temprmd ip` -->

Remove an IP from the temporary IP ban list only

```shell
sudo csf -trd <IP_ADDRESS>
```

<br />

### Remove Temp Allow IP
<!-- md:command `-tra, --temprma ip` -->

Remove an IP from the temporary IP allow list only

```shell
sudo csf -tra <IP_ADDRESS>
```

<br />

### Add Temp Block IP
<!-- md:command `-td, --tempdeny ip ttl [-p port] [-d direction] [comment]` -->

Add an IP to the temp IP ban list. ttl is how long to blocks for (default:seconds, can use one suffix of h/m/d). Optional port.
Optional direction of block can be one of: in, out or inout (default:in)

```shell
sudo csf -td <IP_ADDRESS>
```

<br />

### Add Temp Allow IP
<!-- md:command `-ta, --tempallow ip ttl [-p port] [-d direction] [comment]` -->

Add an IP to the temp IP allow list (default:inout)

=== ":aetherx-axu-rectangle-code: Syntax"

    ```shell
    sudo csf -ta <IP_ADDRESS>
    sudo csf -ta 142.250.189.142
    ```

=== ":aetherx-axs-square-terminal: Terminal"

    ```
    ACCEPT  all opt -- in !lo out *  142.250.189.142  -> 0.0.0.0/0  
    ACCEPT  all opt -- in * out !lo  0.0.0.0/0  -> 142.250.189.142
    ```

<br />

### Flush All Temp IP Entries
<!-- md:command `-tf, --tempf` -->

Flush all IPs from the temporary IP entries

=== ":aetherx-axu-rectangle-code: Syntax"

    ```shell
    sudo csf -tf
    ```

=== ":aetherx-axs-square-terminal: Terminal"

    ```shell
    csf: There are no temporary IP bans
    ACCEPT  all opt -- in !lo out *  142.250.189.142  -> 0.0.0.0/0  
    ACCEPT  all opt -- in * out !lo  0.0.0.0/0  -> 142.250.189.142  
    csf: 142.250.189.142 temporary allow removed
    ```

<br />

### Initiate Lfd Log Scanner
<!-- md:command `-lr, --logrun` -->

Initiate Log Scanner report via lfd

```shell
sudo csf -lr
```

<br />

If you receive the following error in console:

=== ":aetherx-axs-square-terminal: Terminal"

    ```shell
    Option LOGSCANNER needs to be enabled in csf.conf for this feature
    ```

<br />

Open your `csf.conf` configuration file, locate the setting `LOGSCANNER`, and change the value to `1`:

```ini hl_lines="18"
###############################################################################
# SECTION:Log Scanner
###############################################################################
# Log Scanner. This feature will send out an email summary of the log lines of
# each log listed in /etc/csf/csf.logfiles. All lines will be reported unless
# they match a regular expression in /etc/csf/csf.logignore
#
# File globbing is supported for logs listed in /etc/csf/csf.logfiles. However,
# be aware that the more files lfd has to track, the greater the performance
# hit. Note: File globs are only evaluated when lfd is started
#
# Note: lfd builds the report continuously from lines logged after lfd has
# started, so any lines logged when lfd is not running will not be reported
# (e.g. during reboot). If lfd is restarted, then the report will include any
# lines logged during the previous lfd logging period that weren't reported
#
# 1 to enable, 0 to disable
LOGSCANNER = "0"
```

<br />

Then go back to console and re-run the command.

<br />

## Port Management

These commands allow you to manage what ports are whitelisted in your firewall, and view information regarding the ports.

Certain commands require specific arguments to be provided. These arguments are described below:

`<protocol>`
:   Specifies the **protocol** when adding or removing ports. Omitting or providing an incorrect protocol will trigger an error. Accepted values include:

:   - TCP_IN
    - TCP_OUT
    - UDP_IN
    - UDP_OUT

`<port>`
:   Represents the **port** you want to add or remove from your whitelist. Valid port numbers range from `0` to `65535`.

<br />

### Add Port (Allow)
<!-- md:command `-ap, --addport <protocol>:<port>` -->

This command allows you to whitelist a port within CSF, allowing access to or from it.

=== ":aetherx-axu-rectangle-code: Syntax"

    ```shell
    sudo csf --addport <protocol>:<port>
    ```

=== ":aetherx-axu-magnifying-glass: Examples"

    ```shell
    sudo csf --addport TCP_IN:2215
    sudo csf --addport UDP_OUT:985
    ```

<br />

### Remove Port (Deny)
<!-- md:command `-rp, --removeport <protocol>:<port>` -->

This command allows you to remove a specified port from your existing CSF whitelist.

=== ":aetherx-axu-rectangle-code: Syntax"

    ```shell
    sudo csf --removeport <protocol>:<port>
    ```

=== ":aetherx-axu-magnifying-glass: Examples"

    ```shell
    sudo csf --removeport TCP_IN:2215
    sudo csf --removeport UDP_OUT:985
    ```

<br />

### List Ports
<!-- md:command `-lp, --listports` -->

This command lets you view both protocols, all chains, and which ports are currently whitelisted for each protocol.

=== ":aetherx-axu-rectangle-code: Syntax"

    ```shell
    sudo csf --listports
    ```

=== ":aetherx-axs-square-terminal: Terminal"

    ```shell
    $ sudo csf --listports

    INFO              Configured CSF Ports:                           
                      The following are a list of the whitelisted ports configured in your /etc/csf/csf.conf

                      TCP_IN: 22,25,80,143,443
                      TCP_OUT: 22,25,80,113,443
                      UDP_IN: 53,80,443,853
                      UDP_OUT: 53,113,123,853
    ```

<br />

### View Ports
<!-- md:command `-p, --ports` -->

View ports on the server that have a running process behind them listening for external connections

=== ":aetherx-axu-rectangle-code: Syntax"

    ```shell
    sudo csf -p
    ```

=== ":aetherx-axs-square-terminal: Terminal"

    ```
    Ports listening for external connections and the executables running behind them:
    Port/Proto Open Conn  PID/User             Command Line                         Executable
    631/tcp    -/-  -     (1090/root)          /usr/sbin/cupsd -l                   /usr/sbin/cupsd
    8546/tcp   4/6  -     (4627/root)          lfd UI                               /usr/bin/perl
    5353/udp   -/-  -     (337/systemd-resolve /lib/systemd/systemd-resolved        /usr/lib/systemd/systemd-resolved
    5353/udp   -/-  -     (702/avahi)          avahi-daemon: running [local]        /usr/sbin/avahi-daemon
    40857/udp  -/-  -     (702/avahi)          avahi-daemon: running [local]        /usr/sbin/avahi-daemon
    49833/udp  -/-  -     (702/avahi)          avahi-daemon: running [local]        /usr/sbin/avahi-daemon
    ```

<br />

## Graphs and Statistics

These commands outline how to utilize the built-in CSF graphics & statistics functionality.

<br />

### View Graphs
<!-- md:command `--graphs [graph type] [directory]` -->

Generate System Statistics html pages and images for a given graph type into a given directory. See `ST_SYSTEM` for requirements

`[graph type]`

:   - disk
    - apachework
    - mysqlslowqueries
    - cpu
    - load
    - mysqlconns
    - net
    - diskw
    - apachecpu
    - email
    - temp
    - apacheconn
    - mysqlqueries
    - mem
    - mysqldata

```shell
sudo csf --graphs <GRAPH_TYPE> <SAVE_PATH>
sudo csf --graphs mem /home/$USER/graphs
```

<br />

If you run the above command and see the error:

=== ":aetherx-axs-square-terminal: Terminal"

    ```
    ST_SYSTEM is disabled
    ```

<br />

Open your `csf.conf` configuration file, locate the setting `ST_SYSTEM`, and change the value to `1`:

```ini hl_lines="14"
# This option will gather basic system statstics. Through the UI it displays
# various graphs for disk, cpu, memory, network, etc usage over 4 intervals:
#  . Hourly (per minute)
#  . 24 hours (per minute)
#  . 7 days (per minute averaged over an hour)
#  . 30 days (per minute averaged over an hour) - user definable
# The data is stored in /var/lib/csf/stats/system and the option requires the
# perl GD::Graph module
#
# Note: Disk graphs do not show on Virtuozzo/OpenVZ servers as the kernel on
# those systems do not store the required information in /proc/diskstats
# On new installations or when enabling this option it will take time for these
# graphs to be populated
ST_SYSTEM = "0"
```

<br />

If you receive the error:

=== ":aetherx-axs-square-terminal: Terminal"

    ```
    Perl module GD::Graph is not installed/working
    ```

<br />

Install the package `libgd-graph-perl`:

=== ":aetherx-axb-debian: Debian/Ubuntu (apt-get)"

    ```shell
    apt-get update
    apt-get install -y perl \
      libgd-graph-perl
    ```

=== ":aetherx-axb-redhat: CentOS/RHEL (yum/dnf)"

    ```shell
    yum install -y perl \
      perl-GDGraph
    ```

=== ":aetherx-axs-onion: Perl (CPAN)"

    ```shell
    perl -MCPAN -eshell
    cpan> install GD::Graph
    ```

<br />

---

<br />
