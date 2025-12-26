---
title: "Cheatsheet › Structure"
tags:
  - cheatsheet
  - configure
---

# Cheatsheet: Structure <!-- omit from toc -->

This page provides a summary of the files and folders associated with **ConfigServer Security & Firewall (CSF)**. Use it as a reference to locate and edit specific configuration files or resources.

<br />

## 📁 Directory Structure

Directories associated with ConfigServer Filewall which house all of the files used to configure and manage CSF.

| Folder                                  | Description                                                                                                                                   |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `/etc/csf/`                             | CSF configuration files, blocklists, whitelists, etc                                                                                          |
| `/var/lib/csf/`                         | Runtime data, temporary files, and logs for CSF and LFD                                                                                       |
| `/var/lib/csf/ui`                       | Runtime data and cache for the CSF WebUI.                                                                                                     |
| `/usr/local/csf/bin/`                   | Pre & post initialzation scripts `csfpre.sh` and `csfpost.sh`, test script `csftest.pl`, and csf uninstaller `uninstall.sh`                   |
| `/usr/local/csf/lib/`                   | Perl modules and static data                                                                                                                  |
| `/usr/local/csf/profiles/`              | Pre-configured CSF setup profiles                                                                                                             |
| `/usr/local/csf/tpl/`                   | Email alert templates                                                                                                                         |
| `/usr/local/include/csf/pre.d/`         | Scripts to execute when CSF started. Runs **before** CSF configures iptables. These are triggered by `/usr/local/csf/bin/csfpre.sh`           |
| `/usr/local/include/csf/post.d/`        | Scripts to execute when CSF started. Runs **after** CSF configures iptables. These are triggered by `/usr/local/csf/bin/csfpost.sh`           |

<br />

---

<br />

## 📄 File Structure

Files associated with ConfigServer Firewall configuration and management.

