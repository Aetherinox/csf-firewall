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
#                       bl-static.sh privacy.ipset privacy
# #

regexURL='^(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]\.[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$'

# #
#   Parameters
#
#   arg_output
#       file to save to
#
#   arg_static
#       static file to compile
# #

arg_output=$1
arg_static=$2

# #
#    Define > General
# #

NOW=`date -u`
lines=0

# #
#   Validate vars
# #

if [ -z "${arg_static}" ]; then
    echo -e "  ⭕  Aborting -- no static file category specified"
    exit 1
fi

# #
#   Output > Header
# #

echo -e
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
echo -e "  Blocklist - ${arg_output} (${arg_static})"
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"

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
	for file in .github/blocks/${arg_static}/*.ipset; do
		echo -e "  📒 Adding static file ${file}"
    
		cat ${file} >> ${arg_output}
        count=$(grep -c "^[0-9]" ${file})           # count lines starting with number, print line count
        lines=`expr $lines + $count`                # add line count from each file together
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
#   @category       full
#
#   This is a static list of abusive IP addresses provided by https://github.com/Aetherinox/csf-firewall
#   This list contains IP addresses to servers that frequently scan websites in order to obtain information. 
#   This can include crawlers and research groups.
# #

.
w
q
END_ED

echo -e "  ✏️  Modifying template values in ${arg_output}"
sed -i -e "s/{COUNT_TOTAL}/$lines/g" ${arg_output}          # replace {COUNT_TOTAL} with number of lines

echo -e "  🎌 Finished"

# #
#   Output
# #

echo -e
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
printf "%-25s | %-30s\n" "  #️⃣  ${arg_output}" "${lines}"
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
echo -e