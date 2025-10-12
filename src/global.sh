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
#   Global variables
#       must remain POSIX compatible
# #

# set -eu

# #
#   Directory where this script lives
# #

OLDPWD=$(pwd)                                       # save current working directory
cd "$(dirname "$0")" || exit 1                      # change to the dir where the script resides
SCRIPT_DIR=$(pwd)                                   # get absolute path
cd "$OLDPWD" || exit 1                              # restore previous working directory

# #
#   Define › General
# #

APP_NAME="ConfigServer Security & Firewall"
APP_DESC="Robust linux iptables/nftables firewall"
APP_REPO="https://github.com/aetherinox/csf-firewall"
FILE_INSTALL_TXT="install.txt"
CSF_ETC="/etc/csf"
CSF_BIN="/usr/local/csf/bin"
CSF_TPL="/usr/local/csf/tpl"

# #
#   Define › Files
# #

app_file_this=$(basename "$0")                                          # global.sh         (with ext)
app_file_bin="${app_file_this%.*}"                                      # global            (without ext)

# #
#   Define › Folders
# #

app_dir_this="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"           # path where script was last found in
app_dir_this_usr="${PWD}"                                               # path where script is called from

# #
#   Define › Current version
# #

VERSION_FILE="$SCRIPT_DIR/version.txt"

# #
#   Extract ver from version.txt; fallback 'unknown'
# #

APP_VERSION=$( [ -f "$VERSION_FILE" ] && grep -v '^[[:space:]]*$' "$VERSION_FILE" | sed -n '1s/^[[:space:]]*//;s/[[:space:]]*$//p' || true )
: "${APP_VERSION:=unknown}"

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
    exit 1
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

label( )
{
    printf '%-31s %-65s\n' "  ${peach}        ${end}" "${peach} $1 ${end}"
}

print( )
{
    echo "${end}$1${end}"
}

# #
#   Check Sudo
# #

check_sudo( )
{
    if [ "$(id -u)" != "0" ]; then
        error "    ❌ Must run script with ${redl}sudo"
        exit 1
    fi
}

# #
#   Copy If Missing
#   Copies a src file to dest only if missing
#   
#   @arg            src                         File to copy
#   @arg            dest                        Where to copy file
#   @usage			copy_if_missing "install.cpanel.sh" "csf cPanel installer"
# #

copy_if_missing( )
{
    src="$1"
    dest="$2"

    if [ ! -e "$dest" ]; then
        if cp -avf "$src" "$dest"; then
            ok "    Copied ${greenl}$src${greym} to ${greenl}$dest${greym} "
        else
            error "    ❌ Cannot copy ${redl}$src${greym} to ${redl}$dest${greym}"
            exit 1
        fi
    else
        status "    Already existing copy ${bluel}${src}${greym} to ${bluel}$dest${greym}"
    fi
}

# #
#   Special copy: copy to dest or dest.new if dest exists
# #

copy_or_new( )
{
    src="$1"
    dest="$2"

    if [ ! -e "$dest" ]; then
        if cp -avf "$src" "$dest"; then
            ok "    Copied ${greenl}$src${greym} to ${greenl}$dest${greym} "
        else
            error "    ❌ Cannot copy ${redl}$src${greym} to ${redl}$dest${greym}"
            exit 1
        fi
    else
        if cp -avf "$src" "${dest}.new"; then
            ok "    Copied ${greenl}$src${greym} to ${greenl}$dest.new${greym} (destination already existed) "
        else
            error "    ❌ Cannot copy ${redl}$src${greym} to ${redl}$des.newt${greym}"
            exit 1
        fi
    fi
}