#!/bin/bash

# #
#   @for                https://github.com/Aetherinox/csf-firewall
#   @assoc              blocklist-generate.yml
#   @type               bash script
#   
#                       📁 .github
#                           📁 blocks
#                               📁 bruteforce
#                                   📄 *.txt
#                           📁 scripts
#                               📄 bl-download.sh
#                           📁 workflows
#                               📄 blocklist-generate.yml
#
#   activated from github workflow:
#       - .github/workflows/blocklist-generate.yml
#
#   within github workflow, run:
#       chmod +x ".github/scripts/bl-download.sh"
#       run_master=".github/scripts/bl-download.sh ${{ vars.API_01_OUT }} false ${{ secrets.API_01_FILE_01 }} ${{ secrets.API_01_FILE_02 }} ${{ secrets.API_01_FILE_03 }}"
#       eval "./$run_master"
#
#   downloads a list of .txt / .ipset IP addresses in single file.
#   generates a header to place at the top.
#   
#   @uage               bl-download.sh <ARG_SAVEFILE> <ARG_BOOL_DND:false|true> [ <URL_BL_1>, <URL_BL_1> {...} ]
#                       bl-download.sh 01_master.ipset false API_URL_1 
#                       bl-download.sh 01_master.ipset true API_URL_1 API_URL_2 API_URL_3
# #

# #
#   Arguments
#
#   This bash script has the following arguments:
#
#       ARG_SAVEFILE        (str)       file to save IP addresses into
#       ARG_BOOL_DND        (bool)      add `#do not delete` to end of each line
#       { ... }             (varg)      list of URLs to download files from
# #

ARG_SAVEFILE=$1
ARG_BOOL_DND=$2

# #
#    Define > General
# #

FOLDER_SAVETO="blocklists"
NOW=`date -u`
LINES=0
ID="${ARG_SAVEFILE//[^[:alnum:]]/_}"
DESCRIPTION=$(curl -sS "https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/.github/descriptions/${ID}.txt")
CATEGORY=$(curl -sS "https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/.github/categories/${ID}.txt")
regexURL='^(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]\.[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$'

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
   > ${ARG_SAVEFILE}       # clean file
else
    echo -e "  📄 Creating ${ARG_SAVEFILE}"
   touch ${ARG_SAVEFILE}
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
    if [ "$ARG_BOOL_DND" = true ] ; then
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
        download_list ${arg} ${ARG_SAVEFILE}
        echo -e
    fi
done

# #
#   Add Static Files
# #

if [ -d .github/blocks/ ]; then
	for file in .github/blocks/bruteforce/*.ipset; do
		echo -e "  📒 Adding static file ${file}"
    
		cat ${file} >> ${ARG_SAVEFILE}
        filter=$(grep -c "^[0-9]" ${file})     # count lines starting with number, print line count
        count=$(echo ${filter} | wc -l < ${file})
        echo -e "  👌 Added ${count} lines to ${ARG_SAVEFILE}"
	done
fi

# #
#   count total lines
# #

LINES=$(wc -l < ${ARG_SAVEFILE})    # count ip lines

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

echo -e "  ✏️ Modifying template values in ${ARG_SAVEFILE}"
sed -i -e "s/{COUNT_TOTAL}/$LINES/g" ${ARG_SAVEFILE}          # replace {COUNT_TOTAL} with number of lines

# #
#   Move ipset to final location
# #

echo -e "  📡 Moving ${ARG_SAVEFILE} to ${FOLDER_SAVETO}/${ARG_SAVEFILE}"
mkdir -p ${FOLDER_SAVETO}/
mv ${ARG_SAVEFILE} ${FOLDER_SAVETO}/

# #
#   Finished
# #

echo -e "  🎌 Finished"

# #
#   Output
# #

echo -e
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
printf "%-25s | %-30s\n" "  #️⃣  ${ARG_SAVEFILE}" "${LINES}"
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
echo -e