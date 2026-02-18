#!/bin/sh
# #
#   @app                ConfigServer Security & Firewall (CSF)
#                       Login Failure Daemon (LFD)
#   @website            https://configserver.dev
#   @docs               https://docs.configserver.dev
#   @download           https://download.configserver.dev
#   @repo               https://github.com/Aetherinox/csf-firewall
#   @copyright          Copyright (C) 2025-2026 Aetherinox
#                       Copyright (C) 2006-2025 Jonathan Michaelson
#                       Copyright (C) 2006-2025 Way to the Web Ltd.
#   @license            GPLv3
#   @updated            02.12.2026
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

script_dir=$(dirname "${script}")

# #
#   Include global
# #

. "$script_dir/global.sh" ||
{
    echo "    Error: cannot source ${script_dir}/global.sh. Aborting." >&2
    exit 1
}

# #
#   Fetch installer arguments
# #

ARG_SCRIPT="${1:-install.generic.sh}"
ARG_PANEL="${2:-Generic}"

# #
#	Global Variables
# #

argDryrun="${argDryrun:-false}"
dr="$argDryrun"

# #
#	Start Install
# #

prinp "${APP_NAME_SHORT:-CSF} > Starting Installation" \
       "This script will now install ${yellowl}${APP_NAME}${greyd} on your server. \
If you experience issues during installation, make note of any error messages below, \
and report them to the developer on our official repository. \
${greyd}\n\n${greym}Script: 	${greyd}..........${yellowl} ${ARG_SCRIPT}${greyd} \
${greyd}\n${greym}Installer:	${greyd}.......${yellowl} ${yellowl}${ARG_PANEL}${greyd} \
${greyd}\n${greym}Version:  	${greyd}.........${yellowl} ${yellowl}v${APP_VERSION}${greyd} \
${greyd}\n${greym}Path: 	${greyd}............${yellowl} ${script_dir}${greyd} \
${greyd}\n${greym}PWD: 	${greyd}.............${yellowl} ${PWD}${greyd} \
${greyd}\n${greym}Website:  	${greyd}.........${yellowl} ${yellowl}${APP_REPO}${greyd} \
${greyd}\n${greym}Discord:  	${greyd}.........${yellowl} ${yellowl}${APP_LINK_DISCORD}${greyd}"

# #
#	Check if any other panels are installed first
# #

if [ -e "/usr/local/cpanel/version" ]; then
	info "    Detected ${bluel}cPanel${greym} on this workstation; running installer ${greym}"
	echo
	sh "install.cpanel.sh" "${ARG_SCRIPT}" "${ARG_PANEL}"
	exit 0
elif [ -e "/usr/local/directadmin/directadmin" ]; then
	info "    Detected ${bluel}DirectAdmin${greym} on this workstation; running installer ${greym}"
	echo
	sh "install.directadmin.sh" "${ARG_SCRIPT}" "${ARG_PANEL}"
	exit 0
fi

# #
#	Require Root
# #

info "    Starting installation of ${bluel}CSF${greym} and ${bluel}LFD${greym}. Checking current user ..."
if [ ! `id -u` = 0 ]; then
	print
	error "    FAILURE: You must use the ${redl}root${greym} account (UID:0) to install CSF"
	print
	exit 1
else
	ok "    Success. You are running this install script with user account ${greenl}root${greym}"
fi

# #
#	Require install.sh file
# #

if [ ! -e "install.sh" ]; then
	print
	error "    FAILURE: Could not find ${redl}install.sh${greym}; must abort"
	print
	exit 1
fi

# #
#	Create Directory › /etc/csf/
# #

if [ ! -d "${CSF_ETC}" ]; then
    run mkdir -v -m 0600 "${CSF_ETC}"
	info "    Creating folder ${bluel}${CSF_ETC}${greym} with chown ${bluel}0600${greym}"

    if [ -d "${CSF_ETC}" ]; then
		ok "    Created folder ${greenl}${CSF_ETC}${greym}"
    else
		error "    Failed to create folder ${redl}${CSF_ETC}"
    fi
else
	info "    Folder already exists ${bluel}${CSF_ETC}${greym}; skipping creation${greym}"
fi

# #
#	Copy › install.txt
# #

