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
#   @updated            11.25.2026
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

# set -eu

# #
#   Directory where this script lives
# #

OLDPWD=$(pwd)                                       # save current working dir
cd "$(dirname "$0")" || exit 1                      # change to the dir where the script resides
SCRIPT_DIR=$(pwd)                                   # get absolute path
cd "$OLDPWD" || exit 1                              # restore previous working dir

# #
#   Global › Declare › General
# #

APP_NAME="ConfigServer Security & Firewall"
APP_NAME_SHORT="CSF"
APP_NAME_SERVICE_CSF="CSF"
APP_NAME_SERVICE_LFD="LFD"
APP_DESC="Robust linux iptables/nftables firewall"
APP_REPO="https://github.com/aetherinox/csf-firewall"
APP_LINK_DOCS="https://docs.configserver.dev"
APP_LINK_DOWNLOAD="https://download.configserver.dev"
APP_LINK_DISCORD="https://discord.configserver.dev"
FILE_INSTALL_TXT="install.txt"

# #
#   Global › Declare › Files & Dirs
# #

CSF_ETC="/etc/csf"
CSF_VAR="/var/lib/csf"
CSF_USR="/usr/local/csf"
CSF_BIN="/usr/local/csf/bin"
CSF_TPL="/usr/local/csf/tpl"
CSF_CONF="/etc/csf/csf.conf"
CSF_CHOWN_GENERAL="root:root"
CSF_WEBMIN_SHARE_HOME="/usr/share/webmin"
CSF_WEBMIN_SHARE_DEST="${CSF_WEBMIN_SHARE_HOME}/csf"
CSF_WEBMIN_LIBEXEC_HOME="/usr/libexec/webmin"
CSF_WEBMIN_LIBEXEC_DEST="${CSF_WEBMIN_LIBEXEC_HOME}/csf"
CSF_WEBMIN_TARBALL="/usr/local/csf/csfwebmin.tgz"
CSF_WEBMIN_SYMBOLIC="${CSF_ETC}/csfwebmin.tgz"
CSF_WEBMIN_SRC="webmin"
CSF_WEBMIN_ETC="/etc/webmin"
CSF_WEBMIN_FILE_ACL="${CSF_WEBMIN_ETC}/webmin.acl"
CSF_WEBMIN_ACL_USER="root"
CSF_WEBMIN_ACL_MODULE="csf"
CSF_CWP_FOLD_SRC="csf"
CSF_CWP_PATH_DESIGN="/usr/local/cwpsrv/htdocs/admin/design/csf"
CSF_CRON_CSGET_SRC="csget.pl"
CSF_CRON_CSGET_DEST="/etc/cron.daily/csget"
CSF_CRON_CSGET_LOG="/var/log/csf/csget_daemon.log"
CSF_AUTO_GENERIC="auto.generic.pl"
CSF_AUTO_CWP="auto.cwp.pl"
CSF_AUTO_VESTA="auto.vesta.pl"
CSF_AUTO_CYBERPANEL="auto.cyberpanel.pl"
CSF_AUTO_DIRECTADMIN="auto.directadmin.pl"
CSF_AUTO_INTERWORX="auto.interworx.pl"
CSF_AUTO_CPANEL="auto.pl"

# #
#   Global › Declare › Server
# #

SERVER_HOST=$(uname -n 2>/dev/null)
: "${SERVER_HOST:=localhost}"

# #
#   Global › Declare › Files
# #

app_file_this=$(basename "$0")                                          # global.sh (with ext)
app_file_bin="${app_file_this%.*}"                                      # global    (without ext)

# #
#   Global › Declare › Folders
# #

app_dir_this="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"           # path where script was last found in
app_dir_this_usr="${PWD}"                                               # path where script is called from

# #
#   Global › Declare › Current version
# #

VERSION_FILE="$SCRIPT_DIR/version.txt"

# #
#   Extract ver from version.txt; fallback 'unknown'
# #

APP_VERSION=$( [ -f "$VERSION_FILE" ] && grep -v '^[[:space:]]*$' "$VERSION_FILE" | sed -n '1s/^[[:space:]]*//;s/[[:space:]]*$//p' || true )
: "${APP_VERSION:=unknown}"

# #
#   Global › Declare › Icons
# #

icoSheckmark='✔'   # ✔ $'\u2714'
icoXmark='✗'       # ❌ $'\u274C'

# #
#   Global › Declare › Colors
#   
#   Use the color table at:
#       - https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797
# #

