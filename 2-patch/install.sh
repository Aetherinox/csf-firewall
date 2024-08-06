#!/bin/bash

# #
#	/usr/local/include/csf/post.d/docker.sh
#	/usr/local/csf/bin/csfpre.sh
#	/usr/local/csf/bin/csfpost.sh
#	/etc/csf/csf.conf
# #

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
#   vars > system
# #

sys_arch=$(dpkg --print-architecture)
sys_code=$(lsb_release -cs)

# #
#   vars > generic
# #

app_title="CSF Firewall Configuration"
app_about="Configures ConfigServer Firewall to work with Docker and Traefik"
app_ver=("2" "0" "0" "0")
app_file_this=$(basename "$0")
app_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# #
#   STEP 1 > vars
# #

CSF_BIN_PATH="/usr/local/csf/bin"
CSFPRED_PATH="/usr/local/include/csf/pre.d"
CSFPOSTD_PATH="/usr/local/include/csf/post.d"

CSFPRESH_SCRIPT="${CSF_BIN_PATH}/csfpre.sh"
CSFPOSTSH_SCRIPT="${CSF_BIN_PATH}/csfpost.sh"

STEP1_SKIP="false"
STEP2_SKIP="false"

# #
#   Service Exists
# #

service_exists()
{
    local n=$1
    if [[ $(systemctl list-units --all -t service --full --no-legend "$n.service" | sed 's/^\s*//g' | cut -f1 -d' ') == $n.service ]]; then
        return 0
    else
        return 1
    fi
}

# #
#   Display Usage Help
#
#   activate using ./install.sh --help or -h
# #

opt_usage()
{
    echo -e 
    printf "  ${BLUE}${app_title}${NORMAL}\n" 1>&2
    printf "  ${GREYL}${app_about}${NORMAL}\n" 1>&2
    echo -e 
    printf '  %-5s %-40s\n' "Usage:" "" 1>&2
    printf '  %-5s %-40s\n' "    " "${0} [${GREYL}options${NORMAL}]" 1>&2
    printf '  %-5s %-40s\n\n' "    " "${0} [${GREYL}-h${NORMAL}] [${GREYL}-v${NORMAL}] [${GREYL}-d${NORMAL}]" 1>&2
    printf '  %-5s %-40s\n' "Options:" "" 1>&2
    printf '  %-5s %-18s %-40s\n' "    " "-d, --dev" "developer mode" 1>&2
    printf '  %-5s %-18s %-40s\n' "    " "" "displays advanced logs" 1>&2
    printf '  %-5s %-18s %-40s\n' "    " "-v, --version" "current version of csf script" 1>&2
    printf '  %-5s %-18s %-40s\n' "    " "-h, --help" "show help menu" 1>&2
    echo -e 
    echo -e 
    exit 1
}

# #
#   command-line options
#
#   reminder that any functions which need executed must be defined BEFORE
#   this point. Bash sucks like that.
#
#   --dev           show advanced printing
#   --help          show help and usage information
#   --version       display version information
# #

while [ $# -gt 0 ]; do
  case "$1" in
    -d|--dev)
            OPT_DEV_ENABLE=true
            echo -e "  ${FUCHSIA}${BLINK}Devmode Enabled${NORMAL}"
            ;;

    -h*|--help*)
            opt_usage
            ;;

    -v|--version)
            echo
            echo -e "  ${GREEN}${BOLD}${app_title}${NORMAL} - v$(get_version)${NORMAL}"
            echo -e "  ${GREYL}${BOLD}${app_repo_url}${NORMAL}"
            echo -e "  ${GREYL}${BOLD}${OS} | ${OS_VER}${NORMAL}"
            echo
            exit 1
            ;;
    *)
            opt_usage
            ;;
  esac
  shift
done

# #
#   Require Sudo
#
#	this script requires permissions to copy, etc.
# 	require the user to run as sudo
# #

if [ "$EUID" -ne 0 ]; then
	echo -e
    echo -e "  ${BOLD}${ORANGE}WARNING  ${WHITE}Must run script with sudo:${NORMAL}"
    echo -e "  ${BOLD}${WHITE}    ${DEVGREY}sudo ./${app_file_this}${NORMAL}"
	echo -e
  	exit 1
fi

# #
#   clear screen before starting step 1
# #

clear

# #
#   STEP 1 > Copy Script
#
#	call function with
#		copy_script "csfpre.sh" "/usr/local/csf/bin/csfpre.sh"
#		copy_script "csfpost.sh" "/usr/local/csf/bin/csfpost.sh"
# #

