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
#   ConfigServer Firewall › Docker Patch
#   
#   @file               docker.sh
#   @type               Patch
#   @desc               This CSF script scans all docker containers that exist within the server and adds each
#                       container ip to the ConfigServer Firewall.
#   
#   @usage              1.  Automatic
#                           place this docker.sh file inside
#                               /usr/local/include/csf/post.d/docker.sh
#   
#                       2.  Manual
#                           chmod +x /usr/local/include/csf/post.d/docker.sh
#                               sudo /usr/local/include/csf/post.d/docker.sh
# #

export PATH="$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# #
#   Define › Config
#   
#   bridge_default      Default docker network bridge
#                       To locate the name of your bridge for the value to enter; run the command
#                           › docker network inspect bridge --format '{{ index .Options "com.docker.network.bridge.name" }}'
#                       Typically this is called 'docker0'
#   
#   file_csf_allow      /etc/csf/csf.allow file
#                       Each docker container's local IP will be added / whitelisted and a comment will be added at the end.
#   
#   csf_comment         Comment added to each whitelisted ip within /etc/csf/csf.allow
# #

bridge_default="docker0"
csf_comment="Docker container whitelist"
file_csf_allow="/etc/csf/csf.allow"

# #
#   Define › User-defined Bridge (Subnets)
#   
#   This is the list of IP addresses / subnets you have assigned to your user-defined
#   docker bridges.
#   
#   These subnets are defined when you create user bridges using a command such as:
#       › sudo docker network create --driver=bridge --subnet=172.18.0.0/16 --gateway=172.18.0.1 traefik
#   
#   Once the user-defined bridge is created with the command above, add the subnet value to 'bridge_user_subnets'
#       › 172.18.0.0/16
#   
#   Single          bridge_user_subnets="172.17.0.0/16"
#   Multiple        bridge_user_subnets="172.17.0.0/16 10.0.0.0/24 192.168.1.0/24"
# #

bridge_user_subnets="172.17.0.0/16"

# #
#   Define › App
# #

app_dir_this="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"                       # folder where script exists
app_dir_ranfrom="${PWD}"                                                            # absolute path to where script was ran from
app_file_this=$(basename "$0")                                                      # docker.sh (with ext)
app_file_bin="${app_file_this%.*}"                                                  # docker (without ext)
app_pid=$BASHPID                                                                    # app pid
app_name="ConfigServer Firewall - Docker Patch"                                     # app title; displayed with --version
app_desc="Sets up your firewall rules to work with Docker and Traefik.\n\
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
#   Prints single line horizontal line, no text
#   
#   @usage          prin0
# #

