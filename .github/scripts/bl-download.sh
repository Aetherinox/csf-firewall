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
#               📄 bl-download.yml
#
#   @uage               bl-download.sh <URL_BLOCKLIST_DOWNLOAD> <FILE_SAVEAS>
#                       bl-download.sh https://api.endpoint/to/website/ipv4.list csf.deny
#                       bl-download.sh https://api.endpoint/to/website/ipv4.list csf.deny true
# #

# #
#   Parameters
#   
#   arg_url
#       web url to download blocklist from
#
#   arg_file
#       file to save to
#
#   arg_bDND
#       add `#do not delete` to end of each line
# #

arg_url=$1
arg_file=$2
arg_bDND=$3

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

    echo -e "  ✏️  Modifying template values in ${fnFile}"
    sed -i -e "s/{COUNT_TOTAL}/$lines/g" ${fnFile}          # replace {COUNT_TOTAL} with number of lines

    echo -e "  ☑️  Added ${lines} lines to ${fnFile}"
}

# #
#   Download lists
# #

download_list ${arg_url} ${arg_file}