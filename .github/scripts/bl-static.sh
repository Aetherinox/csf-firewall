#!/bin/bash

# #
#   @for                https://github.com/Aetherinox/csf-firewall
#   @assoc              bl-download.yml
#   @type               bash script
#   
#   used in combination with .github/workflows/bl-download.yml
#
#   fetches a list of ipsets within the local repository and puts them together into
#   a single file
#   
#   api-endpoint hosted internally
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
#   @uage               bl-static.sh <FILE_SAVE_AS> <STATIC_CATEGORY>
#                       bl-static.sh 02_privacy_general.ipset privacy
# #

# #
#   Parameters
#
#   arg_output
#       file to save to
#
#   arg_folder
#       static file to compile
#       options:
#           - privacy
#           - bruteforce
# #

arg_output=$1
arg_folder=$2

# #
#   Validation checks
# #

if [[ -z "${arg_output}" ]]; then
    echo -e "  ⭕ No output file specified for Google Crawler list"
    echo -e
    exit 1
fi

if [ -z "${arg_folder}" ]; then
    echo -e "  ⭕  Aborting -- no static file category specified. ex: privacy"
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
echo -e "  Blocklist - ${arg_output} (${arg_folder})"
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
#   Add Static Files
# #

if [ -d .github/blocks/ ]; then
	for file in .github/blocks/${arg_folder}/*.ipset; do
		echo -e "  📒 Adding static file ${file}"
    
		cat ${file} >> ${arg_output}
        count=$(grep -c "^[0-9]" ${file})           # count lines starting with number, print line count
        LINES=`expr $LINES + $count`                # add line count from each file together
        echo -e "  👌 Added ${count} lines to ${arg_output}"
	done
fi

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