prin0()
{
    _p0_indent="  "
    _p0_box_width=110
    _p0_line_width=$(( _p0_box_width + 2 ))

    _p0_line=""
    i=1
    while [ "$i" -le "${_p0_line_width}" ]; do
        _p0_line="${_p0_line}─"
        i=$(( i + 1 ))
    done

    printf '\n'
    printf "%b%s%s%b\n" "${greyd}" "${_p0_indent}" "${_p0_line}" "${reset}"
    printf '\n'

    unset _p0_indent _p0_box_width _p0_line_width _p0_line i
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
#   @param  n   str     Service name
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
#   Iptable › Flush
#   
#   Flushes and clears all iptales
#   
#   @usage              docker.sh --flush
#                       docker.sh -f
#   
#   @param              null
#   @return             null
# #

iptables_flush()
{
    info "    Flushing iptable chains and rules for ${bluel}IPv4${end}"
    
    run "${ipt4}" -F
    run "${ipt4}" -X
    run "${ipt4}" -t nat -F
    run "${ipt4}" -t nat -X
    run "${ipt4}" -t mangle -F
    run "${ipt4}" -t mangle -X

    info "    Flushing iptable chains and rules for ${bluel}IPv6${end}"
    
    run "${ipt6}" -F
    run "${ipt6}" -X
    run "${ipt6}" -t nat -F
    run "${ipt6}" -t nat -X
    run "${ipt6}" -t mangle -F
    run "${ipt6}" -t mangle -X

    ok "    Successfully flushed iptable chains and rules"
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
#   Add › Forward
#   
#   Numerous FORWARD chain rules required for Docker traffic.
# #

add_to_forward()
{
    docker_int="$1"
    rule_append FORWARD -o "${docker_int}" -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j ACCEPT
    rule_append FORWARD -o "${docker_int}" -j DOCKER
    rule_append FORWARD -i "${docker_int}" ! -o "${docker_int}" -j ACCEPT
    rule_append FORWARD -i "${docker_int}" -o "${docker_int}" -j ACCEPT
}

# #
#   Add › NAT
#   
#   -t, --table         <table>                 table to manipulate (default: `filter')
#   -C, --check         <chain>                 check for the existence of a rule
#   -s, --source        <address[/mask]>        source specification
#   -d, --destination   <address[/mask]>        destination specification
#   -o, --out-interface <output name[+]>        network interface name ([+] for wildcard)
#   -j, --jump          <target>                target for rule (may load target extension)
#   -A, --append        <chain>                 append to chain
#   -I, --insert        <chain [rulenum]>       insert in chain as rulenum (default 1=first)
#   -N, --new chain		                        create a new user-defined chain
# #

add_to_nat()
{
    docker_int="$1"
    subnet="$2"

    #   ipv4
    if [ "${subnet}" != "${subnet#*[0-9].[0-9]}" ]; then
        run "${ipt4}" -t nat -C POSTROUTING -s "${subnet}" ! -o "${docker_int}" -j MASQUERADE 2>/dev/null || \
        run "${ipt4}" -t nat -A POSTROUTING -s "${subnet}" ! -o "${docker_int}" -j MASQUERADE
        run "${ipt4}" -t nat -C DOCKER -i "${docker_int}" -j RETURN 2>/dev/null || \
        run "${ipt4}" -t nat -A DOCKER -i "${docker_int}" -j RETURN

        label "         + RULES V4 ${greend}[ADD]${greend} -t nat -A POSTROUTING -s \"${subnet}\" ! -o \"${docker_int}\" -j MASQUERADE${end}"
        label "         + RULES V4 ${greend}[ADD]${greend} -t nat -A DOCKER -i \"${docker_int}\" -j RETURN${end}"

    #   ipv6
    elif [ "${subnet}" != "${subnet#*:[0-9a-fA-F]}" ]; then
        run "${ipt6}" -t nat -C POSTROUTING -s "${subnet}" ! -o "${docker_int}" -j MASQUERADE 2>/dev/null || \
        run "${ipt6}" -t nat -A POSTROUTING -s "${subnet}" ! -o "${docker_int}" -j MASQUERADE
        run "${ipt6}" -C DOCKER -i "${docker_int}" -j RETURN 2>/dev/null || \
        run "${ipt6}" -A DOCKER -i "${docker_int}" -j RETURN

        label "         + RULES V6 ${greend}[ADD]${greend} -t nat -A POSTROUTING -s \"${subnet}\" ! -o \"${docker_int}\" -j MASQUERADE${end}"
        label "         + RULES V6 ${greend}[ADD]${greend} -t nat -A DOCKER -i \"${docker_int}\" -j RETURN${end}"
    else
        label "         ! RULES ${redl}[ERR]${redl} Unrecognized subnet format ${subnet}${end}"
    fi
}

# #
#   Add › Docker Isolation
# #

add_to_docker_isolation()
{
    docker_int="$1"
    rule_append DOCKER-ISOLATION-STAGE-1 -i "${docker_int}" ! -o "${docker_int}" -j DOCKER-ISOLATION-STAGE-2
    rule_append DOCKER-ISOLATION-STAGE-2 -o "${docker_int}" -j DROP
}

# #
#   Docker Container › Iflink
#   
#   Returns the iflink numberassigned to a container
#       697
#       689
#       Unknown
# #

get_iflink()
{
    cont="$1"

    # Attempt using shell bash
    if docker exec "${cont}" bash -c 'cat /sys/class/net/eth0/iflink' >/dev/null 2>&1; then
        docker exec "${cont}" bash -c 'cat /sys/class/net/eth0/iflink' 2>/dev/null
        return 0
    fi

    # Attempt using shell sh
    if docker exec "${cont}" sh -c 'cat /sys/class/net/eth0/iflink' >/dev/null 2>&1; then
        docker exec "${cont}" sh -c 'cat /sys/class/net/eth0/iflink' 2>/dev/null
        return 0
    fi

    # Fallback
    echo "Unknown"
    return 0
}

# #
#   Docker Container › Veth Interface
#   
#   Returns the host's veth interface name corresponding to container's eth0
#       veth77f050d
#       veth0c59f79
#       Unknown
# #

get_veth_main()
{
    cont="$1"
    idx=$(get_iflink "${cont}")

    # If no valid iflink, return Unknown
    if [ -z "$idx" ] || [ "$idx" = "Unknown" ]; then
        echo "Unknown"
        return 0
    fi

    # Look for veth interface on host with matching ifindex
    for f in /sys/class/net/veth*/ifindex; do
        if [ "$(cat "$f" 2>/dev/null)" = "$idx" ]; then
            basename "$(dirname "$f")"
            return 0
        fi
    done

    # Fallback
    echo "Unknown"
}

# #
#   Helpers › Container List
# #

cmd_containers_list()
{

    label ""

    # #
    #   Get container list and count
    # #

    containers=$(docker ps -q)
    containers_num=$(echo "$containers" | wc -w)

    # #
    #   Cache veth ifindex so that scan is faster.
    #   veth name map (scan sysfs once)
    # #

    veth_cache=""
    for i in /sys/class/net/veth*/ifindex; do
        idx=$( cat "$i" 2>/dev/null ) || continue
        name=$( basename "$(dirname "$i")" )
        veth_cache="${veth_cache}${idx}:${name}
    "
    done

    # #
    #   Whitelist docker containers if count higher than zero (0)
    # #

    if [ "$containers_num" -gt 0 ]; then

        printf '%-19s %-30s %-38s %-26s %-30s %-33s %-30s %-30s %-50s' \
            "" \
            "${yellowd}   Container${end}" \
            "${yellowd}   Name" \
            "${yellowd}   Shell${end}" \
            "${yellowd}   IP${end}" \
            "${yellowd}   IfLink ID${end}" \
            "${yellowd}   Veth Adapter${end}" \
            "${yellowd}   Network Mode${end}" \
            "${yellowd}   Network List${end}"

        # #
        #   Loop containers
        #   
        #       cont_id             579fedba3c76
        #       cont_netmode        traefik
        #       cont_network        traefik
        #       cont_network_list   dns traefik
        #       cont_network_json   {"traefik":{"IPAMConfig":{"IPv4Address":"172.18.1.2"},"Links":null,"Aliases":["authentik-worker","authentik-worker"],"MacAddress":"ee:b2:fa:15:e3:7d","DriverOpts":null,"GwPriority":0,"NetworkID":"81421612a0ce7f8c499c0e35a053135191296b8a3fe6f47cd0027205c3d0b842","EndpointID":"e2199bc25e9cb9882f961dee012cafc6b167335cda07b96db45802471f0c7483","Gateway":"172.18.0.1","IPAddress":"172.18.1.2","IPPrefixLen":16,"IPv6Gateway":"","GlobalIPv6Address":"","GlobalIPv6PrefixLen":0,"DNSNames":["authentik-worker","579fedba3c76","worker"]}}
        #       cont_name           authentik-worker
        #       cont_iflink         22
        #       cont_shell          Bash
        # #

        for cont_id in $containers; do

            # #
            #   Output:
            #       CONTAINER ............... : e46adb5f1eb2
            #       NETMODE ................. : 63599565ed58b275d60087e218e2875aec3c3258976433d061721f0cb666e0b8
            #   
            #   Example:
            #       Running `docker inspect -f "{{.HostConfig.NetworkMode}}" 5b251b810e7d` outputs:
            #       63599565ed58b275d60087e218e2875aec3c3258976433d061721f0cb666e0b8
            # #

            cont_asd="$cont_id"                                                                                                                 # 5a92cabbac8c
            cont_netmode=$( docker inspect -f "{{.HostConfig.NetworkMode}}" "$cont_id" )                                                        # dns
            cont_network=$( docker inspect -f '{{range $net,$v := .NetworkSettings.Networks}}{{printf "%s\n" $net}}{{end}}' "$cont_id" )        # dns \n traefik                list of networks assigned to container; multi-lined list
            cont_network_list=$( docker inspect -f '{{range $net,$v := .NetworkSettings.Networks}}{{printf "%s " $net}}{{end}}' "$cont_id" )    # dns traefik                   same as cont_network, but single lined list, no newlines
            cont_network_json=$( docker inspect -f "{{json .NetworkSettings.Networks}}" "$cont_id" )                                            # {"dns":{"IPAMConfig":{"IPv4Address":"10.10.12.12"},"Links":null,"Aliases":["doh","doh"],"MacAddress":"AB:12:CD:2e:3c:29","DriverOpts":null,"GwPriority":0,"NetworkID":"df59056beef1672177e7ffbed5c589db76a2c2165c68b0055d16f8e1c155aa35","EndpointID":"86b628c57d512886ce23730cae733f7ff85e9f482379a9614d9e8fb49ce2bf22","Gateway":"10.10.0.1","IPAddress":"10.10.12.12","IPPrefixLen":16,"IPv6Gateway":"","GlobalIPv6Address":"","GlobalIPv6PrefixLen":0,"DNSNames":["doh","5a92cabbac8c"]},"traefik":{"IPAMConfig":{"IPv4Address":"172.18.20.2"},"Links":null,"Aliases":["doh","doh"],"MacAddress":"aa:26:ea:0a:70:3c","DriverOpts":null,"GwPriority":0,"NetworkID":"81421612a0ce7f8c499c0e35a053135191296b8a3fe6f47cd0027205c3d0b842","EndpointID":"cecd8bb7c25f80e485461eb602c28452b2f829abcd78cfc82e69a7e1af3c18b2","Gateway":"172.18.0.1","IPAddress":"172.18.20.2","IPPrefixLen":16,"IPv6Gateway":"","GlobalIPv6Address":"","GlobalIPv6PrefixLen":0,"DNSNames":["doh","5a92cabbac8c"]}}
            cont_name=$( docker inspect -f "{{.Name}}" "$cont_id" )                                                                             # /authentik-worker             raw container name
            cont_name=${cont_name#/}                                                                                                            # authentik-worker              remove leading slash
            cont_name=$( echo "${cont_name}" | sed 's/ //g' )                                                                                   # authentik-worker              remove spaces
            cont_iflink=$( docker exec -i "$cont_id" sh -c 'cat /sys/class/net/eth0/iflink' 2> /dev/null )                                      # 688
            cont_shell="Unknown"                                                                                                                # initial shell state           "Unknown"

            # #
            #   Determine Shell
            #   
            #   Loop all shells; figure out which one the container uses.
            #       bash, sh, ash dash
            # #

            for shell in bash sh ash dash; do
                if docker exec -i "$cont_id" "$shell" -c 'echo ok' >/dev/null 2>&1; then
                    cont_shell="$shell"
                    cont_iflink=$(docker exec -i "$cont_id" "$shell" -c 'cat /sys/class/net/eth0/iflink' 2>/dev/null)
                    break
                fi
            done
            [ -z "$cont_shell" ] && cont_shell="Unknown"
            [ -z "$cont_iflink" ] && cont_iflink="Unknown"

            # #
            #   Clean up cont_iflink (numbers only)
            # #

            if [ "$cont_iflink" != "Unknown" ]; then
                cont_iflink=$( echo "$cont_iflink" | sed 's/[^0-9]*//g' )
            fi

            # #
            #   Container › running || unresponsive || offline
            #   
            #       › docker container inspect -f '{{.State.Running}}' traefik
            #           returns only true or false
            #   
            #       › docker container inspect -f '{{.State.Status}}' traefik
            #           returns running, exited, paused, or created
            # #

            cont_status=$( docker ps --format '{{.Names}}' | grep -c "^${cont_name}$" )                         # simple list of container names
            if [ "$( docker container inspect -f '{{.State.Running}}' ${cont_name} )" != "true" ]; then
                cont_iflink=$( docker container inspect -f '{{.State.Status}}' ${cont_name} )                   # running, exited, paused, or created
            fi

            # #
            #   If empty iflink; set status to "No Response"
            # #

            if [ -z "${cont_iflink}" ]; then
                cont_iflink="No Response"
            fi

            # #
            #   Veth › Main
            #   
            #   Can find container's main veth by running the two commands below (in order)
            #       › docker exec pihole cat /sys/class/net/eth0/iflink
            #           returns 8
            #       › idx=$(docker exec pihole cat /sys/class/net/eth0/iflink) && for i in /sys/class/net/veth*/ifindex; do [ "$(cat "$i")" = "$idx" ] && basename "$(dirname "$i")"; done
            #           returns vetha0ecc71
            #   
            #   › cont_veth_main
            #     returns main veth interface
            #         vetha0ecc71
            # #

            cont_veth_main="Unknown"
            if [ -n "${cont_iflink}" ] && [ "${cont_iflink}" != "Unknown" ]; then
                cont_veth_main=$( printf '%s' "${veth_cache}" |
                    awk -F: -v id="${cont_iflink}" '$1==id { print $2; exit }' )
            fi
            [ -z "${cont_veth_main}" ] && cont_veth_main="Unknown"

            # #
            #   Veth › List
            #   
            #   Obtain a list of container veth interfaces with the following commands (in order):
            #       › sudo grep -l -s "687" /sys/class/net/veth*/ifindex
            #           returns /sys/class/net/veth7516a61/ifindex
            #       › echo "veth7516a61" | sed -e 's;^.*net/\(.*\)/ifindex$;\1;'
            #           returns veth7516a61
            #   
            #   › cont_veth
            #     returns multi-lined list of veth interfaces
            #         veth034f583
            #         veth0c59f79
            # #

            cont_veth=""
            if [ -n "${cont_iflink}" ]; then
                cont_veth=$( grep -l -s "$cont_iflink" /sys/class/net/veth*/ifindex )
                cont_veth=$( echo "$cont_veth" | sed -e 's;^.*net/\(.*\)/ifindex$;\1;' )

                if [ -z "${cont_veth}" ]; then
                    cont_veth="Unknown"
                fi
            fi
            [ -z "$cont_veth" ] && cont_veth="Unknown"

            # #
            #   Chart Truncation
            # #

            cont_name_chart=$( truncate "${cont_name}" 20 "..." )                       # pihole
            cont_network_list_chart=$( truncate "${cont_network_list}" 50 "..." )       # dns traefik
            cont_network_mode_chart=$( truncate "${cont_netmode}" 18 "..." )            # dns
            cont_network_ip_chart="Unknown"
            cont_network_list="${cont_network}"                                         # dns \n traefik                Multi-line list of networks
            cont_network_arr="${cont_network_list}"                                     # dns traefik                   space-separated
            cont_network_arr=$( echo "${cont_network_arr}" | tr '\n' ' ' )              # dns traefik                   List of network
            cont_network_arr_count=$( echo "${cont_network_arr}" | wc -w | tr -d ' ' )  # 2                             Count of elements (replaces ${#cont_network_arr[@]})

            # #
            #   Netmode › Default
            # #

            if [ "${cont_netmode}" = "default" ]; then
                cont_bridge_name="${bridge_default}"
                cont_ipaddr=$( docker inspect -f "{{.NetworkSettings.IPAddress}}" "${cont_id}" )
                cont_network_ip_chart="${cont_ipaddr}"

            # #
            #   Netmode › Other
            # #

            else

                # #
                #   Loop Network
                # #

                while IFS= read -r cont_network_list; do
                    cont_bridge=$( docker inspect -f "{{with index .NetworkSettings.Networks \"${cont_network_list}\"}}{{.NetworkID}}{{end}}" "${cont_id}" | cut -c -12 )
                    cont_bridge_name=$( docker network inspect -f '{{"'br-${cont_bridge}'" | or (index .Options "com.docker.network.bridge.name")}}' "${cont_bridge}" )
                    cont_ipaddr=$( docker inspect -f "{{with index .NetworkSettings.Networks \"${cont_network_list}\"}}{{.IPAddress}}{{end}}" "${cont_id}" )
                    cont_ipaddr_orig=${cont_ipaddr}
                    cont_network_ip_chart="${cont_ipaddr}"

                    if [ -z "${cont_bridge}" ]; then cont_bridge="${redl}Unknown${end}"; fi
                    if [ -z "${cont_bridge_name}" ]; then cont_bridge_name="${redl}Unknown${end}"; fi
                    if [ -z "${cont_ipaddr}" ]; then 
                        cont_ipaddr="${redl}Unknown${end}";
                        cont_network_ip_chart="Unknown";
                    fi
                done <<EOF
$cont_network_list
EOF
            fi

            # #
            #   List each container
            # #

            printf '\n%-19s %-30s %-38s %-26s %-30s %-33s %-30s %-30s %-50s' \
                "" \
                "${yellowd}   ${cont_id}${end}" \
                "${yellowd}   ${cont_name_chart}" \
                "${yellowd}   ${cont_shell}${end}" \
                "${yellowd}   ${cont_network_ip_chart}${end}" \
                "${yellowd}   ${cont_iflink}${end}" \
                "${yellowd}   ${cont_veth_main}${end}" \
                "${yellowd}   ${cont_network_mode_chart}${end}" \
                "${yellowd}   [${cont_network_arr_count}] ${cont_network_list_chart}${end}"

            # #
            #   Netmode › Default
            # #

            if [ "${cont_netmode}" = "default" ]; then
                cont_bridge_name="${bridge_default}"

                #   This will return empty if IP manually assigned from docker-compose.yml for container
                #   docker inspect -f "{{.NetworkSettings.IPAddress}}" 5b251b810e7d

                cont_ipaddr=$( docker inspect -f "{{.NetworkSettings.IPAddress}}" "$cont_id" )

            # #
            #   Netmode › Other
            # #

            else

                # #
                #   Count networks (used only to detect last line)
                # #

                cont_network_count=$( printf '%s\n' "${cont_network}" | wc -l | tr -d ' ' )
                cont_network_idx=0

                # #
                #   Loop Network
                # #

                while IFS= read -r cont_network; do
                    cont_network_idx=$(( cont_network_idx + 1 ))

                    cont_bridge=$( docker inspect -f \
                        "{{with index .NetworkSettings.Networks \"${cont_network}\"}}{{.NetworkID}}{{end}}" \
                        "$cont_id" | cut -c -12 )

                    cont_bridge_name=$( docker network inspect -f \
                        '{{"'br-${cont_bridge}'" | or (index .Options "com.docker.network.bridge.name")}}' \
                        "${cont_bridge}" )

                    cont_ipaddr=$( docker inspect -f \
                        "{{with index .NetworkSettings.Networks \"${cont_network}\"}}{{.IPAddress}}{{end}}" \
                        "$cont_id" )

                    cont_ipaddr_orig=${cont_ipaddr}

                    [ -z "${cont_bridge}" ] && cont_bridge="${redl}Unknown${end}"
                    [ -z "${cont_bridge_name}" ] && cont_bridge_name="${redl}Unknown${end}"
                    [ -z "${cont_ipaddr}" ] && cont_ipaddr="${redl}Unknown${end}"

                    # For single-network container, BRIDGE gets ├──, IP gets └──
                    printf '\n%-23s %-42s %-55s' " " "${greyd}├── ${greyd}BRIDGE" "${bluel}${cont_bridge_name}${end}"
                    printf '\n%-23s %-42s %-55s' " " "${greyd}└── ${greyd}IP"     "${bluel}${cont_ipaddr}${end}"

done <<EOF
$cont_network
EOF

            fi

            # Blank line between containers
            printf '\n'

        done

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
    printf "   ${magental}${app_file_this}${end} ${greyd}[ ${greym}--list${greyd} | ${greym}--restart${greyd} | ${greym}--flush${greyd} | ${greym}--detect${greyd} | ${greym}--dryrun${greyd} | ${greym}--version${greyd} | ${greym}--help ${greyd}]${end}" 1>&2
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
    printf '   %-5s %-81s %-40s\n' "    " "${blued}-l${greyd},${blued}  --list ${yellowd}${end}                       " "list all docker containers and associated information${end}" 1>&2
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

        -l|--list)
            cmd_containers_list
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
            iptables_flush
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
#   Run › Locate Docker binary
# #

if ! command -v docker >/dev/null 2>&1; then
    label ""
    error "    Could not find ${redl}Docker${greym}"
    label "     ${redl}${bold}This server must have Docker installed before this"
    label "     ${redl}${bold}script can be ran"
    label ""

    exit 1
else
    ok "    Found installed package ${greenl}Docker"
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
#   Clean Comments
#   
#   Cleans out comments in file /etc/csf/csf.allow.
#   
#   Any comment matching the comment added by this script will be cleaned up
#   each time the script is ran.
#       CLEANED         199.165.114.125 # Another whitelist Random comment
#       NOT CLEANED     172.18.0.13 # Docker container whitelist - Wed Dec 24 04:17:35 2025
# #

if [ -n "${csf_path}" ]; then
    if [ -e "${file_csf_allow}" ]; then
        info "    Cleaning comments in csf allow file ${bluel}${file_csf_allow}"

        # Create a temporary file
        tmpfile=$(mktemp) || exit 1

        # Remove lines matching comment pattern; write to temp file
        sed "/${csf_comment}/d" "${file_csf_allow}" > "${tmpfile}"

        # Overwrite original file
        mv "${tmpfile}" "${file_csf_allow}"

    else
        warn "    Could not find csf allow file ${redl}${file_csf_allow}${greym}. Skip cleaning"
    fi
else
    warn "    Skip cleaning allow file. Variable ${yellowl}\$csf_path${greym} for CSF binary not found."
fi

# #
#   Iptables › Save & Restore
#   
#   Remove all iptables associated with DOCKER. Leave other rules alone.
# #

info "    Stripping all ${bluel}DOCKER${greym} chains from existing iptable rules; restoring without ${bluel}DOCKER${greym} chain"
iptables-save | grep -v '\-j DOCKER' | iptables-restore

# #
#   Rule › Docker Chain
#   
#   Create required Docker chains
# #

info "    Re-creating required DOCKER chains"
chain_create DOCKER
chain_create DOCKER-USER
chain_create DOCKER-ISOLATION-STAGE-1
chain_create DOCKER-ISOLATION-STAGE-2
chain_create DOCKER nat

# #
#   Rule › Default Docker Bridge › docker0
#   
#   Add DOCKER0 rule
#   
#   Check with commands:
#       › sudo iptables -C INPUT -i docker0 -j ACCEPT
# #

info "    Apply ACCEPT rule to default docker bridge INPUT chain"
if ip link show ${bridge_default} >/dev/null 2>&1; then
    rule_append INPUT -i "${bridge_default}" -j ACCEPT
else
    echo "    ${yellowl}! WARNING: ${bridge_default} bridge does not exist; skipping ACCEPT rule${end}"
fi

# #
#   Rule › FORWARD
#   
#   Check with commands:
#       › sudo iptables -C FORWARD -j DOCKER-USER
#       › sudo iptables -C FORWARD -j DOCKER-ISOLATION-STAGE-1
# #

rule_append FORWARD -j DOCKER-USER
rule_append FORWARD -j DOCKER-ISOLATION-STAGE-1

# #
#   Add docker0 to forward
# #

add_to_forward "${bridge_default}"

# #
#   To view PREROUTING and POSTROUTING rules; add `-t nat` with:
#       sudo iptables -t nat -L -n -v
#   
#   Check if rule exists with:
#       sudo iptables -t nat -C PREROUTING -m addrtype --dst-type LOCAL -j DOCKER
#       sudo iptables -t nat -C OUTPUT ! -d 127.0.0.0/8 -m addrtype --dst-type LOCAL -j DOCKER
#   
#   Returns blank IF rule exists; or throws error
#       iptables: Bad rule (does a matching rule exist in that chain?).
#   
#   target                      prot opt source             destination         
#   DOCKER                      0    --  0.0.0.0/0          !127.0.0.0/8          ADDRTYPE match dst-type LOCAL
# #

rule_add -t nat -A PREROUTING -m addrtype --dst-type LOCAL -j DOCKER
rule_add -t nat -A OUTPUT ! -d 127.0.0.0/8 -m addrtype --dst-type LOCAL -j DOCKER

# #
#   SECTION › User-Defined Bridge › Whitelist
#   
#   Whitelist ip addresses associated with docker
# #

prinp "User-Defined Bridges" \
       "Fetches all Docker bridge subnets and configures NAT rules to ensure containers can reach external networks correctly. \
${greyd}\n${greyd} \
${greyd}\n${yellowd}- ${greym}Masquerade outbound container traffic${greyd} \
${greyd}\n${yellowd}- ${greym}Avoid adding duplicate NAT rules${greyd} \
${greyd}\n${yellowd}- ${greym}Route container subnets through Docker bridge${greyd}"

info "    Configuring ${bluel}Docker subnet${end}"

# #
#   Loop each subnet
#       172.17.0.0/16
#       [...]
# #

for ip_block in $bridge_user_subnets; do

    # #
    #   Print Subnet
    # #

    label "         ${bold}${fuchsial}${ip_block}${end}"

    # #
    #   Check and add iptables rules in POSIX-compliant way
    #   
    #   Check with commands:
    #       sudo iptables -t nat -C POSTROUTING ! -o docker0 -s 172.17.0.0/16 -j MASQUERADE
    #       sudo iptables -t nat -C POSTROUTING ! -o docker0 -s 172.17.0.0/16 -j MASQUERADE
    # #

    if ! "${ipt4}" -t nat -C POSTROUTING ! -o "${bridge_default}" -s "${ip_block}" -j MASQUERADE >/dev/null 2>&1; then
        run "${ipt4}" -t nat -A POSTROUTING ! -o "${bridge_default}" -s "${ip_block}" -j MASQUERADE
        label "         + RULES ${greend}[ADD]${greend} -t nat -A POSTROUTING ! -o ${bridge_default} -s ${ip_block} -j MASQUERADE${end}"
    else
        label "         ! RULES ${yellowd}[SKP]${yellowd} -t nat -A POSTROUTING ! -o ${bridge_default} -s ${ip_block} -j MASQUERADE${end}"
    fi

    if ! "${ipt4}" -t nat -C POSTROUTING -s "${ip_block}" ! -o "${bridge_default}" -j MASQUERADE >/dev/null 2>&1; then
        run "${ipt4}" -t nat -A POSTROUTING -s "${ip_block}" ! -o "${bridge_default}" -j MASQUERADE
        label "         + RULES ${greend}[ADD]${greend} -t nat -A POSTROUTING -s ${ip_block} ! -o ${bridge_default} -j MASQUERADE${end}"
    else
        label "         ! RULES ${yellowd}[SKP]${yellowd} -t nat -A POSTROUTING -s ${ip_block} ! -o ${bridge_default} -j MASQUERADE${end}"
    fi

done

ok "    Finished configuring ${greenl}Docker subnet${end}"

# #
#   SECTION › Bridges
#   
#   Get all Docker bridge network IDs
# #

prinp "Network Bridges" \
       "This part of the wizard inspects Docker network bridges and creates the required rules. \
${greyd}\n${greyd} \
${greyd}\n${yellowd}- ${greym}Masquerade outbound traffic so containers use the host IP${greyd} \
${greyd}\n${yellowd}- ${greym}Skip extra NAT rules for incoming bridge traffic${greyd} \
${greyd}\n${yellowd}- ${greym}Allow forwarded traffic for new and established connections${greyd} \
${greyd}\n${yellowd}- ${greym}Block traffic between different bridges${greyd} \
${greyd}\n${yellowd}- ${greym}Allow traffic within the same bridge${greyd}"

info "    Configuring ${bluel}Network Bridges${end}"

# #
#   Get Bridges
#   
#   bridges
#       2eceaf004a4e
#       df59056beef1
#       81421612a0ce
#   
#   bridge_ids
#       2eceaf004a4e
#       df59056beef1
#       81421612a0ce
# #

bridges=$(docker network ls -q --filter driver=bridge)
bridge_ids=$(docker network ls -q --filter driver=bridge --format "{{.ID}}")

# #
#   Loop through each bridge network
#   
#   bridge
#       2eceaf004a4e
#       df59056beef1
#       81421612a0ce
#   
#   View all available bridges with command:
#       docker network ls --filter driver=bridge
# #

for bridge in $bridges; do

    # #
    #   Docker network name (traefik, bridge, dns)
    # #

    net_name=$(docker network inspect -f '{{.Name}}' "$bridge")

    # #
    #   Linux bridge interface (br-xxxx)
    # #

    cont_bridge_name=$(docker network inspect -f '{{if .Options.com.docker.network.bridge.name}}{{.Options.com.docker.network.bridge.name}}{{else}}br-'$bridge'{{end}}' "$bridge")

    # #
    #   Subnet
    # #

    subnet=$(docker network inspect -f '{{(index .IPAM.Config 0).Subnet}}' "$bridge")

    # #
    #   Print Subnet
    # #

    label "         ${bold}${fuchsial}${net_name} (${cont_bridge_name})${greyd} | ${subnet}${end}"

    # #
    #   Call functions with bridge info
    # #

    add_to_nat "${cont_bridge_name}" "$subnet"
    add_to_forward "${cont_bridge_name}"
    add_to_docker_isolation "${cont_bridge_name}"

    label ""

done

ok "    Finished configuring ${greenl}Network Bridges${end}"

# #
#   SECTION › Containers
#   
#   Get all Docker bridge network IDs
# #

prinp "Docker Containers" \
       "This part of the wizard inspects Docker containers and updates the CSF firewall allow list. \
${greyd}\n${greyd} \
${greyd}\n${yellowd}- ${greym}List all running Docker containers${greyd} \
${greyd}\n${yellowd}- ${greym}Get container name, shell, network mode, and IPs${greyd} \
${greyd}\n${yellowd}- ${greym}Map the container's veth interface${greyd} \
${greyd}\n${yellowd}- ${greym}Whitelist container IPs in CSF if missing${greyd} \
${greyd}\n${yellowd}- ${greym}Add iptables rules for exposed ports${greyd}"

# #
#   Get container list and count
# #

containers=$(docker ps -q)
containers_num=$(echo "$containers" | wc -w)

# #
#   Cache veth ifindex so that scan is faster.
#   veth name map (scan sysfs once)
# #

veth_cache=""
for i in /sys/class/net/veth*/ifindex; do
    idx=$( cat "$i" 2>/dev/null ) || continue
    name=$( basename "$(dirname "$i")" )
    veth_cache="${veth_cache}${idx}:${name}
"
done

# #
#   Whitelist docker containers if count higher than zero (0)
# #

if [ "$containers_num" -gt 0 ]; then

    printf '%-0s %-30s %-38s %-26s %-30s %-33s %-30s %-30s %-50s' \
        "" \
        "${greym}   Container${end}" \
        "${greym}   Name" \
        "${greym}   Shell${end}" \
        "${greym}   IP${end}" \
        "${greym}   IfLink ID${end}" \
        "${greym}   Veth Adapter${end}" \
        "${greym}   Network Mode${end}" \
        "${greym}   Network List${end}"

    # #
    #   Loop containers
    #   
    #       cont_id             579fedba3c76
    #       cont_netmode        traefik
    #       cont_network        traefik
    #       cont_network_list   dns traefik
    #       cont_network_json   {"traefik":{"IPAMConfig":{"IPv4Address":"172.18.1.2"},"Links":null,"Aliases":["authentik-worker","authentik-worker"],"MacAddress":"ee:b2:fa:15:e3:7d","DriverOpts":null,"GwPriority":0,"NetworkID":"81421612a0ce7f8c499c0e35a053135191296b8a3fe6f47cd0027205c3d0b842","EndpointID":"e2199bc25e9cb9882f961dee012cafc6b167335cda07b96db45802471f0c7483","Gateway":"172.18.0.1","IPAddress":"172.18.1.2","IPPrefixLen":16,"IPv6Gateway":"","GlobalIPv6Address":"","GlobalIPv6PrefixLen":0,"DNSNames":["authentik-worker","579fedba3c76","worker"]}}
    #       cont_name           authentik-worker
    #       cont_iflink         22
    #       cont_shell          Bash
    # #

    for cont_id in $containers; do

        # #
        #   Output:
        #       CONTAINER ............... : e46adb5f1eb2
        #       NETMODE ................. : 63599565ed58b275d60087e218e2875aec3c3258976433d061721f0cb666e0b8
        #   
        #   Example:
        #       Running `docker inspect -f "{{.HostConfig.NetworkMode}}" 5b251b810e7d` outputs:
        #       63599565ed58b275d60087e218e2875aec3c3258976433d061721f0cb666e0b8
        # #

        cont_asd="$cont_id"                                                                                                                 # 5a92cabbac8c
        cont_netmode=$( docker inspect -f "{{.HostConfig.NetworkMode}}" "$cont_id" )                                                        # dns
        cont_network=$( docker inspect -f '{{range $net,$v := .NetworkSettings.Networks}}{{printf "%s\n" $net}}{{end}}' "$cont_id" )        # dns \n traefik                list of networks assigned to container; multi-lined list
        cont_network_list=$( docker inspect -f '{{range $net,$v := .NetworkSettings.Networks}}{{printf "%s " $net}}{{end}}' "$cont_id" )    # dns traefik                   same as cont_network, but single lined list, no newlines
        cont_network_json=$( docker inspect -f "{{json .NetworkSettings.Networks}}" "$cont_id" )                                            # {"dns":{"IPAMConfig":{"IPv4Address":"10.10.12.12"},"Links":null,"Aliases":["doh","doh"],"MacAddress":"AB:12:CD:2e:3c:29","DriverOpts":null,"GwPriority":0,"NetworkID":"df59056beef1672177e7ffbed5c589db76a2c2165c68b0055d16f8e1c155aa35","EndpointID":"86b628c57d512886ce23730cae733f7ff85e9f482379a9614d9e8fb49ce2bf22","Gateway":"10.10.0.1","IPAddress":"10.10.12.12","IPPrefixLen":16,"IPv6Gateway":"","GlobalIPv6Address":"","GlobalIPv6PrefixLen":0,"DNSNames":["doh","5a92cabbac8c"]},"traefik":{"IPAMConfig":{"IPv4Address":"172.18.20.2"},"Links":null,"Aliases":["doh","doh"],"MacAddress":"aa:26:ea:0a:70:3c","DriverOpts":null,"GwPriority":0,"NetworkID":"81421612a0ce7f8c499c0e35a053135191296b8a3fe6f47cd0027205c3d0b842","EndpointID":"cecd8bb7c25f80e485461eb602c28452b2f829abcd78cfc82e69a7e1af3c18b2","Gateway":"172.18.0.1","IPAddress":"172.18.20.2","IPPrefixLen":16,"IPv6Gateway":"","GlobalIPv6Address":"","GlobalIPv6PrefixLen":0,"DNSNames":["doh","5a92cabbac8c"]}}
        cont_name=$( docker inspect -f "{{.Name}}" "$cont_id" )                                                                             # /authentik-worker             raw container name
        cont_name=${cont_name#/}                                                                                                            # authentik-worker              remove leading slash
        cont_name=$( echo "${cont_name}" | sed 's/ //g' )                                                                                   # authentik-worker              remove spaces
        cont_iflink=$( docker exec -i "$cont_id" sh -c 'cat /sys/class/net/eth0/iflink' 2> /dev/null )                                      # 688
        cont_shell="Unknown"                                                                                                                # initial shell state           "Unknown"

        # #
        #   Determine Shell
        #   
        #   Loop all shells; figure out which one the container uses.
        #       bash, sh, ash dash
        # #

        for shell in bash sh ash dash; do
            if docker exec -i "$cont_id" "$shell" -c 'echo ok' >/dev/null 2>&1; then
                cont_shell="$shell"
                cont_iflink=$(docker exec -i "$cont_id" "$shell" -c 'cat /sys/class/net/eth0/iflink' 2>/dev/null)
                break
            fi
        done
        [ -z "$cont_shell" ] && cont_shell="Unknown"
        [ -z "$cont_iflink" ] && cont_iflink="Unknown"

        # #
        #   Clean up cont_iflink (numbers only)
        # #

        if [ "$cont_iflink" != "Unknown" ]; then
            cont_iflink=$( echo "$cont_iflink" | sed 's/[^0-9]*//g' )
        fi

        # #
        #   Container › running || unresponsive || offline
        #   
        #       › docker container inspect -f '{{.State.Running}}' traefik
        #           returns only true or false
        #   
        #       › docker container inspect -f '{{.State.Status}}' traefik
        #           returns running, exited, paused, or created
        # #

        cont_status=$( docker ps --format '{{.Names}}' | grep -c "^${cont_name}$" )                         # simple list of container names
        if [ "$( docker container inspect -f '{{.State.Running}}' ${cont_name} )" != "true" ]; then
            cont_iflink=$( docker container inspect -f '{{.State.Status}}' ${cont_name} )                   # running, exited, paused, or created
        fi

        # #
        #   If empty iflink; set status to "No Response"
        # #

        if [ -z "${cont_iflink}" ]; then
            cont_iflink="No Response"
        fi

        # #
        #   Veth › Main
        #   
        #   Can find container's main veth by running the two commands below (in order)
        #       › docker exec pihole cat /sys/class/net/eth0/iflink
        #           returns 8
        #       › idx=$(docker exec pihole cat /sys/class/net/eth0/iflink) && for i in /sys/class/net/veth*/ifindex; do [ "$(cat "$i")" = "$idx" ] && basename "$(dirname "$i")"; done
        #           returns vetha0ecc71
        #   
        #   › cont_veth_main
        #     returns main veth interface
        #         vetha0ecc71
        # #

        cont_veth_main="Unknown"
        if [ -n "${cont_iflink}" ] && [ "${cont_iflink}" != "Unknown" ]; then
            cont_veth_main=$( printf '%s' "${veth_cache}" |
                awk -F: -v id="${cont_iflink}" '$1==id { print $2; exit }' )
        fi
        [ -z "${cont_veth_main}" ] && cont_veth_main="Unknown"

        # #
        #   Veth › List
        #   
        #   Obtain a list of container veth interfaces with the following commands (in order):
        #       › sudo grep -l -s "687" /sys/class/net/veth*/ifindex
        #           returns /sys/class/net/veth7516a61/ifindex
        #       › echo "veth7516a61" | sed -e 's;^.*net/\(.*\)/ifindex$;\1;'
        #           returns veth7516a61
        #   
        #   › cont_veth
        #     returns multi-lined list of veth interfaces
        #         veth034f583
        #         veth0c59f79
        # #

        cont_veth=""
        if [ -n "${cont_iflink}" ]; then
            cont_veth=$( grep -l -s "$cont_iflink" /sys/class/net/veth*/ifindex )
            cont_veth=$( echo "$cont_veth" | sed -e 's;^.*net/\(.*\)/ifindex$;\1;' )

            if [ -z "${cont_veth}" ]; then
                cont_veth="Unknown"
            fi
        fi
        [ -z "$cont_veth" ] && cont_veth="Unknown"

        # #
        #   Chart Truncation
        # #

        cont_name_chart=$( truncate "${cont_name}" 20 "..." )                       # pihole
        cont_network_list_chart=$( truncate "${cont_network_list}" 50 "..." )       # dns traefik
        cont_network_mode_chart=$( truncate "${cont_netmode}" 18 "..." )            # dns
        cont_network_ip_chart="Unknown"
        cont_network_list="${cont_network}"                                         # dns \n traefik                Multi-line list of networks
        cont_network_arr="${cont_network_list}"                                     # dns traefik                   space-separated
        cont_network_arr=$( echo "${cont_network_arr}" | tr '\n' ' ' )              # dns traefik                   List of network
        cont_network_arr_count=$( echo "${cont_network_arr}" | wc -w | tr -d ' ' )  # 2                             Count of elements (replaces ${#cont_network_arr[@]})

        # #
        #   Netmode › Default
        # #

        if [ "${cont_netmode}" = "default" ]; then
            cont_bridge_name="${bridge_default}"
            cont_ipaddr=$( docker inspect -f "{{.NetworkSettings.IPAddress}}" "${cont_id}" )
            cont_network_ip_chart="${cont_ipaddr}"

        # #
        #   Netmode › Other
        # #

        else

            # #
            #   Loop Network
            # #

            while IFS= read -r cont_network_list; do
                cont_bridge=$( docker inspect -f "{{with index .NetworkSettings.Networks \"${cont_network_list}\"}}{{.NetworkID}}{{end}}" "${cont_id}" | cut -c -12 )
                cont_bridge_name=$( docker network inspect -f '{{"'br-${cont_bridge}'" | or (index .Options "com.docker.network.bridge.name")}}' "${cont_bridge}" )
                cont_ipaddr=$( docker inspect -f "{{with index .NetworkSettings.Networks \"${cont_network_list}\"}}{{.IPAddress}}{{end}}" "${cont_id}" )
                cont_ipaddr_orig=${cont_ipaddr}
                cont_network_ip_chart="${cont_ipaddr}"

                if [ -z "${cont_bridge}" ]; then cont_bridge="${redl}Unknown${end}"; fi
                if [ -z "${cont_bridge_name}" ]; then cont_bridge_name="${redl}Unknown${end}"; fi
                if [ -z "${cont_ipaddr}" ]; then 
                    cont_ipaddr="${redl}Unknown${end}";
                    cont_network_ip_chart="Unknown";
                fi
            done <<EOF
$cont_network_list
EOF
        fi

        # #
        #   Prep list of rules; will be used to determine how file-tree looks.
        #   And then shown later.
        #   
        #   Example output:
        #       22/tcp->0.0.0.0:22
        #       22/tcp->[::]:22
        #       80/tcp->0.0.0.0:80
        #       80/tcp->[::]:80
        # #
    
        rules=$( docker port "${cont_id}" | sed 's/ //g' )

        # #
        #   List each container
        # #

        printf '\n%-0s %-30s %-38s %-26s %-30s %-33s %-30s %-30s %-50s' \
            "" \
            "${greym}   ${cont_id}${end}" \
            "${greym}   ${cont_name_chart}" \
            "${greym}   ${cont_shell}${end}" \
            "${greym}   ${cont_network_ip_chart}${end}" \
            "${greym}   ${cont_iflink}${end}" \
            "${greym}   ${cont_veth_main}${end}" \
            "${greym}   ${cont_network_mode_chart}${end}" \
            "${greym}   [${cont_network_arr_count}] ${cont_network_list_chart}${end}"

        # #
        #   Netmode › Default
        # #

        if [ "${cont_netmode}" = "default" ]; then
            cont_bridge_name="${bridge_default}"

            #   This will return empty if IP manually assigned from docker-compose.yml for container
            #   docker inspect -f "{{.NetworkSettings.IPAddress}}" 5b251b810e7d

            cont_ipaddr=$( docker inspect -f "{{.NetworkSettings.IPAddress}}" "$cont_id" )

        # #
        #   Netmode › Other
        # #

        else

            # #
            #   Count networks (used only to detect last line)
            # #

            cont_network_count=$( printf '%s\n' "${cont_network}" | wc -l | tr -d ' ' )
            cont_network_idx=0

            # #
            #   Loop Network
            # #

            while IFS= read -r cont_network; do
                cont_network_idx=$(( cont_network_idx + 1 ))

                cont_bridge=$( docker inspect -f \
                    "{{with index .NetworkSettings.Networks \"${cont_network}\"}}{{.NetworkID}}{{end}}" \
                    "$cont_id" | cut -c -12 )

                cont_bridge_name=$( docker network inspect -f \
                    '{{"'br-${cont_bridge}'" | or (index .Options "com.docker.network.bridge.name")}}' \
                    "${cont_bridge}" )

                cont_ipaddr=$( docker inspect -f \
                    "{{with index .NetworkSettings.Networks \"${cont_network}\"}}{{.IPAddress}}{{end}}" \
                    "$cont_id" )

                cont_ipaddr_orig=${cont_ipaddr}

                [ -z "${cont_bridge}" ] && cont_bridge="${redl}Unknown${end}"
                [ -z "${cont_bridge_name}" ] && cont_bridge_name="${redl}Unknown${end}"
                [ -z "${cont_ipaddr}" ] && cont_ipaddr="${redl}Unknown${end}"

                # For single-network container, BRIDGE gets ├──, IP gets └──
                printf '\n%-4s %-42s %-55s' " " "${greyd}├── ${greyd}BRIDGE" "${bluel}${cont_bridge_name}${end}"
                printf '\n%-4s %-42s %-55s' " " "${greyd}├── ${greyd}IP"     "${bluel}${cont_ipaddr}${end}"

done <<EOF
$cont_network
EOF

        fi

        # #
        #   CHeck if containers IP is currently in CSF allow list /etc/csf/csf.allow
        #   
        #   To skip an add to the csf allowlist, must match both the word AND the color of the text; otherwise it will
        #   return false.
        #       "$cont_ipaddr" != "${redl}Unknown${end}"
        # #

        if [ -n "${cont_ipaddr}" ] && [ "${cont_ipaddr}" != "${redl}Not found${end}" ] && [ "${cont_ipaddr}" != "${redl}Unknown${end}" ]; then

            if grep -Fq "${cont_ipaddr}" "$file_csf_allow"; then
                if [ -n "$rules" ]; then
                    printf '\n%-4s %-42s %-55s' " " "${greyd}├── ${greyd}WHITELIST" "${yellowl}Already whitelisted in: ${end}${file_csf_allow}${end}"
                else
                    printf '\n%-4s %-42s %-55s' " " "${greyd}└── ${greyd}WHITELIST" "${yellowl}Already whitelisted in: ${end}${file_csf_allow}${end}"
                fi
            else
                # #
                #   Found CSF binary, add container IP to allow list /etc/csf/csf.allow
                # #

                if [ -n "$csf_path" ]; then
                    if [ -n "$rules" ]; then
                        printf '\n%-4s %-42s %-55s' " " "${greyd}├── ${greyd}WHITELIST" "${greenl}Adding ${cont_ipaddr} to allow list ${file_csf_allow}${end}"
                    else
                        printf '\n%-4s %-42s %-55s' " " "${greyd}└── ${greyd}WHITELIST" "${greenl}Adding ${cont_ipaddr} to allow list ${file_csf_allow}${end}"
                    fi

                    # Write whitelist to file
                    "$csf_path" -a "${cont_ipaddr}" "$csf_comment" >/dev/null 2>&1
                fi
            fi

        else
            printf '\n%-4s %-42s %-55s' " " "${greyd}└── ${greyd}WHITELIST" "${redl}Found blank or unknown IP, cannot be added to ${file_csf_allow}${end}"
        fi

        # #
        #   Only proceed if there are rules
        # #

        if [ "$( printf '%s' "$rules" | wc -c )" -gt 1 ]; then

            for rule in $rules; do

                # #
                #   Extract source and destination
                # #

                src=$( echo "$rule" | awk -F'->' '{print $2}' )
                dst=$( echo "$rule" | awk -F'->' '{print $1}' )

                # #
                #   Detect if IPv4 or IPv6
                # #

                case "$src" in
                    \[*\]*)

                        # #
                        #   IPv6
                        # #

                        src_ip=$( echo "$src" | sed 's|^\[\(.*\)\]:.*$|\1|' )
                        src_port=$( echo "$src" | awk -F':' '{print $2}' )
                        dst_port=$( echo "$dst" | awk -F'/' '{print $1}' )
                        dst_proto=$( echo "$dst" | awk -F'/' '{print $2}' )

                        # Fetch container IPv6 address from Docker inspect
                        cont_ipaddr6=$(docker inspect -f \
                            "{{with index .NetworkSettings.Networks \"${cont_network}\"}}{{.GlobalIPv6Address}}{{end}}" \
                            "$cont_id")

                        # Skip if container has no IPv6
                        if [ -z "$cont_ipaddr6" ]; then
                            label "                         ! RULES V6 ${yellowl}[NFO]${yellowl} No valid IPv6 address assigned${end}"
                            continue
                        fi

                        # #
                        #   Print nicely formatted
                        # #

                        printf '\n%-4s %-42s %-55s' " " "${greyd}┌── ${greyd}SOURCE" "${fuchsial}${src}${end}"
                        printf '\n%-4s %-42s %-55s' " " "${greyd}└── ${greyd}DEST" "${fuchsial}${dst}${end}"
                        printf '\n'

                        # #
                        #   Iptables › IPv6
                        # #

                        run "${ipt6}" -A DOCKER -d "${cont_ipaddr6}/128" ! -i "${cont_bridge_name}" -o "${cont_bridge_name}" \
                            -p "${dst_proto}" -m "${dst_proto}" --dport "${dst_port}" -j ACCEPT

                        run "${ipt6}" -t nat -A POSTROUTING -s "${cont_ipaddr6}/128" -d "${cont_ipaddr6}/128" \
                            -p "${dst_proto}" -m "${dst_proto}" --dport "${dst_port}" -j MASQUERADE

                        label "                         + RULES V6 ${greend}[ADD]${greend} -A DOCKER -d ${cont_ipaddr6}/128 ! -i ${cont_bridge_name} -o ${cont_bridge_name} -p ${dst_proto} -m ${dst_proto} --dport ${dst_port} -j ACCEPT${end}"
                        label "                         + RULES V6 ${greend}[ADD]${greend} -t nat -A POSTROUTING -s ${cont_ipaddr6}/128 -d ${cont_ipaddr6}/128 -p ${dst_proto} -m ${dst_proto} --dport ${dst_port} -j MASQUERADE${end}"
                        ;;

                    *)
                        # #
                        #   IPv4
                        # #

                        src_ip=$( echo "$src" | sed 's|^\(.*\):.*$|\1|' )
                        src_port=$( echo "$src" | awk -F':' '{print $2}' )
                        dst_port=$( echo "$dst" | awk -F'/' '{print $1}' )
                        dst_proto=$( echo "$dst" | awk -F'/' '{print $2}' )

                        # #
                        #   Print nicely formatted
                        # #
                    
                        printf '\n%-4s %-42s %-55s' " " "${greyd}┌── ${greyd}SOURCE" "${fuchsial}${src}${end}"
                        printf '\n%-4s %-42s %-55s' " " "${greyd}└── ${greyd}DEST" "${fuchsial}${dst}${end}"
                        printf '\n'

                        # #
                        #   Iptables Rules › IPv4
                        # #
                    
                        run "${ipt4}" -A DOCKER -d "${cont_ipaddr}/32" ! -i "${cont_bridge_name}" -o "${cont_bridge_name}" \
                            -p "${dst_proto}" -m "${dst_proto}" --dport "${dst_port}" -j ACCEPT

                        run "${ipt4}" -t nat -A POSTROUTING -s "${cont_ipaddr}/32" -d "${cont_ipaddr}/32" \
                            -p "${dst_proto}" -m "${dst_proto}" --dport "${dst_port}" -j MASQUERADE

                        label "                         + RULES V4 ${greend}[ADD]${greend} -A DOCKER -d ${cont_ipaddr}/32 ! -i ${cont_bridge_name} -o ${cont_bridge_name} -p ${dst_proto} -m ${dst_proto} --dport ${dst_port} -j ACCEPT${end}"
                        label "                         + RULES V4 ${greend}[ADD]${greend} -t nat -A POSTROUTING -s ${cont_ipaddr}/32 -d ${cont_ipaddr}/32 -p ${dst_proto} -m ${dst_proto} --dport ${dst_port} -j MASQUERADE${end}"

                        # #
                        #   Support for IPv4 DNAT
                        # #

                        iptables_opt_src=""
                        if [ "$src_ip" != "0.0.0.0" ]; then
                            iptables_opt_src="-d ${src_ip}/32 "
                        fi

                        # #
                        #   Only apply DNAT if src_ip is a valid IPv4
                        # #

                        if echo "$src_ip" | grep -qE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; then
                            run "${ipt4}" -t nat -A DOCKER ${iptables_opt_src}! -i "${cont_bridge_name}" \
                                -p "${dst_proto}" -m "${dst_proto}" --dport "${src_port}" -j DNAT --to-destination "${cont_ipaddr}:${dst_port}"

                            label "                         + RULES V4 ${greend}[ADD]${greend} -t nat -A DOCKER ${iptables_opt_src}! -i ${cont_bridge_name} -p ${dst_proto} -m ${dst_proto} --dport ${src_port} -j DNAT --to-destination ${cont_ipaddr}:${dst_port}${end}"
                        fi
                        ;;
                esac
            done
        fi

        # Blank line between containers
        printf '\n'

    done

fi

# #
#   SECTION › DOCKER-ISOLATION-STAGE
#   
#   Get all Docker bridge network IDs
# #

prinp "Add DOCKER-ISOLATION And DOCKER-USER Rules" \
       "This step ensures that the Docker core firewall chains are present and safely configured so CSF and Docker do not interfere with each other. asdasd asdasdsad \
${greyd}\n${greyd} \
${greyd}\n${yellowd}- ${greym}DOCKER-ISOLATION-STAGE-1 exists and returns traffic correctly${greyd} \
${greyd}\n${yellowd}- ${greym}DOCKER-ISOLATION-STAGE-2 exists to enforce bridge isolation${greyd} \
${greyd}\n${yellowd}- ${greym}DOCKER-USER chain returns traffic to CSF rules${greyd} \
${greyd}\n${yellowd}- ${greym}Prevent Docker isolation chains from blocking legitimate traffic${greyd} \
${greyd}\n${yellowd}- ${greym}Ensure docker0 traffic skips extra NAT processing${greyd}"

info "    Configuring tables ${bluel}DOCKER-ISOLATION${greym} and ${bluel}DOCKER-USER${end}"

# #
#   Ensure Docker isolation and user chains allow traffic by default using RETURN rules.
#   
#   Prevent CSF or custom rules from blocking Docker-managed flows and allows Docker to
#   manage isolation and user filtering safely
#   
#   DOCKER                      Handles port forwarding and NAT rules for running containers.
#                               This is where traffic is routed from the host to container ports.
#   DOCKER-USER                 User-defined firewall rules that run BEFORE Docker’s own rules.
#                               Used by CSF or custom firewalls to allow or block container traffic safely.
#   DOCKER-ISOLATION-STAGE-1    First step in Docker’s network isolation.
#                               Identifies traffic moving between different Docker bridges.
#   DOCKER-ISOLATION-STAGE-2    Second step in Docker’s network isolation.
#                               Blocks cross-bridge traffic unless explicitly allowed.
#   DOCKER-INGRESS              Used for Docker Swarm services and overlay networking.
#                               Not used by standalone containers.
# #

rule_add -A DOCKER-ISOLATION-STAGE-1 -j RETURN
rule_add -A DOCKER-ISOLATION-STAGE-2 -j RETURN
rule_add -A DOCKER-USER -j RETURN
rule_add -t nat -I DOCKER -i "${bridge_default}" -j RETURN

# #
#   Finish
# #

ok "    Completed adding all ${greenl}Docker${greym} rules."