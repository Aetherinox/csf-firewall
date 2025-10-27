#!/bin/bash

# #
#   @app                https://github.com/Aetherinox/csf-firewall
#   @workflow           blocklist-generate.yml
#   @type               bash script
#   @summary            generate ipset by fetching locally specified file in /blocks/ repo folder
#                       copies local ipsets from .github/blocks/${ARG_BLOCKS_CAT}/*.ipset
#   @storage            /.github/scripts/bl-block.sh
#   @command            .github/scripts/bl-block.sh blocklists/highrisk.ipset highrisk
# #

# #
#   Populate Paths
# #

OLDPWD=$(pwd)                                                           #  save current working directory
cd "$(dirname "$0")" || exit 1                                          #  change to the dir where the script resides
_app_path_bin=$(pwd)                                                    #  get absolute path
cd "$OLDPWD" || exit 1                                                  #  restore previous working directory

# #
#   Define › path
# #

app_path_runfrom="${PWD}"                                               #  path to where script called from
app_path_bin="${_app_path_bin}"                                         #  the path where script is called from

# #
#   Define › file
# #

app_file_this=$(basename "$0")                                          #  bl-block.sh       (with ext)
app_file_bin="${app_file_this%.*}"                                      #  bl-block          (without ext)

# #
#   Define › folders
# #

app_dir_this="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"           #  path where script was last found in
app_dir_github="${app_path_runfrom}/.github"                            #  .github folder

# #
#   Define › Colors
#   
#   Use the color table at:
#       - https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797
# #

esc=$(printf '\033')
end="${esc}[0m"
bold="${esc}[1m"
dim="${esc}[2m"
underline="${esc}[4m"
blink="${esc}[5m"
white="${esc}[97m"
black="${esc}[0;30m"
redl="${esc}[0;91m"
redd="${esc}[38;5;196m"
magental="${esc}[0;95m"
magentad="${esc}[0;35m"
fuchsial="${esc}[38;5;198m"
fuchsiad="${esc}[38;5;161m"
bluel="${esc}[38;5;75m"
blued="${esc}[38;5;33m"
greenl="${esc}[38;5;76m"
greend="${esc}[38;5;2m"
orangel="${esc}[0;93m"
oranged="${esc}[38;5;202m"
yellowl="${esc}[38;5;190m"
yellowd="${esc}[38;5;184m"
greyl="${esc}[38;5;250m"
greym="${esc}[38;5;244m"
greyd="${esc}[0;90m"
navy="${esc}[38;5;62m"
olive="${esc}[38;5;144m"
peach="${esc}[38;5;210m"
cyan="${esc}[38;5;6m"

# #
#   Define › Logging functions
# #

error( )
{
    printf '%-28s %-65s\n' "   ${redl} ERROR ${end}" "${greym} $1 ${end}"
}

warn( )
{
    printf '%-32s %-65s\n' "   ${yellowl} WARN ${end}" "${greym} $1 ${end}"
}

info( )
{
    printf '%-31s %-65s\n' "   ${bluel} INFO ${end}" "${greym} $1 ${end}"
}

status( )
{
    printf '%-31s %-65s\n' "   ${bluel} STATUS ${end}" "${greym} $1 ${end}"
}

ok( )
{
    printf '%-31s %-65s\n' "   ${greenl} OK ${end}" "${greym} $1 ${end}"
}

debug( )
{
    if [ "$argDevMode" = "true" ]; then
        printf '%-28s %-65s\n' "   ${greyd} DEBUG ${end}" "${greym} $1 ${end}"
    fi
}

verbose( )
{
    if [ "$VERBOSE" -eq 1 ]; then
        printf '%-28s %-65s\n' "   ${greyd} VERBOSE ${end}" "${greym} $1 ${end}"
    fi
}

label( )
{
    printf '%-31s %-65s\n' "   ${navy}        ${end}" "${navy} $1 ${end}"
}

labels( )
{
    printf '%-31s\n' "   ${greym} $1 ${end}"
}

print( )
{
    echo "${greym}$1${end}"
}

debug( )
{
    if [ "$argDevMode" = "true" ]; then
        printf '%-28s %-65s\n' "   ${greyd} DEBUG ${end}" "${greym} $1 ${end}"
    fi
}