| File                                    | Description                                                                                                                                   |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `/etc/csf/changelog.txt`                | List of changes made to each release of CSF / LFD                                                                                             |
| `/etc/csf/cpanel.allow`                 | List of addresses allowed through iptables for unimpeded access to cpanel license servers                                                     |
| `/etc/csf/cpanel.comodo.allow`          | List of Sectigo (Comodo) IPs explicitly allowed through iptables to ensure AutoSSL connections are never blocked.                             |
| `/etc/csf/cpanel.comodo.ignore`         | List of Sectigo (Comodo) IPs ignored by LFD’s login/banning system to prevent them from being auto-blocked.                                   |
| `/etc/csf/cpanel.allow`                 | List of addresses which ensure traffic from cPanel’s license servers is explicitly allowed through iptables.                                  |
| `/etc/csf/cpanel.ignore`                | List of addresses from cPanel’s license servers that are excluded from LFD (Login Failure Daemon) monitoring.                                 |
| `/etc/csf/csf.allow`                    | List of IP's & CIDR addresses allowed through the firewall                                                                                    |
| `/etc/csf/csf.blocklists`               | URLs for external blocklists used by CSF to block malicious IPs                                                                               |
| `/etc/csf/csf.cloudflare`               | Contains configuration elements for the `CF_ENABLE` CloudFlare feature                                                                        |
| `/etc/csf/csf.conf`                     | Main configuration file                                                                                                                       |
| `/etc/csf/csf.deny`                     | IP's and CIDR addresses that should never be allowed through the firewall                                                                     |
| `/etc/csf/csf.dirwatch`                 | Directories & files you want to be alerted when changed. Must specify full paths for entries                                                  |
| `/etc/csf/csf.dyndns`                   | IPs & hostnames of systems that are dynamically updated (like via a dynamic DNS service)                                                      |
| `/etc/csf/csf.fignore`                  | Files that lfd directory watching will ignore. You must specify the full path to the file                                                     |
| `/etc/csf/csf.ignore`                   | IP's & CIDR addresses that the login failure daemon should ignore and not not block if detected                                               |
| `/etc/csf/csf.logfiles`                 | Log files for the `LOGSCANNER` feature                                                                                                        |
| `/etc/csf/csf.logignore`                | Regular expressions for the `LOGSCANNER` feature. If a line matches it will be ignored, otherwise it will be reported                         |
| `/etc/csf/csf.mignore`                  | Usernames and local IP addresses that `RT_LOCALRELAY_ALERT` will ignore                                                                       |
| `/etc/csf/csf.pignore`                  | Processes LFD should ignore (for example, trusted services).                                                                                  | 
| `/etc/csf/csf.rblconf`                  | Optional entries for the IP checking against RBLs within csf                                                                                  |
| `/etc/csf/csf.redirect`                 | Port and/or IP address assignments to direct traffic to alternative ports/IP addresses                                                        |
| `/etc/csf/csf.resellers`                | Reseller accounts to allow access to limited csf functionality.                                                                               |
| `/etc/csf/csf.rignore`                  | Domains & partial domain that lfd process tracking will ignore based on reverse & forward DNS lookups                                         |
| `/etc/csf/csf.signore`                  | Files that `LF_SCRIPT_ALERT` will ignore. Specify the full path to the directory containing the script                                        |
| `/etc/csf/csf.sips`                     | List any server configured IP addresses for which you don't want to allow any incoming or outgoing traffic                                    |
| `/etc/csf/csf.smtpauth`                 | Will allow EXIM to advertise SMTP AUTH. One IP address per line.                                                                              | 
| `/etc/csf/csf.suignore`                 | Usernames that are ignored during the `LF_EXPLOIT` SUPERUSER check                                                                            |
| `/etc/csf/csf.syslogs`                  | Log files for the UI System Log Watch and Search features. IF they exists they will apear in the drop-down lists                              |
| `/etc/csf/csf.syslogusers`              | Usernames which should be allowed to log via syslog/rsyslog                                                                                   |
| `/etc/csf/csf.uidignore`                | User ID's (UID) that are ignored by the User ID Tracking feature                                                                              |
| `/etc/csf/downloadservers`              | Servers that will be pinged to fetch updates for CSF                                                                                          |
| `/etc/csf/ui/ui.allow`                  | IPs allowed to access the CSF WebUI. IPs in this file bypass CSF's IP restrictions for the web ui                                             |
| `/etc/csf/ui/ui.ban`                    | IPs that are explicitly denied access to the CSF WebUI                                                                                        |
| `/lib/systemd/system/csf.service`       | Service file for csf (Login Failure Daemon)                                                                                                   |
| `/lib/systemd/system/lfd.service`       | Service file for lfd (ConfigServer Firewall)                                                                                                  |
| `/var/lib/csf/lfd.log`                  | Main LFD log file recording login attempts, blocked IPs, and alerts.                                                                          |
| `/var/lib/csf/lfd.pid`                  | PID file for Login Failure Daemon (LFD).                                                                                                      |

<br />

---

<br />

## :aetherx-axs-folder-tree:{ .icon-clr-tree-folder } Advanced Structure

We have provided a very detailed tree below that make up CSF and LFD's entire structure. This assists you with locating specific files that you may need to modify. Each file or folder will contain an icon; we have provided a list below to be used as an icon lenend:

<br />

### :aetherx-axs-folder:{ .icon-clr-tree-folder } /etc/csf/

The files within the subfolder `/etc/csf` contain most of your configurable files, including the main `csf.conf` configuration file. This location also holds all of your allow and block lists that will be used to restrict access to your server and to your CSF web interface (if enabled).

