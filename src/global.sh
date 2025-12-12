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
#   @updated            12.10.2025
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
APP_LINK_DISCORD="https://discord.configserver.dev"
FILE_INSTALL_TXT="install.txt"

# #
#   Define › Files & Dirs
# #

CSF_ETC="/etc/csf"
CSF_VAR="/var/lib/csf"
CSF_USR="/usr/local/csf"
CSF_BIN="/usr/local/csf/bin"
CSF_TPL="/usr/local/csf/tpl"
CSF_CONF="/etc/csf/csf.conf"
CSF_CHOWN_GENERAL="root:root"
CSF_WEBMIN_HOME="/usr/share/webmin"
CSF_WEBMIN_TARBALL="/usr/local/csf/csfwebmin.tgz"
CSF_WEBMIN_SYMBOLIC="${CSF_ETC}/csfwebmin.tgz"
CSF_WEBMIN_SRC="webmin"
CSF_WEBMIN_DESC="${CSF_WEBMIN_HOME}/csf"
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
#   Define › Icons
# #

icoSheckmark='✔'   # ✔ $'\u2714'
icoXmark='✗'       # ❌ $'\u274C'

# #
#   Define › Colors
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
#   Define › Logging functions
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
#   truncate text; add ...
#   
#   @usage
#       truncate "This is a long string" 10 "..."
# #

truncate()
{
    text=$1
    maxlen=$2
    suffix=${3:-}

    len=$(printf %s "${text}" | wc -c | tr -d '[:space:]')

    if [ "${len}" -gt "${maxlen}" ]; then
        printf '%s%s\n' "$(printf %s "${text}" | cut -c1-"${maxlen}")" "${suffix}"
    else
        printf '%s\n' "${text}"
    fi
}

# #
#   Print › Demo Notifications
#   
#   Outputs a list of example notifications
#   
#   @usage          demoNoti
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
#   Print › Line
#   
#   Prints single line, no text
#   
#   @usage          prin0
# #

prin0()
{
    local indent="   "
    local box_width=110
    local line_width=$(( box_width + 2 ))

    local line
    line=$(printf '─%.0s' $(seq 1 "$line_width"))

    print
    printf "%b%s%s%b\n" "${greyd}" "$indent" "$line" "${reset}"
    print
}

# #
#   Print › Box › Crop
#   
#   Prints single line with a box surrounding it, excluding the right side
#   
#   @usage          princ "Name › Section"
# #

princ()
{
    local title="$*"
    local indent="   "
    local padding=6
    
    local visible_title
    visible_title=$(echo -e "$title" | sed 's/\x1b\[[0-9;]*m//g')
    
    local title_length=${#visible_title}
    local inner_width=$(( title_length + padding ))
    local box_width=110

    [ "$inner_width" -lt ${box_width} ] && inner_width=${box_width}

    local line
    line=$(printf '─%.0s' $(seq 1 "$inner_width"))

    local spaces_needed=$(( inner_width - title_length - 3 ))
    local spaces=$(printf ' %.0s' $(seq 1 "$spaces_needed"))

    print
    printf "%b%s┌%s┐\n" "${greym}" "$indent" "$line"
    printf "%b%s│  %s%s \n" "${greym}" "$indent" "$title" "$spaces"
    printf "%b%s└%s┘%b\n" "${greym}" "$indent" "$line" "${reset}"
    print
}

# #
#   Print › Box › Single
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
    local box_width=110

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
    printf "%b%s│  %-${inner_width}s \n" "${greym}" "$indent" "$title"
    printf "%b%s└%s┘%b\n" "${greym}" "$indent" "$line" "${reset}"
    print
}

# #
#   Print › Box › Paragraph
#   
#   Places an ASCII box around text. Supports multi-lines with \n.
#   
#   Determines the character count if color codes are used and ensures that the box borders are aligned properly.
#   
#   If using emojis; adjust the spacing so that the far-right line will align with the rest. Add the number of spaces
#   to increase the value, which is represented with a number enclosed in square brackets.
#     [1]           add 1 space to the right.
#     [2]           add 2 spaces to the right.
#     [-1]          remove 1 space to the right (needed for some emojis depending on if the emoji is 1 or 2 bytes)
#   
#   @usage          prinp "Certificate Generation Successful" "Your new certificate and keys have been generated successfully.\n\nYou can find them in the ${greenl}${app_dir_output}${greyd} folder."
#                   prinp "🎗️[1]  ${file_domain_base}" "The following description will show on multiple lines with a ASCII box around it."
#                   prinp "📄[-1] File Overview" "The following list outlines the files that you have generated using this utility, and what certs/keys may be missing."
#                   prinp "➡️[15]  ${bluel}Paths${end}"
# #

