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
echo -e "  Blocklist - ${arg_file}"
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

    lines=$(wc -l < ${tempFile})                            # count ip lines

    echo -e "  🌎 Move ${tempFile} to ${fnFile}"
    cat ${tempFile} >> ${fnFile}                            # copy .tmp contents to real file

    echo -e "  👌 Added ${lines} lines to ${fnFile}"

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
        download_list ${arg} ${arg_file}
        echo -e
    fi
done

# #
#   Add Static Files
# #

if [ -d .github/blocks/ ]; then
	for file in .github/blocks/bruteforce/*.ipset; do
		echo -e "  📒 Adding static file ${file}"
    
		cat ${file} >> ${arg_file}
        filter=$(grep -c "^[0-9]" ${file})     # count lines starting with number, print line count
        count=$(echo ${filter} | wc -l < ${file})
        echo -e "  👌 Added ${count} lines to ${arg_file}"
	done
fi

# #
#   count total lines
# #

lines=$(wc -l < ${arg_file})    # count ip lines

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
#   auto-generated list which contains the following:
#       - AbuseIPDB 100% Confidence
#       - IPThreat.net 90% Confidence
#       - Port scanners
#       - SSH bruteforce attempts
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