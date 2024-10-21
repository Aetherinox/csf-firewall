#!/bin/bash

# #
#   @usage              https://github.com/Aetherinox/csf-firewall
#   @type               bash script
#   
#   used in combination with .github/workflows/db-blocklist-download.yml
#
#   download AbuseIPDB ip list after list of ips are downloaded, merges them with a static list
#   that is not updated as often which contains a list of long-term abusive ip addresses
#   
#   local test requires the same structure as the github workflow
#       📁 .github
#           📁 blocks
#               📄 1.txt
#           📁 scripts
#               📄 db-blocklist-download.sh
#           📁 workflows
#               📄 db-blocklist-download.yml
#
#   @uage               db-blocklist-download.sh <URL_BLOCKLIST_DOWNLOAD> <FILE_SAVEAS>
#                       db-blocklist-download.sh https://path/to/website/ipv4.list csf.deny
# #

# #
#    Define > Parameters
# #

s100_90d_url="$1"
s100_90d_file="$2"

# #
#    Define > IPThreat.net Lists
# #

ipt_url="https://lists.ipthreat.net/file/ipthreat-lists/threat/threat-90.txt"
ipt_file="_ipb.txt"

# #
#    Define > General
# #

NOW=`date -u`
lines_static=0
lines_dynamic=0
lines_ipt=0

# #
#   Output > Header
# #

echo -e
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
echo -e "   csf.deny Blacklist Generation"
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"

echo -e
echo -e "  ⭐ Starting"

# #
#   Func > Download List
# #

download_list()
{
    local url=$1
    local file=$2
    
    echo -e "  🌎 Downloading IP blacklist to ${file}"

    curl ${url} -o ${file} >/dev/null 2>&1
    sed -i '/^#/d' ${file}                              # remove lines starting with `#`
    sed -i 's/$/\t\t\t\#\ do\ not\ delete/' ${file}     # add csf `# do not delete` to end of each line
    lines_dynamic=$(wc -l < ${file})                    # count ip lines

# #
#   Header > Dynamic List
# #

ed -s ${file} <<EOT
1i
# #
#   🧱 ConfigServer Firewall (Deny List)
#
#   @url            Aetherinox/csf-firewall
#   @desc           list of ip addresses actively trying to scan servers
#                       ip addresses no more than 90 days old.
#   @last           ${NOW}
#   @count          {COUNT_TOTAL}
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
#   IPThreat > Modify
# #

curl ${ipt_url} -o ${ipt_file} >/dev/null 2>&1
sed -i 's/\ #.*//' ${ipt_file}                          # remove comments at end
sed -i 's/\-.*//' ${ipt_file}                           # remove hyphens for ip ranges
sed -i '/^#/d' ${ipt_file}                              # remove lines starting with `#`
sed -i 's/$/\t\t\t\#\ do\ not\ delete/' ${ipt_file}     # add csf `# do not delete` to end of each line

lines_ipt=$(wc -l < ${ipt_file})                        # count ip lines

# #
#   IPThreat > Add Header
# #

ed -s ${s100_90d_file} <<END
a

# #
#   🧱 IPThreat.net
#   Full list available at https://ipthreat.net/
#
#   @count          {COUNT_IPT}
# #

.
w
q
END

# #
#   IPThreat > Save list to csf.deny
# #

cat ${ipt_file} >> ${s100_90d_file}

# #
#   Static > Add Header
# #

ed -s ${s100_90d_file} <<END
a

# #
#   🧱 Static Threat List
#
#   This is a static list of abusive IP addresses provided by https://github.com/Aetherinox/csf-firewall
#   These have been found port scanning and attempting multiple ssh bruteforce attacks.
#
#   @count          {COUNT_STATIC}
# #

.
w
q
END

# #
#   Static Block Lists:
#
#   Merge custom block list
#   these are blocks that will stay static and only be added to static
# #

if [ -d .github/blocks/ ]; then
	for file in .github/blocks/*.txt; do
		echo -e "  🗄️  Adding static file ${file}"
    
		cat ${file} >> ${s100_90d_file}
        count=$(grep -c "^[0-9]" ${file} | wc -l < ${file})     # count lines starting with number, print line count
        lines_static=`expr $lines_static + $count`              # add line count from each file together
	done
fi

# #
#   Header > Add Counts
# #

lines=`expr $lines_static + $lines_dynamic + $lines_ipt`
sed -i -e "s/{COUNT_TOTAL}/$lines/g" ${s100_90d_file}
sed -i -e "s/{COUNT_IPT}/$lines_ipt/g" ${s100_90d_file}
sed -i -e "s/{COUNT_STATIC}/$lines_static/g" ${s100_90d_file}

# #
#   Output
# #

echo -e
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
printf "%-25s | %-30s\n" "  #️⃣  Dynamic" "${lines_dynamic}"
printf "%-25s | %-30s\n" "  #️⃣  IPThreat" "${lines_ipt}"
printf "%-25s | %-30s\n" "  #️⃣  Static" "${lines_static}"
echo -e