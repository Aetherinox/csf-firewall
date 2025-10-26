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
APP_NAME_SHORT="CSF"
APP_DESC="Robust linux iptables/nftables firewall"
APP_REPO="https://github.com/aetherinox/csf-firewall"
APP_LINK_DOCS="https://docs.configserver.dev"
APP_LINK_DOWNLOAD="https://download.configserver.dev"
FILE_INSTALL_TXT="install.txt"

# #
#   Define › Files & Dirs
# #

CSF_ETC="/etc/csf"
CSF_BIN="/usr/local/csf/bin"
CSF_TPL="/usr/local/csf/tpl"
CSF_CONF="/etc/csf/csf.conf"
CSF_WEBMIN_HOME="/usr/share/webmin"
CSF_WEBMIN_TARBALL="/usr/local/csf/csfwebmin.tgz"
CSF_WEBMIN_SYMBOLIC="${CSF_ETC}/csfwebmin.tgz"
CSF_WEBMIN_SRC="webmin"
CSF_WEBMIN_DESC="${CSF_WEBMIN_HOME}/csf"
CSF_WEBMIN_ETC="/etc/webmin"
CSF_WEBMIN_FILE_ACL="${CSF_WEBMIN_ETC}/webmin.acl"
CSF_WEBMIN_ACL_USER="root"
CSF_WEBMIN_ACL_MODULE="csf"

# #
#   Define › Server
# #

SERVER_HOST=$(hostname -f 2>/dev/null || hostname)

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
    printf '%-28s %-65s\n' "   ${redl} ERROR ${end}" "${greym} $1 ${end}"
}

warn( )
{
    printf '%-32s %-65s\n' "   ${yellowl} WARN ${end}" "${greym} $1 ${end}"
}

info( )
{
    printf '%-31s %-65s\n' "   ${bluel} INFO ${end}" "${greym} $1 ${end}"
}

status( )
{
    printf '%-31s %-65s\n' "   ${bluel} STATUS ${end}" "${greym} $1 ${end}"
}

ok( )
{
    printf '%-31s %-65s\n' "   ${greenl} OK ${end}" "${greym} $1 ${end}"
}

debug( )
{
    if [ "$argDevMode" = "true" ]; then
        printf '%-28s %-65s\n' "   ${greyd} DEBUG ${end}" "${greym} $1 ${end}"
    fi
}

verbose( )
{
    if [ "$VERBOSE" -eq 1 ]; then
        printf '%-28s %-65s\n' "   ${greyd} VERBOSE ${end}" "${greym} $1 ${end}"
    fi
}

label( )
{
    printf '%-31s %-65s\n' "   ${navy}        ${end}" "${navy} $1 ${end}"
}

print( )
{
    echo "${greym}$1${end}"
}

# #
#   Print > Line
#   
#   Prints single line
#   
#   @usage          prinb
# #

prinl()
{
    local indent="   "
    local box_width=90
    local line_width=$(( box_width + 2 ))

    local line
    line=$(printf '─%.0s' $(seq 1 "$line_width"))

    print
    printf "%b%s%s%b\n" "${greyd}" "$indent" "$line" "${reset}"
    print
}

# #
#   Print > Box > Single
#   
#   Prints single line with a box surrounding it.
#   
#   @usage          prinb "${APP_NAME_SHORT:-CSF} › Customize csf.config"
# #

prinb( )
{
    # #
    #   Dynamic boxed title printer
    # #

    local title="$*"
    local indent="   "                              # Left padding
    local padding=6                                 # Extra horizontal space around text
    local title_length=${#title}
    local inner_width=$(( title_length + padding ))
    local box_width=90

    # #
    #   Minimum width for aesthetics
    # #

    [ "$inner_width" -lt ${box_width} ] && inner_width=${box_width}

    # #
    #   Horizontal border
    # #

    local line
    line=$(printf '─%.0s' $(seq 1 "$inner_width"))

    # #
    #   Draw box
    # #

    print
    print
    printf "%b%s┌%s┐\n" "${greym}" "$indent" "$line"
    printf "%b%s│  %-${inner_width}s│\n" "${greym}" "$indent" "$title"
    printf "%b%s└%s┘%b\n" "${greym}" "$indent" "$line" "${reset}"
    print
}

# #
#   Print > Box > Paragraph
#   
#   Prints multiple lines with a box surrounding it.
#   
#   @usage          prinp "CSF › Title" "This is a really long paragraph that will wrap multiple lines and align properly under the title. Second line of text, same alignment, with multiple words."
# #

prinp()
{
    local title="$1"
    shift
    local text="$*"

    local indent="   "
    local box_width=90
    local pad=2

    local content_width=$(( box_width ))
    local inner_width=$(( box_width - pad*2 ))

    print
    print
    local hline
    hline=$(printf '─%.0s' $(seq 1 "$content_width"))

    printf "${greyd}%s┌%s┐\n" "$indent" "$hline"

    # #
    #   title
    # #

    local title_width=$(( content_width - pad ))
    printf "${greym}%s│%*s${bluel}%-${title_width}s${greym}│\n" "$indent" "$pad" "" "$title"

    printf "${greyd}%s│%-${content_width}s│\n" "$indent" ""

    local line=""
    set -- $text
    for word; do
        if [ ${#line} -eq 0 ]; then
            line="$word"
        elif [ $(( ${#line} + 1 + ${#word} )) -le $inner_width ]; then
            line="$line $word"
        else
            printf "${greyd}%s│%*s%-*s%*s│\n" "$indent" "$pad" "" "$inner_width" "$line" "$pad" ""
            line="$word"
        fi
    done
    [ -n "$line" ] && printf "${greyd}%s│%*s%-*s%*s│\n" "$indent" "$pad" "" "$inner_width" "$line" "$pad" ""

    printf "${greyd}%s└%s┘${reset}\n" "$indent" "$hline"
    print
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