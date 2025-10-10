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
#   @updated            10.07.2025
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
#   This script looks in the folder /usr/local/include/csf/pre.d and loads
#   any scripts that are in there.
#   
#   Pre.d are ran BEFORE CSF imports its own firewall rules into iptables.
#   Post.d are ran AFTER CSF imports its own firewall rules into iptables.
#   
#   These scripts must be installed in:
#       /usr/local/csf/bin/csfpre.sh
#       /usr/local/csf/bin/csfpost.sh
#   
#   Add your pre and post scripts in:
#       /usr/local/include/csf/pre.d/
#       /usr/local/include/csf/post.d/
# #

path_csfpostd="/usr/local/include/csf/post.d"
count_loaded=0

# #
#   define › app
# #

app_name="CSF Script › Post.d Initialization"                           # name of app
app_desc="Loads custom scripts into CSF before adding iptable rules."
app_ver="15.10.0"                                                       # current script version
app_repo="Aetherinox/csf-firewall"                                      # repository
app_repo_branch="main"                                                  # repository branch

# #
#   define › app
# #

app_file_this=$(basename "$0")                                          #  csfpost.sh       (with ext)
app_file_bin="${app_file_this%.*}"                                      #  csfpost          (without ext)

# #
#   define › folders
# #

app_dir_this="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"           # path where script was last found in
app_dir_this_usr="${PWD}"                                               # the path where script is called from

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
#   Logging functions
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
        error "    ❌ Must run script with ${redl}sudo"
        exit 1
    fi
}

# #
#   Start Script
# #

status "    Script ${bluel}${app_dir_this}/$app_file_this${greym} loading ${bluel}post.d${greym} initialzation scripts in folder ${bluel}${path_csfpostd}"

# #
#   Loader
# #

if [ -d "$path_csfpostd" ]; then
    for i in "$path_csfpostd"/*.sh; do
        [ -e "$i" ] || continue      # skip if no files match
        [ -f "$i" ] || continue      # only regular files
        [ -r "$i" ] || continue      # must be readable

        . "$i"
        count_loaded=$((count_loaded + 1))
        ok "    Loaded post.d script ${greenl}$1 "
    done
    unset i
fi

# #
#   Finished loading
# #

ok "    Loaded ${greenl}${count_loaded}${greym} post.d initialization scripts"