info "    Copy file ${bluel}install.txt${greym}"
run copi "install.txt" "${CSF_ETC}"

# #
#	Check › Perl Modules Installed
#	
#	Some users will place the CSF temp files in /tmp, which typically has noexec. Resulting
#	in a "permission denied". Force os.pl to run under perl.
#		mount | grep ' /tmp '
#		findmnt /tmp
# #

info "    Checking ${bluel}Perl${greym} modules"
run chmod 700 os.pl
if [ "$dr" = "false" ]; then
	RETURN=$(perl ./os.pl)
	if [ "$RETURN" = "1" ]; then
		print
		error "    FAILURE: You MUST install the missing perl modules above before you can install csf. ${redl}root${greym} account (UID:0) to install CSF"
		label "     See ${redl}/etc/csf/install.txt${greyd} for installation details."
		print
		exit 1
	else
		ok "    Status of all Perl modules are ${greenl}OK${greym}"
	fi
fi

# #
#	Create Main Structure
# #

dirs="
${CSF_ETC}
${CSF_VAR}
${CSF_VAR}/backup
${CSF_VAR}/Geo
${CSF_VAR}/ui
${CSF_VAR}/stats
${CSF_VAR}/lock
${CSF_VAR}/webmin
${CSF_VAR}/zone
${CSF_USR}
${CSF_USR}/bin
${CSF_USR}/lib
${CSF_USR}/tpl
"

for d in $dirs; do
    if [ -d "$d" ]; then
		info "    Skip mkdir. Folder already exists ${bluel}${d}${greym}"
    else
		info "    Creating and setting permissions ${bluel}600${greym} on folder ${bluel}${d}${greym}"
        run mkdir -p "$d"
        if [ $? -eq 0 ]; then
            run chmod 600 "$d"
            if [ $? -eq 0 ]; then
				ok "    Successfully created folder and set permission ${bluel}600${greym} on ${greenl}${d}${greym}"
            else
				error "    Failed to set permission ${bluel}600${greym} on folder ${redl}${d}${greym}"
            fi
        else
			error "    Failed to create folder ${redl}${d}${greym}"
        fi
    fi
done

# #
#	Manage CSF Specific Files
# #

if [ -e "/etc/csf/alert.txt" ]; then
	run sh migratedata.sh
fi

# #
#	Copy › Main CSF Config
#	
#	csf.conf						cPanel
#	csf.generic.conf				Generic
#	csf.interworx.conf				Interworx
#	csf.directadmin.conf			DirectAdmin
#	csf.cyberpanel.conf				CyberPanel
#	csf.vesta.conf					Vesta
#	csf.cwp.conf					Control Web Panel
# #

if [ "$dr" = "false" ]; then
	if [ ! -e "/etc/csf/csf.conf" ]; then
		cp -avf csf.generic.conf /etc/csf/csf.conf
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
		cp -avf csf.generic.allow /etc/csf/csf.allow
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
		cp -avf csf.generic.ignore /etc/csf/csf.ignore
	fi
	if [ ! -e "/etc/csf/csf.pignore" ]; then
		cp -avf csf.generic.pignore /etc/csf/csf.pignore
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
fi

OLDVERSION=0
if [ -e "/etc/csf/version.txt" ]; then
    OLDVERSION=`head -n 1 /etc/csf/version.txt`
fi

if [ "$dr" = "false" ]; then
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
	cp -avf uninstall.generic.sh /usr/local/csf/bin/uninstall.sh
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
fi

# #
#	Pre & Post Loader
#	
#	Script storage locations for pre and post loaders that can be added by users.
# #

fileLoaderPre="Not Found"
fileLoaderPost="Not Found"
pathLoaderPre="Not Found"
pathLoaderPost="Not Found"

# Search for csfpre.sh
for p in /usr/local/csf/bin/csfpre.sh /etc/csf/csfpre.sh; do
    if [ -e "$p" ]; then
        fileLoaderPre="$p"
        pathLoaderPre=$(dirname "$p")
        break
    fi
done

# Search for csfpost.sh
for p in /usr/local/csf/bin/csfpost.sh /etc/csf/csfpost.sh; do
    if [ -e "$p" ]; then
        fileLoaderPost="$p"
        pathLoaderPost=$(dirname "$p")
        break
    fi