<div class="icon-tree" markdown>
<code>
└── :aetherx-axs-folder:{ .icon-clr-tree-folder } etc  
     └── :aetherx-axs-folder:{ .icon-clr-tree-folder } csf  
          ├── :aetherx-axs-paperclip:{ .icon-clr-tree-symlink } alerts -> :aetherx-axs-folder:{ .icon-clr-tree-folder } /usr/local/csf/tpl  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } changelog.txt   
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } cpanel.allow  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } cpanel.comodo.allow  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } cpanel.comodo.ignore  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } cpanel.ignore  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.allow  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.blocklists  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.cloudflare  
          ├── :aetherx-axd-file-code:{ .icon-clr-tree-file-conf } csf.conf  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.deny  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.dirwatch  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.dyndns  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.fignore  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.ignore  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.logfiles  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.logignore  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.mignore  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.pignore  
          ├── :aetherx-axs-paperclip:{ .icon-clr-tree-symlink } csf.pl -> :aetherx-axd-file:{ .icon-clr-tree-file } /usr/sbin/csf  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.rblconf  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.redirect  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.resellers  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.rignore  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.signore  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.sips  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.smtpauth  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.suignore  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.syslogs  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.syslogusers  
          ├── :aetherx-axs-paperclip:{ .icon-clr-tree-symlink } csftest.pl -> :aetherx-axd-file:{ .icon-clr-tree-file } /usr/local/csf/bin/csftest.pl  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.uidignore  
          ├── :aetherx-axs-paperclip:{ .icon-clr-tree-symlink } csfwebmin.tgz -> :aetherx-axs-file-zipper:{ .icon-clr-tree-file-archive } /usr/local/csf/csfwebmin.tgz  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } downloadservers  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } install.txt  
          ├── :aetherx-axs-paperclip:{ .icon-clr-tree-symlink } lfd.pl -> :aetherx-axd-file:{ .icon-clr-tree-file } /usr/sbin/lfd  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } license.txt  
          ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } messenger  
          │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } en.php  
          │   ├── :aetherx-axb-html5:{ .icon-clr-tree-file-html } index.html  
          │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } index.php  
          │   ├── :aetherx-axb-html5:{ .icon-clr-tree-file-html } index.recaptcha.html  
          │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } index.recaptcha.php  
          │   └── :aetherx-axd-file:{ .icon-clr-tree-file } index.text  
          ├── :aetherx-axs-paperclip:{ .icon-clr-tree-symlink } pt_deleted_action.pl -> :aetherx-axd-file:{ .icon-clr-tree-file } /usr/local/csf/bin/pt_deleted_action.pl  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } readme.txt  
          ├── :aetherx-axs-paperclip:{ .icon-clr-tree-symlink } regex.custom.pm -> :aetherx-axd-file:{ .icon-clr-tree-file } /usr/local/csf/bin/regex.custom.pm  
          ├── :aetherx-axs-paperclip:{ .icon-clr-tree-symlink } remove_apf_bfd.sh -> :aetherx-axd-file:{ .icon-clr-tree-file } /usr/local/csf/bin/remove_apf_bfd.sh  
          ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } ui  
          │   ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } images  
          │   │   ├── admin_icon.svg  
          │   │   ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } bootstrap  
          │   │   │   ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } css  
          │   │   │   │   ├── :aetherx-axb-css:{ .icon-clr-tree-file-css } bootstrap.min.css  
          │   │   │   │   └── :aetherx-axb-css:{ .icon-clr-tree-file-css } bootstrap.min.css.map  
          │   │   │   ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } fonts  
          │   │   │   │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } glyphicons-halflings-regular.eot  
          │   │   │   │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } glyphicons-halflings-regular.svg  
          │   │   │   │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } glyphicons-halflings-regular.ttf  
          │   │   │   │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } glyphicons-halflings-regular.woff  
          │   │   │   │   └── :aetherx-axd-file:{ .icon-clr-tree-file } glyphicons-halflings-regular.woff2  
          │   │   │   └── :aetherx-axs-folder:{ .icon-clr-tree-folder } js  
          │   │   │        └── :aetherx-axd-file:{ .icon-clr-tree-file } bootstrap.min.js  
          │   │   ├── :aetherx-axb-css:{ .icon-clr-tree-file-css } bootstrap-chosen.css  
          │   │   ├── :aetherx-axb-css:{ .icon-clr-tree-file-css } chosen.min.css  
          │   │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } chosen.min.js  
          │   │   ├── :aetherx-axd-image:{ .icon-clr-tree-img } chosen-sprite@2x.png  
          │   │   ├── :aetherx-axd-image:{ .icon-clr-tree-img } chosen-sprite.png  
          │   │   ├── :aetherx-axb-css:{ .icon-clr-tree-file-css } configserver.css  
          │   │   ├── :aetherx-axd-image:{ .icon-clr-tree-img } csf-loader.gif  
          │   │   ├── :aetherx-axd-image:{ .icon-clr-tree-img } csf-logo-alt.svg  
          │   │   ├── :aetherx-axd-image:{ .icon-clr-tree-img } csf-logo.svg  
          │   │   ├── :aetherx-axd-image:{ .icon-clr-tree-img } csf_small.png  
          │   │   ├── :aetherx-axd-image:{ .icon-clr-tree-img } csf.svg  
          │   │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } jquery.min.js  
          │   │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } LICENSE.txt  
          │   │   ├── :aetherx-axd-image:{ .icon-clr-tree-img } loader.gif  
          │   │   └── :aetherx-axd-image:{ .icon-clr-tree-img } reseller_icon.svg  
          │   ├── :aetherx-axd-file-certificate:{ .icon-clr-tree-cert } server.crt  
          │   ├── :aetherx-axd-key:{ .icon-clr-tree-key } server.key  
          │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } ui.allow  
          │   └── :aetherx-axd-file:{ .icon-clr-tree-file } ui.ban  
          ├── :aetherx-axs-paperclip:{ .icon-clr-tree-symlink } uninstall.sh -> :aetherx-axd-file:{ .icon-clr-tree-file } /usr/local/csf/bin/uninstall.sh  
          ├── :aetherx-axd-file:{ .icon-clr-tree-file } version.txt  
          └── :aetherx-axs-paperclip:{ .icon-clr-tree-symlink } webmin -> :aetherx-axs-folder:{ .icon-clr-tree-folder } /usr/local/csf/lib/webmin
