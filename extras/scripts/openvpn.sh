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
#   @updated            12.25.2025
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
#   ConfigServer Firewall › OpenVPN Patch
#   
#   @file               openvpn.sh
#   @type               Patch
#   @desc               Automatically configures OpenVPN integration with ConfigServer Security and Firewall.
#   
#   @usage              1.  Automatic
#                           place this openvpn.sh file inside
#                               /usr/local/include/csf/post.d/openvpn.sh
#   
#                       2.  Manual
#                           chmod +x /usr/local/include/csf/post.d/openvpn.sh
#                               sudo /usr/local/include/csf/post.d/openvpn.sh
# #

export PATH="$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# #
#   Configs
#   
#   ETH_ADAPTER                 : primary ethernet adapter. these are usually eth* or enp.
#                                 to manually specify your network adapter, replace the code with the name.
#                                 ETH_ADAPTER="eth0"
#   
#   TUN_ADAPTER                 : primary openvpn tun adapter. this is usually tun*
#                                 to manually specify your tunnel adapter name, replace the code with the name.
#                                 TUN_ADAPTER="tun0"
#   
#   IP_PUBLIC                   : by default, the script attempts to automatically find your public IP address.
#                                 if you wish to manually define the IP address, replace the code with your IP
#                                 IP_PUBLIC="xx.xx.xx.xx"
#   
#   DEBUG_ENABLED               : debugging mode; throws prints during various steps
#   
# #

# #
#   Define › User Settings
#   
#   The settings below are empty by default. If you set your own values, it will SKIP auto-detection.
#       ETH_ADAPTER="eth1"
#       IP_PUBLIC=203.0.113.10
#   If you leave the values blank, it will attempt to find the correct values.
#       ETH_ADAPTER=""
#       IP_PUBLIC=""
#   
#   ETH_ADAPTER                 Server's main ethernet adapter
#   IP_PUBLIC                   Server's public IP
#   TUN_ADAPTER                 OpenVPN tunnel adapter name; usually "tun0"
#   IP_POOL_LIST                List of space-separated OpenVPN subnets
#                               "10.8.0.0/24 10.16.0.0/24 10.30.0.0/24"
# #

ETH_ADAPTER=""
IP_PUBLIC=""
TUN_ADAPTER=""
IP_POOL_LIST="10.8.0.0/24"

# #
#   Define › App
# #

app_dir_this="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"                       # folder where script exists
app_dir_ranfrom="${PWD}"                                                            # absolute path to where script was ran from
app_file_this=$(basename "$0")                                                      # docker.sh (with ext)
app_file_bin="${app_file_this%.*}"                                                  # docker (without ext)
app_pid=$BASHPID                                                                    # app pid
app_name="ConfigServer Firewall - Docker Patch"                                     # app title; displayed with --version
app_desc="Sets up your firewall rules t work alongside OpenVPN.\n\
   This script requires that you have iptables installed on your system.\n\
   The required packages will be installed if you do not have them."                # app about; displayed with --version
app_version="15.0.9"                                                                # current script version
app_repo_name="csf-firewall"
app_repo_author="Aetherinox"
app_repo_branch="main"
app_repo_url="https://github.com/${app_repo_author}/${app_repo_name}"

# #
#   Define › Icons
# #

icoSheckmark='✔'       # ✔ $'\u2714'
icoXmark='✗'           # ❌ $'\u274C'

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
#   Define › Args
# #

argDryrun="false"				# runs the logic but doesn't actually install; no changes
argVerbose="false"				# enable verbose logging

# #
#   Define › System
# #

sys_arch=$(dpkg --print-architecture)
sys_code=$(lsb_release -cs)

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
#   Run Command
#   
#   Added when dryrun mode was added to the install.sh.
#   Allows for a critical command to be skipped if in --dryrun mode.
#       Throws a debug message instead of executing.
#   
#   argDryrun comes from global export in csf/install.sh
#   
#   @usage              run /sbin/chkconfig csf off
#                       run echo "ConfigServer"
#                       run chmod -v 700 "./${CSF_AUTO_GENERIC}"
# #

