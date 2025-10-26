#!/bin/bash

# #
#   @for                https://github.com/Aetherinox/csf-firewall
#   @workflow           blocklist-generate.yml
#   @type               bash script
#   @summary            generate ipset by fetching locally specified file in /blocks/ repo folder
#                       copies local ipsets from .github/blocks/${ARG_BLOCKS_CAT}/*.ipset
# #


APP_THIS_FILE=$(basename "$0")
APP_THIS_DIR="${PWD}"
APP_GITHUB_DIR="${APP_THIS_DIR}/.github"

# #
#   Colors
# #
RESET="\e[0m"
WHITE="\e[97m"
BOLD="\e[1m"
DIM="\e[2m"
UNDERLINE="\e[4m"
BLINK="\e[5m"
INVERTED="\e[7m"
HIDDEN="\e[8m"
BLACK="\e[38;5;0m"
FUCHSIA1="\e[38;5;125m"
FUCHSIA2="\e[38;5;198m"
RED1="\e[38;5;160m"
RED2="\e[38;5;196m"
ORANGE1="\e[38;5;202m"
ORANGE2="\e[38;5;208m"
MAGENTA="\e[38;5;5m"
BLUE1="\e[38;5;033m"
BLUE2="\e[38;5;39m"
CYAN="\e[38;5;6m"
GREEN1="\e[38;5;2m"
GREEN2="\e[38;5;76m"
YELLOW1="\e[38;5;184m"
YELLOW2="\e[38;5;190m"
YELLOW3="\e[38;5;193m"
GREY1="\e[38;5;240m"
GREY2="\e[38;5;244m"
GREY3="\e[38;5;250m"

# #
#   Error Helper
# #
function error
{
    echo -e "  ⭕ ${GREY2}${APP_THIS_FILE}${RESET}: \n     ${BOLD}${RED1}Error${RESET}: $1"
    echo -e
    exit 1
}

# #
#   Sort Results
# #
function sort_results
{
    declare -a ipv4 ipv6

    while read -r line ; do
        if [[ ${line} =~ : ]] ; then
            ipv6+=("${line}")
        else
            ipv4+=("${line}")
        fi
    done

    [[ -v ipv4[@] ]] && printf '%s\n' "${ipv4[@]}" | sort -g -t. -k1,1 -k2,2 -k3,3 -k4,4 | uniq
    [[ -v ipv6[@] ]] && printf '%s\n' "${ipv6[@]}" | sort -g -t: -k1,1 -k2,2 -k3,3 -k4,4 -k5,5 -k6,6 -k7,7 -k8,8 | uniq
}

# #
#   Arguments
# #
ARG_SAVEFILE=$1
ARG_BLOCKS_CAT=$2

if [[ -z "${ARG_SAVEFILE}" ]]; then
    echo -e "\n  ⭕ ${YELLOW1}[${APP_THIS_FILE}]${RESET}: No output file specified\n"
    exit 0
fi

if [[ -z "${ARG_BLOCKS_CAT}" ]]; then
    echo -e "\n  ⭕ ${YELLOW1}[${APP_THIS_FILE}]${RESET}: Aborting -- no static file category specified. ex: privacy\n"
    exit 0
fi

# #
#   Define General
# #
SECONDS=0                                               # set seconds count for beginning of script
APP_VER=("1" "0" "0" "0")                               # current script version
APP_DEBUG=false                                         # debug mode
APP_REPO="Aetherinox/blocklists"                        # repository
APP_REPO_BRANCH="main"                                  # repository branch
APP_FILE_PERM="${ARG_SAVEFILE}"                         # perm file when building ipset list
COUNT_LINES=0                                           # number of lines in doc
COUNT_TOTAL_SUBNET=0                                    # number of IPs in all subnets combined
COUNT_TOTAL_IP=0                                        # number of single IPs (counts each line)
BLOCKS_COUNT_TOTAL_IP=0                                 # number of ips for one particular file
BLOCKS_COUNT_TOTAL_SUBNET=0                             # number of subnets for one particular file
APP_AGENT="Mozilla/5.0 (Windows NT 10.0; WOW64) "\
"AppleWebKit/537.36 (KHTML, like Gecko) "\
"Chrome/51.0.2704.103 Safari/537.36"                    # user agent used with curl
TEMPL_NOW="$(date -u)"
TEMPL_ID=$(basename -- "${APP_FILE_PERM}")
TEMPL_ID="${TEMPL_ID//[^[:alnum:]]/_}"
TEMPL_UUID="$(uuidgen -m -N "${TEMPL_ID}" -n @url)"
TEMPL_DESC="$(curl -sSL -A "${APP_AGENT}" "https://raw.githubusercontent.com/${APP_REPO}/${APP_REPO_BRANCH}/.github/descriptions/${TEMPL_ID}.txt")"
TEMPL_CAT="$(curl -sSL -A "${APP_AGENT}" "https://raw.githubusercontent.com/${APP_REPO}/${APP_REPO_BRANCH}/.github/categories/${TEMPL_ID}.txt")"
TEMPL_EXP="$(curl -sSL -A "${APP_AGENT}" "https://raw.githubusercontent.com/${APP_REPO}/${APP_REPO_BRANCH}/.github/expires/${TEMPL_ID}.txt")"
TEMP_URL_SRC="$(curl -sSL -A "${APP_AGENT}" "https://raw.githubusercontent.com/${APP_REPO}/${APP_REPO_BRANCH}/.github/url-source/${TEMPL_ID}.txt")"
REGEX_URL='^(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]\.[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$'
REGEX_ISNUM='^[0-9]+$'

