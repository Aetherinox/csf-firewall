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
#   @updated            10.02.2025
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
#   ConfigServer Firewall › Ports › Blacklist
# #

export PATH="$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# #
#   define › ports
# #

BLACKLIST_PORTS=$(cat <<EOF
[
    {"port":"111", "comment":"used by sunrpc/rpcbind, has vulnerabilities"}
]
EOF
)

# #
#   define › system
# #

sys_arch=$(dpkg --print-architecture 2>/dev/null)
sys_code=$(lsb_release -cs 2>/dev/null)

# #
#   define › app
# #

app_name="CSF Script › Blacklist Ports"                             # name of app
app_desc="Block specific ports from being accessed outside your network"
app_ver="15.10.0"                                                   # current script version
app_repo="Aetherinox/csf-firewall"                                  # repository
app_repo_branch="main"                                              # repository branch

# #
#   define › app
# #

app_file_this=$(basename "$0")                          #  ports-blacklistsh    (with ext)
app_file_bin="${app_file_this%.*}"                      #  ports-blacklist      (without ext)

# #
#   define › folders
# #

app_dir_this="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"           # path where script was last found in
app_dir_this_usr="${PWD}"                                               # the path where script is called from

# #
#   define › aargs
# #

argDryrun="false"                                       # Enable dryrun
argDevMode="false"                                      # dev mode

# #
#   vars › colors
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
#   func › usage menu
# #

opt_usage( )
{
    echo
    printf "  ${bluel}${app_name}${end}\n" 1>&2
    printf "  ${greym}${app_desc}${end}\n" 1>&2
    printf "  ${greyd}version:${end} ${greyd}$app_ver${end}\n" 1>&2
    printf "  ${fuchsiad}$app_file_this${end} ${greyd}[${greym}--help${greyd}]${greyd}  |  ${greyd}[${greym}--version ${greyd}]${end}" 1>&2
    echo
    echo
    printf '  %-5s %-40s\n' "${greyd}Syntax:${end}" "" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}Command${end}           " "${fuchsiad}$app_file_this${greyd} [ ${greym}-option ${greyd}[ ${yellowd}arg${greyd} ]${greyd} ]${end}" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}Options${end}           " "${fuchsiad}$app_file_this${greyd} [ ${greym}-h${greyd} | ${greym}--help${greyd} ]${end}" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "    ${greym}-A${end}            " " ${white}required" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "    ${greym}-A...${end}         " " ${white}required; multiple can be specified" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "    ${greym}[ -A ]${end}        " " ${white}optional" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "    ${greym}[ -A... ]${end}     " " ${white}optional; multiple can be specified" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "    ${greym}{ -A | -B }${end}   " " ${white}one or the other; do not use both" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}Arguments${end}         " "${fuchsiad}$app_file_this${end} ${greyd}[ ${greym}-d${yellowd} arg${greyd} | ${greym}--name ${yellowd}arg${greyd} ]${end}${yellowd} arg${end}" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}Examples${end}          " "${fuchsiad}$app_file_this${end} ${greym}--dev${yellowd} ${end}" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}${end}                  " "${fuchsiad}$app_file_this${end} ${greyd}[ ${greym}--help${greyd} | ${greym}-h${greyd} | ${greym}/?${greyd} ]${end}" 1>&2
    echo
    printf '  %-5s %-40s\n' "${greyd}Options:${end}" "" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}-D${greyd},${blued}  --dryrun ${yellowd}${end}                     " "pass dryrun to csf installer script, does not install ${end} ${navy}<default> ${peach}${argDryrun:-"disabled"} ${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}-V${greyd},${blued}  --version ${yellowd}${end}                    " "current version of this utilty ${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}-d${greyd},${blued}  --dev ${yellowd}${end}                        " "developer mode; verbose logging ${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}-h${greyd},${blued}  --help ${yellowd}${end}                       " "show this help menu ${end}" 1>&2
    echo
    echo
}

# #
#   Display help text if command not complete
# #