run()
{
    if [ "${argDryrun}" = "true" ]; then
        debug "    Dryrun (skip): $*"
        return 0
    else
        debug "    Run: $*"
        "$@" >/dev/null 2>&1
        rc=$?
        return $rc
    fi
}

# #
#   Truncate Text
#   
#   Shows text up to a limited number of characters and then appends ...
#   
#   @usage              truncate "This is a long string" 10 "..."
# #

truncate()
{
    text=$1
    maxlen=$2
    suffix=${3:-}

    len=$( printf %s "${text}" | wc -c | tr -d '[:space:]' )

    if [ "${len}" -gt "${maxlen}" ]; then
        printf '%s%s\n' "$( printf %s "${text}" | cut -c1-"${maxlen}" )" "${suffix}"
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
    indent="   "
    box_width=110
    line_width=$(( box_width + 2 ))

    line=""
    i=1
    while [ "$i" -le "$line_width" ]; do
        line="${line}─"
        i=$((i+1))
    done

    print
    printf "%b%s%s%b\n" "$greyd" "$indent" "$line" "$reset"
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
    title="$*"
    indent="   "
    padding=6
    box_width=110

    # Strip ANSI codes
    visible_title=$(printf '%s' "$title" | sed 's/\033\[[0-9;]*[A-Za-z]//g')

    title_length=${#visible_title}
    inner_width=$(( title_length + padding ))
    [ "$inner_width" -lt "$box_width" ] && inner_width=$box_width

    # Horizontal line
    line=""
    i=1
    while [ "$i" -le "$inner_width" ]; do
        line="${line}─"
        i=$((i+1))
    done

    # Spaces
    spaces=""
    spaces_needed=$(( inner_width - title_length - 3 ))
    i=1
    while [ "$i" -le "$spaces_needed" ]; do
        spaces="${spaces} "
        i=$((i+1))
    done

    print
    printf "%b%s┌%s┐\n" "$greym" "$indent" "$line"
    printf "%b%s│  %s%s \n" "$greym" "$indent" "$title" "$spaces"
    printf "%b%s└%s┘%b\n" "$greym" "$indent" "$line" "$reset"
    print
}

# #
#   Print › Box › Single
#   
#   Prints single line with a box surrounding it.
#   
#   @usage          prinb "${APP_NAME_SHORT:-CSF} › Customize csf.config"
# #

prinb()
{
    title="$*"
    indent="   "
    padding=6
    box_width=110
    title_length=${#title}
    inner_width=$(( title_length + padding ))
    [ "$inner_width" -lt "$box_width" ] && inner_width=$box_width

    line=""
    i=1
    while [ "$i" -le "$inner_width" ]; do
        line="${line}─"
        i=$((i+1))
    done

    print
    print
    printf "%b%s┌%s┐\n" "$greym" "$indent" "$line"
    printf "%b%s│  %-${inner_width}s \n" "$greym" "$indent" "$title"
    printf "%b%s└%s┘%b\n" "$greym" "$indent" "$line" "$reset"
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
#                   prinp "🎗️[6] test" "The following description will show on multiple lines with a ASCII box around it."
#                   prinp "📄[2] File Overview" "The following list outlines the files that you have generated using this utility, and what certs/keys may be missing."
#                   prinp "➡️[19]  ${bluel}Paths${end}"
#   
#                   prinp "Add DOCKER-ISOLATION And DOCKER-USER Rules" \
#                          "This is an example description for a section header which should word-wrap. \
#                   ${greyd}\n${greyd} \
#                   ${greyd}\n${yellowd}- ${greym}Point 1${greyd} \
#                   ${greyd}\n${yellowd}- ${greym}Point 2${greyd} \
#                   ${greyd}\n${yellowd}- ${greym}Point 3${greyd} \
#                   ${greyd}\n${yellowd}- ${greym}Point 4${greyd} \
#                   ${greyd}\n${yellowd}- ${greym}Point 5${greyd}"
# #

prinp()
{
    # #
    #   Extract title and text
    # #

    title="$1"
    shift
    text="$*"

    indent="  "
    box_width=110
    pad=1

    content_width=$(( box_width ))
    inner_width=$(( box_width - pad*2 ))

    print
    print

    hline=$(printf '─%.0s' $(seq 1 "$content_width"))

    printf "${greyd}%s┌%s┐\n" "$indent" "$hline"

    # #
    #   Title
    #   
    #   Extract optional [N] adjustment from title (signed integer), portably
    # #

    emoji_adjust=0
    display_title="$title"

    # #
    #   Get content inside first [...] (if present)
    # #

    if printf '%s\n' "$title" | grep -q '\[[[:space:]]*[-0-9][-0-9[:space:]]*\]'; then

        # #
        #   Extract numeric inside brackets (allow optional leading -)
        #   - use sed to capture first bracketed token, then strip non-digit except leading -
        # #

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

    title_width=$(( content_width - pad ))

    # #
    #   Account for emoji adjustment in visible length calculation
    # #

    title_vis_len=$(( ${#display_title} - emoji_adjust ))
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

            out=""
            for word in $line; do

                # #
                #   Strip ANSI for visible width
                # #

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

                    vis_len_full=$(printf "%s" "$out" | sed 's/\x1B\[[0-9;]*[A-Za-z]//g' | wc -c | tr -d ' ')
                    pad_spaces=$(( inner_width - vis_len_full ))
                    [ $pad_spaces -lt 0 ] && pad_spaces=0
                    printf "${greyd}%s│%*s%s%*s│\n" "$indent" "$pad" "" "$out" "$(( pad + pad_spaces ))" ""
                    out="$word"
                fi
            done

            # #
            #   Final flush line
            # #

            if [ -n "$out" ]; then
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
#   Helpers › Check Sudo
# #

check_sudo( )
{
    if [ "$(id -u)" != "0" ]; then
        error "    ❌ Must run script with ${redl}sudo"
        exit 1
    fi
}

# #
#   Run › Check Sudo
# #

check_sudo

# #
#   Helpers › Service Exists
#   
#   Checks if a service exists.
#   Look for script in /etc/init.d or a command in PATH.
#   
#   @param  n   string  Service name
#   @return     0       Service exists
#   @return     1       Service does not exist
# #

service_exists()
{
    n=$1

    # Check if executable script exists in /etc/init.d
    if [ -x "/etc/init.d/$n" ]; then
        return 0
    fi

    # Check if service command exists in PATH
    if command -v "$n" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

# #
#   Helpers › Detect Tunnel Adapter
#   
#   Attempts to locate a tun interface (tun0, tun1, etc)
#   using portable, feature-detected methods.
#   
#   @return     stdout     First detected tun adapter name
#   @return     exit 0     Adapter found
#   @return     exit 1     No adapter found
# #

detect_tun_adapter()
{
    # #
    #   Linux › /sys (most reliable, no external commands)
    # #

    if [ -d /sys/class/net ]; then
        for p in /sys/class/net/tun*; do
            [ -e "$p" ] || continue
            basename "$p"
            return 0
        done
    fi

    # #
    #   Linux › ip (if available)
    # #

    if command -v ip >/dev/null 2>&1; then
        ip link 2>/dev/null |
        awk -F: '
            $2 ~ /^[[:space:]]*tun[0-9]+$/ {
                gsub(/^[[:space:]]+/, "", $2)
                print $2
                exit
            }'
        [ $? -eq 0 ] && return 0
    fi

    # #
    #   BSD / macOS › ifconfig
    # #

    if command -v ifconfig >/dev/null 2>&1; then
        ifconfig 2>/dev/null |
        awk '
            /^[a-z]/ && $1 ~ /^tun[0-9]+:/ {
                sub(":", "", $1)
                print $1
                exit
            }'
        [ $? -eq 0 ] && return 0
    fi

    return 1
}

# #
#   Helpers › Print Value
#   
#   Prints the status of the user-defined values.
# #

print_value()
{
    label_name="$1"
    value="$2"

    LEFT_INDENT=27
    LABEL_WIDTH=24

    if [ "$value" = "Unknown" ] || [ -z "$value" ]; then
        color="$redl"
    else
        color="$greenl"
    fi

    indent=$(printf '%*s' "$LEFT_INDENT" "")

    printf "%s%s%-*s%s %s%s%s\n" \
        "$indent" \
        "$yellowd" \
        "$LABEL_WIDTH" "$label_name" \
        "$end" \
        "$color" "$value" "$end"
}

# #
#   Run › Install › Iptables
# #

if ! command -v iptables >/dev/null 2>&1; then
    info "    Installing ${bluel}iptables${greym}"

    # Debian / Ubuntu
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -y -q >/dev/null 2>&1
        apt-get install -y -qq iptables >/dev/null 2>&1
        label "         ${fuchsiad}${app_file_this}${greyd} apt-get install -y -qq iptables"

    # RHEL / CentOS / Alma / Rocky (dnf)
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y iptables >/dev/null 2>&1
        label "         ${fuchsiad}${app_file_this}${greyd} dnf install -y iptables"

    # Older RHEL / CentOS (yum)
    elif command -v yum >/dev/null 2>&1; then
        yum install -y iptables >/dev/null 2>&1
        label "         ${fuchsiad}${app_file_this}${greyd} yum install -y iptables"

    else
        error "    ${redl}No supported package manager found"
        exit 1
    fi
fi

# #
#   Assign › Iptables
#   
#   Assign iptables binary to variable
# #

ipt4=$( command -v iptables 2>/dev/null )
ipt6=$( command -v ip6tables 2>/dev/null )

# #
#   Run › Iptables v4 › Binary › Missing
#   
#   Tell the user iptables v4 binary could not be found.
#   Abort script.
# #

if [ -z "${ipt4}" ]; then
    label ""
    error "    ${yellowd}WARNING:${redl} This Script Requires Iptables"
    label "     ${redl}${bold}Iptables is required before you can utilize this script with ConfigServer Firewall."
    label ""
    label "     ${greym}Try installing the package with:"
    label "         ${fuchsiad}sudo${yellowd} apt-get update"
    label "         ${fuchsiad}sudo${yellowd} apt-get install iptables"
    label ""
    label "         ${fuchsiad}sudo${yellowd} yum makecache"
    label "         ${fuchsiad}sudo${yellowd} yum install iptables"
    label ""

    exit 1
fi

# #
#   Run › Iptables v6 › Binary › Missing
#   
#   Tell the user iptables v6 binary could not be found.
#   Warn, but continue.
# #

if [ -z "${ipt6}" ]; then
    error "    ${yellowd}WARNING:${redl} Could not find iptables v6"
    label "     ${greym}This script will continue only in ipv4 mode."
fi

# #
#   Clear Iptable Rules
#   
#   Flushes and clears all iptales
#   
#   @usage          docker.sh --clear
#                   docker.sh -c
#   @param          none
# #

cmd_iptables_flush()
{
    info "    Resetting iptable chains and rules for ${bluel}IPv4${end}"
    
    run "${ipt4}" -F
    run "${ipt4}" -X
    run "${ipt4}" -t nat -F
    run "${ipt4}" -t nat -X
    run "${ipt4}" -t mangle -F
    run "${ipt4}" -t mangle -X

    info "    Resetting iptable chains and rules for ${bluel}IPv6${end}"
    
    run "${ipt6}" -F
    run "${ipt6}" -X
    run "${ipt6}" -t nat -F
    run "${ipt6}" -t nat -X
    run "${ipt6}" -t mangle -F
    run "${ipt6}" -t mangle -X

    ok "    Successfully reset iptable chains and rules"
}

# #
#   Helpers › Chain › Create
#   
#   Checks if a chain exists; if not, create it.
#       › Check if the chain exists in the specified table.
#       › If the chain does not exist, create it with `-N`.
#       › Print a message showing the chain creation command for debugging/logging.
#   
#   Ensures that a specific iptables chain exists in a given table.
#       › $1    Name of the chain to check or create
#       › $2    Table name (optional, defaults to "filter")
# #

chain_create()
{
    chain="$1"
    table="${2:-filter}"

    if ! "${ipt4}" -t "${table}" -L "${chain}" >/dev/null 2>&1; then
        run "${ipt4}" -t "${table}" -N "${chain}"
        label "         + CHAIN ${greend}[ADD]${greend} -t ${table} -N ${chain}${end}"
    else
        label "         ! CHAIN ${yellowd}[SKP]${yellowd} -t ${table} -N ${chain}${end}"
    fi
}

# #
#   Helpers › Rules › Append
#   
#   Append an iptables rule only if it does not already exist.
#       › Check for the rule using `-C`
#       › Append the rule using `-A` if missing
#       › Log whether the rule was added or skipped
#   
#   Ensures a specific rule is present in the given chain.
#       › $@    Full iptables rule arguments (everything after -C / -A)
# #

rule_append()
{
    if ! "${ipt4}" -C "$@" >/dev/null 2>&1; then
        run "${ipt4}" -A "$@"
        label "         + RULES ${greend}[ADD]${greend} -A $*${end}"
    else
        label "         ! RULES ${yellowd}[SKP]${yellowd} -A $*${end}"
    fi
}

# #
#   Helpers › Rules › Add
#   
#   Add an iptables rule only if it does not already exist.
#       › Check for the rule using `-C`
#       › Insert or append the rule if missing
#       › Log whether the rule was added or skipped
#   
#   Ensures a rule is present by checking before inserting.
#       › $@    Full iptables rule arguments
# #

rule_add()
{
    # #
    #   Replace -A with -C for existence check
    # #

    check_args=
    for arg in "$@"; do
        if [ "${arg}" = "-A" ]; then
            check_args="${check_args} -C"
        else
            check_args="${check_args} ${arg}"
        fi
    done

    # #
    #   Check if rule exists
    # #

    if "${ipt4}" ${check_args} >/dev/null 2>&1; then
        label "         ! RULES ${yellowd}[SKP]${yellowd} $*${end}"
    else
        label "         + RULES ${greend}[ADD]${greend} $*${end}"
        run "${ipt4}" "$@"
    fi
}

# #
#   Helpers › Restart
# #

cmd_csf_restart()
{
    label ""

    restart_service()
    {
        svc="$1"

        if [ -x "/etc/init.d/${svc}" ]; then
            info "    Restarting ${bluel}${svc}${greym}; using /etc/init.d/${svc}"
            /etc/init.d/${svc} restart
            status=$?
        elif command -v service >/dev/null 2>&1; then
            info "    Restarting ${bluel}${svc}${greym}; using service command"
            service "${svc}" restart
            status=$?
        else
            warn "    Could not restart ${yellowl}${svc}${greym}"
            label "           No init script or service command found"
            return 1
        fi

        # Check status
        if [ "$status" -eq 0 ]; then
            ok "    ${greenl}${svc}${greym} restarted successfully"
        else
            warn "    ${yellowl}WARNING:${end} ${yellowl}${svc} may have failed to restart"
            label "     returned exit code ${yellowl}$status${greym}"
        fi
    }

    # #
    #   Restart lfd
    # #

    if service_exists lfd; then
        info "    Restarting ${bluel}lfd.service${greym}"
        restart_service lfd
    else
        label ""
        warn "    ${yellowl}WARNING:${end} ${yellowl}Could not find service ${orangel}lfd.service"
        label "     It may not be installed or enabled.${greym}"
    fi

    # #
    #   Restart csf
    # #

    if service_exists csf; then
        info "    Restarting ${bluel}csf.service${greym}"
        restart_service csf
    else
        label ""
        warn "    ${yellowl}WARNING:${end} ${yellowl}Could not find service ${orangel}csf.service"
        label "     It may not be installed or enabled.${greym}"
    fi

    label ""
}

# #
#   Help › Usage Menu
# #

opt_usage( )
{
    echo
    print "   ${blued}${bold}${app_name}${end} - v${app_version}"
    print "   ${greenl}${bold}${app_repo_url}"
    printf "   ${greym}${bold}${app_desc}\n"
    printf "   ${magental}${app_file_this}${end} ${greyd}[ ${greym}--restart${greyd} | ${greym}--flush${greyd} | ${greym}--detect${greyd} | ${greym}--dryrun${greyd} | ${greym}--version${greyd} | ${greym}--help ${greyd}]${end}" 1>&2
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
    printf '   %-5s %-81s %-40s\n' "    " "${blued}-D${greyd},${blued}  --detect ${yellowd}${end}                     " "lists the detected values for ethernet adapter, tunnel, and public ip${end}" 1>&2
    printf '   %-5s %-81s %-40s\n' "    " "${blued}-r${greyd},${blued}  --restart ${yellowd}${end}                    " "restart csf and lfd services${end}" 1>&2
    printf '   %-5s %-81s %-40s\n' "    " "${blued}-f${greyd},${blued}  --flush ${yellowd}${end}                      " "flush all iptable rules from server${end}" 1>&2
    printf '   %-5s %-81s %-40s\n' "    " "${blued}-d${greyd},${blued}  --dryrun ${yellowd}${end}                     " "simulates installation, does not install csf ${navy}<default> ${peach}${argDryrun:-"disabled"} ${end}" 1>&2
    printf '   %-5s %-81s %-40s\n' "    " "${blued}-v${greyd},${blued}  --version ${yellowd}${end}                    " "current version of this utilty ${navy}<current> ${peach}${app_version:-"unknown"} ${end}" 1>&2
    printf '   %-5s %-81s %-40s\n' "    " "${blued}-h${greyd},${blued}  --help ${yellowd}${end}                       " "show this help menu ${end}" 1>&2
    echo
    echo
}

# #
#   Commands › Parse
# #

while [ "$#" -gt 0 ]; do
    case "$1" in

        -d|--dryrun)
            argDryrun="true"
            ;;

        -D|--detect)

            : "${ETH_ADAPTER:=}"
            if [ -z "$ETH_ADAPTER" ]; then
                ETH_ADAPTER="Unknown"

                if command -v ip >/dev/null 2>&1; then
                    ETH_ADAPTER=$(ip route 2>/dev/null | awk '/default/ { print $5; exit }')
                elif command -v route >/dev/null 2>&1; then
                    ETH_ADAPTER=$(route -n get default 2>/dev/null | awk '/interface/ { print $2 }')
                fi
            fi

            : "${IP_PUBLIC:=}"
            if [ -z "$IP_PUBLIC" ]; then
                IP_PUBLIC="Unknown"

                if command -v curl >/dev/null 2>&1; then
                    IP_PUBLIC=$( curl -fs https://ipinfo.io/ip 2>/dev/null )
                elif command -v wget >/dev/null 2>&1; then
                    IP_PUBLIC=$( wget -qO- https://ipinfo.io/ip 2>/dev/null )
                fi
            fi

            : "${TUN_ADAPTER:=}"
            if [ -z "$TUN_ADAPTER" ]; then
                TUN_ADAPTER=$( detect_tun_adapter )
                if [ -z "$TUN_ADAPTER" ]; then
                    TUN_ADAPTER="Unknown"
                fi
            fi

            label ""
            info "    Using the following values:"
            print_value "Ethernet Adapter"   "$ETH_ADAPTER"
            print_value "Public IP"          "$IP_PUBLIC"
            print_value "VPN Tunnel Adapter" "$TUN_ADAPTER"
            label ""
            exit 1
            ;;

        -r|--restart)
            cmd_csf_restart
            exit 1
            ;;

        -v|--ver|--version)
            label ""
            print "   ${blued}${bold}${app_name}${end} - v${app_version}"
            print "   ${greenl}${bold}${app_repo_url}"
            printf "   ${greym}${bold}${app_desc}\n"
            label ""
            exit 1
            ;;

        -f|--flush)
            cmd_iptables_flush
            exit 1
            ;;

        -h|--help|\?)
            opt_usage
            exit 1
            ;;

        *)
            label
			error "    ❌ Unknown flag ${redl}$1${greym}. Aborting."
            label
			exit 1
			;;
    esac
    shift
done

# #
#   Run › Locate CSF binary
# #

if ! command -v csf >/dev/null 2>&1; then
    label ""
    error "    Could not find ${redl}ConfigServer Security & Firewall${greym}"
    label "     ${redl}${bold}This server must have ConfigServer Security & Firewall installed before this"
    label "     ${redl}${bold}script can be ran"
    label ""
    label "     ${greym}Download by going to:"
    label "         ${yellowd}${app_repo_url}"
    label ""

    exit 1
else
    ok "    Found installed package ${greenl}CSF + LFD"
fi

# #
#   Assign › CSF Binary
# #

csf_path=$( command -v csf 2>/dev/null )

# #
#   Run › Locate OpenVPN binary
# #

if ! command -v openvpn >/dev/null 2>&1; then
    label ""
    error "    Could not find ${redl}OpenVPN${greym}"
    label "     ${redl}${bold}This server must have OpenVPN installed before this"
    label "     ${redl}${bold}script can be ran"
    label ""

    exit 1
else
    ok "    Found installed package ${greenl}OpenVPN"
fi

# #
#   Run › Install › Iptables
# #

if ! command -v iptables >/dev/null 2>&1; then
    info "    Installing ${bluel}iptables${greym}"

    # Debian / Ubuntu
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -y -q >/dev/null 2>&1
        apt-get install -y -qq iptables >/dev/null 2>&1
        label "         ${fuchsiad}${app_file_this}${greyd} apt-get install -y -qq iptables"

    # RHEL / CentOS / Alma / Rocky (dnf)
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y iptables >/dev/null 2>&1
        label "         ${fuchsiad}${app_file_this}${greyd} dnf install -y iptables"

    # Older RHEL / CentOS (yum)
    elif command -v yum >/dev/null 2>&1; then
        yum install -y iptables >/dev/null 2>&1
        label "         ${fuchsiad}${app_file_this}${greyd} yum install -y iptables"

    else
        error "    ${redl}No supported package manager found"
        exit 1
    fi
else
    ok "    Found installed package ${greenl}iptables"
fi

# #
#   Assign › Iptables
#   
#   Assign iptables binary to variable
# #

ipt4=$( command -v iptables 2>/dev/null )
ipt6=$( command -v ip6tables 2>/dev/null )

# #
#   Run › Iptables v4 › Binary › Missing
#   
#   Tell the user iptables v4 binary could not be found.
#   Abort script.
# #

if [ -z "${ipt4}" ]; then
    label ""
    error "    ${yellowd}WARNING:${redl} This Script Requires Iptables"
    label "     ${redl}${bold}Iptables is required before you can utilize this script with ConfigServer Firewall."
    label ""
    label "     ${greym}Try installing the package with:"
    label "         ${fuchsiad}sudo${yellowd} apt-get update"
    label "         ${fuchsiad}sudo${yellowd} apt-get install iptables"
    label ""
    label "         ${fuchsiad}sudo${yellowd} yum makecache"
    label "         ${fuchsiad}sudo${yellowd} yum install iptables"
    label ""

    exit 1
else
    ok "    Declared iptables4 binary ${greenl}${ipt4}"
fi

# #
#   Run › Iptables v6 › Binary › Missing
#   
#   Tell the user iptables v6 binary could not be found.
#   Warn, but continue.
# #

if [ -z "${ipt6}" ]; then
    error "    ${yellowd}WARNING:${redl} Could not find iptables v6"
    label "     ${greym}This script will continue only in ipv4 mode."
else
    ok "    Declared iptables6 binary ${greenl}${ipt6}"
fi

# #
#   Detect default network adapter (unless user provided one)
# #

: "${ETH_ADAPTER:=}"

if [ -z "$ETH_ADAPTER" ]; then
    ETH_ADAPTER="Unknown"

    if command -v ip >/dev/null 2>&1; then
        ETH_ADAPTER=$(ip route 2>/dev/null | awk '/default/ { print $5; exit }')
    elif command -v route >/dev/null 2>&1; then
        ETH_ADAPTER=$(route -n get default 2>/dev/null | awk '/interface/ { print $2 }')
    fi
fi

# #
#   Detect public IP address (unless user provided one)
# #

: "${IP_PUBLIC:=}"

if [ -z "$IP_PUBLIC" ]; then
    IP_PUBLIC="Unknown"

    if command -v curl >/dev/null 2>&1; then
        IP_PUBLIC=$( curl -fs https://ipinfo.io/ip 2>/dev/null )
    elif command -v wget >/dev/null 2>&1; then
        IP_PUBLIC=$( wget -qO- https://ipinfo.io/ip 2>/dev/null )
    fi
fi

# #
#   Detect public IP address (unless user provided one)
# #

: "${TUN_ADAPTER:=}"

if [ -z "$TUN_ADAPTER" ]; then
    TUN_ADAPTER=$( detect_tun_adapter )
    if [ -z "$TUN_ADAPTER" ]; then
        TUN_ADAPTER="Unknown"
    fi
fi

# #
#   Print Values to User
# #

info "    Using the following values:"
print_value "Ethernet Adapter"   "$ETH_ADAPTER"
print_value "Public IP"          "$IP_PUBLIC"
print_value "VPN Tunnel Adapter" "$TUN_ADAPTER"

# #
#   Start
# #

info "    Starting ${bluel}OpenVPN${greym} integration with ${bluel}CSF${greym}"

# #
#   Check › OpenVPN Tunnel Adapter
# #

if [ -z "${TUN_ADAPTER}" ]; then
    label ""
    error "    Could not find ${redl}OpenVPN tunnel${greym} adapter."
    label "     ${redl}${bold}You must have OpenVPN installed and a valid tunnel adapter"
    label "     ${redl}${bold}configured for your server."
    label ""

    exit 1
fi

# #
#   Configure › Generic
# #

rule_append INPUT -i "tun+" -j ACCEPT
rule_append FORWARD -i "tun+" -j ACCEPT
rule_append FORWARD -o "${TUN_ADAPTER}" -j ACCEPT

# #
#   Configure › Ethernet Adapter
# #

if [ -n "${ETH_ADAPTER}" ]; then

    rule_add -t nat -A POSTROUTING -o "${ETH_ADAPTER}" -j MASQUERADE

    # #
    #   Add firewall rules for each VPN IP in the pool
    # #

    for vpn_ip_pool in $IP_POOL_LIST; do
        rule_add -t nat -A POSTROUTING -s "${vpn_ip_pool}" -o "${ETH_ADAPTER}" -j MASQUERADE
    done

    # #
    #   INPUT / FORWARD rules for OpenVPN
    # #

    rule_add -A INPUT -i "${ETH_ADAPTER}" -m state --state NEW -p udp --dport 1194 -j ACCEPT
    rule_add -A FORWARD -i tun+ -o "${ETH_ADAPTER}" -m state --state RELATED,ESTABLISHED -j ACCEPT
    rule_add -A FORWARD -i "${ETH_ADAPTER}" -o tun+ -m state --state RELATED,ESTABLISHED -j ACCEPT

else
    label ""
    error "    ${bold}${redl}Could not locate ${redl}ethernet adapter${greym}"
    label "     ${yellowd}${bold}Your server must have a valid and detectable ethernet adapter."
    label "     ${yellowd}${bold}You can manually assign an adapter name by opening this file"
    label "     ${yellowd}${bold}and setting your own:"
    label ""
    label "         ${greym}sudo nano ${yellowd}\"${greend}${app_dir_this}/${app_file_this}${yellowd}\"${greyd}"
    label "         ${orangel}ETH_ADAPTER=${yellowd}\"${bluel}eth0${yellowd}\"${greyd}"
    label ""
fi

# #
#   Configure › Public IP
# #

if [ ! -z "${IP_PUBLIC}" ]; then
    rule_add -t nat -A POSTROUTING -j SNAT --to-source "${IP_PUBLIC}"
else
    label ""
    error "    ${bold}${redl}Could not locate ${redl}public IP${greym}"
    label "     ${yellowd}${bold}In order to whitelist your server, this script must know your"
    label "     ${yellowd}${bold}public IP address. We could not detect it automatically."
    label "     ${yellowd}${bold}You can manually assign this by opening this file"
    label "     ${yellowd}${bold}and setting your own:"
    label ""
    label "         ${greym}sudo nano ${yellowd}\"${greend}${app_dir_this}/${app_file_this}${yellowd}\"${greyd}"
    label "         ${orangel}IP_PUBLIC=${yellowd}\"${bluel}xx.xx.xx.xx${yellowd}\"${greyd}"
    label ""
fi

# #
#   Configure › TUN+ Output
#   
#   Required if OUTPUT value is not ACCEPT:
# #

rule_add -A OUTPUT -o tun+ -j ACCEPT