function copy_script
{
	# #
	#   STEP 1 > Header
	# #

	echo -e " ${BLUE}---------------------------------------------------------------------------------------------------${NORMAL}"
	echo -e " ${GREEN}${BOLD} Step 1 - Pre & Post Script${NORMAL}${MAGENTA}"
	echo
	echo -e "  This installer will now copy the CSF pre and post scripts to:"
	echo -e "  ${BOLD}${WHITE}    ${DEVGREY}${CSF_BIN_PATH}${NORMAL}"
	echo -e
	echo -e "  These scripts will be ran by CSF each time you start or restart the csf / lfd services."
	echo -e " ${BLUE}---------------------------------------------------------------------------------------------------${NORMAL}"

	sleep 1

	# #
	#   csf_script ............. csfpre.sh
	#   csf_dst_path ........... /usr/local/csf/bin/csfpre.sh
	# #

	local csf_script=$1
	local csf_dst_path=$2

	echo -e
	echo -e "  ${BOLD}${YELLOW}[ ${csf_script} ]  ${NORMAL}"
	echo -e

	echo -e "  ${BOLD}${DEVGREY}PATHS           ${WHITE}Checking paths for script ${FUCHSIA}${csf_script}${NORMAL}"
	printf '%-17s %-55s %-55s' " " "${DEVGREY}Path: Local" "${FUCHSIA}${app_dir}/${csf_script}${NORMAL}"
	echo -e
	printf '%-17s %-55s %-55s' " " "${DEVGREY}Path: Destination" "${FUCHSIA}${csf_dst_path}${NORMAL}"
	echo -e

	sleep 1

	echo -e
	echo -e " ${BLUE}---------------------------------------------------------------------------------------------------${NORMAL}"
	echo -e

	sleep 1

	# #
	#   STEP 1 > If csf_Dst_path exists
	# #

	if [ -f ${csf_dst_path} ]; then
		md5_0=`md5sum ${csf_script} | awk '{ print $1 }'`
		md5_1=`md5sum ${csf_dst_path} | awk '{ print $1 }'`

		echo -e "  ${BOLD}${DEVGREY}MD5             ${WHITE}Compare local ${DEVGREY}${csf_script}${WHITE} with ${FUCHSIA}${csf_dst_path}${NORMAL}"
		printf '%-17s %-55s %-55s' " " "${DEVGREY}${app_dir}/${csf_script}" "${FUCHSIA}${md5_0}${NORMAL}"
		echo -e
		printf '%-17s %-55s %-55s' " " "${DEVGREY}${csf_dst_path}" "${FUCHSIA}${md5_1}${NORMAL}"
		echo -e

		if [ ${md5_0} == ${md5_1} ]; then
			echo -e
			echo -e "  ${BOLD}${WHITE}                ✔️  ${WHITE}MD5 matches: ${ORANGE}Aborting update${NORMAL}"
		else
			echo -e
			echo -e "  ${BOLD}${WHITE}                ❌  ${WHITE}MD5 mismatch: ${GREEN}Copying new version of file${NORMAL}"
		fi

		sleep 1

		echo -e
		echo -e " ${BLUE}---------------------------------------------------------------------------------------------------${NORMAL}"
		echo -e

		sleep 1

		if [ ${md5_0} == ${md5_1} ]; then
			echo -e "  ${BOLD}${YELLOW}NOTICE          ${WHITE}Script ${GREEN}${csf_script}${WHITE} is already up to date${NORMAL}"
			printf '%-17s %-55s %-55s' " " "${DEVGREY}skipping step ....${NORMAL}"
			echo -e

			STEP1_SKIP="true"
		else
			ok=0
			while [ ${ok} -eq 0 ]; do
				echo -e "  ${BOLD}${ORANGE}WARNING         ${WHITE}A different version of the script ${GREEN}${csf_dst_path}${WHITE} is already present${NORMAL}"
				printf '%-17s %-55s %-55s' " " "${DEVGREY}Do you want to replace it (y/n)?${NORMAL}"
				echo -e

				read answer

				if [ ${answer} == "y" -o ${answer} == "n" ]; then
					ok=1
				fi
			done

			if [ ${answer} == "n" ]; then
				exit 1
			fi
		fi
	fi

	# #
	#   Determine if step 1 should be skipped
	# #

	if [ -z ${STEP1_SKIP} ] || [ ${STEP1_SKIP} == "false" ]; then

		# #
		#   Copy
		# #

		echo -e "  ${WHITE}                Copy            ${FUCHSIA}${app_dir}/${csf_script}${WHITE} > ${FUCHSIA}${csf_dst_path}${NORMAL}"
		cp -f ${csf_script} ${csf_dst_path}

		# #
		#   Chown
		# #

		echo -e "  ${WHITE}                Chown           ${FUCHSIA}root:root${WHITE} > ${FUCHSIA}${csf_dst_path}${NORMAL}"
		chown root:root ${csf_dst_path}

		# #
		#   Chmod
		# #

		echo -e "  ${WHITE}                Chmod           ${FUCHSIA}700${WHITE} > ${FUCHSIA}${csf_dst_path}${NORMAL}"
		chmod 700 ${csf_dst_path}

	fi

	sleep 5
	clear
}