</code>
</div>

<br />

### :aetherx-axs-folder:{ .icon-clr-tree-folder } /usr/local/csf/

The files and subfolders of this path contain most of the functionality for CSF and LFD. For most scenarios, you should not need to modify any of the files here.

The one exception is the `tpl` subfolder, which contains all of the email alert templates. However, you can also find these within `/etc/csf/alerts`

<div class="icon-tree" markdown>
<code>
└── :aetherx-axs-folder:{ .icon-clr-tree-folder } usr  
    └── :aetherx-axs-folder:{ .icon-clr-tree-folder } local  
        └── :aetherx-axs-folder:{ .icon-clr-tree-folder } csf  
            ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } bin  
            │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } csfpre.sh  
            │   └── :aetherx-axd-file:{ .icon-clr-tree-file } csfpost.sh  
            │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } csftest.pl  
            │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } pt_deleted_action.pl  
            │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } regex.custom.pm  
            │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } remove_apf_bfd.sh  
            │   └── :aetherx-axd-file:{ .icon-clr-tree-file } uninstall.sh  
            ├── :aetherx-axs-file-zipper:{ .icon-clr-tree-file-archive } csfwebmin.tgz  
            ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } lib  
            │   ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } ConfigServer  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── AbuseIP.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── CheckIP.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── CloudFlare.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── Config.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── cseUI.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── DisplayResellerUI.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── DisplayUI.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── GetEthDev.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── GetIPs.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── KillSSH.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── Logger.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── LookUpIP.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── Messenger.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── Ports.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── RBLCheck.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── RBLLookup.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── RegexMain.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── Sanity.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── Sendmail.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── ServerCheck.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── ServerStats.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── Service.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── Slurp.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } └── URLGet.pm  
            │   ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } Crypt  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } ├── Blowfish_PP.pm  
            │   │   :aetherx-axd-file:{ .icon-clr-tree-file } └── CBC.pm  
            │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } csfajaxtail.js  
            │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.div  
            │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.help  
            │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.rbls  
            │   ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } HTTP  
            │   │   └── :aetherx-axd-file:{ .icon-clr-tree-file } Tiny.pm  
            │   ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } JSON  
            │   │   └── :aetherx-axd-file:{ .icon-clr-tree-file } Tiny.pm  
            │   ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } Net  
            │   │   ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } CIDR  
            │   │   │   └── :aetherx-axd-file:{ .icon-clr-tree-file } Lite.pm  
            │   │   └── :aetherx-axd-file:{ .icon-clr-tree-file } IP.pm  
            │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } restricted.txt  
            │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } sanity.txt  
            │   ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } version  
            │   │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } regex.pm  
            │   │   └── :aetherx-axd-file:{ .icon-clr-tree-file } vpp.pm  
            │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } version.pm  
            │   └── :aetherx-axs-folder:{ .icon-clr-tree-folder } webmin  
            │       └── :aetherx-axs-folder:{ .icon-clr-tree-folder } csf  
            │           ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } images  
            │           │   ├── :aetherx-axd-image:{ .icon-clr-tree-img } admin_icon.svg  
            │           │   ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } bootstrap  
            │           │   │   ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } css  
            │           │   │   │   ├── :aetherx-axb-css:{ .icon-clr-tree-file-css } bootstrap.min.css  
            │           │   │   │   └── :aetherx-axb-css:{ .icon-clr-tree-file-css } bootstrap.min.css.map  
            │           │   │   ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } fonts  
            │           │   │   │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } glyphicons-halflings-regular.eot  
            │           │   │   │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } glyphicons-halflings-regular.svg  
            │           │   │   │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } glyphicons-halflings-regular.ttf  
            │           │   │   │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } glyphicons-halflings-regular.woff  
            │           │   │   │   └── :aetherx-axd-file:{ .icon-clr-tree-file } glyphicons-halflings-regular.woff2  
            │           │   │   └── :aetherx-axs-folder:{ .icon-clr-tree-folder } js  
            │           │   │       └── :aetherx-axd-file:{ .icon-clr-tree-file } bootstrap.min.js  
            │           │   ├── :aetherx-axb-css:{ .icon-clr-tree-file-css } bootstrap-chosen.css  
            │           │   ├── :aetherx-axb-css:{ .icon-clr-tree-file-css } chosen.min.css  
            │           │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } chosen.min.js  
            │           │   ├── :aetherx-axd-image:{ .icon-clr-tree-img } chosen-sprite@2x.png  
            │           │   ├── :aetherx-axd-image:{ .icon-clr-tree-img } chosen-sprite.png  
            │           │   ├── :aetherx-axb-css:{ .icon-clr-tree-file-css } configserver.css  
            │           │   ├── :aetherx-axd-image:{ .icon-clr-tree-img } csf-loader.gif  
            │           │   ├── :aetherx-axd-image:{ .icon-clr-tree-img } csf-logo-alt.svg  
            │           │   ├── :aetherx-axd-image:{ .icon-clr-tree-img } csf-logo.svg  
            │           │   ├── :aetherx-axd-image:{ .icon-clr-tree-img } csf_small.png  
            │           │   ├── :aetherx-axd-image:{ .icon-clr-tree-img } csf.svg  
            │           │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } jquery.min.js  
            │           │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } LICENSE.txt  
            │           │   ├── :aetherx-axd-image:{ .icon-clr-tree-img } loader.gif  
            │           │   └── :aetherx-axd-image:{ .icon-clr-tree-img } reseller_icon.svg  
            │           ├── :aetherx-axd-file:{ .icon-clr-tree-file } index.cgi  
            │           └── :aetherx-axd-file:{ .icon-clr-tree-file } module.info  
            ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } profiles  
            │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } block_all_perm.conf  
            │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } block_all_temp.conf  
            │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } disable_alerts.conf  
            │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } protection_high.conf  
            │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } protection_low.conf  
            │   ├── :aetherx-axd-file:{ .icon-clr-tree-file } protection_medium.conf  
            │   └── :aetherx-axd-file:{ .icon-clr-tree-file } reset_to_defaults.conf  
            └── :aetherx-axs-folder:{ .icon-clr-tree-folder } tpl  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } accounttracking.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } alert.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } apache.https.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } apache.http.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } apache.main.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } connectiontracking.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } consolealert.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } cpanelalert.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } exploitalert.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } filealert.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } forkbombalert.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } integrityalert.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } litespeed.https.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } litespeed.http.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } litespeed.main.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } loadalert.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } logalert.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } logfloodalert.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } modsecipdbalert.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } netblock.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } permblock.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } portknocking.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } portscan.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } processtracking.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } queuealert.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } recaptcha.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } relayalert.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } resalert.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } reselleralert.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } scriptalert.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } sshalert.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } sualert.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } sudoalert.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } syslogalert.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } tracking.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } uialert.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } uidscan.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } usertracking.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } watchalert.txt  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } webminalert.txt  
                └── :aetherx-axd-file:{ .icon-clr-tree-file } x-arf.txt
