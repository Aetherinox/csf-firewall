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

If you have decided that you'd like to part ways with CSF, uninstalling the application is extremely easy as it only requires you to run the uninstall. First, make sure you set the uninstall script to be executable:

=== ":aetherx-axd-command: Command"

      ``` shell
      sudo chmod +x /etc/csf/uninstall.sh
      ```

<br />

Then run the uninstall script itself:

=== ":aetherx-axd-command: Command"

      ``` shell
      sudo sh uninstall.sh
      ```

<br />

This will perform a series of actions including:

- :aetherx-axs-ban:{ .icon-clr-red } Stop and unregister the services `csf.service` and `lfd.service`
- :aetherx-axd-trash:{ .icon-clr-red } Delete the service files within `/usr/lib/systemd/system/`
- :aetherx-axd-arrows-rotate:{ .icon-clr-green } Reload the systemctl daemon
- :aetherx-axd-trash:{ .icon-clr-red } Delete binaries stored in `/usr/sbin/`
- :aetherx-axd-trash:{ .icon-clr-red } Delete delete main folder `/etc/csf`
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
<br />
