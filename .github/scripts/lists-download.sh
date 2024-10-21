# #
#   Downloads a list of ip addresses that should be added to block lists.
#   This is used in combination with a Github workflow / action.
# #

#!/bin/bash

s100_90d_url="https://raw.githubusercontent.com/borestad/blocklist-abuseipdb/refs/heads/main/abuseipdb-s100-90d.ipv4"
s100_90d_file="csf.deny"
NOW=`date -u`

# #
#   vars > colors
#
#   tput setab  [1-7]       : Set a background color using ANSI escape
#   tput setb   [1-7]       : Set a background color
#   tput setaf  [1-7]       : Set a foreground color using ANSI escape
#   tput setf   [1-7]       : Set a foreground color
# #

BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
ORANGE=$(tput setaf 208)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 156)
LIME_YELLOW=$(tput setaf 190)
POWDER_BLUE=$(tput setaf 153)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
GREYL=$(tput setaf 242)
DEV=$(tput setaf 157)
DEVGREY=$(tput setaf 243)
FUCHSIA=$(tput setaf 198)
PINK=$(tput setaf 200)
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
BLINK=$(tput blink)
REVERSE=$(tput smso)
UNDERLINE=$(tput smul)
STRIKE="\e[9m"
END="\e[0m"

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

ed -s 1.txt <<EOT
1i
# #
#    ConfigServer Firewall (Deny List)
#
#    @url	        Aetherinox/csf-firewall
#    @desc	        list of ip addresses actively trying to scan servers
#    @last          ${NOW}
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