verbose( )
{
    if [ "$VERBOSE" -eq 1 ]; then
        printf '%-28s %-65s\n' "   ${greyd} VERBOSE ${end}" "${greym} $1 ${end}"
    fi
}

# #
#   Print › Line
#   
#   Prints single line
#   
#   @usage          prins
# #

prins()
{
    local indent="   "
    local box_width=90
    local line_width=$(( box_width + 2 ))

    local line
    line=$(printf '─%.0s' $(seq 1 "$line_width"))

    print
    printf "%b%s%s%b\n" "${greyd}" "$indent" "$line" "${reset}"
    print
}

# #
#   Print › Box › Single Line Text
#   
#   Prints single line of text with a box surrounding it.
#   
#   @usage          prinb "${APP_NAME_SHORT:-CSF} › Customize csf.config"
# #

prinb( )
{
    local title="$*"
    local indent="   "
    local padding=6
    
    local visible_title
    visible_title=$(echo -e "$title" | sed 's/\x1b\[[0-9;]*m//g')
    
    local title_length=${#visible_title}
    local inner_width=$(( title_length + padding ))
    local box_width=90

    [ "$inner_width" -lt ${box_width} ] && inner_width=${box_width}

    local line
    line=$(printf '─%.0s' $(seq 1 "$inner_width"))

    local spaces_req=$(( inner_width - title_length - 3 ))
    local spaces=$(printf ' %.0s' $(seq 1 "$spaces_req"))

    print
    print
    printf "%b%s┌%s┐\n" "${greym}" "$indent" "$line"
    printf "%b%s│  %s%s │\n" "${greym}" "$indent" "$title" "$spaces"
    printf "%b%s└%s┘%b\n" "${greym}" "$indent" "$line" "${reset}"
    print
}

# #
#   Print > Box > Paragraph
#   
#   Prints multiple lines with a box surrounding it.
#   
#   @usage          prinp "CSF › Title" "This is a really long paragraph that will wrap multiple lines and align properly under the title. Second line of text, same alignment, with multiple words."
# #

prinp()
{
    local title="$1"
    shift
    local text="$*"

    local indent="   "
    local box_width=90
    local pad=2

    local content_width=$(( box_width ))
    local inner_width=$(( box_width - pad*2 ))

    print
    print
    local hline
    hline=$(printf '─%.0s' $(seq 1 "$content_width"))

    printf "${greyd}%s┌%s┐\n" "$indent" "$hline"

    # #
    #   title
    # #

    local title_width=$(( content_width - pad ))
    printf "${greym}%s│%*s${bluel}%-${title_width}s${greym}│\n" "$indent" "$pad" "" "$title"

    printf "${greyd}%s│%-${content_width}s│\n" "$indent" ""

    local line=""
    set -- $text
    for word; do
        if [ ${#line} -eq 0 ]; then
            line="$word"
        elif [ $(( ${#line} + 1 + ${#word} )) -le $inner_width ]; then
            line="$line $word"
        else
            printf "${greyd}%s│%*s%-*s%*s│\n" "$indent" "$pad" "" "$inner_width" "$line" "$pad" ""
            line="$word"
        fi
    done
    [ -n "$line" ] && printf "${greyd}%s│%*s%-*s%*s│\n" "$indent" "$pad" "" "$inner_width" "$line" "$pad" ""

    printf "${greyd}%s└%s┘${reset}\n" "$indent" "$hline"
    print
}

# #
#   Print › Box › Multi-line Text (Left Line)
#   
#   Prints single line with a box surrounding it, excluding the right side
#   
#   @usage          prinb "Name › Section"
# #

prinl( )
{
    local title="$*"
    local indent="   "
    local padding=6
    
    local visible_title
    visible_title=$(echo -e "$title" | sed 's/\x1b\[[0-9;]*m//g')
    
    local title_length=${#visible_title}
    local inner_width=$(( title_length + padding ))
    local box_width=90

    [ "$inner_width" -lt ${box_width} ] && inner_width=${box_width}

    local line
    line=$(printf '─%.0s' $(seq 1 "$inner_width"))

    local spaces_req=$(( inner_width - title_length - 3 ))
    local spaces=$(printf ' %.0s' $(seq 1 "$spaces_req"))

    print
    printf "%b%s┌%s┐\n" "${greym}" "$indent" "$line"
    printf "%b%s│  %s%s \n" "${greym}" "$indent" "$title" "$spaces"
    printf "%b%s└%s┘%b\n" "${greym}" "$indent" "$line" "${reset}"
    print
}

# #
#   Define › Logging › Verbose
# #

log()
{
    if [ "$VERBOSE" -eq 1 ]; then
		verbose "    $@ "
    fi
}

# #
#   Define › Args
# #

ARG_SAVEFILE=$1
ARG_BLOCKS_CAT=$2

if [[ -z "${ARG_SAVEFILE}" ]]; then
    echo -e
    error "    ⭕  No target file specified ${redl}${app_file_this}${greym}; aborting${greym}"
    echo -e
    exit 1
fi

if [[ -z "${ARG_BLOCKS_CAT}" ]]; then
    error "    ⭕  No static category specified ${redl}${app_file_this}${greym}; aborting${greym}"
    exit 1
fi

# #
#   Define › General
# #

SECONDS=0                                               # set seconds count for beginning of script
APP_VER=("1" "0" "0" "0")                               # current script version
APP_DEBUG=false                                         # debug mode
APP_REPO="Aetherinox/blocklists"                        # repository
APP_REPO_BRANCH="main"                                  # repository branch
APP_FILE_PERM="${ARG_SAVEFILE}"                         # perm file when building ipset list
APP_AGENT="Mozilla/5.0 (Windows NT 10.0; WOW64) "\
"AppleWebKit/537.36 (KHTML, like Gecko) "\
"Chrome/51.0.2704.103 Safari/537.36"                    # user agent used with curl

# #
#   Define › Count Defaults
# #

i_cnt_lines=0                                           # number of lines in doc
i_cnt_ip_total=0                                        # number of single IPs (counts each line)
i_cnt_subnet_total=0                                    # number of ips in all subnets combined
i_cnt_block_ip_total=0                                  # number of ips for one particular file
i_cnt_block_subnet_total=0                              # number of subnets for one particular file

# #
#   Define › Template
# #

templ_now="$(date -u)"
templ_id=$(basename -- "${APP_FILE_PERM}")
templ_id="${templ_id//[^[:alnum:]]/_}"
templ_uuid="$(uuidgen -m -N "${templ_id}" -n @url)"
templ_curl_opts=(-sSL -A "$APP_AGENT")

# #
#   Define › Template › External Sources
# #

curl "${templ_curl_opts[@]}" "https://raw.githubusercontent.com/${APP_REPO}/${APP_REPO_BRANCH}/.github/descriptions/${templ_id}.txt" > desc.txt &
curl "${templ_curl_opts[@]}" "https://raw.githubusercontent.com/${APP_REPO}/${APP_REPO_BRANCH}/.github/categories/${templ_id}.txt" > cat.txt &
curl "${templ_curl_opts[@]}" "https://raw.githubusercontent.com/${APP_REPO}/${APP_REPO_BRANCH}/.github/expires/${templ_id}.txt" > exp.txt &
curl "${templ_curl_opts[@]}" "https://raw.githubusercontent.com/${APP_REPO}/${APP_REPO_BRANCH}/.github/url-source/${templ_id}.txt" > src.txt &
wait
templ_desc=$(<desc.txt)
templ_cat=$(<cat.txt)
templ_exp=$(<exp.txt)
templ_url_src=$(<src.txt)
rm -f desc.txt cat.txt exp.txt src.txt

# #
#   Define › Template › Default Values
# #

if [[ "${templ_desc}" == *"404: Not Found"* ]]; then templ_desc="#   No description provided"; fi
if [[ "${templ_cat}" == *"404: Not Found"* ]]; then templ_cat="Uncategorized"; fi
if [[ "${templ_exp}" == *"404: Not Found"* ]]; then templ_exp="6 hours"; fi
if [[ "${templ_url_src}" == *"404: Not Found"* ]]; then templ_url_src="None"; fi

# #
#   Define › Regex
# #

regex_url='^(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]\.[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$'
regex_isnum='^[0-9]+$'

# #
#   Output › Header
# #

echo
prins
print "    ${yellowl}${APP_FILE_PERM}${end}"
print
print "    ${greym}ID:          ${templ_id}${end}"
print "    ${greym}UUID:        ${templ_uuid}${end}"
print "    ${greym}CATEGORY:    ${templ_cat}${end}"
print "    ${greym}ACTION:      ${app_file_this}${end}"
prins

# #
#   Start
# #

info "    ⭐ Starting script ${bluel}${app_file_this}${greym}"

# #
#   Create or Clean file
# #

if [ -f "${APP_FILE_PERM}" ]; then
    info "    🗑️  Wipe existing file ${bluel}${PWD}/${APP_FILE_PERM}${greym}"
   > "${APP_FILE_PERM}"       # clean file
else
    info "    📁 Create ${bluel}${PWD}/${APP_FILE_PERM}${greym}"
    mkdir -p "$(dirname "${APP_FILE_PERM}")"

    if [ -d "$(dirname "${APP_FILE_PERM}")" ]; then
        ok "    📁 Created ${greenl}$(dirname "${APP_FILE_PERM}")${greym}"
    else
        error "    ⭕  Failed to create directory ${redl}$(dirname "${APP_FILE_PERM}")${greym}; aborting${greym}"
        exit 1
    fi

    touch "${APP_FILE_PERM}"
    if [ -f "${APP_FILE_PERM}" ]; then
        ok "    📄 Created perm file ${greenl}${PWD}/${APP_FILE_PERM}${greym}"
    else
        error "    ⭕ Failed to create perm file ${bluel}${PWD}/${APP_FILE_PERM}${greym}"
        exit 1
    fi
fi

# #
#   Pre-clean generated data BEFORE appending static blocks
#       - remove comment lines starting with # or ;
#       - remove blank lines
#       - remove trailing whitespace
#       - sort and dedupe
# #

if [ -f "${APP_FILE_PERM}" ]; then
    info "    📄 Cleaning current list of IPs in file ${bluel}${PWD}/${APP_FILE_PERM}"
    awk '!/^(#|;|[[:space:]]*$)/ { sub(/[[:space:]]+$/,""); if(!seen[$0]++) print }' "${APP_FILE_PERM}" | sort -V > "${APP_FILE_PERM}.tmp" && mv "${APP_FILE_PERM}.tmp" "${APP_FILE_PERM}"
fi

# #
#   Add Static Files
# #

if [ -d ".github/blocks/" ]; then

    # #
    #   Determines if the category provided is either a folder, or a file ending with `.ipset`.
    #   
    #   if a folder is provided, all files in the folder will be looped and loaded.
    #   if a file is provided, only that one file will be loaded.
    # #

    APP_BLOCK_TARGET=".github/blocks/${ARG_BLOCKS_CAT}/*.ipset"
    if [[ "${ARG_BLOCKS_CAT}" == *ipset ]]; then
        APP_BLOCK_TARGET=".github/blocks/${ARG_BLOCKS_CAT}"
    fi

    # #
    #   Block folder specified. Each file in folder will be loaded.
    #   
    #   @usage      .github/scripts/bl-block.sh blocklists/isp/isp_aol.ipset isp/aol
    # #

    for APP_FILE_TEMP in ${APP_BLOCK_TARGET}; do
        info "    📒 Reading static block ${bluel}${PWD}/${APP_FILE_TEMP}"

        # #
        #   calculate how many IPs are in a subnet
        #   if you want to calculate the USABLE IP addresses, subtract -2 from any subnet not ending with 31 or 32.
        #   
        #   for our purpose, we want to block them all in the event that the network has reconfigured their network / broadcast IPs,
        #   so we will count every IP in the block.
        # #

        i_cnt_block_ip_total=0
        i_cnt_block_subnet_total=0

        info "    📊 Fetching statistics for ${bluel}${PWD}/${APP_FILE_TEMP}"

        # line-by-line read (preserves spaces + full lines)
        while IFS= read -r line; do
            # skip empty lines
            [[ -z "${line}" ]] && continue

            # is ipv6 (contains a colon)
            if [[ "${line}" == *:* ]]; then
                if [[ ${line} =~ /[0-9]{1,3}$ ]]; then
                    i_cnt_subnet_total=$((i_cnt_subnet_total + 1))
                    i_cnt_block_subnet_total=$((i_cnt_block_subnet_total + 1))
                else
                    i_cnt_ip_total=$((i_cnt_ip_total + 1))
                    i_cnt_block_ip_total=$((i_cnt_block_ip_total + 1))
                fi
            # is subnet (ipv4)
            elif [[ ${line} =~ /[0-9]{1,2}$ ]]; then
                ips=$((1 << (32 - ${line#*/})))
                if [[ ${ips} =~ ${regex_isnum} ]]; then
                    i_cnt_block_ip_total=$((i_cnt_block_ip_total + ips))
                    i_cnt_block_subnet_total=$((i_cnt_block_subnet_total + 1))
                    i_cnt_ip_total=$((i_cnt_ip_total + ips))
                    i_cnt_subnet_total=$((i_cnt_subnet_total + 1))
                fi
            # is normal IP (ipv4)
            elif [[ ${line} =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                i_cnt_block_ip_total=$((i_cnt_block_ip_total + 1))
                i_cnt_ip_total=$((i_cnt_ip_total + 1))
            fi
        done < "${APP_FILE_TEMP}"

        # #
        #   Count lines and subnets
        # #

        i_cnt_lines=$(wc -l < "${APP_FILE_TEMP}")                                       # GLOBAL count ip lines
        i_cnt_lines=$(printf "%'d" "${i_cnt_lines}")                                    # GLOBAL add commas to thousands
        i_cnt_ip_total=$(printf "%'d" "${i_cnt_ip_total}")                              # GLOBAL add commas to thousands
        i_cnt_subnet_total=$(printf "%'d" "${i_cnt_subnet_total}")                      # GLOBAL add commas to thousands
        i_cnt_block_ip_total=$(printf "%'d" "${i_cnt_block_ip_total}")                  # LOCAL add commas to thousands
        i_cnt_block_subnet_total=$(printf "%'d" "${i_cnt_block_subnet_total}")          # LOCAL add commas to thousands

        info "    🚛 Copy static block rules from ${bluel}${PWD}/${APP_FILE_TEMP}${greym} to ${bluel}${PWD}/${APP_FILE_PERM}${greym}"

        cat "${APP_FILE_TEMP}" >> "${APP_FILE_PERM}"
        ok "    ➕ Added ${bluel}${i_cnt_block_ip_total} IPs${greym} and ${bluel}${i_cnt_block_subnet_total} subnets${greym} to ${bluel}${PWD}/${APP_FILE_PERM}"
    done
else
    warn "    ❌ No static blocklist found at ${orangel}.github/blocks/${greym}"
fi

# #
#   Template › Header
# #

ed -s "${APP_FILE_PERM}" <<END_ED
0a
# #
#   🧱 Firewall Blocklist - ${APP_FILE_PERM}
#   
#   @url            https://raw.githubusercontent.com/${APP_REPO}/${APP_REPO_BRANCH}/${APP_FILE_PERM}
#   @source         ${templ_url_src}
#   @id             ${templ_id}
#   @uuid           ${templ_uuid}
#   @updated        ${templ_now}
#   @entries        ${i_cnt_ip_total} ips
#                   ${i_cnt_subnet_total} subnets
#                   ${i_cnt_lines} lines
#   @expires        ${templ_exp}
#   @category       ${templ_cat}
#
${templ_desc}
# #

.
w
q
END_ED

# #
#   Output › Stats
# #

T=$SECONDS
D=$((T/86400))
H=$((T/3600%24))
M=$((T/60%60))
S=$((T%60))

print
labels "🎌 Finished! ${yellowd}${D} days ${H} hrs ${M} mins ${S} secs"

prinl "#️⃣  ${bluel}${APP_FILE_PERM}${end} | Added ${fuchsial}${i_cnt_ip_total} IPs${end} and ${fuchsial}${i_cnt_subnet_total} Subnets"
