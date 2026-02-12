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
#
# chkconfig: 2345 15 80
# description: ConfigServer Firewall
#
### BEGIN INIT INFO
# Provides:          csf
# Required-Start:    $network
# Required-Stop:     $network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# X-Start-Before:    $syslog
# Short-Description: ConfigServer Firewall (csf)
# Description:       ConfigServer Firewall (csf) init script
### END INIT INFO
#

# #
#	Allow for execution from different relative directories
# #

case $0 in
    /*) script="$0" ;;                      # Absolute path
    *)  script="$(pwd)/$0" ;;               # Relative path
esac

# #
#	Find script directory
# #

script_dir=$(dirname "$script")

# #
#    Change working directory
# #

cd "$script_dir" || exit 1

# #
#   Define › Files
# #

app_file_this=$(basename "$0")              # global.sh         (with ext)
app_file_bin="${app_file_this%.*}"          # global            (without ext)

# #
#   CSF Init Script (POSIX-compliant with argument loop)
# #

DAEMON="/usr/sbin/csf"
LOCKFILE="/var/lock/subsys/csf"
VERBOSE=0
NOLOCK=0
COMMAND=""

# #
#   Define › General
# #

app_name="ConfigServer Security & Firewall"
app_desc="Robust linux iptables/nftables firewall"
app_repo="https://github.com/aetherinox/csf-firewall"
app_version_file="$script_dir/version.txt"
app_version=$( [ -f "$app_version_file" ] && grep -v '^[[:space:]]*$' "$app_version_file" | sed -n '1s/^[[:space:]]*//;s/[[:space:]]*$//p' || true )
: "${app_version:=15}"

# #
#   Define › Colors
#   
#   Use the color table at:
#       - https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797
# #

esc=$(printf '\033')
end="${esc}[0m"
bold="${esc}[1m"
dim="${esc}[2m"
underline="${esc}[4m"
blink="${esc}[5m"
white="${esc}[97m"
black="${esc}[0;30m"
redl="${esc}[0;91m"
redd="${esc}[38;5;196m"
magental="${esc}[0;95m"
magentad="${esc}[0;35m"
fuchsial="${esc}[38;5;198m"
fuchsiad="${esc}[38;5;161m"
bluel="${esc}[38;5;75m"
blued="${esc}[38;5;33m"
greenl="${esc}[38;5;76m"
greend="${esc}[38;5;2m"
orangel="${esc}[0;93m"
oranged="${esc}[38;5;202m"
yellowl="${esc}[38;5;190m"
yellowd="${esc}[38;5;184m"
greyl="${esc}[38;5;250m"
greym="${esc}[38;5;244m"
greyd="${esc}[0;90m"
navy="${esc}[38;5;62m"
olive="${esc}[38;5;144m"
peach="${esc}[38;5;210m"
cyan="${esc}[38;5;6m"

# #
#   Define › Logging functions
# #

error( )
{
    printf '%-28s %-65s\n' "  ${redl} ERROR ${end}" "${greym} $1 ${end}"
}

warn( )
{
    printf '%-32s %-65s\n' "  ${yellowl} WARN ${end}" "${greym} $1 ${end}"
}

status( )
{
    printf '%-31s %-65s\n' "  ${bluel} STATUS ${end}" "${greym} $1 ${end}"
}

ok( )
{
    printf '%-31s %-65s\n' "  ${greenl} OK ${end}" "${greym} $1 ${end}"
}

debug( )
{
    if [ "$argDevMode" = "true" ]; then
        printf '%-28s %-65s\n' "  ${greyd} DEBUG ${end}" "${greym} $1 ${end}"
    fi
}

verbose( )
{
    if [ "$VERBOSE" -eq 1 ]; then
        printf '%-28s %-65s\n' "  ${greyd} VERBOSE ${end}" "${greym} $1 ${end}"
    fi
}

label( )
{
    printf '%-31s %-65s\n' "  ${navy}        ${end}" "${navy} $1 ${end}"
}

print( )
{
    echo "${end}$1${end}"
}

# #
#   Define › Logging › Verbose
# #

log()
{
    if [ "$VERBOSE" -eq 1 ]; then
		verbose "    $@ "
    fi
}

# #
#	Usage Menu
# #