# #
#   Default Values
# #
if [[ "${TEMPL_DESC}" == *"404: Not Found"* ]]; then TEMPL_DESC="#   No description provided"; fi
if [[ "${TEMPL_CAT}" == *"404: Not Found"* ]]; then TEMPL_CAT="Uncategorized"; fi
if [[ "${TEMPL_EXP}" == *"404: Not Found"* ]]; then TEMPL_EXP="6 hours"; fi
if [[ "${TEMP_URL_SRC}" == *"404: Not Found"* ]]; then TEMP_URL_SRC="None"; fi

# #
#   Header
# #
echo -e "\n ──────────────────────────────────────────────────────────────────────────────────────────────"
echo -e "  ${YELLOW1}${APP_FILE_PERM} (${ARG_BLOCKS_CAT})${RESET}\n"
echo -e "  ${GREY2}ID:          ${TEMPL_ID}${RESET}"
echo -e "  ${GREY2}UUID:        ${TEMPL_UUID}${RESET}"
echo -e "  ${GREY2}CATEGORY:    ${TEMPL_CAT}${RESET}"
echo -e "  ${GREY2}ACTION:      ${APP_THIS_FILE}${RESET}"
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────\n"
echo -e "  ⭐ Starting script ${GREEN1}${APP_THIS_FILE}${RESET}\n"

# #
#   Create or Clean file
# #
if [ -f "${APP_FILE_PERM}" ]; then
    echo -e "  📄 Clean ${BLUE2}${APP_FILE_PERM}${RESET}\n"
    : > "${APP_FILE_PERM}"
else
    echo -e "  📁 Create ${BLUE2}${APP_FILE_PERM}${RESET}\n"
    mkdir -p "$(dirname "${APP_FILE_PERM}")"
    touch "${APP_FILE_PERM}"
fi