done

prinp "${APP_NAME_SHORT:-CSF} > Setup Pre & Post Loader" \
       "The ${yellowl}pre${greyd} and ${yellowl}post${greyd} loader files allow you \
to integrate your own custom bash scripts into ${APP_NAME_SHORT:-CSF}. These loaders activate at two different times: \
${greyd}\n\n${blued}Pre Loader Path: 	${greyd}......${yellowl} ${pathLoaderPre}${greyd} \
${greyd}\n${greym}Place scripts in this folder you want to load ${bold}${greenl}before${end}${greym} ${APP_NAME_SHORT:-CSF} imports firewall rules.${greyd} \
${greyd}\n\n${blued}Post Loader Path:	${greyd}.....${yellowl} ${pathLoaderPost}${greyd} \
${greyd}\n${greym}Place scripts in this folder you want to load ${bold}${greenl}after${end}${greym} ${APP_NAME_SHORT:-CSF} imports firewall rules.${greyd}"

# #
#	Only creates pre and post autoloader if it doesn't exist in either location
# #

if [ ! -e "/usr/local/csf/bin/csfpre.sh" ] && [ ! -e "/etc/csf/csfpre.sh" ]; then
	info "    No existing file ${bluel}csfpre.sh${greym}; copying"
	run copi "csfpre.sh" "/usr/local/csf/bin/"
else
	ok "    File ${greenl}/usr/local/csf/bin/csfpre.sh${greym} already exists in valid location"
fi

if [ ! -e "/usr/local/csf/bin/csfpost.sh" ] && [ ! -e "/etc/csf/csfpost.sh" ]; then
	info "    No existing file ${bluel}csfpost.sh${greym}; copying"
	run copi "csfpost.sh" "/usr/local/csf/bin/"
else
	ok "    File ${greenl}/usr/local/csf/bin/csfpost.sh${greym} already exists in valid location"
fi

if [ -e "/usr/local/ispconfig/interface/web/csf/ispconfig_csf" ]; then
    run rm -Rfv /usr/local/ispconfig/interface/web/csf/
fi

# #
#	Step › Spamhaus, Man Pages, Permissions
# #

if [ "$dr" = "false" ]; then
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
fi

# #
#	Step › Cron › Csget
#	
#	Copy local file csget.pl to /etc/cron.daily/csget
#	Used for periodic automatic update checks
# #

prinp "${APP_NAME_SHORT:-CSF} > Installing CSGet Cron Service" \
       "This cron is responsible for periodic update checks between your workstation and the CSF update servers."

# #
#   Check if cron file exists and whether it differs from source
# #

if [ -e "${CSF_CRON_CSGET_DEST}" ]; then

    # #
    #   File exists; compare with source
    # #

    if cmp -s "${CSF_CRON_CSGET_SRC}" "${CSF_CRON_CSGET_DEST}"; then
        info "    Skip copy. File ${bluel}${CSF_CRON_CSGET_DEST}${greym} already exists and is identical"
    else
        info "    Updating ${bluel}${CSF_CRON_CSGET_DEST}${greym} (file differs from source)"
        run copi "${CSF_CRON_CSGET_SRC}" "${CSF_CRON_CSGET_DEST}"
        cwp_copy_status=$?

        if [ "${cwp_copy_status}" -eq 0 ]; then
            ok "    Successfully updated ${greenl}${CSF_CRON_CSGET_DEST}${greym}"
        else
            error "    Failed to update with status ${redl}${cwp_copy_status}${greym}"
        fi
    fi
else

    # #
    #   File does not exist ⇒ copy new file
    # #

    info "    Copying ${bluel}${CSF_CRON_CSGET_SRC}${greym} to ${bluel}${CSF_CRON_CSGET_DEST}${greym}"
    run copi "${CSF_CRON_CSGET_SRC}" "${CSF_CRON_CSGET_DEST}"
    cwp_copy_status=$?

    if [ "${cwp_copy_status}" -eq 0 ]; then
        ok "    Successfully copied ${greenl}${CSF_CRON_CSGET_SRC}${greym} to ${greenl}${CSF_CRON_CSGET_DEST}${greym}"
    else
        error "    Failed to copy with status ${redl}${cwp_copy_status}${greym}"
    fi