opt_usage( )
{
	# #
	#	Define › Defaults
	# #

	status_verbose="disabled"; [ "$VERBOSE" -eq 1 ] && status_verbose="enabled" || :
	status_quiet="disabled"; [ "$VERBOSE" -eq 0 ] && status_quiet="enabled" || :
	status_nolock="disabled"; [ "$NOLOCK" -eq 1 ] && status_nolock="enabled" || :

	# #
	#	Start Help Menu
	# #

    echo
    printf "  ${bluel}${app_name}${end}\n" 1>&2
    printf "  ${greym}${app_desc}${end}\n" 1>&2
    printf "  ${greyd}version:${end} ${greyd}$app_version${end}\n" 1>&2
    printf "  ${fuchsiad}$app_file_this${end} ${greyd}[ ${greym}--verbose${greyd} | ${greym}--quiet${greyd} | ${greym}--no-lock${greyd} ] { ${greym}start${greyd} | ${greym}stop${greyd} | ${greym}status${greyd} | ${greym}restart${greyd} | ${greym}force-reload${greyd} | ${greym}reload${greyd} | ${greym}restart-all${greyd} | ${greym}enable${greyd} | ${greym}disable${greyd} }${end} " 1>&2
    echo
    echo
    printf '  %-5s %-40s\n' "${greyd}Syntax:${end}" "" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}Flags${end}             " "" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "    ${greym}-A${end}            " " ${white}required flag" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "    ${greym}-A...${end}         " " ${white}required flag; multiple flags can be specified" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "    ${greym}[ -A ]${end}        " " ${white}optional flag" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "    ${greym}[ -A... ]${end}     " " ${white}optional flag; multiple flags can be specified" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "    ${greym}{ -A | -B }${end}   " " ${white}one flag or the other; do not use both" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}Arguments${end}         " "${fuchsiad}$app_file_this${end} ${greyd}[ ${greym}-d${yellowd} arg${greyd} | ${greym}--flag ${yellowd}arg${greyd} ]${end}${yellowd} arg${end}" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}Examples${end}          " "${fuchsiad}$app_file_this${end} ${greym}start${yellowd} ${end}" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}${end}                  " "${fuchsiad}$app_file_this${end} ${greym}--verbose start${yellowd} ${end}" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}${end}                  " "${fuchsiad}$app_file_this${end} ${greym}--no-lock stop${yellowd} ${end}" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}${end}                  " "${fuchsiad}$app_file_this${end} ${greym}--help${greyd} | ${greym}-h${greyd} | ${greym}/?${end}" 1>&2
    echo
    printf '  %-5s %-40s\n' "${greyd}Flags:${end}" "" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}-v${greyd},${blued}  --verbose ${yellowd}${end}                    " "show detailed output of script actions for debugging or informational purposes ${navy}<default> ${peach}${status_verbose:-"disabled"} ${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}-q${greyd},${blued}  --quiet ${yellowd}${end}                      " "suppress most output; only show essential messages or errors ${navy}<default> ${peach}${status_quiet:-"enabled"} ${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}-n${greyd},${blued}  --no-lock ${yellowd}${end}                    " "do not create a lock file; bypass init lock mechanism ${navy}<default> ${peach}${status_nolock:-"disabled"} ${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}-v${greyd},${blued}  --version ${yellowd}${end}                    " "current version of this utilty ${navy}<current> ${peach}${app_version:-"unknown"} ${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}-h${greyd},${blued}  --help ${yellowd}${end}                       " "show this help menu ${end}" 1>&2
    echo
    printf '  %-5s %-40s\n' "${greyd}Actions:${end}" "" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}  ${greyd} ${blued}    start ${yellowd}${end}            " "start the CSF firewall daemon  ${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}  ${greyd} ${blued}    stop ${yellowd}${end}             " "stop the CSF firewall daemon ${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}  ${greyd} ${blued}    status ${yellowd}${end}           " "display the current status of the CSF daemon ${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}  ${greyd} ${blued}    restart ${yellowd}${end}          " "restart the CSF daemon ${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}  ${greyd} ${blued}    reload ${yellowd}${end}           " "reload CSF configuration without full restart ${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}  ${greyd} ${blued}    force-reload ${yellowd}${end}     " "force reload CSF configuration (stop/start) ${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}  ${greyd} ${blued}    restart-all ${yellowd}${end}      " "force restart CSF and LFD services ${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}  ${greyd} ${blued}    enable ${yellowd}${end}           " "enable the CSF firewall daemon ${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}  ${greyd} ${blued}    disable ${yellowd}${end}          " "disable the CSF firewall daemon ${end}" 1>&2
    echo
    echo
}

# #
#   Parse command-line arguments
# #

while [ "$#" -gt 0 ]; do
    case "$1" in
        --verbose|-v)
            VERBOSE=1
            ;;
        --quiet|-q)
            VERBOSE=0
            ;;
        --no-lock|-n)
            NOLOCK=1
            ;;
        -h|--help|\?)
            opt_usage
            exit 1
            ;;
        -V|--version)
			echo
			print "    ${blued}${bold}${app_name}${end} - v$app_version "
			print "    ${greenl}${bold}${app_repo} "
			echo
            exit 1
            ;;
        start|stop|status|restart|force-reload|reload|ra|restart-all|enable|disable)
            COMMAND="$1"
            ;;
        *)
			echo
			error "    ❌ Unknown flag ${redl}$1${greym}. Aborting."
			label "    ${end}${fuchsiad}$app_file_this${end} ${greyd}[${greym}--verbose${greyd}|${greym}--quiet${greyd}|${greym}--no-lock${greyd}] {${greym}start${greyd}|${greym}stop${greyd}|${greym}status${greyd}|${greym}restart${greyd}|${greym}force-reload${greyd}|${greym}reload${greyd}|${greym}restart-all${greyd}|${greym}enable${greyd}|${greym}disable}"
			echo
			exit 1
            ;;
    esac
    shift