esc=$(printf '\033')
end="${esc}[0m"
bgEnd="${esc}[49m"
fgEnd="${esc}[39m"
bold="${esc}[1m"
dim="${esc}[2m"
underline="${esc}[4m"
blink="${esc}[5m"
white="${esc}[97m"
black="${esc}[0;30m"
redl="${esc}[0;91m"
redd="${esc}[38;5;196m"
magental="${esc}[38;5;197m"
magentad="${esc}[38;5;161m"
fuchsial="${esc}[38;5;206m"
fuchsiad="${esc}[38;5;199m"
bluel="${esc}[38;5;33m"
blued="${esc}[38;5;27m"
greenl="${esc}[38;5;47m"
greend="${esc}[38;5;35m"
orangel="${esc}[38;5;208m"
oranged="${esc}[38;5;202m"
yellowl="${esc}[38;5;226m"
yellowd="${esc}[38;5;214m"
greyl="${esc}[38;5;250m"
greym="${esc}[38;5;244m"
greyd="${esc}[38;5;240m"
navy="${esc}[38;5;62m"
olive="${esc}[38;5;144m"
peach="${esc}[38;5;204m"
cyan="${esc}[38;5;6m"
bgVerbose="${esc}[1;38;5;15;48;5;125m"
bgDebug="${esc}[1;38;5;15;48;5;237m"
bgInfo="${esc}[1;38;5;15;48;5;27m"
bgOk="${esc}[1;38;5;15;48;5;64m"
bgWarn="${esc}[1;38;5;16;48;5;214m"
bgDanger="${esc}[1;38;5;15;48;5;202m"
bgError="${esc}[1;38;5;15;48;5;160m"

# #
#   Global › Declare › Logging functions
#   
#   verbose "This is an verbose message"
#   debug "This is an debug message"
#   info "This is an info message"
#   ok "This is an ok message"
#   warn "This is a warn message"
#   danger "This is a danger message"
#   error "This is an error message"
# #

verbose( )
{
    case "${argVerbose:-0}" in
        1|true|TRUE|yes|YES)
            printf '\033[0m\r%-42s %-65s\n' "   ${bgVerbose} VRBO ${end}" "${greym} $1 ${end}"
            ;;
    esac
}

debug( )
{
    if [ "$argDevEnabled" = "true" ] || [ "$argDryrun" = "true" ]; then
        printf '\033[0m\r%-42s %-65s\n' "   ${bgDebug} DBUG ${end}" "${greym} $1 ${end}"
    fi
}

info( )
{
    printf '\033[0m\r%-41s %-65s\n' "   ${bgInfo} INFO ${end}" "${greym} $1 ${end}"
}

ok( )
{
    printf '\033[0m\r%-41s %-65s\n' "   ${bgOk} PASS ${end}" "${greym} $1 ${end}"
}

warn( )
{
    printf '\033[0m\r%-42s %-65s\n' "   ${bgWarn} WARN ${end}" "${greym} $1 ${end}"
}

danger( )
{
    printf '\033[0m\r%-42s %-65s\n' "   ${bgDanger} DNGR ${end}" "${greym} $1 ${end}"
}

error( )
{
    printf '\033[0m\r%-42s %-65s\n' "   ${bgError} FAIL ${end}" "${greym} $1 ${end}"
}

label( )
{
    printf '\033[0m\r%-31s %-65s\n' "   ${greyd}        ${end}" "${greyd} $1 ${end}"
}

print( )
{
    echo "${greym}$1${end}"
}

# #
#   Global › Truncate
#   
#   truncates text; add ...
#   
#   @usage      truncate "This is a long string" 10 "..."
# #

truncate()
{
    truncate_text=$1
    maxlen=$2
    suffix=${3:-}

    len=$(printf %s "${truncate_text}" | wc -c | tr -d '[:space:]')

    if [ "${len}" -gt "${maxlen}" ]; then
        printf '%s%s\n' "$(printf %s "${truncate_text}" | cut -c1-"${maxlen}")" "${suffix}"
    else
        printf '%s\n' "${truncate_text}"
    fi
}

# #
#   Global › Print › Demo Notifications
#   
#   Outputs a list of example notifications
#   
#   @usage      demoNoti
# #

demoNoti()
{
    verbose "This is an verbose message"
    debug "This is an debug message"
    info "This is an info message"
    ok "This is an ok message"
    warn "This is a warn message"
    danger "This is a danger message"
    error "This is an error message"
}

# #
#   Global › Print › Line
#   
#   Prints single line horizontal line, no text.
#   
#   @usage      prin0
# #

prin0()
{
    _p0_indent="  "
    _p0_box_w=110
    _p0_line=""
    _p0_line_w=$(( _p0_box_w + 2 ))

    _p0_i=1
    while [ "$_p0_i" -le "${_p0_line_w}" ]; do
        _p0_line="${_p0_line}─"
        _p0_i=$(( _p0_i + 1 ))
    done

    printf '\n'
    printf "%b%s%s%b\n" "${greyd}" "${_p0_indent}" "${_p0_line}" "${reset}"
    printf '\n'

    unset   _p0_indent _p0_box_w _p0_line_w _p0_line _p0_i
}