# #
#   STEP 2 > Setup
# #

# Create directories needed for custom csf{pre,post}
if [ ! -d ${CSFPRED_PATH} ]; then
	if [ "${OPT_DEV_ENABLE}" = true ]; then
		echo -e "  ${WHITE}                Mkdir           ${FUCHSIA}${CSFPRED_PATH}${NORMAL}"
	fi
	mkdir -p ${CSFPRED_PATH}
fi

if [ ! -d ${CSFPOSTD_PATH} ]; then
	if [ "${OPT_DEV_ENABLE}" = true ]; then
		echo -e "  ${WHITE}                Mkdir           ${FUCHSIA}${CSFPOSTD_PATH}${NORMAL}"
	fi
	mkdir -p ${CSFPOSTD_PATH}
fi

# #
#   STEP 1 > Copy Scripts
# #

copy_script "csfpre.sh" ${CSFPRESH_SCRIPT}
copy_script "csfpost.sh" ${CSFPOSTSH_SCRIPT}

# #
#   STEP 1 > Clear Console
# #

clear

# #
#   STEP 2 > vars
# #

SCRIPT_NAME="docker.sh"
CSF_CUSTOM_PATH="/usr/local/include/csf"
CSFPOSTD_PATH="${CSF_CUSTOM_PATH}/post.d"

# #
#   STEP 2 > Header
# #

echo -e " ${BLUE}---------------------------------------------------------------------------------------------------${NORMAL}"
echo -e " ${GREEN}${BOLD} Step 2 - Install Docker Script${NORMAL}${MAGENTA}"
echo
echo -e "  This installer will now copy the docker.sh script to:"
echo -e "  ${BOLD}${WHITE}    ${DEVGREY}${CSFPOSTD_PATH}/${SCRIPT_NAME}${NORMAL}"
echo -e
echo -e "  Every time the services csf and lfd are started / restarted; firewall rules will be added so"
echo -e "  that your containers have access to the network and can be accessed."
echo -e " ${BLUE}---------------------------------------------------------------------------------------------------${NORMAL}"

sleep 1

# #
#	STEP 2:
#   	check if script has been ran before:
#		- csf-firewall\2-patch-docker\1-patch-pre\install.sh
# #

if [ ! -d ${CSF_CUSTOM_PATH} ]; then
	echo -e "** 1-patch-pre has not been ran **"
	echo -e
	echo -e "You must first run the script"
	echo -e "    csf-firewall\2-patch-docker\1-patch-pre\install.sh"
	echo -e
	echo -e "Download from https://github.com/Aetherinox/csf-firewall"

	exit 1
fi

PREFIX="None"
if [ "$1" == "-p" ] || [ "$1" == "--prefix" ]; then
	PREFIX=$2
	shift 2
fi

SCRIPT_NAME_FINAL="${SCRIPT_NAME}"
if [ ${PREFIX} != "None" ]; then
	SCRIPT_NAME_FINAL="${PREFIX}_${SCRIPT_NAME}"
fi

# #
#	STEP 2:
#   	check if file exists:
#		- /usr/local/include/csf/post.d/docker.sh
# #

