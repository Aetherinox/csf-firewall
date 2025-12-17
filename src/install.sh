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
#   @updated            10.11.2025
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
#   @script             ConfigServer Security & Firewall Installer
#   @desc               determines the users distro and (if any) control panel, launches correct installer sub-script
#   
#   @usage              Normal install          sh install.sh
#                       Dryrun install          sh install.sh --dryrun
# #

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

. "${script_dir}/global.sh" ||
{
    echo "    Error: cannot source ${script_dir}/global.sh. Aborting." >&2
    exit 1
}

# #
#    Change working directory
# #

cd "${script_dir}" || exit 1

# #
#   Define › Args
# #

argDryrun="false"				# runs the logic but doesn't actually install; no changes
argDetect="false"				# returns the installer name + desc that would have ran, but exits; no changes
argLegacy="false"				# certain actions will work how pre CSF v15.01 did 

# #
#   Func › Usage Menu
# #

opt_usage( )
{
    echo
    printf "  ${bluel}${APP_NAME}${end}\n" 1>&2
    printf "  ${greym}${APP_DESC}${end}\n" 1>&2
    printf "  ${greyd}version:${end} ${greyd}$APP_VERSION${end}\n" 1>&2
    printf "  ${magental}${app_file_this}${end} ${greyd}[ ${greym}--detect${greyd} | ${greym}--dryrun${greyd} |  ${greym}--version${greyd} | ${greym}--help ${greyd}]${end}" 1>&2
    echo
    echo
    printf '   %-5s %-40s\n' "${greyd}Syntax:${end}" "" 1>&2
    printf '   %-5s %-30s %-40s\n' "    " "${greyd}Command${end}           " "${magental}${app_file_this}${greyd} [ ${greym}--option ${greyd}[ ${yellowd}arg${greyd} ]${greyd} ]${end}" 1>&2
    printf '   %-5s %-30s %-40s\n' "    " "${greyd}Options${end}           " "${magental}${app_file_this}${greyd} [ ${greym}-h${greyd} | ${greym}--help${greyd} ]${end}" 1>&2
    printf '   %-5s %-30s %-40s\n' "    " "    ${greym}-A${end}            " "   ${white}required" 1>&2
    printf '   %-5s %-30s %-40s\n' "    " "    ${greym}-A...${end}         " "   ${white}required; multiple can be specified" 1>&2
    printf '   %-5s %-30s %-40s\n' "    " "    ${greym}[ -A ]${end}        " "   ${white}optional" 1>&2
    printf '   %-5s %-30s %-40s\n' "    " "    ${greym}[ -A... ]${end}     " "   ${white}optional; multiple can be specified" 1>&2
    printf '   %-5s %-30s %-40s\n' "    " "    ${greym}{ -A | -B }${end}   " "   ${white}one or the other; do not use both" 1>&2
    printf '   %-5s %-30s %-40s\n' "    " "${greyd}Examples${end}          " "${magental}${app_file_this}${end} ${greym}--detect${yellowd} ${end}" 1>&2
    printf '   %-5s %-30s %-40s\n' "    " "${greyd}${end}                  " "${magental}${app_file_this}${end} ${greym}--dryrun${yellowd} ${end}" 1>&2
    printf '   %-5s %-30s %-40s\n' "    " "${greyd}${end}                  " "${magental}${app_file_this}${end} ${greym}--version${yellowd} ${end}" 1>&2
    printf '   %-5s %-30s %-40s\n' "    " "${greyd}${end}                  " "${magental}${app_file_this}${end} ${greym}--help${greyd} | ${greym}-h${greyd} | ${greym}/?${end}" 1>&2
    echo
    printf '   %-5s %-40s\n' "${greyd}Flags:${end}" "" 1>&2
    printf '   %-5s %-81s %-40s\n' "    " "${blued}-D${greyd},${blued}  --detect ${yellowd}${end}                     " "returns installer script that will run; does not install csf ${navy}<default> ${peach}${argDetect:-"disabled"} ${end}" 1>&2
    printf '   %-5s %-81s %-40s\n' "    " "${blued}-d${greyd},${blued}  --dryrun ${yellowd}${end}                     " "simulates installation, does not install csf ${navy}<default> ${peach}${argDryrun:-"disabled"} ${end}" 1>&2
    printf '   %-5s %-81s %-40s\n' "    " "${blued}-v${greyd},${blued}  --version ${yellowd}${end}                    " "current version of this utilty ${navy}<current> ${peach}${APP_VERSION:-"unknown"} ${end}" 1>&2
    printf '   %-5s %-81s %-40s\n' "    " "${blued}-h${greyd},${blued}  --help ${yellowd}${end}                       " "show this help menu ${end}" 1>&2
    echo
    echo
}

# #
#   Args › Parse
# #

while [ "$#" -gt 0 ]; do
    case "$1" in
        -d|--dryrun)
            argDryrun="true"
            ;;
        -D|--detect)
            argDetect="true"
            ;;
        -l|--legacy)
            argLegacy="true"
            ;;
        -v|--ver|--version)
            print
			print "    ${blued}${bold}${APP_NAME}${end} - v${APP_VERSION} "
			print "    ${greenl}${bold}${APP_REPO} "
            print
            exit 1
            ;;
        -h|--help|\?)
            opt_usage
            exit 1
            ;;
        *)
            print
			error "    ❌ Unknown flag ${redl}$1${greym}. Aborting."
            print
			exit 1
			;;
    esac
    shift
done

# #
#   Export
# #

export argDryrun argDetect argLegacy

# #
#	Runs the requested installer
#	
#	@arg 			installerFile				Install script to run
#	@arg 			installerDesc				Brief description for the user
#	@usage			run_installer "install.cpanel.sh" "csf cPanel installer"
# #

run_installer()
{
    installer="$1"
    description="$2"

	# #
	#	Detect; but do not run
	# #

    if [ "${argDetect}" = "true" ]; then
        print
		ok "    Detected Installer: ${greenl}${script_dir}/${installer}${greym} (${description}) "
        print
		exit 0
	fi

	# #
	#	Dryrun; or run chosen installer script
	# #

    if [ "${argDryrun}" = "true" ]; then
		ok "    Dryrun flag specified; skipped installer ${greenl}${script_dir}/${installer}${greym} "
    fi

    print
    print "   ${greyd}# #"
    print "   ${greyd}#  ${bluel}${APP_NAME} › Installer${end}" 1>&2
    print "   ${greyd}#  ${greyd}version:${end} ${greyd}$APP_VERSION${end}" 1>&2
    print "   ${greyd}# #"
    print
    ok "    Starting installer ${greenl}${description}${greym} › ${greenl}${installer}"
    print

    sh "${script_dir}/${installer}" "${installer}" "${description}"
}

# #
#   Define which installation script to run
# #

if [ -e "/usr/local/cpanel/version" ]; then
    run_installer "install.cpanel.sh" "cPanel"
elif [ -e "/usr/local/directadmin/directadmin" ]; then
    run_installer "install.directadmin.sh" "DirectAdmin"
elif [ -e "/usr/local/interworx" ]; then
    run_installer "install.interworx.sh" "InterWorx"
elif [ -e "/usr/local/cwpsrv" ]; then
    run_installer "install.cwp.sh" "Control Web Panel (CWP)"
elif [ -e "/usr/local/vesta" ]; then
    run_installer "install.vesta.sh" "VestaCP"
elif [ -e "/usr/local/CyberCP" ]; then
    run_installer "install.cyberpanel.sh" "CyberPanel"
else
    run_installer "install.generic.sh" "Generic"
fi