</code>
</div>

<br />

### :aetherx-axs-folder:{ .icon-clr-tree-folder } /usr/local/include/csf/

This folder contains your own custom `pre` and `post` initialization scripts for CSF. These scripts control the execution of custom Bash scripts **before** and **after** CSF applies firewall rules to your IP tables. 

- Drop custom bash scripts in the `pre.d` folder if you want to modify your iptables **before** CSF injects its own rules into iptables.
- Drop custom bash scripts in the `post.d` folder if you want to modify your iptables **after** CSF injects its own rules into iptables.

<div class="icon-tree" markdown>
<code>
└── :aetherx-axs-folder:{ .icon-clr-tree-folder } usr  
    └── :aetherx-axs-folder:{ .icon-clr-tree-folder } local  
        └── :aetherx-axs-folder:{ .icon-clr-tree-folder } include  
            └── :aetherx-axs-folder:{ .icon-clr-tree-folder } csf  
                └── :aetherx-axs-folder:{ .icon-clr-tree-folder } pre.d  
                    └── :aetherx-axd-file:{ .icon-clr-tree-file } custom_script.sh  
                └── :aetherx-axs-folder:{ .icon-clr-tree-folder } post.d  
                    └── :aetherx-axd-file:{ .icon-clr-tree-file } custom_script.sh  
