#!/bin/sh

# #
#   Copyright (C) 2025 Aetherinox
#   Copyright (C) 2006-2025 Jonathan Michaelson
#   
#   This program is free software; you can redistribute it and/or modify it under
#   the terms of the GNU General Public License as published by the Free Software
#   Foundation; either version 3 of the License, or (at your option) any later
#   version.
#   
#   This program is distributed in the hope that it will be useful, but WITHOUT
#   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
#   FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
#   details.
#   
#   You should have received a copy of the GNU General Public License along with
#   this program; if not, see <https://www.gnu.org/licenses>.
#   
#   @script     ConfigServer Firewall Downloader
#   @desc       Fetches the latest version of CSFirewall from github repository to local machine.
#   @author     Aetherinox
#   @repo       https://github.com/Aetherinox/csf-firewall
#   
#   @usage      Download Only                               sh get.sh
#               Download + Extract                          sh get.sh --extract
#               Download + Extract + Install                sh get.sh --install
#               Download + Install (Dryrun)                 sh get.sh --install --dryrun
#               Install Only Existing Archive               sh get.sh --installOnly
#               Install Only Existing Archive (Dryun)       sh get.sh --installOnly --dryrun
#               Clean existing archive + folder             sh get.sh --clean
#               Help menu                                   sh get.sh --help
#               Version information                         sh get.sh --version
#   
#   @notes      --install automatically extracts
#               --dryrun is passed to csf install.sh script
#               --installOnly requires existing .tar/.zip; 
#                   will not download new from github.
#               --clean removes .tar/.zip and csf folder
# #

# #
#   define › colors
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
fuchsial="${esc}[38;5;205m"
fuchsiad="${esc}[38;5;198m"
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

# #
#   define › general
# #

app_title="ConfigServer Firewall & Security"
app_about="Bash utility to download the latest version of ConfigServer Firewall from the official github repository."
app_repo_branch="main"
app_ver=1.0.0
app_repo="Aetherinox/csf-firewall"
github_url="https://github.com/$app_repo"
api_url="https://api.github.com/repos/$app_repo/releases/latest"
file_release="csf-firewall-v"
file_installer="install.sh"
folder_extract="csf"

# #
#   define › args
# #

argExtract="false"
argInstall="false"
argInstallOnly="false"
argDryrun="false"
argInstaller=""
argDev="false"
argStatus="downloaded"

# #
#   define › files
# #

app_file_this=$(basename "$0")                                                      #  get.sh (with ext)
app_file_bin="${app_file_this%.*}"                                                  #  get (without ext)

# #
#   define › folders
# #

app_dir=$(dirname -- "$0")
app_dir=$(cd "$app_dir" && pwd)
app_dir_this_dir=$PWD

# #
#   https://man7.org/linux/man-pages/man1/date.1.html
#   
#   Thu, 01 May 2025 14:33:00 +0200
#   
#   %a      locale's abbreviated weekday name (e.g., Sun)
#   %d      day of month (e.g., 01)
#   %b      locale's abbreviated month name (e.g., Jan)
#   %Y      year
#   %H      hour (00..23)
#   %M      minute (00..59)
#   %S      second (00..60)
# #

date_now=$(date -u '+%a, %d %b %Y %H:%M:%S')
date_stamp=$(date -u '+%m/%d/%Y %H:%M')

# #
#   func › usage menu
# #