fi

info "    Chmod ${bluel}0700${greym} on folder ${bluel}${CSF_CRON_CSGET_DEST}${greym}"
run chmod 700 "${CSF_CRON_CSGET_DEST}"
info "    Chown ${bluel}${CSF_CHOWN_GENERAL}${greym} on file ${bluel}${CSF_CRON_CSGET_DEST}${greym}"
run chown "${CSF_CHOWN_GENERAL}" "${CSF_CRON_CSGET_DEST}"
info "    Starting cron ${bluel}${CSF_CRON_CSGET_DEST}${greym}"
run "$CSF_CRON_CSGET_DEST" --nodaemon --response
CSF_CRON_CSGET_STATUS=$?

if [ "$CSF_CRON_CSGET_STATUS" -eq 0 ]; then
    ok "    CSGET daemon ${greenl}${CSF_CRON_CSGET_DEST}${greym} successfully ran"
else
    warn "    CSGET daemon ${yellowl}${CSF_CRON_CSGET_DEST}${greym} failed to run"
fi

if [ -f "${CSF_CRON_CSGET_LOG}" ]; then
	ok "    CSGET daemon successfully generated log ${greenl}${CSF_CRON_CSGET_LOG}${greym}"
else
    warn "    CSGET daemon did not generated log ${yellowl}${CSF_CRON_CSGET_LOG}${greym}${greym}"
fi

# #
#	Step › Auto Migration
# #

prinp "${APP_NAME_SHORT:-CSF} > Automatic Settings Migration" \
       "We will now check your original config file and see if you are missing any settings that may be new and not added yet."

if [ -f "./${CSF_AUTO_GENERIC}" ]; then
    info "    Found ${bluel}${CSF_AUTO_GENERIC}${greym}; applying chmod 0700"
    run chmod -v 700 "./${CSF_AUTO_GENERIC}"

    if [ -x "./${CSF_AUTO_GENERIC}" ]; then
        info "    Running ${bluel}${CSF_AUTO_GENERIC}${greym} with version ${bluel}${OLDVERSION}${greym}"
        run "./${CSF_AUTO_GENERIC}" "${OLDVERSION}"
    else
        error "    File exists but is not executable: ${redl}${CSF_AUTO_GENERIC}${greym}"
    fi
else
    error "    File not found: ${redl}${CSF_AUTO_GENERIC}${greym}"
fi

# #
#	Systemd & SysV Init
# #

prinp "${APP_NAME_SHORT:-CSF} > Systemd & SysV Init Setup" \
       "Detecting init system (systemd or SysV Init)"

# #
#	Check systemd assigned to PID 1
# #

