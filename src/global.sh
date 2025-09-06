#!/bin/sh
# #
#	  @author					  Copyright (C) 2006-2025 Jonathan Michaelson
#							        Copyright (C) 2025 Aetherinox
#	  @repo_primary			https://github.com/Aetherinox/csf-firewall/actions
#	  @repo_legacy			https://github.com/waytotheweb/scripts
#
#	  This program is free software; you can redistribute it and/or modify it under
#	  the terms of the GNU General Public License as published by the Free Software
#	  Foundation; either version 3 of the License, or (at your option) any later
#	  version.
#
#	  This program is distributed in the hope that it will be useful, but WITHOUT
#	  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
#	  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
#	  details.
#
#	  You should have received a copy of the GNU General Public License along with
#	  this program; if not, see <https://www.gnu.org/licenses>.
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
#   standard files
# #

FILE_INSTALL_TXT="install.txt"
CSF_ETC="/etc/csf"
CSF_BIN="/usr/local/csf/bin"
CSF_TPL="/usr/local/csf/tpl"

# #
#   get current version
# #

VERSION_FILE="$SCRIPT_DIR/version.txt"

# extract ver from version.txt; fallback 'unknown'
VERSION=$( [ -f "$VERSION_FILE" ] && grep -v '^[[:space:]]*$' "$VERSION_FILE" | sed -n '1s/^[[:space:]]*//;s/[[:space:]]*$//p' || true )
: "${VERSION:=unknown}"

# #
#   ANSI color codes (POSIX-compatible)
# #

ESC=$(printf '\033')
END="${ESC}[0m"

# #
#   Styles
# #

BOLD="${ESC}[1m"
DIM="${ESC}[2m"
UNDERLINE="${ESC}[4m"
BLINK="${ESC}[5m"
STRIKE="${ESC}[9m"

# #
#   Basic colors (foreground)
# #

BLACK="${ESC}[38;5;0m"
WHITE="${ESC}[97m"

# #
#   Extended colors
# #

REDD="${ESC}[38;5;160m"
REDL="${ESC}[38;5;196m"

ORANGED="${ESC}[38;5;202m"
ORANGEL="${ESC}[38;5;215m"

FUCHSIAL="${ESC}[38;5;205m"
FUCHSIAD="${ESC}[38;5;198m"

BLUED="${ESC}[38;5;33m"
BLUEL="${ESC}[38;5;39m"

GREEND="${ESC}[38;5;2m"
GREENL="${ESC}[38;5;76m"

YELLOWD="${ESC}[38;5;184m"
YELLOWL="${ESC}[38;5;190m"

GREYD="${ESC}[38;5;240m"
GREYL="${ESC}[38;5;244m"

MAGENTA="${ESC}[38;5;5m"
CYAN="${ESC}[38;5;51m"

# #
#   Helper function: copy a file if missing
# #

copy_if_missing()
{
    SRC="$1"
    DEST="$2"

    if [ ! -e "$DEST" ]; then
        if cp -avf "$SRC" "$DEST"; then
            echo "   ${GREYD}Copied ${GREYL}$SRC${GREYD} to ${GREYL}$DEST${END}"
        else
            echo "   ${REDL}FAILED: Cannot copy ${YELLOWD}$SRC${REDL}$DEST${END}" >&2
            exit 1
        fi
    else
        echo "   ${GREYD}Already existing copy ${GREYL}$SRC${GREYD} to ${GREYL}$DEST${END}"
    fi
}

# #
#   Special copy: copy to DEST or DEST.new if DEST exists
# #

copy_or_new()
{
    SRC="$1"
    DEST="$2"

    if [ ! -e "$DEST" ]; then
        if cp -avf "$SRC" "$DEST"; then
            echo "   ${GREYD}Copied ${GREYL}$SRC${GREYD} to ${GREYL}$DEST${END}"
        else
            echo "   ${REDL}FAILED: Cannot copy ${YELLOWD}$SRC${REDL}$DEST${END}" >&2
            exit 1
        fi
    else
        if cp -avf "$SRC" "${DEST}.new"; then
            echo "   ${GREYD}Copied ${GREYL}$SRC${GREYD} to ${GREYL}$DEST.new${GREYD} (destination already existed)${END}"
        else
            echo "   ${REDL}FAILED: Cannot copy ${YELLOWD}$SRC${REDL}$DEST.new${REDL}${END}" >&2
            exit 1
        fi
    fi
}