done

# #
#   Exit if csf binary not found
# #

if [ ! -x "$DAEMON" ]; then
	error "    ${redl}$DAEMON${end} not found or not executable."
    exit 1
else
	log "Daemon path: ${navy}$DAEMON"
fi

# #
#	Lock file
# #

log "Lock file: ${navy}$LOCKFILE"

# #
#   Source system function library if available
# #

if [ -f /etc/init.d/functions ]; then
    . /etc/init.d/functions
	log "Loaded: ${navy}/etc/init.d/functions"
else
	log "Not found: ${navy}/etc/init.d/functions"
fi

# #
#   Source SuSE rc.status if available
# #

if [ -f /etc/SuSE-release ]; then
    if [ -f /etc/rc.status ]; then
        . /etc/rc.status
        if command -v rc_reset >/dev/null 2>&1; then
            rc_reset
        fi
    fi
fi

# #
#   Ensure a command was provided
# #

if [ -z "$COMMAND" ]; then
	label "    ${end}Usage: ${fuchsiad}$app_file_this${end} ${redl}[--verbose|--quiet|--no-lock] {start|stop|status|restart|force-reload|reload|restart-all|enable|disable}"
    exit 1
fi

# #
#   Command handler
#	
#	Only used on:
#		start|stop|status|restart|force-reload|reload|ra|restart-all|enable|disable
# #

case "$COMMAND" in
    start)
        status_msg="$("$DAEMON" --initup 2>&1)"
		status "    Starting ${bluel}${DAEMON}${end}: ${status_msg}"

        if [ -f /etc/SuSE-release ]; then
            if command -v rc_status >/dev/null 2>&1; then
                rc_status -v
            fi
        elif [ -f /etc/debian_version ] || [ -f /etc/lsb-release ] || [ -f /etc/gentoo-release ]; then
			ok "    Successfully started ${greenl}${DAEMON}"
        else
            if command -v success >/dev/null 2>&1; then
                success
            else
				ok "    Successfully started ${greenl}${DAEMON}"
            fi
        fi

        if [ "$NOLOCK" -eq 0 ] && [ -d /var/lock/subsys ]; then
            : > "$LOCKFILE"
			log "Lock file created: ${navy}$LOCKFILE"
        fi
        ;;

    stop)
		debug "    ${redd}WARNING:${redl} This script should ONLY be used by the init process."
		debug "    ${redl}To restart csf use the CLI command 'csf -r"

        status_msg="$("$DAEMON" --initdown 2>&1)"
		status "    Stopping ${bluel}${DAEMON}${end}: ${status_msg}"

        "$DAEMON" --stop >/dev/null 2>&1
		label "    ${end}Flushing chains"

        if [ -f /etc/SuSE-release ]; then
            if command -v rc_status >/dev/null 2>&1; then
                rc_status -v
            fi
        elif [ -f /etc/debian_version ] || [ -f /etc/lsb-release ] || [ -f /etc/gentoo-release ]; then
            ok "    Action ${greenl}stop${greym} complete "
        else
            if command -v success >/dev/null 2>&1; then
                success
            else
                ok "    Action ${greenl}stop${greym} complete "
            fi
        fi

        if [ "$NOLOCK" -eq 0 ] && [ -d /var/lock/subsys ]; then
            rm -f "$LOCKFILE"
			log "Lock file removed: ${navy}$LOCKFILE"
        fi
        ;;

    status)
		status "    Daemon status ${bluel}${DAEMON}"
        "$DAEMON" --status
        ;;

	restart|force-reload|reload)
		"$script_dir/$app_file_this" ${VERBOSE:+--verbose} ${NOLOCK:+--no-lock} stop
		"$script_dir/$app_file_this" ${VERBOSE:+--verbose} ${NOLOCK:+--no-lock} start
		;;

    ra|restart-all)
		status "    Restarting both ${bluel}csf${greym} and ${bluel}lfd"
        "$DAEMON" -ra
        ;;

    enable)
		status_msg="$("$DAEMON" -e 2>&1)"
		status "    Enabling ${bluel}${DAEMON}${end}: ${status_msg}"
        ;;

    disable)
		status_msg="$("$DAEMON" -x 2>&1)"
		status "    Disabling ${bluel}${DAEMON}${end}: ${status_msg}"
        ;;
esac

exit 0
