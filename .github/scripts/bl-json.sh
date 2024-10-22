#!/bin/bash

# #
#   @for                https://github.com/Aetherinox/csf-firewall
#   @assoc              bl-download.yml
#   @type               bash script
#   
#   used in combination with .github/workflows/bl-download.yml
#
#   allows you to specify a .json file, and the query to use for data extraction.
#   
#   local test requires the same structure as the github workflow
#       📁 .github
#           📁 blocks
#               📄 privacy.txt
#           📁 scripts
#               📄 bl-download.sh
#           📁 workflows
#               📄 blocklist-generate.yml
#
#   @uage               bl-json.sh <FILE_SAVE_AS> <API_URL> <JQ_JSON_QUERY>
#                       bl-json.sh googlecrawl.ipset https://api.domain.lan/googlebot.json '.prefixes | .[] |.ipv4Prefix//empty,.ipv6Prefix//empty'
# #

# #
#   Parameters
#
#   arg_output
#       file to save to
#
#   arg_url
#       url to online api file
# #

arg_output=$1
arg_url=$2
arg_jsonquery=$3

# #
#   Validation checks
# #

if [[ -z "${arg_output}" ]]; then
    echo -e "  ⭕ No output file specified for Google Crawler list"
    echo -e
    exit 1
fi

if [[ -z "${arg_url}" ]] || [[ ! $arg_url =~ $regexURL ]]; then
    echo -e "  ⭕ Invalid URL specified for ${arg_output}"
    echo -e
    exit 1
fi

if [[ -z "${arg_jsonquery}" ]]; then
    echo -e "  ⭕ No valid jq query specified for ${arg_output}"
    echo -e
    exit 1
fi

# #
#    Define > General
# #

FOLDER_SAVETO="blocklists"
NOW=`date -u`
LINES=0
ID="${arg_output//[^[:alnum:]]/_}"
DESCRIPTION=$(curl -sS "https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/.github/descriptions/${ID}.txt")
CATEGORY=$(curl -sS "https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/.github/categories/${ID}.txt")
regexURL='^(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]\.[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$'

# #
#   Output > Header
# #

echo -e
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
echo -e "  Blocklist - ${arg_output}"
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

if [ -f $arg_output ]; then
    echo -e "  📄 Cleaning ${arg_output}"
   > ${arg_output}       # clean file
else
    echo -e "  📄 Creating ${arg_output}"
   touch ${arg_output}
fi

# #
#   Get IP list
# #

echo -e "  🌎 Downloading IP blacklist to ${arg_output}"

# #
#   Get IP list
# #

tempFile="${arg_output}.tmp"
jsonOutput=$(curl -Ss ${arg_url} | jq -r "${arg_jsonquery}" > ${tempFile})
sed -i 's/\ #.*//' ${tempFile}                          # remove comments at end
sed -i 's/\-.*//' ${tempFile}                           # remove hyphens for ip ranges
sed -i '/^#/d' ${tempFile}                              # remove lines starting with `#`

# #
#   count lines
# #

LINES=$(wc -l < ${tempFile})                            # count ip lines

# #
#   move temp file to perm
# #

echo -e "  🌎 Move ${tempFile} to ${arg_output}"
cat ${tempFile} >> ${arg_output}                        # copy .tmp contents to real file
rm ${tempFile}
echo -e "  👌 Added ${LINES} lines to ${arg_output}"

# #
#   ed
#       0a  top of file
# #

ed -s ${arg_output} <<END_ED
0a
# #
#   🧱 Firewall Blocklist - ${arg_output}
#
#   @url            https://github.com/Aetherinox/csf-firewall
#   @updated        ${NOW}
#   @entries        {COUNT_TOTAL}
#   @expires        6 hours
#   @category       ${CATEGORY}
#
${DESCRIPTION}
# #

.
w
q
END_ED

echo -e "  ✏️ Modifying template values in ${arg_output}"
sed -i -e "s/{COUNT_TOTAL}/$LINES/g" ${arg_output}          # replace {COUNT_TOTAL} with number of lines

# #
#   Move ipset to final location
# #

echo -e "  📡 Moving ${arg_output} to ${FOLDER_SAVETO}/${arg_output}"
mkdir -p ${FOLDER_SAVETO}/
mv ${arg_output} ${FOLDER_SAVETO}/

# #
#   Finished
# #

echo -e "  🎌 Finished"

# #
#   Output
# #

echo -e
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
printf "%-25s | %-30s\n" "  #️⃣  ${arg_output}" "${LINES}"
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
echo -e