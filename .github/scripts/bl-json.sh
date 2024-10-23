#!/bin/bash

# #
#   @for                https://github.com/Aetherinox/csf-firewall
#   @assoc              blocklist-generate.yml
#   @type               bash script
#   @summary            uses a URL to fetch JSON from a website, then formats that JSON so that there is one IP per line.
#   
#                       📁 .github
#                           📁 scripts
#                               📄 bl-json.sh
#                           📁 workflows
#                               📄 blocklist-generate.yml
#
#   activated from github workflow:
#       - .github/workflows/blocklist-generate.yml
#
#   within github workflow, run:
#       chmod +x ".github/scripts/bl-json.sh"
#       run_google=".github/scripts/bl-json.sh ${{ vars.API_02_GOOGLE_OUT }} ${{secrets.API_02_GOOGLE_URL}} '.prefixes | .[] |.ipv4Prefix//empty,.ipv6Prefix//empty'"
#       eval "./$run_google"
#
#   allows you to specify a .json file, and the query to use for data extraction.
#
#   @uage               bl-json.sh <ARG_SAVEFILE> <ARG_JSON_URL> <ARG_JSON_QRY>
#                       bl-json.sh 02_privacy_google.ipset https://api.domain.lan/googlebot.json '.prefixes | .[] |.ipv4Prefix//empty,.ipv6Prefix//empty'
# #

# #
#   Arguments
#
#   This bash script has the following arguments:
#
#       ARG_SAVEFILE        (str)       file to save IP addresses into
#       ARG_JSON_URL        (str)       direct url to json file to download
#       ARG_JSON_QRY        (str)       jq rules which pull the needed ip addresses
# #

ARG_SAVEFILE=$1
ARG_JSON_URL=$2
ARG_JSON_QRY=$3

# #
#   Validation checks
# #

if [[ -z "${ARG_SAVEFILE}" ]]; then
    echo -e "  ⭕ No output file specified for Google Crawler list"
    echo -e
    exit 1
fi

if [[ -z "${ARG_JSON_URL}" ]] || [[ ! $ARG_JSON_URL =~ $regexURL ]]; then
    echo -e "  ⭕ Invalid URL specified for ${ARG_SAVEFILE}"
    echo -e
    exit 1
fi

if [[ -z "${ARG_JSON_QRY}" ]]; then
    echo -e "  ⭕ No valid jq query specified for ${ARG_SAVEFILE}"
    echo -e
    exit 1
fi

# #
#    Define > General
# #

FOLDER_SAVETO="blocklists"
SECONDS=0
NOW=`date -u`
COUNT_LINES=0                   # number of lines in doc
COUNT_TOTAL_SUBNET=0            # number of IPs in all subnets combined
COUNT_TOTAL_IP=0                # number of single IPs (counts each line)
ID="${ARG_SAVEFILE//[^[:alnum:]]/_}"
DESCRIPTION=$(curl -sS "https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/.github/descriptions/${ID}.txt")
CATEGORY=$(curl -sS "https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/.github/categories/${ID}.txt")
regexURL='^(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]\.[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$'

# #
#   Default Values
# #

if [[ $DESCRIPTION == *"404: Not Found"* ]]; then
    DESCRIPTION="#   No description provided"
fi

if [[ $CATEGORY == *"404: Not Found"* ]]; then
    CATEGORY="Uncategorized"
fi

# #
#   Output > Header
# #

echo -e
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
echo -e "  Blocklist - ${ARG_SAVEFILE}"
echo -e "  ID:         ${ID}"
echo -e "  CATEGORY:   ${CATEGORY}"
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"

# #
#   output
# #

echo -e
echo -e "  ⭐ Starting"

# #
#   Create or Clean file
# #

if [ -f $ARG_SAVEFILE ]; then
    echo -e "  📄 Cleaning ${ARG_SAVEFILE}"
    echo -e
   > ${ARG_SAVEFILE}       # clean file
else
    echo -e "  📄 Creating ${ARG_SAVEFILE}"
    echo -e
   touch ${ARG_SAVEFILE}
fi

# #
#   Get IP list
# #

echo -e "  🌎 Downloading IP blacklist to ${ARG_SAVEFILE}"

# #
#   Get IP list
# #

tempFile="${ARG_SAVEFILE}.tmp"
jsonOutput=$(curl -Ss ${ARG_JSON_URL} | jq -r "${ARG_JSON_QRY}" | sort > ${tempFile})
sed -i '/[#;]/{s/#.*//;s/;.*//;/^$/d}' ${tempFile}                              # remove # and ; comments
sed -i 's/\-.*//' ${tempFile}                                                   # remove hyphens for ip ranges
sed -i 's/[[:blank:]]*$//' ${tempFile}                                          # remove space / tab from EOL

# #
#   calculate how many IPs are in a subnet
#   if you want to calculate the USABLE IP addresses, subtract -2 from any subnet not ending with 31 or 32.
#   
#   for our purpose, we want to block them all in the event that the network has reconfigured their network / broadcast IPs,
#   so we will count every IP in the block.
# #