prinp()
{
    local title="$1"
    shift
    local text="$*"

    local indent="  "
    local box_width=110
    local pad=1

    local content_width=$(( box_width ))
    local inner_width=$(( box_width - pad*2 ))

    print
    print

    local hline
    hline=$(printf '─%.0s' $(seq 1 "$content_width"))

    printf "${greyd}%s┌%s┐\n" "$indent" "$hline"

    # #
    #   Title
    #   
    #   Extract optional [N] adjustment from title (signed integer), portably
    # #

    local emoji_adjust=0
    local display_title="$title"

    # #
    #   Get content inside first [...] (if present)
    # #

    if printf '%s\n' "$title" | grep -q '\[[[:space:]]*[-0-9][-0-9[:space:]]*\]'; then

        # #
        #   Extract numeric inside brackets (allow optional leading -)
        #   - use sed to capture first bracketed token, then strip non-digit except leading -
        # #

        local bracket
        bracket=$(printf '%s' "$title" | sed -n 's/.*\[\([-0-9][-0-9]*\)\].*/\1/p')

        # #
        #   Validate numeric and assign, otherwise fallback to 0
        # #
    
        if printf '%s\n' "$bracket" | grep -qE '^-?[0-9]+$'; then
            emoji_adjust=$bracket
        else
            emoji_adjust=0
        fi

        # #
        #   Remove the first [...] token from the display_title
        # #
    
        display_title=$(printf '%s' "$title" | sed 's/\[[^]]*\]//')
    fi

    # #
    #   Sanity: ensure emoji_adjust is a decimal integer so math works
    # #

    case "$emoji_adjust" in
        ''|*[!0-9-]*)
            emoji_adjust=0
            ;;
    esac

    local title_width=$(( content_width - pad ))

    # #
    #   Account for emoji adjustment in visible length calculation
    # #
  
    local title_vis_len=$(( ${#display_title} - emoji_adjust ))
    printf "${greyd}%s│%*s${bluel}%s${greyd}%*s│\n" \
        "$indent" "$pad" "" "$display_title" "$(( title_width - title_vis_len ))" ""

    # #
    #   Only render body text if provided
    # #

    if [ -n "$text" ]; then
        printf "${greyd}%s│%-${content_width}s│\n" "$indent" ""

        # #
        #   Convert literal \n to real newlines
        # #

        text=$(printf "%b" "$text")

        # #
        #   Handle each line with ANSI-aware wrapping and true padding
        # #

        printf "%s" "$text" | while IFS= read -r line || [ -n "$line" ]; do

        # #
        #   Blank line
        # #
    
        if [ -z "$line" ]; then
            printf "${greyd}%s│%-*s│\n" "$indent" "$content_width" ""
            continue
        fi

        local out="" word
        for word in $line; do
            # #
            #   Strip ANSI for visible width
            # #
        
            local vis_out vis_len vis_word
            vis_out=$(printf "%s" "$out" | sed 's/\x1B\[[0-9;]*[A-Za-z]//g')
            vis_word=$(printf "%s" "$word" | sed 's/\x1B\[[0-9;]*[A-Za-z]//g')
            vis_len=$(( ${#vis_out} + ( ${#vis_out} > 0 ? 1 : 0 ) + ${#vis_word} ))

            if [ -z "$out" ]; then
                out="$word"
            elif [ $vis_len -le $inner_width ]; then
                out="$out $word"
            else
                # #
                #   Print and pad manually based on visible length
                # #

                local vis_len_full
                vis_len_full=$(printf "%s" "$out" | sed 's/\x1B\[[0-9;]*[A-Za-z]//g' | wc -c | tr -d ' ')
                local pad_spaces=$(( inner_width - vis_len_full ))
                [ $pad_spaces -lt 0 ] && pad_spaces=0
                printf "${greyd}%s│%*s%s%*s│\n" "$indent" "$pad" "" "$out" "$(( pad + pad_spaces ))" ""
                out="$word"
            fi
        done

        # #
        #   Final flush line
        # #
    
        if [ -n "$out" ]; then
            local vis_len_full pad_spaces
            vis_len_full=$(printf "%s" "$out" | sed 's/\x1B\[[0-9;]*[A-Za-z]//g' | wc -c | tr -d ' ')
            pad_spaces=$(( inner_width - vis_len_full ))
            [ $pad_spaces -lt 0 ] && pad_spaces=0
            printf "${greyd}%s│%*s%s%*s│\n" "$indent" "$pad" "" "$out" "$(( pad + pad_spaces ))" ""
        fi

        done
    fi

    printf "${greyd}%s└%s┘${reset}\n" "$indent" "$hline"
    print
}

# #
#   Define › Logging › Verbose
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
#   Run Command
#   
#   Added when dryrun mode was added to the install.sh.
#   Allows for a critical command to be skipped if in --dryrun mode.
#       Throws a debug message instead of executing.
#   
#   argDryrun comes from global export in csf/install.sh
#   
#   @usage          run /sbin/chkconfig csf off
#                   run echo "ConfigServer"
#                   run chmod -v 700 "./${CSF_AUTO_GENERIC}"
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
#   Copy If Missing
#   Copies a src file to dest only if missing
#   
#   @arg            src                         File to copy
#   @arg            dest                        Where to copy file
#   @usage			copy_if_missing "install.cpanel.sh" "csf cPanel installer"
#   @todo           deprecate in favor of func 'copi'
# #

copy_if_missing( )
{
    src="$1"
    dest="$2"

    if [ ! -e "${dest}" ]; then
        if cp -avf "${src}" "${dest}"; then
            ok "    Copied ${greenl}${src}${greym} to ${greenl}${dest}${greym} "
        else
            error "    ❌ Cannot copy ${redl}${src}${greym} to ${redl}${dest}${greym}"
            exit 1
        fi
    else
        status "    Already existing copy ${bluel}${src}${greym} to ${bluel}${dest}${greym}"
    fi
}

# #
#   Special copy: copy to dest or dest.new if dest exists
#   
#   @todo           deprecate in favor of func 'copi'
# #

copy_or_new( )
{
    src="$1"
    dest="$2"

    if [ ! -e "${dest}" ]; then
        if cp -avf "${src}" "${dest}"; then
            ok "    Copied ${greenl}${src}${greym} to ${greenl}${dest}${greym} "
        else
            error "    ❌ Cannot copy ${redl}${src}${greym} to ${redl}${dest}${greym}"
            exit 1
        fi
    else
        if cp -avf "${src}" "${dest}.new"; then
            ok "    Copied ${greenl}${src}${greym} to ${greenl}${dest}.new${greym} (destination already existed) "
        else
            error "    ❌ Cannot copy ${redl}${src}${greym} to ${redl}$des.newt${greym}"
            exit 1
        fi
    fi
}

# #
#   Copy
#   
#   Custom copy function to replace 'cp'; handles copy a bit differently but with the
#   same behavior.
#   
#   @desc           › Auto detects file, symlink, or directory copying
#                   › Preserve permissions & timestamps (uses `cp -p`)
#                   › Supports copying into directories
#                   › Supports copying to directory paths ending in '/' or '/.'
#                   › Supports copying entire directory trees (recursive)
#                   › Returns non-zero on error (never partially copies silently)
#   
#   @usage          › Copy file into existing directory:
#                       copi 'csfpre.sh' '/usr/local/csf/bin/'
#   
#                   › Copy file and force 'directory intent' using trailing slash:
#                       copi 'csfpre.sh' '/usr/local/csf/bin/'
#                       copi 'csfpre.sh' '/usr/local/csf/bin/.'
#   
#                   › Copy file to specific destination filename:
#                       copi 'config.txt' '/etc/csf/config.txt'
#   
#                   › Copy directory (full tree) to a new location:
#                       copi './tpl' '/usr/local/csf/tpl'
#   
#                   › Copy directory into another directory:
#                       copi './webmin' '/var/lib/csf/'
#   
#                   › Error handling:
#                       copi '/missing/badfile' '/tmp/'             # returns `3` (source missing)
#                       copi '/etc/passwd' '/root/badfolder'        # returns `1` or `2` depending on mkdir/cp errors
#   
#   @return codes   0   Success
#                   1   Failed to create destination directories
#                   2   Failed file copy
#                   3   Source does not exist / unsupported type
#   
#   @motes          - `/path/to/dir/`       treated as directory
#                   - `/path/to/dir/.`      treated as directory
#                   - Destination directories auto-created when required
#                   - Directory copies preserve directory structure and timestamps
# #

copi()
{
    src="$1"
    dest="$2"

    # #
    #   Source must exist
    # #

    if [ ! -e "${src}" ]; then
        warn "    No such file or directory ${yellowl}${src}${greym}"
        return 3
    fi

    # #
    #   File || symlink copy mode
    # #

    if [ -f "${src}" ] || [ -L "${src}" ]; then

        # #
        #   If dest is an existing dir; copy into it
        # #
    
        if [ -d "${dest}" ]; then
            fname=$(basename "${src}")
            label "     Copying ${navy}${fname}${greym} › ${navy}${dest}${greym}"
            cp -p "${src}" "${dest}/$fname" || return 2
            return 0
        fi

        # #
        #   Handle directory intent:
        #       ends in '/' OR ends in '/.'
        # #

        case "${dest}" in
            */ | */.)
                # Normalize "/." → "/"
                d="${dest%/.}"

                mkdir -p "${d}" || return 1
                fname=$(basename "${src}")
                label "     Copying ${navy}${fname}${greym} › ${navy}${d}${greym}"
                cp -p "${src}" "${d}/${fname}" || return 2
                return 0
                ;;
        esac

        # #
        #   Otherwise treat dest as a file path
        # #
    
        label "     Copying ${navy}${src}${greym} › ${navy}${dest}${greym}"
        cp -p "${src}" "${dest}" || return 2
        return 0
    fi

    # #
    #   Directory copy mode
    # #

    if [ -d "${src}" ]; then
        mkdir -p "${dest}" || return 1

        (
            cd "${src}" || exit 1

            # #
            #   Recreate directory tree
            # #

            find . -type d -print | while IFS= read -r d; do
                mkdir -p "${dest}/${d}" || { error "    Failed mkdir ${redl}${dest}/${d}"; exit 1; }
            done

            # #
            #   Copy files
            # #

            find . -type f -print | while IFS= read -r f; do
                label "     Copying ${navy}${f}${greym} › ${navy}${dest}${greym}"
                mkdir -p "${dest}/$(dirname "${f}")"
                cp -p "${f}" "${dest}/${f}" || { error "    Failed copying ${redl}${f}"; exit 1; }
            done
        )
        return $?
    fi

    # #
    #   Unknown type
    # #

    warn "    No such file or directory ${yellowl}${src}${greym}"
    return 3
}

# #
#   Get UI bind address, and credentials from CSF config
# #

get_csf_ui_info()
{
    if [ ! -f "${CSF_CONF}" ]; then
        return 1
    fi

    UI=""
    UI_PORT=""
    UI_IP=""
    UI_USER=""
    UI_PASS=""

    # Extract config data using awk
    awk '
        /^[[:space:]]*UI[[:space:]]*=/ { gsub(/"/,"",$3); print "UI="$3 }
        /^[[:space:]]*UI_PORT[[:space:]]*=/ { gsub(/"/,"",$3); print "PORT="$3 }
        /^[[:space:]]*UI_IP[[:space:]]*=/ { gsub(/"/,"",$3); print "IP="$3 }
        /^[[:space:]]*UI_USER[[:space:]]*=/ { gsub(/"/,"",$3); print "USER="$3 }
        /^[[:space:]]*UI_PASS[[:space:]]*=/ { gsub(/"/,"",$3); print "PASS="$3 }
    ' "${CSF_CONF}" > /tmp/csf_ui_values.$$ 

    # Read values in current shell
    while IFS='=' read -r key val
    do
        case "${key}" in
            UI)   UI="${val}" ;;
            PORT) UI_PORT="${val}" ;;
            IP)   UI_IP="${val}" ;;
            USER) UI_USER="${val}" ;;
            PASS) UI_PASS="${val}" ;;
        esac
    done < /tmp/csf_ui_values.$$

    rm -f /tmp/csf_ui_values.$$

    # Disabled; return empty
    if [ "${UI}" != "1" ]; then
        printf '%s\n' ""
        return 0
    fi

    # Fallbacks
    [ -z "${UI_IP}" ] && UI_IP="127.0.0.1"
    [ -z "${UI_PORT}" ] && UI_PORT="6666"

    # Output: "IP:PORT USER PASS"
    printf '%s:%s %s %s\n' "${UI_IP}" "${UI_PORT}" "${UI_USER}" "${UI_PASS}"
}
