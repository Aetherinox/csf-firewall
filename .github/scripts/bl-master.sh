#!/bin/bash

# #
#   @for                https://github.com/Aetherinox/csf-firewall
#   @workflow           blocklist-generate.yml
#   @type               bash script
#   @summary            generate master ipset | URLs: VARARG
#                       Should only be used with the primary 01_master ipset file.
#                       Uses a URL to download various files from online websites.
#                       At the end, it also fetches any file inside `github/blocks/bruteforce/*` and adds those IPs to the end of the file.
#                       Supports multiple URLs as arguments.
#   
#   @notes              API format changed 09/2025; update script to accept new format, regex rules, remove dupes.
#
#   @terminal           .github/scripts/bl-master.sh blocklists/01_master.ipset \
#                           https://blocklist.url1.txt \
#                           https://blocklist.url2.txt \
#                           https://blocklist.url3.txt \
#                           https://blocklist.url4.txt
#
#   @workflow           chmod +x ".github/scripts/bl-master.sh"
#                       run_master=".github/scripts/bl-master.sh 01_master.ipset ${{ secrets.API_01_FILE_01 }} ${{ secrets.API_01_FILE_02 }} ${{ secrets.API_01_FILE_03 }} "
#                       eval "./$run_master"
#
#   @command            bl-master.sh
#                           <ARG_SAVEFILE>
#                           <URL_1>
#                           <URL_2>
#                           {...}
#                       bl-master.sh 01_master.ipset URL_1
#                       bl-master.sh 01_master.ipset URL_1 URL_2 URL_3
#
#                       📁 .github
#                           📁 scripts
#                               📄 bl-master.sh
#                           📁 workflows
#                               📄 blocklist-generate.yml
#
# #

APP_THIS_FILE=$(basename "$0")                          # current script file
APP_THIS_DIR="${PWD}"                                   # current script directory
APP_GITHUB_DIR="${APP_THIS_DIR}/.github"                # .github folder

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

prins()
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
    local title="$*"
    local indent="   "
    local padding=6
    
    local visible_title
    visible_title=$(echo -e "$title" | sed 's/\x1b\[[0-9;]*m//g')
    
    local title_length=${#visible_title}
    local inner_width=$(( title_length + padding ))
    local box_width=90

    [ "$inner_width" -lt ${box_width} ] && inner_width=${box_width}

    local line
    line=$(printf '─%.0s' $(seq 1 "$inner_width"))

    local spaces_needed=$(( inner_width - title_length - 3 ))
    local spaces=$(printf ' %.0s' $(seq 1 "$spaces_needed"))

    print
    print
    printf "%b%s┌%s┐\n" "${greym}" "$indent" "$line"
    printf "%b%s│  %s%s │\n" "${greym}" "$indent" "$title" "$spaces"
    printf "%b%s└%s┘%b\n" "${greym}" "$indent" "$line" "${reset}"
    print
}

# #
#   Print > Box > Single (Left Line)
#   
#   Prints single line with a box surrounding it, excluding the right side
#   
#   @usage          prinb "Name › Section"
# #

