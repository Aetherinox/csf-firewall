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
#   @uage               bl-download.sh <URL_BLOCKLIST_DOWNLOAD> <FILE_SAVEAS>
#                       bl-download.sh csf.deny false API_URL_1 
#                       bl-download.sh csf.deny true API_URL_1 API_URL_2 API_URL_3
# #

regexURL='^(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]\.[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$'

# #
#   Parameters
#
#   arg_file
#       file to save to
#
#   arg_bDND
#       add `#do not delete` to end of each line
# #

arg_file=$1
arg_bDND=$2

# #
#    Define > General
# #

NOW=`date -u`
lines=0

# #
#   Output > Header
# #

echo -e
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
echo -e "  Blocklist - ${arg_file} (Privacy)"
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"

echo -e
echo -e "  ⭐ Starting"

# #
#   Create or Clean file
# #

if [ -f $arg_file ]; then
    echo -e "  📄 Cleaning ${arg_file}"
   > ${arg_file}       # clean file
else
    echo -e "  📄 Creating ${arg_file}"
   touch ${arg_file}
fi

# #
#   Add Static Files
# #

if [ -d .github/blocks/ ]; then
	for file in .github/blocks/privacy/*.ipset; do
		echo -e "  📒 Adding static file ${file}"
    
		cat ${file} >> ${arg_file}
        count=$(grep -c "^[0-9]" ${file})           # count lines starting with number, print line count
        lines=`expr $lines + $count`                # add line count from each file together
        echo -e "  👌 Added ${count} lines to ${arg_file}"
	done
fi

# #
#   ed
#       0a  top of file
# #

ed -s ${arg_file} <<END_ED
0a
# #
#   🧱 Firewall Blocklist - ${arg_file}
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

echo -e "  ✏️  Modifying template values in ${arg_file}"
sed -i -e "s/{COUNT_TOTAL}/$lines/g" ${arg_file}          # replace {COUNT_TOTAL} with number of lines

echo -e "  🎌 Finished"

# #
#   Output
# #

echo -e
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
printf "%-25s | %-30s\n" "  #️⃣  ${arg_file}" "${lines}"
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
echo -e