detectSys="Unknown"
if test `cat /proc/1/comm` = "systemd"; then
	ok "    Found PID 1 assigned to ${greenl}systemd${greym}"
    if [ -e /etc/init.d/lfd ]; then
		ok "    Found ${greenl}/etc/init.d/lfd${greym}"

		# #
		#	/etc/redhat-release			RHEL / Alma / Rocky / CentOS
		#	/etc/debian_version			Debian
		#	/etc/lsb-release			Ubuntu & derivatives
		#	/etc/gentoo-release			Gentoo
		#	/etc/slackware-version		Slackware
		# #

        if [ -f /etc/redhat-release ]; then
			detectSys="/etc/redhat-release"
            run /sbin/chkconfig csf off
            run /sbin/chkconfig lfd off
            run /sbin/chkconfig csf --del
            run /sbin/chkconfig lfd --del
        elif [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
			if [ -f /etc/debian_version ]; then
				detectSys="/etc/debian_version"
			elif [ -f /etc/lsb-release ]; then
				detectSys="/etc/lsb-release"
			fi
            run update-rc.d -f lfd remove
            run update-rc.d -f csf remove
        elif [ -f /etc/gentoo-release ]; then
			detectSys="/etc/gentoo-release"
            run rc-update del lfd default
            run rc-update del csf default
        elif [ -f /etc/slackware-version ]; then
			detectSys="/etc/slackware-version"
            run rm -vf /etc/rc.d/rc3.d/S80csf
            run rm -vf /etc/rc.d/rc4.d/S80csf
            run rm -vf /etc/rc.d/rc5.d/S80csf
            run rm -vf /etc/rc.d/rc3.d/S85lfd
            run rm -vf /etc/rc.d/rc4.d/S85lfd
            run rm -vf /etc/rc.d/rc5.d/S85lfd
        else
			detectSys="Other"
            run /sbin/chkconfig csf off
            run /sbin/chkconfig lfd off
            run /sbin/chkconfig csf --del
            run /sbin/chkconfig lfd --del
        fi

		ok "    Detected ${greenl}${detectSys}${greym}"

        run rm -fv /etc/init.d/csf
        run rm -fv /etc/init.d/lfd
	else
		info "    Did not detect ${bluel}/etc/init.d/lfd${greym}; skipping${greym}"
    fi

	# #
	#	/etc/systemd/system/
	# #

	pathEtcSystemdSystem="/etc/systemd/system/"
	if [ ! -d "${pathEtcSystemdSystem}" ]; then
		run mkdir -p "${pathEtcSystemdSystem}"
		info "    Creating folder ${bluel}${pathEtcSystemdSystem}${greym}"

		if [ -d "${pathEtcSystemdSystem}" ]; then
			ok "    Created folder ${greenl}${pathEtcSystemdSystem}${greym}"
		else
			error "    Failed to create folder ${redl}${pathEtcSystemdSystem}"
		fi
	else
		info "    Folder already exists ${bluel}${pathEtcSystemdSystem}${greym}; skipping creation${greym}"
	fi

	# #
	#	/usr/lib/systemd/system/
	# #

	pathUsrLibSystemdSystem="/usr/lib/systemd/system/"
	if [ ! -d "${pathUsrLibSystemdSystem}" ]; then
		run mkdir -p "${pathUsrLibSystemdSystem}"
		info "    Creating folder ${bluel}${pathUsrLibSystemdSystem}${greym}"

		if [ -d "${pathUsrLibSystemdSystem}" ]; then
			ok "    Created folder ${greenl}${pathUsrLibSystemdSystem}${greym}"
		else
			error "    Failed to create folder ${redl}${pathUsrLibSystemdSystem}"
		fi
	else
		info "    Folder already exists ${bluel}${pathUsrLibSystemdSystem}${greym}; skipping creation${greym}"
	fi

	run copi "lfd.service" "/usr/lib/systemd/system/"
	run copi "csf.service" "/usr/lib/systemd/system/"

	# #
	#   Fix SELinux context on systemd unit files
	#   Required for RHEL-based systems so systemd can load them
	# #

    run chcon -h system_u:object_r:systemd_unit_file_t:s0 /usr/lib/systemd/system/lfd.service
    run chcon -h system_u:object_r:systemd_unit_file_t:s0 /usr/lib/systemd/system/csf.service

	# #
	#	Reload daemon
	# #

	info "    Running systemctl ${bluel}daemon-reload${greym}"
    run systemctl daemon-reload

	# #
	#	Enable csf / lfd services
	#	Disable firewalld
	# #

	info "    Enabling systemctl services ${bluel}csf.service${greym} and ${bluel}lfd.service${greym}"
    run systemctl enable csf.service
    run systemctl enable lfd.service

	info "    Disabling systemctl service ${bluel}firewalld${greym}"
    run systemctl disable firewalld
    run systemctl stop firewalld
    run systemctl mask firewalld
else
	ok "    Systemd not found in PID 1; Using ${greenl}SysV Init${greym}"

	info "    Copying system services ${bluel}/etc/init.d/${greym}"
	run copi "lfd.sh" "/etc/init.d/lfd"
	run copi "csf.sh" "/etc/init.d/csf"

	info "    Chmod ${bluel}0755${greym} on file ${bluel}/etc/init.d/lfd${greym}"
    run chmod -v 755 /etc/init.d/lfd

	info "    Chmod ${bluel}0755${greym} on file ${bluel}/etc/init.d/csf${greym}"
    run chmod -v 755 /etc/init.d/csf

    if [ -f /etc/redhat-release ]; then
		detectSys="/etc/redhat-release"
        run /sbin/chkconfig lfd on
        run /sbin/chkconfig csf on
    elif [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
		if [ -f /etc/debian_version ]; then
			detectSys="/etc/debian_version"
		elif [ -f /etc/lsb-release ]; then
			detectSys="/etc/lsb-release"
		fi
        run update-rc.d -f lfd remove
        run update-rc.d -f csf remove
        run update-rc.d lfd defaults 80 20
        run update-rc.d csf defaults 20 80
    elif [ -f /etc/gentoo-release ]; then
		detectSys="/etc/gentoo-release"
        run rc-update add lfd default
        run rc-update add csf default
    elif [ -f /etc/slackware-version ]; then
		detectSys="/etc/slackware-version"
        run ln -svf /etc/init.d/csf /etc/rc.d/rc3.d/S80csf
        run ln -svf /etc/init.d/csf /etc/rc.d/rc4.d/S80csf
        run ln -svf /etc/init.d/csf /etc/rc.d/rc5.d/S80csf
        run ln -svf /etc/init.d/lfd /etc/rc.d/rc3.d/S85lfd
        run ln -svf /etc/init.d/lfd /etc/rc.d/rc4.d/S85lfd
        run ln -svf /etc/init.d/lfd /etc/rc.d/rc5.d/S85lfd
    else
		detectSys="Other"
        run /sbin/chkconfig lfd on
        run /sbin/chkconfig csf on
    fi

	ok "    Detected ${greenl}${detectSys}${greym}"
fi

# #
#	Step › Permissions
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

for dir in $dirs; do
    if [ -d "$dir" ]; then
        run chown -Rf "${CSF_CHOWN_GENERAL}" "$dir"
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
        run chown -f "${CSF_CHOWN_GENERAL}" "$file"
		ok "    Set ownership ${greenl}${CSF_CHOWN_GENERAL}${greym} for file ${bluel}${file}${greym}"
    else
		warn "    Could not set ownership ${yellowl}${CSF_CHOWN_GENERAL}${greym}; file does not exist: ${yellowl}${file}${greym}"
    fi
done

# #
#	@app			Webmin
#	@desc			› create tarball of webmin files
#					› Detect /usr/share/webmin
#					› Extract tarball to /usr/share/webmin/csf
# #

prinp "${APP_NAME_SHORT:-CSF} > Webmin Integration" \
       "We will now check your system and see if Webmin integration needs enabled."

cd "${CSF_WEBMIN_SRC}"
run tar -czf "${CSF_WEBMIN_TARBALL}" ./*
if [ -f "$CSF_WEBMIN_TARBALL" ]; then
    ok "    Created ${greenl}$CSF_WEBMIN_TARBALL"
else
    error "    Failed to create ${redl}$CSF_WEBMIN_TARBALL"
fi

run ln -sf "${CSF_WEBMIN_TARBALL}" "${CSF_ETC}/"
if [ -L "${CSF_WEBMIN_SYMBOLIC}" ] && [ -f "${CSF_WEBMIN_SYMBOLIC}" ]; then
	ok "    Created symbolic link ${greenl}${CSF_WEBMIN_SYMBOLIC}"
else
    error "    Failed to create symbolic link ${redl}${CSF_WEBMIN_SYMBOLIC}"
fi

# #
#	@app			Webmin
#   @desc			Copy Webmin files if destination exists
#						/usr/share/webmin			Debian, Ubuntu, ZorinOS
#						/usr/libexec/webmin			AlmaLinux, Redhat, Rocky 10
# #

if [ -d "${CSF_WEBMIN_SHARE_HOME}" ]; then
    run mkdir -p "$CSF_WEBMIN_SHARE_DEST"                     			# Ensure destination exists
	run cp -a csf/* "$CSF_WEBMIN_SHARE_DEST"/							# Copy all files from current folder
	ok "    CSF Webmin module installed to ${greenl}${CSF_WEBMIN_SHARE_DEST}${greym}"
else
	warn "    Webmin home folder ${yellowl}${CSF_WEBMIN_SHARE_HOME}${greym} does not exist; trying alternative"
fi

if [ -d "${CSF_WEBMIN_LIBEXEC_HOME}" ]; then
    run mkdir -p "$CSF_WEBMIN_LIBEXEC_DEST"                     		# Ensure destination exists
	run cp -a csf/* "$CSF_WEBMIN_LIBEXEC_DEST"/							# Copy all files from current folder
	ok "    CSF Webmin module installed to ${greenl}${CSF_WEBMIN_LIBEXEC_DEST}${greym}"
else
	error "    Webmin home folder ${redl}${CSF_WEBMIN_LIBEXEC_HOME}${greym} does not exist; skipping Webmin install"
fi

# #
#	@app			Webmin
#	@desc			Install CSF to webmin.acl
#					This is what makes CSF appear in Webmin menu
# #

if [ -f "$CSF_WEBMIN_FILE_ACL" ] && [ "$dr" = "false" ]; then

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
#	Step › csf.conf Modified Settings
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
        run sed -i "s|^${KEY}.*|${KEY} = \"${SYSLOG_PATH}\"|" "${CSF_CONF}"
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
       "Your installation is now complete. Review the notes below on getting started with the firewall."

print "    For complete documentation on ${APP_NAME_SHORT:-CSF}; including setup and troubleshooting; visit"
print "        ${yellowd}${APP_LINK_DOCS:-https://docs.configserver.dev}"
print "    "
print "    All settings associated with ${APP_NAME_SHORT:-CSF} can be found in the file:"
print "        ${bluel}${CSF_CONF}"
print "    "
print "    If you are a Sponsor and wish to apply your license key, open ${bluel}${CSF_CONF}${greym} and"
print "    add the following line to your config:"
print "        ${fuchsial}SPONSOR_LICENSE = ${white}\"${bluel}XXXXXX-XXXX-XXXX-XXXXXX${white}\"${greym}"
if [ -f "$CSF_CONF" ]; then
	webui_creds=$(get_csf_ui_info)

	print "    "
	print "    Before starting ${APP_NAME_SHORT:-CSF}; the setting ${yellowd}TESTING${greym} must be ${redl}disabled${greym}."
	if [ "$TESTING_VALUE" = "1" ]; then
	print "        ${redl}${icoXmark}${greym} ${redl}You currently have this setting ${greenl}enabled${greym}."
	print "        ${redl}Disable${greym} this in the file ${bluel}${CSF_CONF}${greym}:"
	print "            ${fuchsial}TESTING = ${white}\"${bluel}0${white}\"${greym}"
	else
	print "        ${greenl}${icoSheckmark}${greym} ${greenl}You currently have the setting disabled which is correct.${end}"
	print "        If you need to test ${APP_NAME_SHORT:-CSF}, edit the file ${bluel}${CSF_CONF}${greym}:"
	print "            ${fuchsial}TESTING = ${white}\"${bluel}1${white}\"${greym}"
	fi
	print "    "
	print "    After you have configured ${bluel}${CSF_CONF}${greym} with the desired settings, restart all"
	print "    ${APP_NAME_SHORT:-CSF} services for changes to apply:"
	print "        ${yellowd}sudo csf -ra"
	print "    "

	if [ -n "$webui_creds" ]; then
		UI_ADDR=$(printf '%s' "$webui_creds" | awk '{print $1}')
		UI_USER=$(printf '%s' "$webui_creds" | awk '{print $2}')
		UI_PASS=$(printf '%s' "$webui_creds" | awk '{print $3}')

		print "    ${APP_NAME_SHORT:-CSF} Web Interface:"
		print "        ${greyd}Status .....  ${greenl}${icoSheckmark}${greym} ${greenl}enabled${greym}"
		print "        ${greyd}Url ........  ${yellowd}http://${UI_ADDR}${greym}"
		print "        ${greyd}Username .... ${yellowd}${UI_USER}${greym}"
		print "        ${greyd}Password .... ${yellowd}${UI_PASS}${greym}"
	else
		print "    ${APP_NAME_SHORT:-CSF} Web Interface:"
		print "        ${greyd}${redl}${icoXmark}${greym} ${redl}disabled${greym}"
	fi
else
	print "    ${redl}${icoXmark} An error occured; we cannot locate your ${APP_NAME_SHORT:-CSF} config file."
	print "    "
	print "    After adding a ${bluel}${CSF_CONF}${greym} config file, restart all ${APP_NAME_SHORT:-CSF}"
	print "    services for changes to apply"
	print "        ${yellowd}sudo csf -ra"
fi
print
print