prinl( )
{
    local title="$*"
    local indent="   "
    local padding=6
    
    local visible_title
    visible_title=$(echo -e "$title" | sed 's/\x1b\[[0-9;]*m//g')
    
    local title_length=${#visible_title}
    local inner_width=$(( title_length + padding ))
    local box_width=90

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
#   Sort Results
#
#   @usage          line=$(parse_spf_record "${ip}" | sort_results)
# #

sort_results()
{
    declare -a ipv4 ipv6

    while read -r line ; do
        if [[ ${line} =~ : ]] ; then
            ipv6+=("${line}")
        else
            ipv4+=("${line}")
        fi
    done

    [[ -v ipv4[@] ]] && printf '%s\n' "${ipv4[@]}" | sort -g -t. -k1,1 -k 2,2 -k 3,3 -k 4,4 | uniq
    [[ -v ipv6[@] ]] && printf '%s\n' "${ipv6[@]}" | sort -g -t: -k1,1 -k 2,2 -k 3,3 -k 4,4 -k 5,5 -k 6,6 -k 7,7 -k 8,8 | uniq
}

# #
#   Arguments
#
#   This bash script has the following arguments:
#
#       ARG_SAVEFILE        (str)       file to save IP addresses into
#       { ... }             (varg)      list of URLs to API end-points
# #

ARG_SAVEFILE=$1

# #
#   Arguments > Validate
# #

if [[ -z "${ARG_SAVEFILE}" ]]; then
    echo -e
    error "    ⭕  No target file specified ${redl}${APP_THIS_FILE}${greym}; aborting${greym}"
    echo -e
    exit 0
fi

if test "$#" -lt 2; then
    echo -e
    echo -e "  ⭕  ${yellowl}[${APP_THIS_FILE}]${end}: Aborting -- did not provide URL arguments for ${yellowl}${ARG_SAVEFILE}${end}"
    echo -e
    exit 0
fi

# #
#    Define > General
# #

SECONDS=0                                               # set seconds count for beginning of script
APP_VER=("1" "0" "0" "0")                               # current script version
APP_DEBUG=false                                         # debug mode
APP_REPO="Aetherinox/blocklists"                        # repository
APP_REPO_BRANCH="main"                                  # repository branch
APP_OUT=""                                              # each ip fetched from stdin will be stored in this var
APP_FILE_PERM="${ARG_SAVEFILE}"                         # perm file when building ipset list
COUNT_LINES=0                                           # number of lines in doc
COUNT_TOTAL_SUBNET=0                                    # number of IPs in all subnets combined
COUNT_TOTAL_IP=0                                        # number of single IPs (counts each line)
BLOCKS_COUNT_TOTAL_IP=0                                 # number of ips for one particular file
BLOCKS_COUNT_TOTAL_SUBNET=0                             # number of subnets for one particular file
APP_AGENT="Mozilla/5.0 (Windows NT 10.0; WOW64) "\
"AppleWebKit/537.36 (KHTML, like Gecko) "\
"Chrome/51.0.2704.103 Safari/537.36"                    # user agent used with curl
TEMPL_NOW=`date -u`                                     # get current date in utc format
TEMPL_ID=$(basename -- ${APP_FILE_PERM})                # ipset id, get base filename
TEMPL_ID="${TEMPL_ID//[^[:alnum:]]/_}"                  # ipset id, only allow alphanum and underscore, /description/* and /category/* files must match this value
TEMPL_UUID=$(uuidgen -m -N "${TEMPL_ID}" -n @url)       # uuid associated to each release
TEMPL_DESC=$(curl -sSL -A "${APP_AGENT}" "https://raw.githubusercontent.com/${APP_REPO}/${APP_REPO_BRANCH}/.github/descriptions/${TEMPL_ID}.txt")
TEMPL_CAT=$(curl -sSL -A "${APP_AGENT}" "https://raw.githubusercontent.com/${APP_REPO}/${APP_REPO_BRANCH}/.github/categories/${TEMPL_ID}.txt")
TEMPL_EXP=$(curl -sSL -A "${APP_AGENT}" "https://raw.githubusercontent.com/${APP_REPO}/${APP_REPO_BRANCH}/.github/expires/${TEMPL_ID}.txt")
TEMP_URL_SRC=$(curl -sSL -A "${APP_AGENT}" "https://raw.githubusercontent.com/${APP_REPO}/${APP_REPO_BRANCH}/.github/url-source/${TEMPL_ID}.txt")
REGEX_URL='^(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]\.[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$'
REGEX_ISNUM='^[0-9]+$'

# #
#   Default Values
# #

if [[ "$TEMPL_DESC" == *"404: Not Found"* ]]; then
    TEMPL_DESC="#   No description provided"
fi

if [[ "$TEMPL_CAT" == *"404: Not Found"* ]]; then
    TEMPL_CAT="Uncategorized"
fi

if [[ "$TEMPL_EXP" == *"404: Not Found"* ]]; then
    TEMPL_EXP="6 hours"
fi

if [[ "$TEMP_URL_SRC" == *"404: Not Found"* ]]; then
    TEMP_URL_SRC="None"
fi

# #
#   Output > Header
# #

echo
prins
print "    ${yellowl}${APP_FILE_PERM}${end}"
print
print "    ${greym}ID:          ${TEMPL_ID}${end}"
print "    ${greym}UUID:        ${TEMPL_UUID}${end}"
print "    ${greym}CATEGORY:    ${TEMPL_CAT}${end}"
print "    ${greym}ACTION:      ${APP_THIS_FILE}${end}"
prins

# #
#   Start
# #

info "    ⭐ Starting script ${bluel}${APP_THIS_FILE}${greym}"

# #
#   Create or Clean file
# #

if [ -f "${APP_FILE_PERM}" ]; then
    info "    📄 Clean ${bluel}${PWD}/${APP_FILE_PERM}${greym}"
   > "${APP_FILE_PERM}"       # clean file
else
    info "    📁 Create ${bluel}${PWD}/${APP_FILE_PERM}${greym}"
    mkdir -p "$(dirname "${APP_FILE_PERM}")"

    if [ -d "$(dirname "${APP_FILE_PERM}")" ]; then
        ok "    📁 Created ${greenl}$(dirname "${APP_FILE_PERM}")${greym}"
    else
        error "    ⭕  Failed to create directory ${redl}$(dirname "${APP_FILE_PERM}")${greym}; aborting${greym}"
        exit 1
    fi

    touch "${APP_FILE_PERM}"
    if [ -f "${APP_FILE_PERM}" ]; then
        ok "    📄 Created perm file ${greenl}${PWD}/${APP_FILE_PERM}${greym}"
    else
        error "    ⭕ Failed to create perm file ${bluel}${PWD}/${APP_FILE_PERM}${greym}"
        exit 1
    fi
fi

# #
#   Func > Download List
# #
download_list()
{

    local fnUrl=$1
    local fnFile=$2
    local fnFileTemp="${2}.tmp"
    local fnListNum=$3
    local DL_COUNT_TOTAL_IP=0
    local DL_COUNT_TOTAL_SUBNET=0

    # #
    #   Create the file if it doesn't exist
    # #

    prinl "📄 Processing list #${fnListNum}"

    if [ ! -f "${fnFileTemp}" ]; then
        touch "${fnFileTemp}"

        if [ -f "${fnFileTemp}" ]; then
            ok "    📄 Created temp file ${greenl}${PWD}/${fnFileTemp}${greym}"
        else
            error "    ⭕ Failed to create temp file ${bluel}${PWD}/${fnFileTemp}${greym}"
            exit 1
        fi
    fi

    info "    🌎 Downloading IP blacklist to ${bluel}${PWD}/${fnFileTemp}${greym}"

    # curl to grab file
    curl -sSL -k -A "${APP_AGENT}" "${fnUrl}" -o "${fnFileTemp}" >/dev/null 2>&1      # download file

    # normalize CRLF
    sed -i 's/\r$//' "${fnFileTemp}"

    # remove hyphens from IP ranges (if format is "1.2.3.4 - 1.2.3.5" take left side)
    sed -i 's/-.*//' "${fnFileTemp}"

    # remove inline comments (strip ' # comment' or ' ; comment' from end of lines ; collapse whitespace, trim)
    sed -i 's/[[:space:]]*[#;].*$//' "${fnFileTemp}"

    # collapse multiple whitespace into a single space
    sed -i 's/[[:space:]]\+/ /g' "${fnFileTemp}"

    # trim leading and trailing whitespace
    sed -i 's/^[[:space:]]*//;s/[[:space:]]*$//' "${fnFileTemp}"

    # remove empty lines (after trimming/comment removal)
    sed -i '/^$/d' "${fnFileTemp}"

    # #
    #    print contents of file (commented out)
    # #

    # #
    #   calculate how many IPs are in a subnet
    #   if you want to calculate the USABLE IP addresses, subtract -2 from any subnet not ending with 31 or 32.
    #   
    #   for our purpose, we want to block them all in the event that the network has reconfigured their network / broadcast IPs,
    #   so we will count every IP in the block.
    # #

    info "    📊 Fetching statistics for clean file ${bluel}${PWD}/${fnFileTemp}${greym}"
    while IFS= read -r line; do
        # is ipv6
        if [ "$line" != "${line#*:[0-9a-fA-F]}" ]; then
            COUNT_TOTAL_IP=$(( COUNT_TOTAL_IP + 1 ))                           # GLOBAL count subnet
            DL_COUNT_TOTAL_IP=$(( DL_COUNT_TOTAL_IP + 1 ))                     # LOCAL count subnet

        # is subnet (IPv4 CIDR)
        elif [[ $line =~ /[0-9]{1,2}$ ]]; then
            ips=$(( 1 << (32 - ${line#*/}) ))

            if [[ $ips =~ $REGEX_ISNUM ]]; then
                COUNT_TOTAL_IP=$(( COUNT_TOTAL_IP + ips ))                      # GLOBAL count IPs in subnet
                COUNT_TOTAL_SUBNET=$(( COUNT_TOTAL_SUBNET + 1 ))                # GLOBAL count subnet

                DL_COUNT_TOTAL_IP=$(( DL_COUNT_TOTAL_IP + ips ))                # LOCAL count IPs in subnet
                DL_COUNT_TOTAL_SUBNET=$(( DL_COUNT_TOTAL_SUBNET + 1 ))          # LOCAL count subnet
            fi

        # is normal IPv4
        elif [[ $line =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            COUNT_TOTAL_IP=$(( COUNT_TOTAL_IP + 1 ))
            DL_COUNT_TOTAL_IP=$(( DL_COUNT_TOTAL_IP + 1 ))
        fi
    done < "${fnFileTemp}"

    DL_COUNT_TOTAL_IP=$(printf "%'d" "$DL_COUNT_TOTAL_IP")                      # LOCAL add commas to thousands
    DL_COUNT_TOTAL_SUBNET=$(printf "%'d" "$DL_COUNT_TOTAL_SUBNET")              # LOCAL add commas to thousands

    info "    🚛 Move ${bluel}${fnFileTemp}${greym} to ${bluel}${fnFile}${greym}"

    cat "${fnFileTemp}" >> "${fnFile}"                                          # copy .tmp contents to real file
    rm "${fnFileTemp}"                                                          # delete temp file

    if [ ! -f "${fnFileTemp}" ]; then
        ok "    📄 Removed temp file ${greenl}${PWD}/${fnFileTemp}${greym}"
    else
        error "    ⭕  Unable to delete temp file ${redl}${PWD}/${fnFileTemp}${greym}"
    fi

    ok "    ➕ Added ${greenl}${DL_COUNT_TOTAL_IP}${greym} IP addresses and ${greenl}${DL_COUNT_TOTAL_IP}${greym} subnets to ${greenl}${PWD}/${fnFile}${greym}"
}

# #
#   Download lists
#   
#   flips the args around.
#       - url is first
#       - file to store ips in second
# #

for url in "$@"
do
    case "$url" in
        http://*|https://*)
            # Get the Nth entry from the table
            name=$(echo "$TABLE_LIST" | awk -v n="$i" '{print $n}')

            # Call your function with 3 args
            download_list "$url" "$APP_FILE_PERM" "$i"
            ;;
    esac
    i=$((i + 1))
done

# #
#   Add Static Files
# #

if [ -d .github/blocks/ ]; then

    # #
    #   Expand files into an array and ensure the first element exists
    # #

    files=( .github/blocks/bruteforce/*.ipset )

    if [ -e "${files[0]}" ]; then
        for APP_FILE_TEMP in "${files[@]}"; do
            echo -e "  📒 Reading static block ${oranged}${APP_FILE_TEMP}${end}"

            # #
            #   calculate how many IPs are in a subnet
            #   if you want to calculate the USABLE IP addresses, subtract -2 from any subnet not ending with 31 or 32.
            #   
            #   for our purpose, we want to block them all in the event that the network has reconfigured their network / broadcast IPs,
            #   so we will count every IP in the block.
            # #

            BLOCKS_COUNT_TOTAL_IP=0
            BLOCKS_COUNT_TOTAL_SUBNET=0

            echo -e "  📊 Fetching statistics for clean file ${oranged}${APP_FILE_TEMP}${end}"
            while IFS= read -r line; do

                # is ipv6
                if [ "$line" != "${line#*:[0-9a-fA-F]}" ]; then
                    if [[ $line =~ /[0-9]{1,3}$ ]]; then
                        COUNT_TOTAL_SUBNET=$(( COUNT_TOTAL_SUBNET + 1 ))                       # GLOBAL count subnet
                        BLOCKS_COUNT_TOTAL_SUBNET=$(( BLOCKS_COUNT_TOTAL_SUBNET + 1 ))         # LOCAL count subnet
                    else
                        COUNT_TOTAL_IP=$(( COUNT_TOTAL_IP + 1 ))                               # GLOBAL count ip
                        BLOCKS_COUNT_TOTAL_IP=$(( BLOCKS_COUNT_TOTAL_IP + 1 ))                 # LOCAL count ip
                    fi

                # is subnet
                elif [[ $line =~ /[0-9]{1,2}$ ]]; then
                    ips=$(( 1 << (32 - ${line#*/}) ))

                    if [[ $ips =~ $REGEX_ISNUM ]]; then
                        BLOCKS_COUNT_TOTAL_IP=$(( BLOCKS_COUNT_TOTAL_IP + ips ))              # LOCAL count IPs in subnet
                        BLOCKS_COUNT_TOTAL_SUBNET=$(( BLOCKS_COUNT_TOTAL_SUBNET + 1 ))         # LOCAL count subnet

                        COUNT_TOTAL_IP=$(( COUNT_TOTAL_IP + ips ))                            # GLOBAL count IPs in subnet
                        COUNT_TOTAL_SUBNET=$(( COUNT_TOTAL_SUBNET + 1 ))                       # GLOBAL count subnet
                    fi

                # is normal IP
                elif [[ $line =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    BLOCKS_COUNT_TOTAL_IP=$(( BLOCKS_COUNT_TOTAL_IP + 1 ))
                    COUNT_TOTAL_IP=$(( COUNT_TOTAL_IP + 1 ))
                fi
            done < "${APP_FILE_TEMP}"

            # #
            #   Count lines and subnets
            # #

            BLOCKS_COUNT_TOTAL_IP=$(printf "%'d" "$BLOCKS_COUNT_TOTAL_IP")                  # LOCAL add commas to thousands
            BLOCKS_COUNT_TOTAL_SUBNET=$(printf "%'d" "$BLOCKS_COUNT_TOTAL_SUBNET")          # LOCAL add commas to thousands

            echo -e "  🚛 Copy static block rules from ${oranged}${APP_FILE_TEMP}${end} to ${bluel}${APP_FILE_PERM}${end}"
            # Append raw block file; dedupe in the sort step
            cat "${APP_FILE_TEMP}" >> "${APP_FILE_PERM}"

            echo -e "  ➕ Added ${fuchsial}${BLOCKS_COUNT_TOTAL_IP} IPs${end} and ${fuchsial}${BLOCKS_COUNT_TOTAL_SUBNET} Subnets${end} to ${bluel}${APP_FILE_PERM}${end}"
            echo -e
        done
    else
        prinl "📄 Processing Static List ${yellowl}.github/blocks/bruteforce/"
        warn "    ⚠️  No static block files found in ${yellowl}.github/blocks/bruteforce/${greym}; skipping${greym}"
    fi
fi

# #
#   Sort
#       - remove lines that start with # or ;, and blank lines
#       - remove comments from the end of a line
#       - sort and awk / dedupe
# #

grep -vE '^(#|;|[[:space:]]*$)' "${APP_FILE_PERM}" \
    | sort -V \
    | awk '!seen[$0]++' > "${APP_FILE_PERM}.sort"

: > "${APP_FILE_PERM}"
cat "${APP_FILE_PERM}.sort" >> "${APP_FILE_PERM}"
rm -f "${APP_FILE_PERM}.sort"

# #
#   Format Counts
# #

COUNT_LINES=$(wc -l < "${APP_FILE_PERM}")                                   # count ip lines
COUNT_LINES=$(printf "%'d" "$COUNT_LINES")                                  # GLOBAL add commas to thousands

# #
#   Format count totals since we no longer need to add
# #

COUNT_TOTAL_IP=$(printf "%'d" "$COUNT_TOTAL_IP")                            # GLOBAL add commas to thousands
COUNT_TOTAL_SUBNET=$(printf "%'d" "$COUNT_TOTAL_SUBNET")                    # GLOBAL add commas to thousands

# #
#   ed
#       0a  top of file
# #

ed -s "${APP_FILE_PERM}" <<END_ED
0a
# #
#   🧱 Firewall Blocklist - ${APP_FILE_PERM}
#
#   @url            https://raw.githubusercontent.com/${APP_REPO}/${APP_REPO_BRANCH}/${APP_FILE_PERM}
#   @source         ${TEMP_URL_SRC}
#   @id             ${TEMPL_ID}
#   @uuid           ${TEMPL_UUID}
#   @updated        ${TEMPL_NOW}
#   @entries        ${COUNT_TOTAL_IP} ips
#                   ${COUNT_TOTAL_SUBNET} subnets
#                   ${COUNT_LINES} lines
#   @expires        ${TEMPL_EXP}
#   @category       ${TEMPL_CAT}
#
${TEMPL_DESC}
# #

.
w
q
END_ED

# #
#   Finished
# #

T=$SECONDS
D=$((T/86400))
H=$((T/3600%24))
M=$((T/60%60))
S=$((T%60))

prinl "🎌 Finished! ${yellowd}${D} days ${H} hrs ${M} mins ${S} secs"

# #
#   Output
# #

echo -e
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
echo -e "  #️⃣ ${bluel}${APP_FILE_PERM}${end} | Added ${fuchsial}${COUNT_TOTAL_IP} IPs${end} and ${fuchsial}${COUNT_TOTAL_SUBNET} Subnets${end}"
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
echo -e