</code>
</div>

<br />

### :aetherx-axs-folder:{ .icon-clr-tree-folder } /var/lib/csf/

This folder contains your `csf.conf` backups and also stores files generated by the integrated statistics module, including charts. While backups can be accessed directly from the CSF web interface, this folder is primarily for internal use. You generally won’t need to interact with it, and it’s important not to modify any of the files stored here.

<div class="icon-tree" markdown>
<code>
└── :aetherx-axs-folder:{ .icon-clr-tree-folder } var  
    └── :aetherx-axs-folder:{ .icon-clr-tree-folder } lib  
        └── :aetherx-axs-folder:{ .icon-clr-tree-folder } csf  
            └── :aetherx-axs-folder:{ .icon-clr-tree-folder } backup  
            │   └── :aetherx-axd-file:{ .icon-clr-tree-file } 1759876810_pre_v15_01_upgrade  
            ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } Geo  
            ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } lock  
            │   └── :aetherx-axd-file:{ .icon-clr-tree-file } command.lock  
            ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } stats  
            ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } ui  
            ├── :aetherx-axs-folder:{ .icon-clr-tree-folder } webmin  
            └── :aetherx-axs-folder:{ .icon-clr-tree-folder } zone  
</code>
</div>

<br />

### :aetherx-axs-folder:{ .icon-clr-tree-folder } /usr/sbin/

The `/usr/sbin` folder contains the two most important files, which are the main CSF and LFD binary files. These files are responsible for how CSF and LFD behave and contain the core code.

<div class="icon-tree" markdown>
<code>
└── :aetherx-axs-folder:{ .icon-clr-tree-folder } user  
     └── :aetherx-axs-folder:{ .icon-clr-tree-folder } sbin  
          ├── :aetherx-axs-file-binary:{ .icon-clr-tree-file-binary } csf  
          └── :aetherx-axs-file-binary:{ .icon-clr-tree-file-binary } lfd  
</code>
</div>

<br />

### :aetherx-axs-folder:{ .icon-clr-tree-folder } /lib/systemd/system

The `/usr/sbin` folder contains the CSF and LFD services which are responsible for bringing the two servces online.

<div class="icon-tree" markdown>
<code>
└── :aetherx-axs-folder:{ .icon-clr-tree-folder } lib  
     └── :aetherx-axs-folder:{ .icon-clr-tree-folder } systemd  
         └── :aetherx-axs-folder:{ .icon-clr-tree-folder } system  
              ├── :aetherx-axd-file:{ .icon-clr-tree-file } csf.service  
              └── :aetherx-axd-file:{ .icon-clr-tree-file } lfd.service  
</code>
</div>

<br />

---

<br />

## Patcher Files

The following files are associated with the ConfigServer Firewall scripts located in this repo's `extras/scripts` folder. These scripts add special iptable rules so that CSF can communicate with Docker & OpenVPN.

| File                                        | Description                                                                                                     |
| ------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `/usr/local/csf/bin/csfpre.sh`              | Loader for **pre** scripts. Runs before CSF adds firewall rules.                                                |
| `/usr/local/csf/bin/csfpost.sh`             | Loader for **post** scripts. Runs after CSF adds firewall rules.                                                |
| `/usr/local/include/csf/post.d/docker.sh`   | Patch adds specific Docker network compatibility to CSF.                                                        |
| `/usr/local/include/csf/post.d/openvpn.sh`  | Patch adds specific OpenVPN rules to CSF to allow VPN connections.                                              |

<br />

---

<br />
