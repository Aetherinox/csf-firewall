#!/bin/bash

# #
#   @for                https://github.com/Aetherinox/csf-firewall
#   @assoc              bl-download.yml
#   @type               bash script
#   
#   used in combination with .github/workflows/bl-download.yml
#
#   downloads a list of .txt / .ipset IP addresses in single file.
#   generates a header to place at the top.
#   
#   api-endpoint hosted internally
#   
#   local test requires the same structure as the github workflow
#       📁 .github
#           📁 blocks
#               📄 1.txt
#           📁 scripts
#               📄 bl-download.sh
#           📁 workflows
#               📄 blocklist-generate.yml
#
#   @uage               bl-download.sh <URL_BLOCKLIST_DOWNLOAD> <FILE_SAVEAS>
#                       bl-download.sh 01_master.ipset false API_URL_1 
#                       bl-download.sh 01_master.ipset true API_URL_1 API_URL_2 API_URL_3
# #

# #
#   Parameters
#
#       arg_output
#       file to save to
#
#       arg_bDND
#       add `#do not delete` to end of each line
# #

arg_output=$1
arg_bDND=$2

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
#   Func > Download List
# #

download_list()
{

    local fnUrl=$1
    local fnFile=$2
    local tempFile="${2}.tmp"

    echo -e "  🌎 Downloading IP blacklist to ${tempFile}"

    curl ${fnUrl} -o ${tempFile} >/dev/null 2>&1            # download file
    sed -i 's/\ #.*//' ${tempFile}                          # remove comments at end
    sed -i 's/\-.*//' ${tempFile}                           # remove hyphens for ip ranges
    sed -i '/^#/d' ${tempFile}                              # remove lines starting with `#`
    if [ "$arg_bDND" = true ] ; then
        echo -e "  ⭕ Enabled \`# do not delete\`"
        sed -i 's/$/\t\t\t\#\ do\ not\ delete/' ${tempFile} # add csf `# do not delete` to end of each line
    fi

    LINES=$(wc -l < ${tempFile})                            # count ip lines

    echo -e "  🌎 Move ${tempFile} to ${fnFile}"
    cat ${tempFile} >> ${fnFile}                            # copy .tmp contents to real file

    echo -e "  👌 Added ${LINES} lines to ${fnFile}"

    # #
    #   Cleanup
    # #

    rm ${tempFile}
}

# #
#   Download lists
# #

for arg in "${@:3}"; do
    if [[ $arg =~ $regexURL ]]; then
        download_list ${arg} ${arg_output}
        echo -e
    fi
done

# #
#   Add Static Files
# #

if [ -d .github/blocks/ ]; then
	for file in .github/blocks/bruteforce/*.ipset; do
		echo -e "  📒 Adding static file ${file}"
    
		cat ${file} >> ${arg_output}
        filter=$(grep -c "^[0-9]" ${file})     # count lines starting with number, print line count
        count=$(echo ${filter} | wc -l < ${file})
        echo -e "  👌 Added ${count} lines to ${arg_output}"
	done
fi

# #
#   count total lines
# #

LINES=$(wc -l < ${arg_output})    # count ip lines

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