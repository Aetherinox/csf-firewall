---
title: Install › Uninstall CSF
tags:
  - uninstall
---

# Uninstall CSF <!-- omit from toc -->

This section of the guide explains how to uninstall ConfigServer Firewall and the LFD daemon from your server entirely.

<br />

---

<br />

## Uninstall

If you have decided that you'd like to part ways with CSF, uninstalling the application is extremely easy as it only requires you to run the uninstall script. Pick **one** of the two options listed below:

:   :aetherx-axd-circle-1: Runs `uninstall.sh` :aetherx-axd-dot: uses shebang interpreter :aetherx-axd-dot: requires executable `+x` permission
:   :aetherx-axd-circle-2: Runs `uninstall.sh` :aetherx-axd-dot: uses `sh` shell :aetherx-axd-dot: executable permission not required

<br />

??? note "Dependencies & packages not removed"

    Running the CSF uninstaller will **not** remove extra dependencies such as `perl`, `ipset`, or `gd-library`. You must uninstall these yourself.

<br />

=== ":aetherx-axd-circle-1: Option 1"

    ```bash
    # set executable permission
    sudo chmod +x /etc/csf/uninstall.sh

    # run uninstall script
    /etc/csf/uninstall.sh
    ```

=== ":aetherx-axd-circle-2: Option 2"

    ```bash
    # run uninstall script
    sh /etc/csf/uninstall.sh
    ```

<br />

This will perform a series of actions including:

- :aetherx-axs-ban:{ .icon-clr-red } Stop and unregister the services `csf.service` and `lfd.service`
- :aetherx-axd-trash:{ .icon-clr-red } Delete the service files within `/usr/lib/systemd/system/`
- :aetherx-axd-arrows-rotate:{ .icon-clr-green } Reload the systemctl daemon
- :aetherx-axd-trash:{ .icon-clr-red } Delete binaries stored in `/usr/sbin/`
- :aetherx-axd-trash:{ .icon-clr-red } Delete main folder `/etc/csf`
- :aetherx-axd-trash:{ .icon-clr-red } Delete pre and post scripts from `/usr/local/csf` and `/usr/local/include/csf`
- :aetherx-axd-trash:{ .icon-clr-red } Delete temp allow/ban lists from `/var/lib/csf`
- :aetherx-axd-trash:{ .icon-clr-red } Delete man pages from `/usr/local/man/`
- :aetherx-axd-trash:{ .icon-clr-red } Delete initialzation scripts in `/sbin/chkconfig` and `/etc/init.d/`
- :aetherx-axd-trash:{ .icon-clr-red } Delete logs stored in `/etc/logrotate.d/`
- :aetherx-axd-trash:{ .icon-clr-red } Delete WHM / cPanel integration scripts from `/usr/local/cpanel/whostmgr/` and `/usr/local/cpanel/Cpanel/`
- :aetherx-axd-trash:{ .icon-clr-red } Delete Interworx integration scripts from `/usr/local/interworx/plugins/`
- :aetherx-axd-trash:{ .icon-clr-red } Delete CWP integration scripts from `/usr/local/cwpsrv/`
- :aetherx-axd-trash:{ .icon-clr-red } Delete CyberPanel integration scripts from `/usr/local/CyberCP/` and `/home/cyberpanel/plugins`
- :aetherx-axd-trash:{ .icon-clr-red } Delete VestaCP integration scripts from `/usr/local/vesta`
- :aetherx-axd-trash:{ .icon-clr-red } Delete DirectAdmin integration scripts from `/usr/local/directadmin/data/admin/services.status`
- :aetherx-axd-trash:{ .icon-clr-red } Delete crons registered in `/etc/cron.d/`

<br />

---

<br />


## Clean Iptables

Uninstalling CSF does not clean up your existing iptables. These rulles will still sit in iptables until you do one of two things:

1. Restart your server
2. Manually wipe your iptables

<br />

If you would like to clean your iptables and remove any existing firewall rules from your server, you can run the following commands in order:

```shell
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo iptables -t mangle -F
sudo iptables -t mangle -X
```

<br />

An optional step is to verify that your iptables chains are not restricting incoming or outgoing connections. You can modify the state of your chains using the commands below.

??? danger "Danger! This will leave your server exposed"

    Setting all three primary iptable chains to `ACCEPT` will **remove all firewall protection from your server**. Only do this if you fully understand the risks and truly intend to leave your server unprotected.

    Even if you’ve removed CSF from your system, you still have the option of using iptables as a standalone firewall.  

```shell
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT
```


<br />

You can now confirm if your iptables are empty and your chains have the default policy `ACCEPT`:

```shell
sudo iptables -L -n -v
```

<br />

You should see the following:

```shell
Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain FORWARD (policy ACCEPT 0 packets, 6508 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination  
```

<br />

No IP addresses should be listed under each chain, and you should see `policy: ACCEPT` to the right of each chain name.

<br />

---

<br />

## Docker Users

If you are running docker on your server and you remove CSF; you may notice that your docker containers are no longer accessible. You may also receive errors in your terminal if you attempt to start up or shut down any of your containers, such as the following:

```
docker: Error response from daemon: driver failed programming
   external connectivity on endpoint portainer1 (XXX):
   (iptables failed: iptables --wait -t filter -A DOCKER ! -i docker0 -o docker0 -p tcp -d 172.17.0.2 --dport 9000 -j ACCEPT:
   iptables: No chain/target/match by that name.
```

<br />

To correct these errors, ensure you complete the steps:

:   - [Clean Iptables](#clean-iptables)
    - [Restart Service](#restart-service)

<br />

### Restart Service

After you have completed all other steps, simply give your docker service a restart.

=== ":aetherx-axd-command: Command"

      ```shell
      sudo systemctl restart docker
      ```

<br />
<br />