opt_usage()
{
    echo
    printf "  ${bluel}${app_title}${end}\n" 1>&2
    printf "  ${greym}${app_about}${end}\n" 1>&2
    printf "  ${greyd}version:${end} ${greyd}$app_ver${end}\n" 1>&2
    printf "  ${fuchsiad}$app_file_this${end} ${greyd}[${greym}--help${greyd}]${greyd}  |  ${greyd}[${greym}--version${greyd}]${greyd}  |  ${greyd}[${greym}--clean${greyd}]${greyd}  |  ${greyd}[${greym}--extract${greyd}${end} ${greyd}[${greym}--install${greyd}] ${end}${greyd}[${greym}--dryrun${greyd}]]${greyd}  |  ${greyd}[${greym}--installOnly${greyd} ${greyd}[${greym}--dryrun${greyd}]]${greyd}  |  ${greyd}[${greym}--install${greyd} ${greyd}[${greym}--dryrun${greyd}]]${end}" 1>&2
    echo
    echo
    printf '  %-5s %-40s\n' "${greyd}Syntax:${end}" "" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}Command${end}           " "${fuchsiad}$app_file_this${greyd} [ ${greym}-option ${greyd}[ ${yellowd}arg${greyd} ]${greyd} ]${end}" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}Options${end}           " "${fuchsiad}$app_file_this${greyd} [ ${greym}-h${greyd} | ${greym}--help${greyd} ]${end}" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "    ${greym}-A${end}            " " ${white}required" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "    ${greym}-A...${end}         " " ${white}required; multiple can be specified" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "    ${greym}[ -A ]${end}        " " ${white}optional" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "    ${greym}[ -A... ]${end}     " " ${white}optional; multiple can be specified" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "    ${greym}{ -A | -B }${end}   " " ${white}one or the other; do not use both" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}Arguments${end}         " "${fuchsiad}$app_file_this${end} ${greyd}[ ${greym}-d${yellowd} arg${greyd} | ${greym}--name ${yellowd}arg${greyd} ]${end}${yellowd} arg${end}" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}Examples${end}          " "${fuchsiad}$app_file_this${end} ${end}" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}${end}                  " "${fuchsiad}$app_file_this${end} ${greym}--install${yellowd} ${end}" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}${end}                  " "${fuchsiad}$app_file_this${end} ${greym}--extract${yellowd} ${greym}--install${yellowd} ${end}" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}${end}                  " "${fuchsiad}$app_file_this${end} ${greym}--extract${yellowd} ${greym}--install${yellowd} ${greym}--dryrun${yellowd} ${end}" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}${end}                  " "${fuchsiad}$app_file_this${end} ${greym}--install${yellowd} ${greym}--dryrun${yellowd} ${end}" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}${end}                  " "${fuchsiad}$app_file_this${end} ${greym}--installOnly${yellowd} ${end}" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}${end}                  " "${fuchsiad}$app_file_this${end} ${greym}--installOnly${yellowd} ${greym}--dryrun${yellowd} ${end}" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}${end}                  " "${fuchsiad}$app_file_this${end} ${greyd}[ ${greym}--help${greyd} | ${greym}-h${greyd} | ${greym}/?${greyd} ]${end}" 1>&2
    echo
    printf '  %-5s %-40s\n' "${greyd}Options:${end}" "" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}-e${greyd},${blued}  --extract ${yellowd}${end}                    " "download, extract latest version of csf ${navy}<default> ${peach}$argExtract ${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}-i${greyd},${blued}  --install ${yellowd}${end}                    " "download, extract, and install latest version of csf ${end} ${navy}<default> ${peach}$argInstall ${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}-I${greyd},${blued}  --installOnly ${yellowd}${end}                " "no download, no extract, only install existing archive, requires existing source archive ${navy}<default> ${peach}$argInstallOnly ${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}-c${greyd},${blued}  --clean ${yellowd}${end}                      " "cleans up lingering archive and tmp folders and exits ${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}-D${greyd},${blued}  --dryrun ${yellowd}${end}                     " "pass dryrun to csf installer script, does not install csf ${end} ${navy}<default> ${peach}$argDryrun ${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}-V${greyd},${blued}  --version ${yellowd}${end}                    " "current version of this utilty${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}-d${greyd},${blued}  --dev ${yellowd}${end}                        " "developer mode; verbose logging${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}-h${greyd},${blued}  --help ${yellowd}${end}                       " "show this help menu${end}" 1>&2
    echo
    echo
}

# #
#   args › handle
# #

while [ "$#" -gt 0 ]; do
    case "$1" in
        -d|--dev)
            argDev="true"
            ;;
        -e|--extract)
            argExtract="true"
            argStatus="extracted"
            ;;
        -i|--install)
            argExtract="true"
            argInstall="true"
            argStatus="installed"
            ;;
        -I|--installOnly)
            argInstallOnly="true"
            argStatus="installed local"
            ;;
        -c|--clean)
            printf '%-31s %-65s\n' "  ${bluel} STATUS ${end}" \
                "${greym} cleaning existing files and folders ${end}"

            rm -rf "./$folder_extract" "./$file_release"*.zip

            # #
            #   Verify cleanup / deletion
            # #

            if [ ! -d "./$folder_extract" ] && [ ! -e "./$file_release"*.zip ]; then
                printf '%-31s %-65s\n' "  ${greenl} SUCCESS ${end}" \
                    "${greym} all files and folders removed ${end}"
            else
                printf '%-31s %-65s\n' "  ${redd} ERROR ${end}" \
                    "${greym} some files or folders could not be removed ${end}"
            fi

            exit 0
            ;;
        -D|--dryrun)
            if [ -n "$argInstaller" ]; then
                argInstaller="$argInstaller --dryrun"
            else
                argInstaller="--dryrun"
            fi
            ;;
        -v|--version|/v)
            echo
            printf "  ${bluel}${app_title} (v$app_ver) ${end}\n" 1>&2
            printf "  ${end}${app_about} ${end}\n" 1>&2
            printf "  ${greyd}${github_url} ${end}\n" 1>&2
            echo
            exit 1
            ;;
        -h|--help|/?)
            opt_usage
            return
            ;;
        *)
            printf '%-28s %-65s\n' "  ${redl} ERROR ${end}" "${greym} Unknown parameter: ${redl}$1 ${greym}. Aborting${end}"
            exit 1
            ;;
    esac
    shift
done

# #
#   output › header
# #