# #
#   Add Static Files
# #
if [ -d .github/blocks/ ]; then

    # #
    #   Determines if the category provided is either a folder, or a file ending with `.ipset`.
    #   
    #   if a folder is provided, all files in the folder will be looped and loaded.
    #   if a file is provided, only that one file will be loaded.
    # #

    APP_BLOCK_TARGET=".github/blocks/${ARG_BLOCKS_CAT}/*.ipset"
    if [[ "${ARG_BLOCKS_CAT}" == *ipset ]]; then
        APP_BLOCK_TARGET=".github/blocks/${ARG_BLOCKS_CAT}"
    fi

    # #
    #   Block folder specified. Each file in folder will be loaded.
    #   
    #   @usage      .github/scripts/bl-block.sh blocklists/isp/isp_aol.ipset isp/aol
    # #

    for APP_FILE_TEMP in ${APP_BLOCK_TARGET}; do
        echo -e "  📒 Reading static block ${ORANGE2}${APP_FILE_TEMP}${RESET}"

        # #
        #   calculate how many IPs are in a subnet
        #   if you want to calculate the USABLE IP addresses, subtract -2 from any subnet not ending with 31 or 32.
        #   
        #   for our purpose, we want to block them all in the event that the network has reconfigured their network / broadcast IPs,
        #   so we will count every IP in the block.
        # #

        BLOCKS_COUNT_TOTAL_IP=0
        BLOCKS_COUNT_TOTAL_SUBNET=0

        echo -e "  📊 Fetching statistics for ${ORANGE2}${APP_FILE_TEMP}${RESET}"

        # line-by-line read (preserves spaces + full lines)
        while IFS= read -r line; do
            # skip empty lines
            [[ -z "${line}" ]] && continue

            # is ipv6 (contains a colon)
            if [[ "${line}" == *:* ]]; then
                if [[ ${line} =~ /[0-9]{1,3}$ ]]; then
                    COUNT_TOTAL_SUBNET=$((COUNT_TOTAL_SUBNET + 1))
                    BLOCKS_COUNT_TOTAL_SUBNET=$((BLOCKS_COUNT_TOTAL_SUBNET + 1))
                else
                    COUNT_TOTAL_IP=$((COUNT_TOTAL_IP + 1))
                    BLOCKS_COUNT_TOTAL_IP=$((BLOCKS_COUNT_TOTAL_IP + 1))
                fi
            # is subnet (ipv4)
            elif [[ ${line} =~ /[0-9]{1,2}$ ]]; then
                ips=$((1 << (32 - ${line#*/})))
                if [[ ${ips} =~ ${REGEX_ISNUM} ]]; then
                    BLOCKS_COUNT_TOTAL_IP=$((BLOCKS_COUNT_TOTAL_IP + ips))
                    BLOCKS_COUNT_TOTAL_SUBNET=$((BLOCKS_COUNT_TOTAL_SUBNET + 1))
                    COUNT_TOTAL_IP=$((COUNT_TOTAL_IP + ips))
                    COUNT_TOTAL_SUBNET=$((COUNT_TOTAL_SUBNET + 1))
                fi
            # is normal IP (ipv4)
            elif [[ ${line} =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                BLOCKS_COUNT_TOTAL_IP=$((BLOCKS_COUNT_TOTAL_IP + 1))
                COUNT_TOTAL_IP=$((COUNT_TOTAL_IP + 1))
            fi
        done < "${APP_FILE_TEMP}"

        # #
        #   Count lines and subnets
        # #

        COUNT_LINES=$(wc -l < "${APP_FILE_TEMP}")                                       # GLOBAL count ip lines
        COUNT_LINES=$(printf "%'d" "${COUNT_LINES}")                                    # GLOBAL add commas to thousands
        COUNT_TOTAL_IP=$(printf "%'d" "${COUNT_TOTAL_IP}")                              # GLOBAL add commas to thousands
        COUNT_TOTAL_SUBNET=$(printf "%'d" "${COUNT_TOTAL_SUBNET}")                      # GLOBAL add commas to thousands

        BLOCKS_COUNT_TOTAL_IP=$(printf "%'d" "${BLOCKS_COUNT_TOTAL_IP}")                # LOCAL add commas to thousands
        BLOCKS_COUNT_TOTAL_SUBNET=$(printf "%'d" "${BLOCKS_COUNT_TOTAL_SUBNET}")        # LOCAL add commas to thousands

        echo -e "  🚛 Copy static block rules from ${ORANGE2}${APP_FILE_TEMP}${RESET} to ${BLUE2}${APP_FILE_PERM}${RESET}"
        cat "${APP_FILE_TEMP}" >> "${APP_FILE_PERM}"

        echo -e "  ➕ Added ${FUCHSIA2}${BLOCKS_COUNT_TOTAL_IP} IPs${RESET} and ${FUCHSIA2}${BLOCKS_COUNT_TOTAL_SUBNET} Subnets${RESET} to ${BLUE2}${APP_FILE_PERM}${RESET}\n"
    done
fi

# #
#   Clean lines
#       - remove trailing whitespace
#       - keep original order (comments stay in place)
# #

sed -i 's/[[:blank:]]*$//' "${APP_FILE_PERM}" || true

# #
#   Remove duplicates
# #

if [ -s "${APP_FILE_PERM}" ]; then
    echo -e "  🧹 Cleaning duplicates from ${BLUE2}${APP_FILE_PERM}${RESET}"
    awk '{gsub(/[[:space:]]+$/, ""); if(!seen[$0]++) print}' "${APP_FILE_PERM}" > "${APP_FILE_PERM}.tmp" && mv "${APP_FILE_PERM}.tmp" "${APP_FILE_PERM}"
fi

# #
#   Header insertion
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

echo -e "  🎌 ${GREY2}Finished! ${YELLOW2}${D} days ${H} hrs ${M} mins ${S} secs${RESET}\n"
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
echo -e "  #️⃣ ${BLUE2}${APP_FILE_PERM}${RESET} | Added ${FUCHSIA2}${COUNT_TOTAL_IP} IPs${RESET} and ${FUCHSIA2}${COUNT_TOTAL_SUBNET} Subnets${RESET}"
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────\n"