# #
#   Global › Print › Box › Single
#   
#   Print single line with a box surrounding it, accepts text.
#   
#   @usage      prinb "${APP_NAME_SHORT:-CSF} › Customize csf.config"
# #

prinb()
{
    _pb_title="$*"
    _pb_indent="   "                                                            # Left padding
    _pb_pad=6                                                                   # Extra horizontal space around text
    _pb_title_len=${#_pb_title}
    _pb_inner_w=$(( _pb_title_len + _pb_pad ))
    _pb_box_w=110

    # Min width for aesthetics
    if [ "$_pb_inner_w" -lt "$_pb_box_w" ]; then
        _pb_inner_w=$_pb_box_w
    fi

    # Horizontal border
    _pb_line=""
    _pb_i=1
    while [ "$_pb_i" -le "$_pb_inner_w" ]; do
        _pb_line="${_pb_line}─"
        _pb_i=$(( _pb_i + 1 ))
    done

    # Draw box
    printf '\n'
    printf '\n'
    printf "%b%s┌%s┐\n" "${greym}" "$_pb_indent" "$_pb_line"
    printf "%b%s│  %-${_pb_inner_w}s \n" "${greym}" "$_pb_indent" "$_pb_title"
    printf "%b%s└%s┘%b\n" "${greym}" "$_pb_indent" "$_pb_line" "${reset}"
    printf '\n'

    unset   _pb_title _pb_indent _pb_pad \
            _pb_title_len _pb_inner_w _pb_box_w \
            _pb_line _pb_i
}

# #
#   Global › Print › Box › Paragraph
#   
#   Places an ASCII box around text. Supports multi-lines with \n.
#   
#   Determine the char count if color codes are used, ensure that the
#   box borders are aligned properly.
#   
#   If using emojis; adjust the spacing so that the right side line
#   aligns with the rest. Add the number of spaces to increase the
#   value, which is specified with a number enclosed in square
#   brackets.
#       [1]     add 1 space to the right.
#       [2]     add 2 spaces to the right.
#       [-1]    remove 1 space from the right
#                   needed for some emojis, if the emoji takes 1 or 2 bytes
#   
#   @usage      prinp "Cert Generation Successful" "Your new cert and keys have been generated successfully.\n\nFind them in ${greenl}${app_dir_output}${greyd} folder."
#               prinp "🎗️[1]  ${file_domain_base}" "The following desc will shows on multiple lines with ASCII box around it."
#               prinp "📄[-1] File Overview" "The following list outlines files you have generated using this util, and what certs/keys are missing."
#               prinp "➡️[15]  ${bluel}Paths${end}"
# #

prinp()
{
    _pp_title="$1"
    shift
    _pp_text="$*"

    _pp_indent="  "
    _pp_box_w=110
    _pp_pad=1

    _pp_content_w=$(( _pp_box_w ))
    _pp_inner_w=$(( _pp_box_w - _pp_pad*2 ))

    print
    print

    _pp_hline=""
    _pp_i=1

    while [ "$_pp_i" -le "$_pp_content_w" ]; do
        _pp_hline="${_pp_hline}─"
        _pp_i=$(( _pp_i + 1 ))
    done

    printf "${greyd}%s┌%s┐\n" "$_pp_indent" "$_pp_hline"

    # #
    #   Title
    #   
    #   Extract optional [N] adjustment from title (signed int)
    # #

    _pp_emoji_adjust=0
    _pp_display_title="$_pp_title"

    # #
    #   Get content inside first [...] (if present)
    # #

    if printf '%s\n' "$_pp_title" | grep -q '\[[[:space:]]*[-0-9][-0-9[:space:]]*\]'; then

        # #
        #   Read title spacing adjustment from [N]
        #       [1]     add +1 space
        #       [-1]    remove -1 space
        #   
        #   eg:     prinp "🎗️[1]  Example" "Box with +1 adjustment for 1 byte emoji"
        # #

        _pp_bracket=$(printf '%s' "$_pp_title" | sed -n 's/.*\[\([-0-9][-0-9]*\)\].*/\1/p')

        # #
        #   Validate numeric and assign, otherwise fallback to 0
        # #
    
        if printf '%s\n' "$_pp_bracket" | grep -qE '^-?[0-9]+$'; then
            _pp_emoji_adjust=$_pp_bracket
        else
            _pp_emoji_adjust=0
        fi

        # #
        #   Remove the first [...] token from the _pp_display_title
        # #
    
        _pp_display_title=$(printf '%s' "$_pp_title" | sed 's/\[[^]]*\]//')
    fi

    # #
    #   Sanity: ensure _pp_emoji_adjust is a decimal integer so math works
    # #

    case "$_pp_emoji_adjust" in
        ''|*[!0-9-]*)
            _pp_emoji_adjust=0
            ;;
    esac

    _pp_title_w=$(( _pp_content_w - _pp_pad ))

    # #
    #   Adjust title spacing, keeps the right box border aligned
    # #
  
    _pp_title_vis_len=$(( ${#_pp_display_title} - _pp_emoji_adjust ))
    printf "${greyd}%s│%*s${bluel}%s${greyd}%*s│\n" \
        "$_pp_indent" "$_pp_pad" "" "$_pp_display_title" "$(( _pp_title_w - _pp_title_vis_len ))" ""

    # #
    #   Only render body text ( if provided )
    # #

    if [ -n "$_pp_text" ]; then
        printf "${greyd}%s│%-${_pp_content_w}s│\n" "$_pp_indent" ""

        # #
        #   Convert literal \n to real newlines
        # #

        _pp_text=$(printf "%b" "$_pp_text")

        # #
        #   Read each line, wrap long text, keep box's lines aligned
        # #

        printf "%s" "$_pp_text" | while IFS= read -r _pp_line || [ -n "$_pp_line" ]; do

        # #
        #   Blank line
        # #
    
        if [ -z "$_pp_line" ]; then
            printf "${greyd}%s│%-*s│\n" "$_pp_indent" "$_pp_content_w" ""
            continue
        fi

        _pp_out=""
        _pp_word=""

        for _pp_word in $_pp_line; do
            # #
            #   Remove ansi color codes, before calculating text width
            #   
            #   _pp_vis_out     Current line with color codes removed
            #   _pp_vis_len     Visible line len if current word is added
            #   _pp_vis_word    Current word with color codes removed
            #   
            #   eg:     prinp "CSF > Web Interface" "Information about the CSF web interface."
            #   
            #   Loop 1  _pp_line        Information about the CSF web interface.
            #           _pp_out 
            #           _pp_word        Information
            #           _pp_vis_out     
            #           _pp_vis_word    Information
            #           _pp_vis_len     11
            #           _pp_content_w   110
            #           _pp_inner_w     108
            #   
            #   Loop 2  _pp_line        Information about the CSF web interface.
            #           _pp_out         Information
            #           _pp_word        about
            #           _pp_vis_out     Information
            #           _pp_vis_word    about
            #           _pp_vis_len     17
            #           _pp_content_w   110
            #           _pp_inner_w     108
            #   
            #           [...]
            #   
            #   Loop 6  _pp_line        Information about the CSF web interface.
            #           _pp_out         Information about the CSF web
            #           _pp_word        interface.
            #           _pp_vis_out     Information about the CSF web
            #           _pp_vis_word    interface.
            #           _pp_vis_len     40          40 ( 29 + 1 space + 10 )
            #           _pp_content_w   110
            #           _pp_inner_w     108
            # #
        
            _pp_vis_out=""
            _pp_vis_len=""
            _pp_vis_word=""

            _pp_vis_out=$(printf "%s" "$_pp_out" | sed "s/${esc}\[[0-9;]*[A-Za-z]//g")
            _pp_vis_word=$(printf "%s" "$_pp_word" | sed "s/${esc}\[[0-9;]*[A-Za-z]//g")
            _pp_vis_len=$(( ${#_pp_vis_out} + ( ${#_pp_vis_out} > 0 ? 1 : 0 ) + ${#_pp_vis_word} ))

            if [ -z "$_pp_out" ]; then
                _pp_out="$_pp_word"
            elif [ $_pp_vis_len -le $_pp_inner_w ]; then
                _pp_out="$_pp_out $_pp_word"
            else
                # #
                #   Print and pad manually based on visible len
                # #

                _pp_vis_len_full=""
                _pp_pad_spaces=""

                _pp_vis_len_full=$(printf "%s" "$_pp_out" | sed "s/${esc}\[[0-9;]*[A-Za-z]//g" | wc -c | tr -d ' ')
                _pp_pad_spaces=$(( _pp_inner_w - _pp_vis_len_full ))
                [ $_pp_pad_spaces -lt 0 ] && _pp_pad_spaces=0
                printf "${greyd}%s│%*s%s%*s│\n" "$_pp_indent" "$_pp_pad" "" "$_pp_out" "$(( _pp_pad + _pp_pad_spaces ))" ""
                _pp_out="$_pp_word"
            fi

        done

        # #
        #   Final flush line
        # #
    
        if [ -n "$_pp_out" ]; then
            _pp_vis_len_full=""
            _pp_pad_spaces=""

            _pp_vis_len_full=$(printf "%s" "$_pp_out" | sed "s/${esc}\[[0-9;]*[A-Za-z]//g" | wc -c | tr -d ' ')
            _pp_pad_spaces=$(( _pp_inner_w - _pp_vis_len_full ))
            [ $_pp_pad_spaces -lt 0 ] && _pp_pad_spaces=0
            printf "${greyd}%s│%*s%s%*s│\n" "$_pp_indent" "$_pp_pad" "" "$_pp_out" "$(( _pp_pad + _pp_pad_spaces ))" ""
        fi

        done
    fi

    printf "${greyd}%s└%s┘${reset}\n" "$_pp_indent" "$_pp_hline"
    print

    unset   _pp_title _pp_text _pp_indent _pp_box_w _pp_pad \
            _pp_content_w _pp_inner_w _pp_hline _pp_i \
            _pp_emoji_adjust _pp_display_title _pp_bracket \
            _pp_title_w _pp_title_vis_len _pp_line _pp_out \
            _pp_word _pp_vis_out _pp_vis_len _pp_vis_word \
            _pp_vis_len_full _pp_pad_spaces
}

# #
#   Global › Logging › Verbose
# #

log()
{
    case "${argVerbose:-0}" in
        1|true|TRUE|yes|YES)
            verbose "$@"
            ;;
    esac
}

# #
#   Global › Check Sudo
# #

check_sudo( )
{
    if [ "$(id -u)" != "0" ]; then
        error "    ❌ Must run script with ${redl}sudo${end}"
        exit 1
    fi
}

# #
#   Global › Run Command
#   
#   Added when dryrun mode was added to the install.sh.
#   Allows for a critical command to be skipped if in --dryrun mode.
#       Throws a debug message instead of executing.
#   
#   argDryrun comes from global export in csf/install.sh
#   
#   @usage      run /sbin/chkconfig csf off
#               run echo "ConfigServer"
#               run chmod -v 700 "./${CSF_AUTO_GENERIC}"
# #

run()
{
    if [ "${argDryrun}" = "true" ]; then
        debug "    Drymode (skip): $*"
    else
        debug "    Run: $*"
        "$@"
    fi
}

# #
#   Global › Copy
#   
#   Custom copy function to replace 'cp'; handles copy a bit differently but
#   with the same behavior.
#   
#   @usage      ›   Copy file into existing dir:
#                       copi 'csfpre.sh' '/usr/local/csf/bin'
#   
#               ›   Copy file into a dir that may not exist:
#                       copi 'csfpre.sh' '/usr/local/csf/bin/'
#                       copi 'csfpre.sh' '/usr/local/csf/bin/.'
#   
#               ›   Copy file to a specific dest filename:
#                       copi 'config.txt' '/etc/csf/config.txt'
#   
#               ›   Copy only if dest does not exist:
#                       copi --if-missing 'config.txt' '/etc/csf/config.txt'
#   
#                       Replaces old 'copy_if_missing()' func:
#                           Old:    copy_if_missing 'src' 'dest'
#   
#               ›   Copy to dest.new if dest already exists:
#                       copi --or-new 'config.txt' '/etc/csf/config.txt'
#   
#                       Replaces old 'copy_or_new()' func:
#                           Old:    copy_or_new 'src' 'dest'
#   
#               ›   Copy dir tree to exact dest (no '/' at the end):
#                       copi './tpl' '/usr/local/csf/tpl'
#   
#               ›   Copy dir into a parent dir ('/' or '/.' at the end):
#                       copi './webmin' '/var/lib/csf/'
#                       copi './webmin' '/var/lib/csf/.'
#
#               ›   Error handling:
#                       copi '/missing/badfile' '/tmp/'             # returns "3" (src missing)
#                       copi '/etc/passwd' '/proc/csf-copy-test/'   # returns "1" (mkdir failed)
#                       copi '/etc/passwd' '/missing/dir/passwd'    # returns "2" (copy failed)
#   
#   @return     0   Success
#               1   Failed to create dest dirs
#               2   Failed file copy
#               3   Source does not exist / unsupported type
#               4   Invalid opt or number of args
#   
#   @notes      - '/path/to/dir/'       treated as dir
#               - '/path/to/dir/.'      treated as dir
#               - Dest dirs auto created (if required)
#               - Dir copies preserve dir struct and timestamps
# #

copi()
{
    _c_opt="overwrite"

    # #
    #   Options:
    #       --if-missing        Replaces old func 'copy_if_missing()'
    #           Eg:                 copi --if-missing 'config.txt' '/etc/csf/config.txt'
    #   
    #       --or-new            Replaces old func 'copy_or_new()'
    #           Eg:                 copi --or-new 'config.txt' '/etc/csf/config.txt'
    # #

    case "${1:-}" in
        --if-missing)
            _c_opt="if-missing"
            shift
            ;;
        --or-new)
            _c_opt="or-new"
            shift
            ;;
        --)
            shift
            ;;
        --*)
            warn "    Unknown copi option ${yellowl}${1}${end}"
            return 4
            ;;
    esac

    if [ "$#" -ne 2 ]; then
        warn "    copi requires a src and dest"
        return 4
    fi

    _c_src="$1"
    _c_dest="$2"

    # #
    #   Compat options for removed copy functions:
    #       copy_if_missing()
    #       copy_or_new()
    # #

    case "${_c_opt}" in
        if-missing)
            if [ -e "${_c_dest}" ] || [ -L "${_c_dest}" ]; then
                label "     Dest already exists; skipping ${navy}${_c_dest}${end}"
                return 0
            fi
            ;;
        or-new)
            if [ -e "${_c_dest}" ] || [ -L "${_c_dest}" ]; then
                _c_dest="${_c_dest}.new"
                label "     Dest already exists; copying to ${navy}${_c_dest}${end}"
            fi
            ;;
    esac

    # #
    #   Src must exist
    # #

    if [ ! -e "${_c_src}" ]; then
        warn "    No such file or directory ${yellowl}${_c_src}${end}"
        return 3
    fi

    # #
    #   File || symlink copy mode
    # #

    if [ -f "${_c_src}" ] || [ -L "${_c_src}" ]; then

        # #
        #   If _c_dest is an existing dir; copy into it
        # #
    
        if [ -d "${_c_dest}" ]; then
            fname=$(basename "${_c_src}")
            label "     Copying ${navy}${fname}${greym} › ${navy}${_c_dest}${end}"
            cp -p "${_c_src}" "${_c_dest}/$fname" || return 2
            return 0
        fi

        # #
        #   Handle dir intent:
        #       ends in '/' OR ends in '/.'
        # #

        case "${_c_dest}" in
            */ | */.)
                # #
                #   Normalize '/.' to '/'
                # #

                d="${_c_dest%/.}"

                mkdir -p "${d}" || return 1
                fname=$(basename "${_c_src}")

                label "     Copying ${navy}${fname}${greym} › ${navy}${d}${end}"
                cp -p "${_c_src}" "${d}/${fname}" || return 2

                return 0
                ;;
        esac

        # #
        #   Otherwise treat _c_dest as a file path
        # #
    
        label "     Copying ${navy}${_c_src}${greym} › ${navy}${_c_dest}${end}"
        cp -p "${_c_src}" "${_c_dest}" || return 2

        return 0
    fi

    # #
    #   Dir copy mode
    # #

    if [ -d "${_c_src}" ]; then
        (
            _c_dir_dest="${_c_dest}"

            # #
            #   Trailing '/' or '/.':
            #       Makes the dest a parent dir.
            #       Append src dir name to create the final dest.
            # #

            case "${_c_dest}" in
                */ | */.)
                    _c_dir_parent="${_c_dest%/.}"
                    _c_dir_parent="${_c_dir_parent%/}"
                    _c_dir_name=$(basename "${_c_src%/}")

                    if [ -z "${_c_dir_parent}" ]; then
                        _c_dir_dest="/${_c_dir_name}"
                    else
                        _c_dir_dest="${_c_dir_parent}/${_c_dir_name}"
                    fi
                    ;;
            esac

            mkdir -p "${_c_dir_dest}" || exit 1
            cd "${_c_src}" || exit 1

            # #
            #   Recreate dir tree
            # #

            find . -type d -print | while IFS= read -r _c_tree_dir; do
                mkdir -p "${_c_dir_dest}/${_c_tree_dir}" || {
                    error "    Failed mkdir ${redl}${_c_dir_dest}/${_c_tree_dir}"
                    exit 1
                }
            done || exit 1

            # #
            #   Copy files
            # #

            find . -type f -print | while IFS= read -r _c_file; do
                label "     Copying ${navy}${_c_file}${greym} › ${navy}${_c_dir_dest}${end}"

                mkdir -p "${_c_dir_dest}/$(dirname "${_c_file}")" || {
                    error "    Failed mkdir ${redl}${_c_dir_dest}/$(dirname "${_c_file}")"
                    exit 1
                }

                cp -p "${_c_file}" "${_c_dir_dest}/${_c_file}" || {
                    error "    Failed copying ${redl}${_c_file}"
                    exit 2
                }
            done || exit 2
        )

        return $?
    fi

    # #
    #   Unknown type
    # #

    warn "    No such file or dir ${yellowl}${_c_src}${greym}"

    return 3
}