echo
echo " ${greyd}――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――${end}"
printf '%-32s %-65s\n' "  ${greym} App${end}" "${fuchsial} $app_title › Downloader  ${end}"
printf '%-32s %-65s\n' "  ${greym} Repository${end}" "${fuchsial} ${app_repo}  ${end}"
printf '%-32s %-65s\n' "  ${greym} Api${end}" "${fuchsial} ${api_url}  ${end}"
printf '%-32s %-65s\n' "  ${greym} Version${end}" "${fuchsial} v${app_ver}  ${end}"
echo " ${greyd}――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――${end}"
echo

# #
#   api url › missing
# #

if [ -z "$api_url" ]; then
    printf '%-28s %-65s\n' "  ${redl} ERROR ${end}" "${greym} api_url empty, cannot retrieve from api.github.com. Aborting ${end}"
    exit 1
fi

# #
#   get json information from latest releases
# #

printf '%-31s %-65s\n' "  ${bluel} STATUS ${end}" "${greym} fetching latest release info from ${bluel}$api_url ${end}"
release_json=$(curl -sL "$api_url")

# #
#   extract latest tag
# #

tag_latest=$(echo "$release_json" | grep -m1 '"tag_name"' | awk -F'"' '{print $4}')
if [ -z "$tag_latest" ]; then
    printf '%-28s %-65s\n' "  ${redl} ERROR ${end}" "${greym} could not find latest release tag. Aborting ${end}"
    exit 1
else
    printf '%-31s %-65s\n' "  ${greenl} OK ${end}" "${greym} found latest release tag ${greenl}$tag_latest ${end}"
fi

# #
#   extract download URL for the main zip
# #

DOWNLOAD_URL=$(echo "$release_json" \
    | grep '"browser_download_url"' \
    | awk -F'"' '{print $4}' \
    | grep "$file_release$tag_latest\.zip" \
    | head -n1)

if [ -z "$DOWNLOAD_URL" ]; then
    printf '%-28s %-65s\n' "  ${redl} ERROR ${end}" "${greym} could not find download url for latest release tag. Aborting ${end}"
    exit 1
fi

# #
#   get latest release filename
# #

FILENAME=$(basename "$DOWNLOAD_URL")

# #
#   download latest release
#   should not be ran if we've provided -o, --installOnly
# #

if [ "$argInstallOnly" = "false" ]; then
    printf '%-31s %-65s\n' "  ${bluel} STATUS ${end}" "${greym} downloading file ${bluel}$FILENAME${greym} from ${bluel}$DOWNLOAD_URL${end}"
    echo 
    curl -L -o "$FILENAME" "$DOWNLOAD_URL"
    echo 
fi

# #
#   check if new release file downloaded / exists
# #

if [ -f "$FILENAME" ]; then
    printf '%-31s %-65s\n' "  ${greenl} OK ${end}" "${greym} file ${bluel}$FILENAME${greym} downloaded successfully.${end}"
else
    printf '%-28s %-65s\n' "  ${redl} ERROR ${end}" "${greym} archive file ${bluel}$FILENAME${greym} missing or not downloaded. Please check the URL or your connection. Aborting ${end}"
    exit 1
fi

# #
#   extract archive if -e, --extract arg specified
# #

if [ "$argExtract" = "true" ] || [ "$argInstall" = "true" ]; then
    printf '%-31s %-65s\n' "  ${bluel} STATUS ${end}" "${greym} extracting file ${bluel}$FILENAME ${end}"
    [ ! -d $folder_extract ] && mkdir $folder_extract

    case "$FILENAME" in
        *.zip)
            unzip -oq "$FILENAME" -d "$folder_extract"
            ;;
        *.tar.gz|*.tgz)
            tar -xzf "$FILENAME" -C "$folder_extract"
            ;;
        *)
            printf '%-28s %-65s\n' "  ${redl} ERROR ${end}" "${greym} unknown archive format for file ${redl}$FILENAME${greym}. Aborting${end}"
            exit 1
            ;;
    esac

    printf '%-31s %-65s\n' "  ${greenl} OK ${end}" "${greym} extracted to ${greenl}./$folder_extract/ ${end}"
fi

# #
#   install
# #

if [ "$argInstall" = "true" ] || [ "$argInstallOnly" = "true" ]; then
    path_installer="./$folder_extract/$file_installer"
    if [ ! -f "$path_installer" ]; then
        printf '%-28s %-65s\n' "  ${redl} ERROR ${end}" "${greym} install script not found at ${redl}$path_installer${greym}. Aborting${end}"
        exit 1
    fi

    printf '%-31s %-65s\n' "  ${bluel} STATUS ${end}" "${greym} running install script ${bluel}$path_installer ${greym} with elevated permissions${end}"

    #  sudo check
    if command -v sudo >/dev/null 2>&1; then
        sudo sh "$path_installer" $argInstaller
    else
        sh "$path_installer" $argInstaller
    fi

    printf '%-31s %-65s\n' "  ${greenl} OK ${end}" "${greym} installation script ${greenl}$path_installer${greym} finished with args ${greenl}$argInstaller ${end}"
fi

# #
#   output › footer
# #

printf '%-31s %-65s\n' "  ${greenl} OK ${end}" "${greym} successfully $argStatus $app_title ${end}"