while [ $# -gt 0 ]; do
    case "$1" in
        -d|--dev|--debug)
            argDevMode=true
            echo "    ⚠️ Debug Mode › ${blink}${greyd}enabled${greym}${end}"
            ;;
        --dry|--dryrun)
            argDryrun=true
            echo "    ⚠️ Dryrun Mode › ${blink}${greyd}enabled${greym}${end}"
            ;;
        -v|--version)
            echo
            echo "  ${blued}${bold}${app_name}${end} - v$app_ver ${end}"
            echo "  ${greym}${app_desc}${end}"
            echo "  ${greenl}${bold}https://github.com/${app_repo} ${end}"
            echo
            exit 1
            ;;
        -\?|-h|--help)
            opt_usage
            exit 1
            ;;
        *)
            printf '%-28s %-65s\n' "  ${redl} ERROR ${end}" "${greym} Unknown parameter:${redl} $1 ${greym}. Aborting ${end}"
            exit 1
            ;;
    esac
    shift
done

# #
#   print messages
# #

error()
{
    printf '%-28s %-65s\n' "  ${redl} ERROR ${end}" "${greym} $1 ${end}"
    exit 1
}

warn()
{
    printf '%-32s %-65s\n' "  ${yellowl} WARN ${end}" "${greym} $1 ${end}"
}

status()
{
    printf '%-31s %-65s\n' "  ${bluel} STATUS ${end}" "${greym} $1 ${end}"
}

ok()
{
    printf '%-31s %-65s\n' "  ${greenl} OK ${end}" "${greym} $1 ${end}"
}

debug()
{
    if [ "$argDevMode" = "true" ]; then
        printf '%-28s %-65s\n' "  ${greyd} DEBUG ${end}" "${greym} $1 ${end}"
    fi
}

print()
{
    printf '%-31s %-65s\n' "  ${peach}        ${end}" "${peach} $1 ${end}"
}

# #
#   Check Sudo
# #

check_sudo()
{
    if [ "$(id -u)" != "0" ]; then
        error "    ❌ Must run script with sudo ${redl}${ipv4_tmp}"
        exit 1
    fi
}

check_sudo

# #
#   Ensure we are in script directory
# #

cd "$app_dir_this" || exit 1

# #
#   Ensure iptables
# #

path_iptables4=$(command -v iptables)

if [ -z "$path_iptables4" ]; then
    error "    ❌ Could not locate package ${redl}iptables; aborting"
fi

# #
#   Loop blacklists
# #

status "⭕ Blacklisting Ports"

echo "$BLACKLIST_PORTS" | jq -c '.[]' | while IFS= read -r row; do
    entry_port=$(echo "$row" | jq -r '.port')
    entry_comment=$(echo "$row" | jq -r '.comment')

    delete_input_udp=0
    delete_input_tcp=0

    $path_iptables4 -C INPUT -p udp --dport "$entry_port" -j DROP >/dev/null 2>&1 || delete_input_udp=1
    debug "    ➕ Running cmd: ${greyd}$path_iptables4 -C INPUT -p udp --dport "$entry_port" -j DROP"
    
    $path_iptables4 -C INPUT -p tcp --dport "$entry_port" -j DROP >/dev/null 2>&1 || delete_input_tcp=1
    debug "    ➕ Running cmd: ${greyd}$path_iptables4 -C INPUT -p tcp --dport "$entry_port" -j DROP"

    if [ "$delete_input_udp" = "0" ]; then
        ok "    ✓  Port ${greenl}$entry_port${greym} for protocl ${greenl}UDP${greym} already blocked "
    else
        $path_iptables4 -I INPUT -p udp --dport "$entry_port" -j DROP
        print  "    ├─ Blacklisting | port: ${fuchsial}$entry_port${peach} ${fuchsial}UDP${peach} | comment: ${fuchsial}$entry_comment${peach} "
    fi

    if [ "$delete_input_tcp" = "0" ]; then
        ok "    ✓  Port ${greenl}$entry_port${greym} for protocl ${greenl}TCP${greym} already blocked "
    else
        $path_iptables4 -I INPUT -p tcp --dport "$entry_port" -j DROP
        print  "    ├─ Blacklisting | port: ${fuchsial}$entry_port${peach} ${fuchsial}TCP${peach} | comment: ${fuchsial}$entry_comment${peach} "
    fi
done

echo 
echo 