# #
#   Downloads a list of ip addresses that should be added to block lists.
#   This is used in combination with a Github workflow / action.
#   
#   local test requires the same structure as the github workflow
#       📁 .github
#           📁 blocks
#               📄 1.txt
#           📁 scripts
#               📄 lists-download.sh
#           📁 workflows
#               📄 lists-download.yml
# #

#!/bin/bash

s100_90d_url="https://raw.githubusercontent.com/borestad/blocklist-abuseipdb/refs/heads/main/abuseipdb-s100-90d.ipv4"
s100_90d_file="csf.deny"
NOW=`date -u`

echo -e "⭐ Starting"

# #
#   Func > Download List
# #

download_list()
{
    local url=$1
    local file=$2
    
    curl ${url} -o ${file} >/dev/null 2>&1
    sed -i '/^#/d' ${file}
    sed -i 's/$/\t\t\#\ do\ not\ delete/' ${file}

ed -s ${file} <<EOT
1i
# #
#    🧱 ConfigServer Firewall (Deny List)
#
#    @url          Aetherinox/csf-firewall
#    @desc         list of ip addresses actively trying to scan servers
#    @last         ${NOW}
# #

.
w
q
EOT

}

# #
#   Download lists
# #

download_list ${s100_90d_url} ${s100_90d_file}

# #
#   Static Block Lists:
#
#   Merge custom block list
#   these are blocks that will stay static and only be added to static
# #

if [ -d .github/blocks/ ]; then
	for file in .github/blocks/*.txt; do
		echo -e "🗄️ Adding static file ${file}"
		cat ${file} >> ${s100_90d_file}
	done
fi