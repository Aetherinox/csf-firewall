#!/bin/sh
# #
#   @app                ConfigServer Firewall & Security (CSF)
#                       Login Failure Daemon (LFD)
#   @website            https://configserver.dev
#   @docs               https://docs.configserver.dev
#   @download           https://download.configserver.dev
#   @repo               https://github.com/Aetherinox/csf-firewall
#   @copyright          Copyright (C) 2025-2026 Aetherinox
#                       Copyright (C) 2006-2025 Jonathan Michaelson
#                       Copyright (C) 2006-2025 Way to the Web Ltd.
#   @license            GPLv3
#   @updated            10.23.2025
#   
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 3 of the License, or (at
#   your option) any later version.
#   
#   This program is distributed in the hope that it will be useful, but
#   WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#   General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, see <https://www.gnu.org/licenses>.
# #

# #
#	v15.02
#	
#	Cyberpanel has opted to replace ConfigServer with their own in-house firewall.
#	However, for users who wish to return to CSF; we will give them a solution
# #

umask 0177

if [ -e "/usr/local/cpanel/version" ]; then
	echo "Running csf cPanel installer"
	echo
	sh install.cpanel.sh
	exit 0
elif [ -e "/usr/local/directadmin/directadmin" ]; then
	echo "Running csf DirectAdmin installer"
	echo
	sh install.directadmin.sh
	exit 0
fi

echo "Installing csf and lfd"
echo

echo "Check we're running as root"
if [ ! `id -u` = 0 ]; then
	echo
	echo "FAILED: You have to be logged in as root (UID:0) to install csf"
	exit
fi
echo

mkdir -v -m 0600 /etc/csf
cp -avf install.txt /etc/csf/

echo "Checking Perl modules..."
chmod 700 os.pl
RETURN=`./os.pl`
if [ "$RETURN" = 1 ]; then
	echo
	echo "FAILED: You MUST install the missing perl modules above before you can install csf. See /etc/csf/install.txt for installation details."
    echo
	exit
else
    echo "...Perl modules OK"
    echo
fi

mkdir -v -m 0600 /etc/csf
mkdir -v -m 0600 /var/lib/csf
mkdir -v -m 0600 /var/lib/csf/backup
mkdir -v -m 0600 /var/lib/csf/Geo
mkdir -v -m 0600 /var/lib/csf/ui
mkdir -v -m 0600 /var/lib/csf/stats
mkdir -v -m 0600 /var/lib/csf/lock
mkdir -v -m 0600 /var/lib/csf/webmin
mkdir -v -m 0600 /var/lib/csf/zone
mkdir -v -m 0600 /usr/local/csf
mkdir -v -m 0600 /usr/local/csf/bin
mkdir -v -m 0600 /usr/local/csf/lib
mkdir -v -m 0600 /usr/local/csf/tpl

if [ -e "/etc/csf/alert.txt" ]; then
	sh migratedata.sh
fi

if [ ! -e "/etc/csf/csf.conf" ]; then
	cp -avf csf.cyberpanel.conf /etc/csf/csf.conf
fi

if [ ! -d /var/lib/csf ]; then
	mkdir -v -p -m 0600 /var/lib/csf
fi
if [ ! -d /usr/local/csf/lib ]; then
	mkdir -v -p -m 0600 /usr/local/csf/lib
fi
if [ ! -d /usr/local/csf/bin ]; then
	mkdir -v -p -m 0600 /usr/local/csf/bin
fi
if [ ! -d /usr/local/csf/tpl ]; then
	mkdir -v -p -m 0600 /usr/local/csf/tpl
fi

if [ ! -e "/etc/csf/csf.allow" ]; then
	cp -avf csf.cyberpanel.allow /etc/csf/csf.allow
fi
if [ ! -e "/etc/csf/csf.deny" ]; then
	cp -avf csf.deny /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.redirect" ]; then
	cp -avf csf.redirect /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.resellers" ]; then
	cp -avf csf.resellers /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.dirwatch" ]; then
	cp -avf csf.dirwatch /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.syslogs" ]; then
	cp -avf csf.syslogs /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.logfiles" ]; then
	cp -avf csf.logfiles /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.logignore" ]; then
	cp -avf csf.logignore /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.blocklists" ]; then
	cp -avf csf.blocklists /etc/csf/.
else
	cp -avf csf.blocklists /etc/csf/csf.blocklists.new
fi
if [ ! -e "/etc/csf/csf.ignore" ]; then
	cp -avf csf.cyberpanel.ignore /etc/csf/csf.ignore
fi
if [ ! -e "/etc/csf/csf.pignore" ]; then
	cp -avf csf.cyberpanel.pignore /etc/csf/csf.pignore
fi
if [ ! -e "/etc/csf/csf.rignore" ]; then
	cp -avf csf.rignore /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.fignore" ]; then
	cp -avf csf.fignore /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.signore" ]; then
	cp -avf csf.signore /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.suignore" ]; then
	cp -avf csf.suignore /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.uidignore" ]; then
	cp -avf csf.uidignore /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.mignore" ]; then
	cp -avf csf.mignore /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.sips" ]; then
	cp -avf csf.sips /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.dyndns" ]; then
	cp -avf csf.dyndns /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.syslogusers" ]; then
	cp -avf csf.syslogusers /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.smtpauth" ]; then
	cp -avf csf.smtpauth /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.rblconf" ]; then
	cp -avf csf.rblconf /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.cloudflare" ]; then
	cp -avf csf.cloudflare /etc/csf/.
fi

if [ ! -e "/usr/local/csf/tpl/alert.txt" ]; then
	cp -avf alert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/reselleralert.txt" ]; then
	cp -avf reselleralert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/logalert.txt" ]; then
	cp -avf logalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/logfloodalert.txt" ]; then
	cp -avf logfloodalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/syslogalert.txt" ]; then
	cp -avf syslogalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/integrityalert.txt" ]; then
	cp -avf integrityalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/exploitalert.txt" ]; then
	cp -avf exploitalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/queuealert.txt" ]; then
	cp -avf queuealert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/modsecipdbalert.txt" ]; then
	cp -avf modsecipdbalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/tracking.txt" ]; then
	cp -avf tracking.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/connectiontracking.txt" ]; then
	cp -avf connectiontracking.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/processtracking.txt" ]; then
	cp -avf processtracking.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/accounttracking.txt" ]; then
	cp -avf accounttracking.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/usertracking.txt" ]; then
	cp -avf usertracking.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/sshalert.txt" ]; then
	cp -avf sshalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/webminalert.txt" ]; then
	cp -avf webminalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/sualert.txt" ]; then
	cp -avf sualert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/sudoalert.txt" ]; then
	cp -avf sudoalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/consolealert.txt" ]; then
	cp -avf consolealert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/uialert.txt" ]; then
	cp -avf uialert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/cpanelalert.txt" ]; then
	cp -avf cpanelalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/scriptalert.txt" ]; then
	cp -avf scriptalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/relayalert.txt" ]; then
	cp -avf relayalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/filealert.txt" ]; then
	cp -avf filealert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/watchalert.txt" ]; then
	cp -avf watchalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/loadalert.txt" ]; then
	cp -avf loadalert.txt /usr/local/csf/tpl/.
else
	cp -avf loadalert.txt /usr/local/csf/tpl/loadalert.txt.new
fi
if [ ! -e "/usr/local/csf/tpl/resalert.txt" ]; then
	cp -avf resalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/portscan.txt" ]; then
	cp -avf portscan.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/uidscan.txt" ]; then
	cp -avf uidscan.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/permblock.txt" ]; then
	cp -avf permblock.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/netblock.txt" ]; then
	cp -avf netblock.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/portknocking.txt" ]; then
	cp -avf portknocking.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/forkbombalert.txt" ]; then
	cp -avf forkbombalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/recaptcha.txt" ]; then
	cp -avf recaptcha.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/apache.main.txt" ]; then
	cp -avf apache.main.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/apache.http.txt" ]; then
	cp -avf apache.http.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/apache.https.txt" ]; then
	cp -avf apache.https.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/litespeed.main.txt" ]; then
	cp -avf litespeed.main.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/litespeed.http.txt" ]; then
	cp -avf litespeed.http.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/litespeed.https.txt" ]; then
	cp -avf litespeed.https.txt /usr/local/csf/tpl/.
fi
cp -avf x-arf.txt /usr/local/csf/tpl/.

# #
#	Only creates pre and post autoloader if it doesn't exist in either location
# #

if [ ! -e "/usr/local/csf/bin/csfpre.sh" ] && [ ! -e "/etc/csf/csfpre.sh" ]; then
	echo "No existing csfpre.sh found — installing a fresh copy..."
    cp -avf csfpre.sh /usr/local/csf/bin/.
else
    echo "csfpre.sh already exists in one of the valid locations — skipping copy."
fi

if [ ! -e "/usr/local/csf/bin/csfpost.sh" ] && [ ! -e "/etc/csf/csfpost.sh" ]; then
	echo "No existing csfpost.sh found — installing a fresh copy..."
    cp -avf csfpost.sh /usr/local/csf/bin/.
else
    echo "csfpost.sh already exists in one of the valid locations — skipping copy."
fi

if [ ! -e "/usr/local/csf/bin/regex.custom.pm" ]; then
	cp -avf regex.custom.pm /usr/local/csf/bin/.
fi
if [ ! -e "/usr/local/csf/bin/pt_deleted_action.pl" ]; then
	cp -avf pt_deleted_action.pl /usr/local/csf/bin/.
fi
if [ ! -e "/etc/csf/messenger" ]; then
	cp -avf messenger /etc/csf/.
fi
if [ ! -e "/etc/csf/messenger/index.recaptcha.html" ]; then
	cp -avf messenger/index.recaptcha.html /etc/csf/messenger/.
fi
if [ ! -e "/etc/csf/ui" ]; then
	cp -avf ui /etc/csf/.
fi
if [ -e "/etc/cron.d/csfcron.sh" ]; then
	mv -fv /etc/cron.d/csfcron.sh /etc/cron.d/csf-cron
fi
if [ ! -e "/etc/cron.d/csf-cron" ]; then
	cp -avf csfcron.sh /etc/cron.d/csf-cron
fi
if [ -e "/etc/cron.d/lfdcron.sh" ]; then
	mv -fv /etc/cron.d/lfdcron.sh /etc/cron.d/lfd-cron
fi
if [ ! -e "/etc/cron.d/lfd-cron" ]; then
	cp -avf lfdcron.sh /etc/cron.d/lfd-cron
fi
sed -i "s%/etc/init.d/lfd restart%/usr/sbin/csf --lfd restart%" /etc/cron.d/lfd-cron
if [ -e "/usr/local/csf/bin/servercheck.pm" ]; then
	rm -f /usr/local/csf/bin/servercheck.pm
fi
if [ -e "/etc/csf/cseui.pl" ]; then
	rm -f /etc/csf/cseui.pl
fi
if [ -e "/etc/csf/csfui.pl" ]; then
	rm -f /etc/csf/csfui.pl
fi
if [ -e "/etc/csf/csfuir.pl" ]; then
	rm -f /etc/csf/csfuir.pl
fi
if [ -e "/usr/local/csf/bin/cseui.pl" ]; then
	rm -f /usr/local/csf/bin/cseui.pl
fi
if [ -e "/usr/local/csf/bin/csfui.pl" ]; then
	rm -f /usr/local/csf/bin/csfui.pl
fi
if [ -e "/usr/local/csf/bin/csfuir.pl" ]; then
	rm -f /usr/local/csf/bin/csfuir.pl
fi
if [ -e "/usr/local/csf/bin/regex.pm" ]; then
	rm -f /usr/local/csf/bin/regex.pm
fi

OLDVERSION=0
if [ -e "/etc/csf/version.txt" ]; then
    OLDVERSION=`head -n 1 /etc/csf/version.txt`
fi

rm -f /etc/csf/csf.pl /usr/sbin/csf /etc/csf/lfd.pl /usr/sbin/lfd
chmod 700 csf.pl lfd.pl
cp -avf csf.pl /usr/sbin/csf
cp -avf lfd.pl /usr/sbin/lfd
chmod 700 /usr/sbin/csf /usr/sbin/lfd
ln -svf /usr/sbin/csf /etc/csf/csf.pl
ln -svf /usr/sbin/lfd /etc/csf/lfd.pl
ln -svf /usr/local/csf/bin/csftest.pl /etc/csf/
ln -svf /usr/local/csf/bin/pt_deleted_action.pl /etc/csf/
ln -svf /usr/local/csf/bin/remove_apf_bfd.sh /etc/csf/
ln -svf /usr/local/csf/bin/uninstall.sh /etc/csf/
ln -svf /usr/local/csf/bin/regex.custom.pm /etc/csf/
ln -svf /usr/local/csf/lib/webmin /etc/csf/
if [ ! -e "/etc/csf/alerts" ]; then
    ln -svf /usr/local/csf/tpl /etc/csf/alerts
fi
chcon -h system_u:object_r:bin_t:s0 /usr/sbin/lfd
chcon -h system_u:object_r:bin_t:s0 /usr/sbin/csf

mkdir webmin/csf/images
mkdir ui/images
mkdir da/images
mkdir interworx/images

cp -avf csf/* webmin/csf/images/
cp -avf csf/* ui/images/
cp -avf csf/* da/images/
cp -avf csf/* interworx/images/

cp -avf messenger/*.php /etc/csf/messenger/
cp -avf uninstall.cyberpanel.sh /usr/local/csf/bin/uninstall.sh
cp -avf csftest.pl /usr/local/csf/bin/
cp -avf remove_apf_bfd.sh /usr/local/csf/bin/
cp -avf readme.txt /etc/csf/
cp -avf sanity.txt /usr/local/csf/lib/
cp -avf csf.rbls /usr/local/csf/lib/
cp -avf restricted.txt /usr/local/csf/lib/
cp -avf changelog.txt /etc/csf/
cp -avf downloadservers /etc/csf/
cp -avf install.txt /etc/csf/
cp -avf version.txt /etc/csf/
cp -avf license.txt /etc/csf/
cp -avf webmin /usr/local/csf/lib/
cp -avf ConfigServer /usr/local/csf/lib/
cp -avf Net /usr/local/csf/lib/
cp -avf Geo /usr/local/csf/lib/
cp -avf Crypt /usr/local/csf/lib/
cp -avf HTTP /usr/local/csf/lib/
cp -avf JSON /usr/local/csf/lib/
cp -avf version/* /usr/local/csf/lib/
cp -avf csf.div /usr/local/csf/lib/
cp -avf csfajaxtail.js /usr/local/csf/lib/
cp -avf ui/images /etc/csf/ui/.
cp -avf profiles /usr/local/csf/
cp -avf csf.conf /usr/local/csf/profiles/reset_to_defaults.conf
cp -avf lfd.logrotate /etc/logrotate.d/lfd
chcon --reference /etc/logrotate.d /etc/logrotate.d/lfd
cp -avf apf_stub.pl /etc/csf/

rm -fv /etc/csf/csf.spamhaus /etc/csf/csf.dshield /etc/csf/csf.tor /etc/csf/csf.bogon

mkdir -p /usr/local/man/man1/
cp -avf csf.1.txt /usr/local/man/man1/csf.1
cp -avf csf.help /usr/local/csf/lib/
chmod 755 /usr/local/man/
chmod 755 /usr/local/man/man1/
chmod 644 /usr/local/man/man1/csf.1

chmod -R 600 /etc/csf
chmod -R 600 /var/lib/csf
chmod -R 600 /usr/local/csf/bin
chmod -R 600 /usr/local/csf/lib
chmod -R 600 /usr/local/csf/tpl
chmod -R 600 /usr/local/csf/profiles
chmod 600 /var/log/lfd.log*

chmod -v 700 /usr/local/csf/bin/*.pl /usr/local/csf/bin/*.sh /usr/local/csf/bin/*.pm
chmod -v 700 /etc/csf/*.pl /etc/csf/*.cgi /etc/csf/*.sh /etc/csf/*.php /etc/csf/*.py
chmod -v 700 /etc/csf/webmin/csf/index.cgi
chmod -v 644 /etc/cron.d/lfd-cron
chmod -v 644 /etc/cron.d/csf-cron

cp -avf csget.pl /etc/cron.daily/csget
chmod 700 /etc/cron.daily/csget
/etc/cron.daily/csget --nosleep

chmod -v 700 auto.cyberpanel.pl
./auto.cyberpanel.pl $OLDVERSION

if test `cat /proc/1/comm` = "systemd"; then
    if [ -e /etc/init.d/lfd ]; then
        if [ -f /etc/redhat-release ]; then
            /sbin/chkconfig csf off
            /sbin/chkconfig lfd off
            /sbin/chkconfig csf --del
            /sbin/chkconfig lfd --del
        elif [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
            update-rc.d -f lfd remove
            update-rc.d -f csf remove
        elif [ -f /etc/gentoo-release ]; then
            rc-update del lfd default
            rc-update del csf default
        elif [ -f /etc/slackware-version ]; then
            rm -vf /etc/rc.d/rc3.d/S80csf
            rm -vf /etc/rc.d/rc4.d/S80csf
            rm -vf /etc/rc.d/rc5.d/S80csf
            rm -vf /etc/rc.d/rc3.d/S85lfd
            rm -vf /etc/rc.d/rc4.d/S85lfd
            rm -vf /etc/rc.d/rc5.d/S85lfd
        else
            /sbin/chkconfig csf off
            /sbin/chkconfig lfd off
            /sbin/chkconfig csf --del
            /sbin/chkconfig lfd --del
        fi
        rm -fv /etc/init.d/csf
        rm -fv /etc/init.d/lfd
    fi

    mkdir -p /etc/systemd/system/
    mkdir -p /usr/lib/systemd/system/
    cp -avf lfd.service /usr/lib/systemd/system/
    cp -avf csf.service /usr/lib/systemd/system/

    chcon -h system_u:object_r:systemd_unit_file_t:s0 /usr/lib/systemd/system/lfd.service
    chcon -h system_u:object_r:systemd_unit_file_t:s0 /usr/lib/systemd/system/csf.service

    systemctl daemon-reload

    systemctl enable csf.service
    systemctl enable lfd.service

    systemctl disable firewalld
    systemctl stop firewalld
    systemctl mask firewalld
else
    cp -avf lfd.sh /etc/init.d/lfd
    cp -avf csf.sh /etc/init.d/csf
    chmod -v 755 /etc/init.d/lfd
    chmod -v 755 /etc/init.d/csf

    if [ -f /etc/redhat-release ]; then
        /sbin/chkconfig lfd on
        /sbin/chkconfig csf on
    elif [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
        update-rc.d -f lfd remove
        update-rc.d -f csf remove
        update-rc.d lfd defaults 80 20
        update-rc.d csf defaults 20 80
    elif [ -f /etc/gentoo-release ]; then
        rc-update add lfd default
        rc-update add csf default
    elif [ -f /etc/slackware-version ]; then
        ln -svf /etc/init.d/csf /etc/rc.d/rc3.d/S80csf
        ln -svf /etc/init.d/csf /etc/rc.d/rc4.d/S80csf
        ln -svf /etc/init.d/csf /etc/rc.d/rc5.d/S80csf
        ln -svf /etc/init.d/lfd /etc/rc.d/rc3.d/S85lfd
        ln -svf /etc/init.d/lfd /etc/rc.d/rc4.d/S85lfd
        ln -svf /etc/init.d/lfd /etc/rc.d/rc5.d/S85lfd
    else
        /sbin/chkconfig lfd on
        /sbin/chkconfig csf on
    fi
fi

chown -Rf root:root /etc/csf /var/lib/csf /usr/local/csf
chown -f root:root /usr/sbin/csf /usr/sbin/lfd /etc/logrotate.d/lfd /etc/cron.d/csf-cron /etc/cron.d/lfd-cron /usr/local/man/man1/csf.1 /usr/lib/systemd/system/lfd.service /usr/lib/systemd/system/csf.service /etc/init.d/lfd /etc/init.d/csf

mkdir -vp /usr/local/CyberCP/public/static/configservercsf/
cp -avf csf/* /usr/local/CyberCP/public/static/configservercsf/
cp -avf csf/* cyberpanel/configservercsf/static/configservercsf/
chmod 755 /usr/local/CyberCP/public/static/configservercsf/

cp cyberpanel/cyberpanel.pl /usr/local/csf/bin/
chmod 700 /usr/local/csf/bin/cyberpanel.pl
cp -avf cyberpanel/configservercsf /usr/local/CyberCP/

mkdir /home/cyberpanel/plugins
touch /home/cyberpanel/plugins/configservercsf

# #
#	Cyberpanel Structure Reference
#		
#	stat -c "%n %U:%G %a" /usr/local/CyberCP/CyberCP/*
#		/usr/local/CyberCP/CyberCP/__init__.py 			root:root 		644
#		/usr/local/CyberCP/CyberCP/__pycache__ 			root:root 		755
#		/usr/local/CyberCP/CyberCP/secMiddleware.py 	root:root 		644
#		/usr/local/CyberCP/CyberCP/SecurityLevel.py 	root:root 		644
#		/usr/local/CyberCP/CyberCP/settings.py 			root:cyberpanel 640
#		/usr/local/CyberCP/CyberCP/urls.py 				root:root 		644
#		/usr/local/CyberCP/CyberCP/wsgi.py 				root:root 		644
# #

# #
#	Open
#		/usr/local/CyberCP/CyberCP/settings.py
#	
#	Find
#		'pluginHolder',
#	
#	Add Above
#		'configservercsf',
#	
#	
#	@target			/usr/local/CyberCP/CyberCP/settings.py
#	@perms			root:cyberpanel 640
# #

SETTINGSPY_FILE="/usr/local/CyberCP/CyberCP/settings.py"
if [ -f "$SETTINGSPY_FILE" ]; then
    if ! grep "configservercsf" "$SETTINGSPY_FILE" >/dev/null 2>&1; then
        SETTINGSPY_TEMP="/tmp/settings.py.$$"
        i=1

		# #
        #	Ensure temp file does not collide
		# #

        while [ -e "$SETTINGSPY_TEMP" ]; do
            SETTINGSPY_TEMP="/tmp/settings.py.$$.$i"
            i=$((i + 1))
        done

		# #
        #	Store original file permission + owner:group to restore after patched
		#		settings.py requires root:cyberpanel 0640
		# #

        if stat --version >/dev/null 2>&1; then
            # GNU stat (Linux)
            FILE_MODE=$(stat -c %a "$SETTINGSPY_FILE")
            FILE_OWNER=$(stat -c %u "$SETTINGSPY_FILE")
            FILE_GROUP=$(stat -c %g "$SETTINGSPY_FILE")
        else
            # BSD/macOS stat
            FILE_MODE=$(stat -f %Lp "$SETTINGSPY_FILE")
            FILE_OWNER=$(stat -f %u "$SETTINGSPY_FILE")
            FILE_GROUP=$(stat -f %g "$SETTINGSPY_FILE")
        fi

        trap 'rm -f "$SETTINGSPY_TEMP"' EXIT INT TERM

		# #
        #	Insert 'configservercsf' above pluginHolder
		# #

        sed "/pluginHolder/ i \
    \ \ \ \ 'configservercsf'," "$SETTINGSPY_FILE" > "$SETTINGSPY_TEMP" \
            && mv "$SETTINGSPY_TEMP" "$SETTINGSPY_FILE" \
            && chown "$FILE_OWNER:$FILE_GROUP" "$SETTINGSPY_FILE" \
            && chmod "$FILE_MODE" "$SETTINGSPY_FILE"

        echo "  CSF [CyberPanel]: Add configservercsf above pluginHolder in $SETTINGSPY_FILE"
        trap - EXIT INT TERM
    else
        echo "  CSF [CyberPanel]: Skip configservercsf above pluginHolder in $SETTINGSPY_FILE"
    fi
fi

# #
#	Open
#		/usr/local/CyberCP/CyberCP/urls.py
#	
#	Find
#		path('plugins/', include('pluginHolder.urls')),
#	
#	Add Above
#		path('configservercsf/',include('configservercsf.urls')),
#	
#	@target			/usr/local/CyberCP/CyberCP/urls.py
#	@perms			root:root 644
# #

URLSPY_FILE="/usr/local/CyberCP/CyberCP/urls.py"
if [ -f "$URLSPY_FILE" ]; then
    if ! grep "configservercsf" "$URLSPY_FILE" >/dev/null 2>&1; then
        URLSPY_TEMP="/tmp/urls.py.$$"
        i=1

		# #
        #	Ensure temp file does not collide
		# #

        while [ -e "$URLSPY_TEMP" ]; do
            URLSPY_TEMP="/tmp/urls.py.$$.$i"
            i=$((i + 1))
        done

		# #
        #	Store original file permission to restore after patched
		# #

        if stat --version >/dev/null 2>&1; then
            FILE_MODE=$(stat -c %a "$URLSPY_FILE")		# GNU stat
        else
            FILE_MODE=$(stat -f %Lp "$URLSPY_FILE")		# BSD/macOS stat
        fi

        trap 'rm -f "$URLSPY_TEMP"' EXIT INT TERM

		# #
        #	Insert the CSF URL above pluginHolder
		# #

        sed "/pluginHolder/ i \
    \ \ \ \ path('configservercsf/',include('configservercsf.urls'))," \
            "$URLSPY_FILE" > "$URLSPY_TEMP" \
            && mv "$URLSPY_TEMP" "$URLSPY_FILE" \
            && chmod "$FILE_MODE" "$URLSPY_FILE"

        echo "  CSF [CyberPanel]: Add configservercsf.urls above pluginHolder.urls in $URLSPY_FILE"
        trap - EXIT INT TERM
    else
        echo "  CSF [CyberPanel]: Skip configservercsf.urls above pluginHolder.urls in $URLSPY_FILE"
    fi
fi

# #
#	if ! cat /usr/local/CyberCP/baseTemplate/templates/baseTemplate/index.html | grep -q configservercsf; then
#   	sed -i "/url 'csf'/ i <li><a href='/configservercsf/' title='ConfigServer Security and Firewall'><span>ConfigServer Security \&amp; Firewall</span></a></li>" /usr/local/CyberCP/baseTemplate/templates/baseTemplate/index.html
#	fi
# #

# #
#	This is for older versions of Cyberpanel, not needed in newer releases.
#	
#   Open:
#       /usr/local/CyberCP/baseTemplate/templates/baseTemplate/index.html
#	
#   Find:
#       <a href="#" title="{% trans 'Plugins' %}">
#	
#   Insert New (above it):
#       {% include "/usr/local/CyberCP/configservercsf/templates/configservercsf/menu.html" %}
#	
#	@target			/usr/local/CyberCP/baseTemplate/templates/baseTemplate/index.html
#	@perms			root:root 644
# #

BASEINDEX_FILE="/usr/local/CyberCP/baseTemplate/templates/baseTemplate/index.html"
if [ -f "$BASEINDEX_FILE" ]; then
    if ! grep "configserver" "$BASEINDEX_FILE" >/dev/null 2>&1; then
        BASEINDEX_TEMP="/tmp/index.html.$$"
        i=1

		# #
        #	Ensure temp file does not collide
		# #

        while [ -e "$BASEINDEX_TEMP" ]; do
            BASEINDEX_TEMP="/tmp/index.html.$$.$i"
            i=$((i + 1))
        done

		# #
        #	Store original file permission to restore after patched
		# #

        if stat --version >/dev/null 2>&1; then
            FILE_MODE=$(stat -c %a "$BASEINDEX_FILE")		# GNU stat
        else
            FILE_MODE=$(stat -f %Lp "$BASEINDEX_FILE")		# BSD/macOS stat
        fi

        trap 'rm -f "$BASEINDEX_TEMP"' EXIT INT TERM

		# #
        #	Insert the CSF menu include above the Plugins line
		# #

        sed "/trans 'Plugins'/ i \
\{\% include \"/usr/local/CyberCP/configservercsf/templates/configservercsf/menu.html\" \%\}" \
            "$BASEINDEX_FILE" > "$BASEINDEX_TEMP" \
            && mv "$BASEINDEX_TEMP" "$BASEINDEX_FILE" \
            && chmod "$FILE_MODE" "$BASEINDEX_FILE"

        echo "  CSF [CyberPanel]: Add legacy csf menu include in $BASEINDEX_FILE"
        trap - EXIT INT TERM
    else
        echo "  CSF [CyberPanel]: Skip legacy csf menu include - already present in ($BASEINDEX_FILE)"
    fi
else
    echo "  CSF [CyberPanel]: Skip legacy csf menu include - file not found ($BASEINDEX_FILE)"
fi

# #
#	Open
#		/usr/local/CyberCP/baseTemplate/templates/baseTemplate/index.html
#	
#	Find
#		<a href="{% url 'imunify' %}" class="menu-item">
#			<span>Imunify 360</span>
#		</a>
#	
#	Add Above
#		<a href="{% url 'configservercsf' %}" class="menu-item">
#			<span>CSF</span>
#		</a>
#	
#	@target			/usr/local/CyberCP/baseTemplate/templates/baseTemplate/index.html
#	@perms			root:root 644
#	@todo			Make POSIX compliant
# #

if ! grep -q "configservercsf" /usr/local/CyberCP/baseTemplate/templates/baseTemplate/index.html; then
	sed -i '/url '\''imunify'\''/ i \
				<a href="{% url '\''configservercsf'\'' %}" class="menu-item">\
					<span>CSF</span>\
				</a>' /usr/local/CyberCP/baseTemplate/templates/baseTemplate/index.html
fi

# #
#	Cyberpanel > Backardards Compatibility > path to url
#	
#	In Django 2.x+, URL routing switched from the old url() function to the newer path().
#	which means older versions of Cyberpabel require url().
#	
#	Check the target file to see if we need to convert back to the old url() method.
#	
#	Change
#		from django.urls import path
#	
#	To
#		from django.conf.urls import url
#	
#	@target			/usr/local/CyberCP/CyberCP/urls.py
#	@perms			root:root 644
#	@todo			Make POSIX compliant
# #

if grep -q "import url" /usr/local/CyberCP/CyberCP/urls.py; then
    sed -i \
        -e "s/from django\.urls import path/from django.conf.urls import url/g" \
        -e "s|path('', views.configservercsf, name='configservercsf')|url(r'^$', views.configservercsf, name='configservercsf')|g" \
        -e "s|path('iframe', views.configservercsfiframe, name='configservercsfiframe')|url(r'^iframe/$', views.configservercsfiframe, name='configservercsfiframe')|g" \
        -e "s/path(/url(/g" \
        /usr/local/CyberCP/CyberCP/urls.py

    echo "  CSF [CyberPanel]: Add Backwards Compaibility - path() => url()"
else
    echo "  CSF [CyberPanel]: Skip Backwards Compaibility - using path()"
fi

# #
#	Saving form on "Firewall Configuration" page will toss the following error:
#		{"error_message": "Data supplied is not accepted, following characters are not allowed in the input ` $ & ( ) [ ] { } ; : 
#			\u2018 < >.", "errorMessage": "Data supplied is not accepted, following characters are not allowed in the input ` $ & ( ) [ ] { } ; : \u2018 < >."}
#	
#	Around 07/25, Cyberpabel removed path "configservercsf" from whitelisted path.
#	Manually re-add exception.
#	
#	Adds:
#                   if not isAPIEndpoint and valueAlreadyChecked == 0:
#	
#                       if 'configservercsf' in pathActual:
#                           continue
#	
#	@target			/usr/local/CyberCP/CyberCP/secMiddleware.py
#	@perms			root:root 644
# #

SECMID_FILE="/usr/local/CyberCP/CyberCP/secMiddleware.py"
SECMID_TARGET_IF="if not isAPIEndpoint and valueAlreadyChecked == 0:"
BYPASS_LINE="                        if 'configservercsf' in pathActual:"
BYPASS_CONT="                            continue"

if [ -f "$SECMID_FILE" ]; then
    printf '\n'
    printf '  CSF [CyberPanel]: Start secMiddleware.py - security exception...\n'

	# #
    #	Skip if exception already present
	# #

    if grep "if 'configservercsf' in pathActual" "$SECMID_FILE" >/dev/null 2>&1; then
        printf '  CSF [CyberPanel]: Skip secMiddleware.py - security exception already present\n'
    else
		# #
		#	Backup
		# #

		SECMID_BACKUP="${SECMID_FILE}.bak.$$"
		cp -p "$SECMID_FILE" "$SECMID_BACKUP" ||
		{
			printf '  CSF [CyberPanel]: Fail secMiddleware.py - cannot create backup %s\n' "$SECMID_BACKUP"
			exit 1
		}

        SECMID_TEMP="${SECMID_FILE}.tmp.$$"
        i=1

        while [ -e "$SECMID_TEMP" ]; do
            SECMID_TEMP="${SECMID_FILE}.tmp.$$.$i"
            i=$((i + 1))
        done

		# #
        #	Store original file permission to restore after patched
		# #

        if stat --version >/dev/null 2>&1; then
            FILE_MODE=$(stat -c %a "$SECMID_FILE")		# GNU stat
        else
            FILE_MODE=$(stat -f %Lp "$SECMID_FILE")		# BSD/macOS stat
        fi

        trap 'rm -f "$SECMID_TEMP"' EXIT INT TERM

		# #
        #	Insert bypass after every target line
		# #

        while IFS= read -r line || [ -n "$line" ]; do
            printf '%s\n' "$line" >>"$SECMID_TEMP"

            case "$line" in
                *"$SECMID_TARGET_IF"*)
                    printf '%s\n' '' >>"$SECMID_TEMP"
                    printf '%s\n' "$BYPASS_LINE" >>"$SECMID_TEMP"
                    printf '%s\n' "$BYPASS_CONT" >>"$SECMID_TEMP"
                    printf '%s\n' '' >>"$SECMID_TEMP"
                    ;;
            esac
        done <"$SECMID_FILE"

        if cp -p "$SECMID_TEMP" "$SECMID_FILE"; then

			# #
            #	Restore original permissions
			# #

            chmod "$FILE_MODE" "$SECMID_FILE"
            printf '  CSF [CyberPanel]: Add secMiddleware.py - exception after every occurrence of %s.\n' "'$SECMID_TARGET_IF'"
        else
            printf '  CSF [CyberPanel]: Fail secMiddleware.py - cannot write patched file — restoring backup.\n'
            cp -p "$SECMID_BACKUP" "$SECMID_FILE" >/dev/null 2>&1 || true
            exit 1
        fi

        trap - EXIT INT TERM
        rm -f "$SECMID_TEMP"
    fi
else
    printf '  CSF [CyberPanel]: Skip secMiddleware.py  -- target file not found (%s)\n' "$SECMID_FILE"
fi

# #
#	restart services
# #

service lscpd restart
service lsws restart

echo
echo "Installation Completed"
echo