if [ -f ${CSFPOSTD_PATH}/${SCRIPT_NAME_FINAL} ]; then
	md5_0=`md5sum docker.sh | awk '{ print $1 }'`
	md5_1=`md5sum ${CSFPOSTD_PATH}/${SCRIPT_NAME_FINAL} | awk '{ print $1 }'`

	echo -e
	echo -e "  ${BOLD}${DEVGREY}MD5             ${WHITE}Compare local ${DEVGREY}${app_dir}/docker.sh${WHITE} with ${FUCHSIA}${CSFPOSTD_PATH}/${SCRIPT_NAME_FINAL}${NORMAL}"
	printf '%-17s %-55s %-55s' " " "${DEVGREY}${app_dir}/docker.sh" "${FUCHSIA}${md5_0}${NORMAL}"
	echo -e
	printf '%-17s %-55s %-55s' " " "${DEVGREY}${CSFPOSTD_PATH}/${SCRIPT_NAME_FINAL}" "${FUCHSIA}${md5_1}${NORMAL}"
	echo -e

	if [ ${md5_0} == ${md5_1} ]; then
		echo -e
		echo -e "  ${BOLD}${WHITE}                ✔️  ${WHITE}MD5 matches: ${ORANGE}Aborting update${NORMAL}"
	else
		echo -e
		echo -e "  ${BOLD}${WHITE}                ❌  ${WHITE}MD5 mismatch: ${GREEN}Copying new version of file${NORMAL}"
	fi

	sleep 1

	echo -e
	echo -e " ${BLUE}---------------------------------------------------------------------------------------------------${NORMAL}"
	echo -e

	sleep 1

	if [ ${md5_0} == ${md5_1} ]; then
		echo -e "  ${BOLD}${YELLOW}NOTICE          ${WHITE}Script ${GREEN}${CSFPOSTD_PATH}/${SCRIPT_NAME_FINAL}${WHITE} is already up to date${NORMAL}"
		printf '%-17s %-55s %-55s' " " "${DEVGREY}skipping step ....${NORMAL}"
		echo -e

		STEP2_SKIP="true"

	else
		ok=0
		while [ ${ok} -eq 0 ]; do
			echo -e "  ${BOLD}${ORANGE}WARNING         ${WHITE}A different version of the script ${GREEN}${CSFPOSTD_PATH}/${SCRIPT_NAME_FINAL}${WHITE} is already present${NORMAL}"
			printf '%-17s %-55s %-55s' " " "${DEVGREY}Do you want to replace it (y/n)?${NORMAL}"
			echo -e

			read answer

			if [ ${answer} == "y" -o ${answer} == "n" ]; then
				ok=1
			fi
		done

		if [ ${answer} == "n" ]; then
			exit 1
		fi
	fi
fi

# #
#	STEP 2:
#   	Determine if step 2 should be skipped
# #

if [ -z ${STEP2_SKIP} ] || [ ${STEP2_SKIP} == "false" ]; then
	echo -e "  ${WHITE}                Copy            ${FUCHSIA}${SCRIPT_NAME}${WHITE} > ${FUCHSIA}${CSFPOSTD_PATH}/${SCRIPT_NAME_FINAL}${NORMAL}"
	cp -f ${SCRIPT_NAME} ${CSFPOSTD_PATH}/${SCRIPT_NAME_FINAL}

	echo -e "  ${WHITE}                Chown           ${FUCHSIA}root:root${WHITE} > ${FUCHSIA}${CSFPOSTD_PATH}/${SCRIPT_NAME_FINAL}${NORMAL}"
	chown root:root ${CSFPOSTD_PATH}/${SCRIPT_NAME_FINAL}

	echo -e "  ${WHITE}                Chmod           ${FUCHSIA}700${WHITE} > ${FUCHSIA}${CSFPOSTD_PATH}/${SCRIPT_NAME_FINAL}${NORMAL}"
	chmod 700 ${CSFPOSTD_PATH}/${SCRIPT_NAME_FINAL}
fi

# #
#	STEP 2:
#   	All steps skipped, no changes made
# #

if [ ${STEP1_SKIP} == "true" ] && [ ${STEP2_SKIP} == "true" ]; then
	echo -e
	echo -e "  ${BOLD}${GREEN}FINISH          ${WHITE}All of your configs were already up to date${NORMAL}"
	printf '%-17s %-55s %-55s' " " "${DEVGREY}No changes were made to CSF and docker${NORMAL}"
	echo -e
fi

# #
#	STEP 2:
#   	Services
#		After applying all the changes, restart the services csf and lfd
# #

echo -e
echo -e "  ${BOLD}${DEVGREY}SERVICES        ${WHITE}Checking for ${DEVGREY}lfd.service${WHITE} and ${DEVGREY}csf.service${WHITE}${NORMAL}"

if service_exists lfd; then
	printf '%-17s %-55s %-55s' " " "lfd.service" "${GREEN}Restarting${NORMAL}"
	echo -e
	systemctl restart lfd.service
else
	printf '%-17s %-55s %-55s' " " "lfd.service" "${ORANGE}Not Found${NORMAL}"
	echo -e
fi

if service_exists csf; then
	printf '%-17s %-55s %-55s' " " "csf.service" "${GREEN}Restarting${NORMAL}"
	echo -e
	systemctl restart csf.service
else
	printf '%-17s %-55s %-55s' " " "csf.service" "${ORANGE}Not Found${NORMAL}"
	echo -e
fi

echo -e
exit 0