BLOCKS_COUNT_TOTAL_IP=0
BLOCKS_COUNT_TOTAL_SUBNET=0

for line in $(cat ${tempFile}); do

    # is ipv6
    if [ "$line" != "${line#*:[0-9a-fA-F]}" ]; then
        COUNT_TOTAL_IP=`expr $COUNT_TOTAL_IP + 1`                               # GLOBAL count subnet
        BLOCKS_COUNT_TOTAL_IP=`expr $BLOCKS_COUNT_TOTAL_IP + 1`                 # LOCAL count subnet

    # is subnet
    elif [[ $line =~ /[0-9]{1,2}$ ]]; then
        ips=$(( 1 << (32 - ${line#*/}) ))

        regexIsNum='^[0-9]+$'
        if [[ $ips =~ $regexIsNum ]]; then
            CIDR=$(echo $line | sed 's:.*/::')

            # subtract - 2 from any cidr not ending with 31 or 32
            # if [[ $CIDR != "31" ]] && [[ $CIDR != "32" ]]; then
                # BLOCKS_COUNT_TOTAL_IP=`expr $BLOCKS_COUNT_TOTAL_IP - 2`
                # COUNT_TOTAL_IP=`expr $COUNT_TOTAL_IP - 2`
            # fi

            BLOCKS_COUNT_TOTAL_IP=`expr $BLOCKS_COUNT_TOTAL_IP + $ips`          # LOCAL count IPs in subnet
            BLOCKS_COUNT_TOTAL_SUBNET=`expr $BLOCKS_COUNT_TOTAL_SUBNET + 1`     # LOCAL count subnet

            COUNT_TOTAL_IP=`expr $COUNT_TOTAL_IP + $ips`                        # GLOBAL count IPs in subnet
            COUNT_TOTAL_SUBNET=`expr $COUNT_TOTAL_SUBNET + 1`                   # GLOBAL count subnet
        fi

    # is normal IP
    elif [[ $line =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        BLOCKS_COUNT_TOTAL_IP=`expr $BLOCKS_COUNT_TOTAL_IP + 1`
        COUNT_TOTAL_IP=`expr $COUNT_TOTAL_IP + 1`
    fi
done

# #
#   Count lines and subnets
# #

COUNT_LINES=$(wc -l < ${tempFile})                                              # GLOBAL count ip lines
COUNT_LINES=$(printf "%'d" "$COUNT_LINES")                                      # GLOBAL add commas to thousands
COUNT_TOTAL_IP=$(printf "%'d" "$COUNT_TOTAL_IP")                                # GLOBAL add commas to thousands
COUNT_TOTAL_SUBNET=$(printf "%'d" "$COUNT_TOTAL_SUBNET")                        # GLOBAL add commas to thousands

BLOCKS_COUNT_TOTAL_IP=$(printf "%'d" "$BLOCKS_COUNT_TOTAL_IP")                  # LOCAL add commas to thousands
BLOCKS_COUNT_TOTAL_SUBNET=$(printf "%'d" "$BLOCKS_COUNT_TOTAL_SUBNET")          # LOCAL add commas to thousands

echo -e "  🚛 Move ${tempFile} to ${ARG_SAVEFILE}"
cat ${tempFile} >> ${ARG_SAVEFILE}                                              # copy .tmp contents to real file
rm ${tempFile}                                                                  # delete temp file

echo -e "  ➕ Added ${BLOCKS_COUNT_TOTAL_IP} IPs and ${BLOCKS_COUNT_TOTAL_SUBNET} Subnets to ${tempFile}"
echo -e

# #
#   ed
#       0a  top of file
# #

ed -s ${ARG_SAVEFILE} <<END_ED
0a
# #
#   🧱 Firewall Blocklist - ${ARG_SAVEFILE}
#
#   @url            https://github.com/Aetherinox/csf-firewall
#   @id             ${ID}
#   @updated        ${NOW}
#   @entries        $COUNT_LINES lines
#                   $COUNT_TOTAL_SUBNET subnets
#                   $COUNT_TOTAL_IP ips
#   @expires        6 hours
#   @category       ${CATEGORY}
#
${DESCRIPTION}
# #

.
w
q
END_ED

# #
#   Move ipset to final location
# #

echo -e "  🚛 Move ${ARG_SAVEFILE} to ${FOLDER_SAVETO}/${ARG_SAVEFILE}"
mkdir -p ${FOLDER_SAVETO}/
mv ${ARG_SAVEFILE} ${FOLDER_SAVETO}/

# #
#   Finished
# #

T=$SECONDS
echo -e "  🎌 Finished"

# #
#   Run time
# #

echo -e
printf "  🕙 Elapsed time: %02d days %02d hrs %02d mins %02d secs\n" "$((T/86400))" "$((T/3600%24))" "$((T/60%60))" "$((T%60))"

# #
#   Output
# #

echo -e
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
printf "%-25s | %-30s\n" "  #️⃣  ${ARG_SAVEFILE}" "${COUNT_TOTAL_IP} IPs, ${COUNT_TOTAL_SUBNET} Subnets"
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
echo -e
echo -e
echo -e