# #
#   Global › Get CSF Config
#   
#   Reads /etc/csf/csf.conf, fetches current settings for CSF web
#   interface.
#   
#   if UI = "1", CSF installer will print the following in terminal:
#       Status .......  ✔ enabled
#       Url ..........  http://127.0.0.1:6666
#       Username ...... username
#       Password ...... password
#   
#   Grabs the settings:
#       UI_IP           Web ui bind address
#       UI_PORT         Web ui port
#       UI_USER         Web ui username
#       UI_PASS         Web ui password
#   
#   Default values:
#       UI_IP = ""      use 127.0.0.1
#       UI_PORT = ""    use 6666
#   
#   @usage      _install_webui_creds=$(csf_getcfg)
#   
#   @return     0   Config read and output printed
#               1+  CSF_CONF does not exist OR output couldn't print
# #

csf_getcfg()
{
    if [ ! -f "${CSF_CONF}" ]; then
        return 1
    fi

    _csf_ui_enabled=""
    _csf_ui_port=""
    _csf_ui_ip=""
    _csf_ui_user=""
    _csf_ui_pass=""
    _csf_ui_values=""

    # #
    #   Extract config data
    # #

    _csf_ui_values=$(awk '
        /^[[:space:]]*UI[[:space:]]*=/ { gsub(/"/,"",$3); print "UI="$3 }
        /^[[:space:]]*UI_PORT[[:space:]]*=/ { gsub(/"/,"",$3); print "PORT="$3 }
        /^[[:space:]]*UI_IP[[:space:]]*=/ { gsub(/"/,"",$3); print "IP="$3 }
        /^[[:space:]]*UI_USER[[:space:]]*=/ { gsub(/"/,"",$3); print "USER="$3 }
        /^[[:space:]]*UI_PASS[[:space:]]*=/ { gsub(/"/,"",$3); print "PASS="$3 }
    ' "${CSF_CONF}")

    while IFS='=' read -r _csf_ui_key _csf_ui_value
    do
        case "${_csf_ui_key}" in
            UI)     _csf_ui_enabled="${_csf_ui_value}" ;;
            PORT)   _csf_ui_port="${_csf_ui_value}" ;;
            IP)     _csf_ui_ip="${_csf_ui_value}" ;;
            USER)   _csf_ui_user="${_csf_ui_value}" ;;
            PASS)   _csf_ui_pass="${_csf_ui_value}" ;;
        esac
    done <<EOF
${_csf_ui_values}
EOF

    if [ "${_csf_ui_enabled}" != "1" ]; then
        printf '%s\n' ""
    else
        [ -z "${_csf_ui_ip}" ] && _csf_ui_ip="127.0.0.1"
        [ -z "${_csf_ui_port}" ] && _csf_ui_port="6666"

        printf '%s:%s\n%s\n%s\n' \
            "${_csf_ui_ip}" \
            "${_csf_ui_port}" \
            "${_csf_ui_user}" \
            "${_csf_ui_pass}"
    fi

    _csf_ui_status=$?
    set -- "${_csf_ui_status}"

    unset   _csf_ui_enabled _csf_ui_port _csf_ui_ip \
            _csf_ui_user _csf_ui_pass _csf_ui_values \
            _csf_ui_key _csf_ui_value _csf_ui_status

    return "$1"
}

# #
#   Global › Install Complete
#   
#   Print installation status after CSF is installed.
#   Checks several factors of the installation, including:
#       -   CSF web ui username should not be 'username' or [EMPTY].
#       -   CSF web ui password should not be 'password' or [EMPTY].
#   
#   @params     void
#   @return     0   Output completed
# #

install_complete()
{
    prinp "${APP_NAME_SHORT:-CSF} > Installation Complete" \
           "Your installation is now complete. Review the notes below on getting started with the firewall."

    print "    ${greym}For complete ${APP_NAME_SHORT:-CSF} documentation; visit:"
    print "        ${yellowd}${APP_LINK_DOCS:-https://docs.configserver.dev}"
    print "    "
    print "    ${greym}All settings for ${APP_NAME_SHORT:-CSF} are found in the file:${end}"
    print "        ${bluel}${CSF_CONF}"
    print "    "
    print "    ${greym}If you are a ${magental}${bold}SPONSOR${end}${greym} with a license key, set the following line in your config ${bluel}${CSF_CONF}${end}:"
    print "        ${yellowd}SPONSOR_LICENSE ${white}= \"${bluel}XXXXXX-XXXX-XXXX-XXXXXX${white}\"${end}"

    if [ -f "${CSF_CONF}" ]; then
        _install_testing_value=$(grep '^[[:space:]]*TESTING[[:space:]]*=' "${CSF_CONF}" |
            awk -F= '{gsub(/ /,"",$2); print $2}' | tr -d '"')

        _install_webui_creds=$(csf_getcfg)

        print "    "
        print "    ${greym}Before you start ${APP_NAME_SHORT:-CSF}; the setting ${yellowd}${bold}TESTING${end}${greym} must be ${redl}${bold}DISABLED${end}${greym}. ${APP_NAME_SERVICE_LFD:-LFD} service will not start if this is enabled.${end}"

        if [ "${_install_testing_value}" = "1" ]; then
            print "        ${redl}${icoXmark}${greym} ${redl}This setting is currently enabled ${redl}${bold}[WARN]${end}"
            print "        ${greym}Disable by opening the file ${bluel}${CSF_CONF}${greym} and set:${end}"
            print "            ${yellowd}TESTING ${white}= \"${bluel}0${white}\"${end}"
        else
            print "        ${greenl}${icoSheckmark}${greym} ${greenl}This setting is currently disabled ${greenl}${bold}[OK]${end}"
            print "        ${greym}To test ${APP_NAME_SHORT:-CSF}, edit the file ${bluel}${CSF_CONF}${greym}:${end}"
            print "            ${yellowd}TESTING ${white}= \"${bluel}1${white}\"${end}"
        fi

        print "    "
        print "    ${greym}After you have configured ${bluel}${CSF_CONF}${greym}, restart all ${APP_NAME_SHORT:-CSF} services to apply changes:${end}"
        print "        ${yellowd}sudo csf -ra${end}"

        prinp "${APP_NAME_SHORT:-CSF} > Web Interface" \
            "Information about the ${APP_NAME_SHORT:-CSF} web interface."

        if [ -n "${_install_webui_creds}" ]; then
            _install_webui_addr=""
            _install_webui_user=""
            _install_webui_pass=""

            {
                IFS= read -r _install_webui_addr
                IFS= read -r _install_webui_user
                IFS= read -r _install_webui_pass || :
            } <<EOF
${_install_webui_creds}
EOF

            print "    ${greym}Status ..........  ${greenl}${icoSheckmark}${greym} ${greenl}enabled${end}"
            print "    ${greym}Url .............  ${yellowd}http://${_install_webui_addr}${end}"

            # #
            #   Print csf.conf username or [EMPTY]
            # #

            if [ -z "${_install_webui_user}" ]; then
                print "    ${greym}Username ......... ${redl}[EMPTY]${end}"
            else
                print "    ${greym}Username ......... ${yellowd}${_install_webui_user}${end}"
            fi

            # #
            #   Print csf.conf password or [EMPTY]
            # #

            if [ -z "${_install_webui_pass}" ]; then
                print "    ${greym}Password ......... ${redl}[EMPTY]${end}"
            else
                print "    ${greym}Password ......... ${yellowd}${_install_webui_pass}${end}"
            fi

            print "    "

            # #
            #   CSF web UI username cannot be:
            #       empty, username, admin
            # #

            case "${_install_webui_user}" in
                "")
                    error "    ${greym}${APP_NAME_SHORT:-CSF} web interface setting ${redl}${bold}UI_USER${end}${greym} is ${redl}${bold}EMPTY${end}"
                    label "     ${greym}Set ${yellowd}${bold}UI_USER${end}${greym} in ${bluel}${CSF_CONF}${greym} before using the web interface.${end}"
                    print "    "
                    ;;
                username|admin)
                    error "    ${greym}${APP_NAME_SHORT:-CSF} web interface setting ${redl}${bold}UI_USER${end}${greym} has insecure default value ${redl}'${_install_webui_user}'${end}"
                    label "     ${greym}You MUST change ${yellowd}${bold}UI_USER${end}${greym} in ${bluel}${CSF_CONF}${greym} before using the web interface.${end}"
                    print "    "
                    ;;
            esac

            # #
            #   CSF web UI password cannot be:
            #       empty, password, pass
            # #

            case "${_install_webui_pass}" in
                "")
                    error "    ${greym}${APP_NAME_SHORT:-CSF} web interface setting ${redl}${bold}UI_PASS${end}${greym} is ${redl}${bold}EMPTY${end}"
                    label "     ${greym}Set ${yellowd}${bold}UI_PASS${end}${greym} in ${bluel}${CSF_CONF}${greym} before using the web interface.${end}"
                    print "    "
                    ;;
                password|pass)
                    error "    ${greym}${APP_NAME_SHORT:-CSF} web interface setting ${redl}${bold}UI_PASS${end}${greym} has insecure default value ${redl}${bold}'${_install_webui_pass}'${end}"
                    label "     ${greym}You MUST change ${yellowd}${bold}UI_PASS${end}${greym} in ${bluel}${CSF_CONF}${greym} before using the web interface.${end}"
                    print "    "
                    ;;
            esac
        else
            warn "    ${greym}${APP_NAME_SHORT:-CSF} web interface is currently disabled, and will not be accessible.${end}"
            label "     ${greym}Set ${yellowd}${bold}UI = \"1\" ${end}${greym} in ${bluel}${CSF_CONF}${greym}, and then restart ${APP_NAME_SERVICE_CSF:-CSF}/${APP_NAME_SERVICE_LFD:-LFD}:${end}"
            label "        ${yellowd}sudo csf -ra${end}"
            print "    "
        fi
    else
        print "    ${redl}${icoXmark} Error! cannot locate your ${APP_NAME_SHORT:-CSF} config file.${end}"
        print "    "
        print "    ${greyd}After adding a ${bluel}${CSF_CONF}${greym} config file, restart all ${APP_NAME_SHORT:-CSF}${end}"
        print "    ${greyd}services for changes to apply${end}"
        print "        ${yellowd}sudo csf -ra${end}"
    fi

    print
    print

    unset   _install_testing_value _install_webui_creds \
            _install_webui_addr _install_webui_user _install_webui_pass

    return 0
}
