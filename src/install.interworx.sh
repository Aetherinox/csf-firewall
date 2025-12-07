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
#   @updated            10.25.2025
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

umask 0177


# #
#	Allow for execution from different relative directories
# #

case $0 in
    /*) script="$0" ;;                       # Absolute path
    *)  script="$(pwd)/$0" ;;                # Relative path
esac

# #
#	Find script directory
# #

script_dir=$(dirname "$script")

# #
#   Include global
# #

. "$script_dir/global.sh" ||
{
    echo "    Error: cannot source $script_dir/global.sh. Aborting." >&2
    exit 1
}

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
	cp -avf csf.interworx.conf /etc/csf/csf.conf
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
	cp -avf csf.interworx.allow /etc/csf/csf.allow
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
	cp -avf csf.interworx.ignore /etc/csf/csf.ignore
fi
if [ ! -e "/etc/csf/csf.pignore" ]; then
	cp -avf csf.interworx.pignore /etc/csf/csf.pignore
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
cp -avf uninstall.interworx.sh /usr/local/csf/bin/uninstall.sh
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

if [ -e "/usr/local/ispconfig/interface/web/csf/ispconfig_csf" ]; then
    rm -Rfv /usr/local/ispconfig/interface/web/csf/
fi

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

# #
#	Step › Cron › Csget
#	
#	Copy local file csget.pl to /etc/cron.daily/csget
#	Used for periodic automatic update checks
# #

prinp "${APP_NAME_SHORT:-CSF} > Installing Cron" \
       "This cron is responsible for periodic update checks between your workstation and the CSF update servers."

if [ -e "${CSF_CRON_CSGET_DEST}" ]; then
	info "    Skip copy. File ${bluel}${CSF_CRON_CSGET_DEST}${greym} already exists${greym}"
else
	info "    Copying ${bluel}csget.pl${greym} to ${bluel}${CSF_CRON_CSGET_DEST}${greym}"
	copi "${CSF_CRON_CSGET_SRC}" "${CSF_CRON_CSGET_DEST}"
	cwp_copy_status=$?

	if [ ${cwp_copy_status} -eq 0 ]; then
		count=$(ls -A "${CSF_CWP_PATH_DESIGN}" | wc -l)
		if [ "${count}" -gt 0 ]; then
			ok "    Successfully copied ${greenl}${CSF_CRON_CSGET_SRC}${greym} to folder ${greenl}${CSF_CRON_CSGET_DEST}${greym}"
		else
			warn "    Copy reported success but no files found in ${yellowl}${CSF_CRON_CSGET_DEST}${greym}"
		fi
	else
		error "    Failed to copy with status ${redl}${cwp_copy_status}${greym}"
	fi
fi

info "    Chmod ${bluel}0700${greym} on folder ${bluel}${CSF_CRON_CSGET_DEST}${greym}"
chmod 700 "${CSF_CRON_CSGET_DEST}"
info "    Chown ${bluel}${CSF_CHOWN_GENERAL}${greym} on file ${bluel}${CSF_CRON_CSGET_DEST}${greym}"
chown "${CSF_CHOWN_GENERAL}" "${CSF_CRON_CSGET_DEST}"
info "    Starting cron ${bluel}${CSF_CRON_CSGET_DEST}${greym}"
/etc/cron.daily/csget --nosleep

chmod -v 700 auto.interworx.pl
./auto.interworx.pl $OLDVERSION

if test `cat /proc/1/comm` = "systemd"
then
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

# #
#	Step > Permissions
# #

prinp "${APP_NAME_SHORT:-CSF} > File Permissions" \
       "This step ensures that your ${APP_NAME_SHORT:-CSF} files contain the correct folder and file permissions."

# #
#   List of directories to set ownership
# #

dirs="/etc/csf /var/lib/csf /usr/local/csf"

# #
#   List of individual files to set ownership
# #

files="/usr/sbin/csf /usr/sbin/lfd /etc/logrotate.d/lfd /etc/cron.d/csf-cron /etc/cron.d/lfd-cron /usr/local/man/man1/csf.1 /usr/lib/systemd/system/lfd.service /usr/lib/systemd/system/csf.service /etc/init.d/lfd /etc/init.d/csf"

# #
#   Set ownership for directories
# #

CSF_CHOWN_GENERAL="root:root"

for dir in $dirs; do
    if [ -d "$dir" ]; then
        chown -Rf "${CSF_CHOWN_GENERAL}" "$dir"
		ok "    Set ownership ${greenl}${CSF_CHOWN_GENERAL}${greym} for folder ${bluel}${dir}${greym}"
    else
		warn "    Could not set ownership ${yellowl}${CSF_CHOWN_GENERAL}${greym}; folder does not exist: ${yellowl}${dir}${greym}"
    fi
done

# #
#   Set ownership for individual files
# #

for file in $files; do
    if [ -e "$file" ]; then
        chown -f "${CSF_CHOWN_GENERAL}" "$file"
		ok "    Set ownership ${greenl}${CSF_CHOWN_GENERAL}${greym} for file ${bluel}${file}${greym}"
    else
		warn "    Could not set ownership ${yellowl}${CSF_CHOWN_GENERAL}${greym}; file does not exist: ${yellowl}${file}${greym}"
    fi
done

mkdir -v -m 0600 /usr/local/interworx/plugins/configservercsf /usr/local/interworx/html/configserver
chmod -v 0711 /usr/local/interworx/html/configserver
cp -avf interworx/* /usr/local/interworx/plugins/configservercsf
cp -avf csf /usr/local/interworx/html/configserver/
chown -R iworx:iworx /usr/local/interworx/plugins/configservercsf /usr/local/interworx/html/configserver
find /usr/local/interworx/plugins/configservercsf -type d -exec chmod -v 700 {} \;
find /usr/local/interworx/plugins/configservercsf -type f -exec chmod -v 600 {} \;
/usr/local/interworx/bin/nodeworx.pex -u --controller Plugins --action edit --plugin_name configservercsf --status 1 -n

if [ -e "/usr/local/interworx/include/Ctrl/Nodeworx/Firewall.php.orig" ]; then
    mv /usr/local/interworx/include/Ctrl/Nodeworx/Firewall.php.orig /usr/local/interworx/include/Ctrl/Nodeworx/Firewall.php 
    chown iworx:iworx /usr/local/interworx/include/Ctrl/Nodeworx/Firewall.php
    chmod 600 /usr/local/interworx/include/Ctrl/Nodeworx/Firewall.php
fi

chattr -ia /etc/apf/apf
if [ -e "/etc/apf/apf.old" ]; then
    cp -avf apf_stub.pl /etc/apf/apf
else
    mv /etc/apf/apf /etc/apf/apf.old
    cp -avf apf_stub.pl /etc/apf/apf
fi
chmod 750 /etc/apf/apf

# #
#	Step > Webmin
#		- create tarball of webmin files
#		- Detect /usr/share/webmin
#		- Extract tarball to /usr/share/webmin/csf
# #

prinp "${APP_NAME_SHORT:-CSF} > Webmin" \
       "We will now check your system and see if Webmin integration needs enabled."

cd "${CSF_WEBMIN_SRC}"
tar -czf "${CSF_WEBMIN_TARBALL}" ./*
if [ -f "$CSF_WEBMIN_TARBALL" ]; then
    ok "    Created ${greenl}$CSF_WEBMIN_TARBALL"
else
    error "    Failed to create ${redl}$CSF_WEBMIN_TARBALL"
fi

ln -sf "${CSF_WEBMIN_TARBALL}" "${CSF_ETC}/"
if [ -L "${CSF_WEBMIN_SYMBOLIC}" ] && [ -f "${CSF_WEBMIN_SYMBOLIC}" ]; then
	ok "    Created symbolic link ${greenl}${CSF_WEBMIN_SYMBOLIC}"
else
    error "    Failed to create symbolic link ${redl}${CSF_WEBMIN_SYMBOLIC}"
fi

# #
#   Copy Webmin files if destination exists
# #

if [ -d "${CSF_WEBMIN_HOME}" ]; then
    mkdir -p "$CSF_WEBMIN_DESC"                     		# Ensure destination exists
	cp -a csf/* "$CSF_WEBMIN_DESC"/							# Copy all files from current folder
	ok "    CSF Webmin module installed to ${greenl}${CSF_WEBMIN_DESC}${greym}"
else
    echo "Directory ${CSF_WEBMIN_HOME} does not exist. Skipping copy."
	error "    Webmin home folder ${redl}${CSF_WEBMIN_HOME}${greym} does not exist; skipping Webmin install"
fi

# #
#	Webmin > Install CSF to webmin.acl
#	This is what makes CSF appear in Webmin menu
# #

if [ -f "$CSF_WEBMIN_FILE_ACL" ]; then

	# #
	#	Get Webmin connection info
	# #

	WEBMIN_CONF="/etc/webmin/miniserv.conf"

	# #
	#	fetch webmin port and protocol
	# #

	if grep '^ssl=' "$WEBMIN_CONF" | cut -d= -f2 | grep -q '^1$'; then
		WEBMIN_PROTO="https"
	else
		WEBMIN_PROTO="http"
	fi

	WEBMIN_PORT=$(grep '^port=' "$WEBMIN_CONF" | cut -d= -f2)

	# #
	#   Check if 'csf' is already listed for root
	# #

	if grep -Eq "^${CSF_WEBMIN_ACL_USER}:.*\b${CSF_WEBMIN_ACL_MODULE}\b" "$CSF_WEBMIN_FILE_ACL"; then
		info "    CSF Webmin module already registered in ${bluel}${CSF_WEBMIN_FILE_ACL}${greym}"
		print

		print "   Webmin already contains ${APP_NAME_SHORT:-CSF} module"
		print "   "
		print "   To access ${APP_NAME_SHORT:-CSF}, open your browser and navigate to"
		print "       ${yellowd}${WEBMIN_PROTO}://${SERVER_HOST}:${WEBMIN_PORT}/"
		print "   "
		print "   On the left-side menu, navigate to ${yellowd}System ${greym} > ${yellowd}${APP_NAME:-ConfigServer Security & Firewall}"
	else
		CSF_WEBMIN_TEMP=$(mktemp)
		awk -v user="$CSF_WEBMIN_ACL_USER" -v mod="$CSF_WEBMIN_ACL_MODULE" '
			BEGIN {found=0}
			$0 ~ "^"user":" {
				$0 = $0 " " mod
				found=1
			}
			{print}
			END {
				if (found == 0) {
					print user ": " mod
				}
			}
		' "$CSF_WEBMIN_FILE_ACL" > "$CSF_WEBMIN_TEMP" && mv "$CSF_WEBMIN_TEMP" "$CSF_WEBMIN_FILE_ACL"

		ok "    Added CSF Webmin module installed to ${greenl}${CSF_WEBMIN_FILE_ACL}${greym}"
		print
	
		print "   CSF has been integrated into Webmin"
		print "   "
		print "   To access ${APP_NAME_SHORT:-CSF}, open your browser and navigate to"
		print "       ${yellowd}${WEBMIN_PROTO}://${SERVER_HOST}:${WEBMIN_PORT}/"
		print "   "
		print "   On the left-side menu, navigate to ${yellowd}System ${greym} > ${yellowd}${APP_NAME:-ConfigServer Security & Firewall}"
	fi
else
	info "    CSF Webmin skipped; could not find ${bluel}${CSF_WEBMIN_FILE_ACL}${greym}"
fi

# #
#	Step > csf.conf Modified Settings
#   
#   SYSLOG_LOG          By default, RHEL systems use /var/log/messages
#                       Debian systems use /var/log/syslog
#	
#	IPTABLES_LOG		The same as SYSLOG_LOG
# #

prinp "${APP_NAME_SHORT:-CSF} > Customize csf.config" \
       "This step will check which Linux distribution family you are running, RHEL (Red Hat) or a Debian-based system. This determines what your default " \
	   "logging paths will be."

# #
#   Detect system log file path
# #

SYSLOG_PATH=""

if [ -f /var/log/syslog ]; then
    SYSLOG_PATH="/var/log/syslog"
elif [ -f /var/log/messages ]; then
    SYSLOG_PATH="/var/log/messages"
else
    SYSLOG_PATH="/dev/null"
fi

# #
#   Update SYSLOG_LOG and IPTABLES_LOG defaults
#   
#   Only change these values during installation.
#   Users can manually edit csf.conf later, and those
#   settings will not be overridden by updates.
# #

for KEY in SYSLOG_LOG IPTABLES_LOG; do
    if grep -qE "^${KEY}" "${CSF_CONF}"; then
        # Update existing line
        sed -i "s|^${KEY}.*|${KEY} = \"${SYSLOG_PATH}\"|" "${CSF_CONF}"
		ok "    Updating ${greenl}${CSF_CONF}${greym} setting ${fuchsial}${KEY}=${white}\"${bluel}${SYSLOG_PATH}${white}\"${greym}"
    else
        # Append if missing
        echo "${KEY} = \"${SYSLOG_PATH}\"" >> "${CSF_CONF}"
		ok "    Appending ${greenl}${CSF_CONF}${greym} setting ${fuchsial}${KEY}=${white}\"${bluel}${SYSLOG_PATH}${white}\"${greym}"
    fi
done

# #
#	Check current value of
#		TESTING="0"
# #

TESTING_VALUE=$(grep '^[[:space:]]*TESTING[[:space:]]*=' "$CSF_CONF" | awk -F= '{gsub(/ /,"",$2); print $2}' | tr -d '"')

prinp "${APP_NAME_SHORT:-CSF} > Installation Complete" \
       "Your installation is complete. Read important notes below."

print "    For more information on how to use ${APP_NAME_SHORT:-CSF}; visit"
print "        ${yellowd}${APP_LINK_DOCS:-https://docs.configserver.dev}"
if [ -f "$CSF_CONF" ]; then
	print "    "
	print "    The next step in the process should be to open the config file located at"
	print "        ${yellowd}${CSF_CONF}"
	if [ "$TESTING_VALUE" = "1" ]; then
	print "    "
	print "    The setting ${yellowd}TESTING${greym} is currently ${greenl}enabled${greym}; you should open your config and"
	print "    disable this setting before to you begin using your new firewall."
	print "    To disable this setting, open ${yellowd}${CSF_CONF}${greym} and set the following:"
	print "        ${fuchsial}TESTING = ${white}\"${bluel}0${white}\"${greym}"
	else
	print "    "
	print "    The setting ${yellowd}TESTING${greym} is currently ${redl}disabled${greym}; which is the"
	print "    correct setting if you plan to start using your firewall."
	fi
else
	print "    "
	print "    An error has occured; we cannot locate your ${APP_NAME_SHORT:-CSF} config file:"
	print "        ${yellowd}${CSF_CONF}"
	print "    "
	print "    You must have a valid config in the correct location before ${APP_NAME_SHORT:-CSF} will"
	print "    function properly."
fi
print
print "    After editing or adding a new ${yellowd}${CSF_CONF}${greym}, restart ${APP_NAME_SHORT:-CSF} with:"
print "        ${yellowd}sudo csf -ra"
print
print
