#!/bin/bash

# #
#
#	this script copies the following files to the below paths:
#		/usr/local/include/csf/post.d/openvpn.sh
#		/usr/local/include/csf/post.d/docker.sh
#		/usr/local/csf/bin/csfpre.sh
#		/usr/local/csf/bin/csfpost.sh
#
#	you can find the ConfigServer Firewall config at:
#		/etc/csf/csf.conf
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
#   vars > internal
# #

STEP1_SKIP="false"
STEP2_SKIP="false"

# #
#   vars > system
# #

sys_arch=$(dpkg --print-architecture)
sys_code=$(lsb_release -cs)

# #
#   vars > generic
# #

app_title="ConfigServer Firewall Configuration"
app_about="Configures ConfigServer Firewall to work with Docker and Traefik"
app_ver=("2" "0" "0" "0")
app_file_this=$(basename "$0")
app_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# #
#   vars > app repo
# #

app_repo_name="csf-firewall"
app_repo_author="Aetherinox"
app_repo_branch="main"
app_repo_url="https://github.com/${app_repo_author}/${app_repo_name}"

# #
#   STEP 1 > vars
# #

PATH_INCLUDE="/usr/local/include"
PATH_INCLUDE_CSF="${PATH_INCLUDE}/csf"

PATH_CSF_PRE="${PATH_INCLUDE}/csf/pre.d"
PATH_CSF_POST="${PATH_INCLUDE}/csf/post.d"
PATH_CSF_BIN="/usr/local/csf/bin"

FILE_CSF_PRE="${PATH_CSF_BIN}/csfpre.sh"
FILE_CSF_POST="${PATH_CSF_BIN}/csfpost.sh"

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
#   distro
#
#   returns distro information.
# #

    # #
    #   freedesktop.org and systemd
    # #

        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$NAME
            OS_VER=$VERSION_ID

    # #
    #   linuxbase.org
    # #

        elif type lsb_release >/dev/null 2>&1; then
            OS=$(lsb_release -si)
            OS_VER=$(lsb_release -sr)

    # #
    #   versions of Debian/Ubuntu without lsb_release cmd
    # #

        elif [ -f /etc/lsb-release ]; then
            . /etc/lsb-release
            OS=$DISTRIB_ID
            OS_VER=$DISTRIB_RELEASE

    # #
    #   older Debian/Ubuntu/etc distros
    # #

        elif [ -f /etc/debian_version ]; then
            OS=Debian
            OS_VER=$(cat /etc/debian_version)

    # #
    #   fallback: uname, e.g. "Linux <version>", also works for BSD
    # #

        else
            OS=$(uname -s)
            OS_VER=$(uname -r)
        fi

# #
#   func > get version
#
#   returns current version of app
#   converts to human string.
#       e.g.    "1" "2" "4" "0"
#               1.2.4.0
# #

get_version()
{
    ver_join=${app_ver[@]}
    ver_str=${ver_join// /.}
    echo ${ver_str}
}

# #
#   func > version > compare greater than
#
#   this function compares two versions and determines if an update may
#   be available. or the user is running a lesser version of a program.
# #

get_version_compare_gt()
{
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1";
}

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
#   iptables > find
# #

if ! [ -x "$(command -v iptables)" ]; then
    echo -e "  ${GREYL}Installing package ${MAGENTA}iptables${WHITE}"
    sudo apt-get update -y -q >/dev/null 2>&1
    sudo apt-get install iptables -y -qq >/dev/null 2>&1
fi

# #
#   iptables > assign path to var
# #

PATH_IPTABLES=$(which iptables)
PATH_IP6TABLES=$(which ip6tables)

# #
#   iptables > doesnt exist
# #

if [ -z "${PATH_IPTABLES}" ]; then
    echo -e "  ${BOLD}${ORANGE}WARNING         ${WHITE}Could not locate the package ${YELLOW}iptables${NORMAL}"
    printf '%-17s %-55s %-55s' " " "${DEVGREY}Must install iptables before continuing${NORMAL}"
    echo -e

    exit 0
fi

# #
#   Install > Ipset
# #

if ! [ -x "$(command -v ipset)" ]; then
	echo -e "  ${WHITE}Installing package ${MAGENTA}ipset${WHITE}"

	sudo apt-get update -y -q >/dev/null 2>&1
	sudo apt-get install ipset -y -qq >/dev/null 2>&1
fi

# #
#   Install > ConfigServer Firewall
# #

if ! [ -x "$(command -v csf)" ]; then
	echo -e "  ${WHITE}Installing package ${MAGENTA}ConfigServer Firewall${WHITE}"

	# #
	#   csf > install prerequisites
	# #

	sudo apt-get update -y -q >/dev/null 2>&1
	sudo apt-get install perl ipset -y -qq >/dev/null 2>&1

	# #
	#   csf > download, extract, install
	# #

	wget https://download.configserver.com/csf.tgz >> /dev/null 2>&1
	tar -xzf csf.tgz >> /dev/null 2>&1
	cd ${app_dir}/csf
	sudo sh install.sh >> /dev/null 2>&1

	# #
	#   csf > cleanup
	# #

	cd ${app_dir}
	sudo rm csf.tgz >> /dev/null 2>&1
	sudo rm -rf csf/ >> /dev/null 2>&1

	echo -e
	echo -e "  ${WHITE}Docker patch will now start ...${NORMAL}"
	echo -e

	# #
	#   iptables > assign path to var
	# #

	PATH_IPTABLES=$(which iptables)
	PATH_IP6TABLES=$(which ip6tables)

	sleep 5
fi

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

    -f|--flush)
            echo -e "  ${FUCHSIA}${BLINK}Flushing Iptables${NORMAL}"
			${PATH_IPTABLES} -P INPUT ACCEPT
			${PATH_IPTABLES} -P FORWARD ACCEPT
			${PATH_IPTABLES} -P OUTPUT ACCEPT
			${PATH_IPTABLES} -t nat -F
			${PATH_IPTABLES} -t mangle -F
			${PATH_IPTABLES} -F
			${PATH_IPTABLES} -X

			${PATH_IP6TABLES} -P INPUT ACCEPT
			${PATH_IP6TABLES} -P FORWARD ACCEPT
			${PATH_IP6TABLES} -P OUTPUT ACCEPT
			${PATH_IP6TABLES} -t nat -F
			${PATH_IP6TABLES} -t mangle -F
			${PATH_IP6TABLES} -F
			${PATH_IP6TABLES} -X
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
	echo -e "  ${DEVGREY}${BOLD}${app_title} - v$(get_version)${NORMAL}${MAGENTA}"
	echo -e
	echo -e "  ${GREEN}${BOLD}Step 1 - Pre & Post Script${NORMAL}"
	echo -e
	echo -e "  ${MAGENTA}This installer will now copy the CSF pre and post scripts to:"
	echo -e "  ${BOLD}${WHITE}    ${DEVGREY}${PATH_CSF_BIN}${NORMAL}"
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
if [ ! -d ${PATH_CSF_PRE} ]; then
	if [ "${OPT_DEV_ENABLE}" = true ]; then
		echo -e "  ${WHITE}                Mkdir           ${FUCHSIA}${PATH_CSF_PRE}${NORMAL}"
	fi
	mkdir -p ${PATH_CSF_PRE}
fi

if [ ! -d ${PATH_CSF_POST} ]; then
	if [ "${OPT_DEV_ENABLE}" = true ]; then
		echo -e "  ${WHITE}                Mkdir           ${FUCHSIA}${PATH_CSF_POST}${NORMAL}"
	fi
	mkdir -p ${PATH_CSF_POST}
fi

# #
#   STEP 1 > Copy Scripts
# #

copy_script "csfpre.sh" ${FILE_CSF_PRE}
copy_script "csfpost.sh" ${FILE_CSF_POST}

# #
#   STEP 1 > Clear Console
# #

clear

# #
#   STEP 2 > SCRIPT > DOCKER
# #

SCRIPT_DOCKER="docker.sh"

# #
#   STEP 2 > Header
# #

echo -e " ${BLUE}---------------------------------------------------------------------------------------------------${NORMAL}"
echo -e "  ${DEVGREY}${BOLD}${app_title} - v$(get_version)${NORMAL}${MAGENTA}"
echo -e
echo -e "  ${GREEN}${BOLD}Step 2 - Install Docker Script${NORMAL}"
echo -e
echo -e "  ${MAGENTA}This installer will now copy the docker.sh script to:"
echo -e "  ${BOLD}${WHITE}    ${DEVGREY}${PATH_CSF_POST}${NORMAL}"
echo -e
echo -e "  Every time the services csf and lfd are started / restarted; firewall rules will be added so"
echo -e "  that your containers have access to the network and can be accessed."
echo -e " ${BLUE}---------------------------------------------------------------------------------------------------${NORMAL}"

sleep 1

# #
#	STEP 2:
#   	check if script has been ran before:
#		- csf-firewall\patch\install.sh
# #

if [ ! -d ${PATH_INCLUDE_CSF} ]; then
	echo -e "** 1-patch-pre has not been ran **"
	echo -e
	echo -e "You must first run the script"
	echo -e "    csf-firewall\patch\install.sh"
	echo -e
	echo -e "Download from https://github.com/Aetherinox/csf-firewall"

	exit 1
fi

PREFIX="None"
if [ "$1" == "-p" ] || [ "$1" == "--prefix" ]; then
	PREFIX=$2
	shift 2
fi

SCRIPT_DOCKER_FILE="${SCRIPT_DOCKER}"
if [ ${PREFIX} != "None" ]; then
	SCRIPT_DOCKER_FILE="${PREFIX}_${SCRIPT_DOCKER}"
fi

# #
#	STEP 2:
#   	check if file exists:
#		- /usr/local/include/csf/post.d/docker.sh
# #

if [ -f ${PATH_CSF_POST}/${SCRIPT_DOCKER_FILE} ]; then
	md5_0=`md5sum docker.sh | awk '{ print $1 }'`
	md5_1=`md5sum ${PATH_CSF_POST}/${SCRIPT_DOCKER_FILE} | awk '{ print $1 }'`

	echo -e
	echo -e "  ${BOLD}${DEVGREY}MD5             ${WHITE}Compare local ${DEVGREY}${app_dir}/docker.sh${WHITE} with ${FUCHSIA}${PATH_CSF_POST}/${SCRIPT_DOCKER_FILE}${NORMAL}"
	printf '%-17s %-55s %-55s' " " "${DEVGREY}${app_dir}/docker.sh" "${FUCHSIA}${md5_0}${NORMAL}"
	echo -e
	printf '%-17s %-55s %-55s' " " "${DEVGREY}${PATH_CSF_POST}/${SCRIPT_DOCKER_FILE}" "${FUCHSIA}${md5_1}${NORMAL}"
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
		echo -e "  ${BOLD}${YELLOW}NOTICE          ${WHITE}Script ${GREEN}${PATH_CSF_POST}/${SCRIPT_DOCKER_FILE}${WHITE} is already up to date${NORMAL}"
		printf '%-17s %-55s %-55s' " " "${DEVGREY}skipping step ....${NORMAL}"
		echo -e

		STEP2_SKIP="true"
	else
		ok=0
		while [ ${ok} -eq 0 ]; do
			echo -e "  ${BOLD}${ORANGE}WARNING         ${WHITE}A different version of the script ${GREEN}${PATH_CSF_POST}/${SCRIPT_DOCKER_FILE}${WHITE} is already present${NORMAL}"
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
	echo -e "  ${WHITE}                Copy            ${FUCHSIA}${SCRIPT_DOCKER}${WHITE} > ${FUCHSIA}${PATH_CSF_POST}/${SCRIPT_DOCKER_FILE}${NORMAL}"
	cp -f ${SCRIPT_DOCKER} ${PATH_CSF_POST}/${SCRIPT_DOCKER_FILE}

	echo -e "  ${WHITE}                Chown           ${FUCHSIA}root:root${WHITE} > ${FUCHSIA}${PATH_CSF_POST}/${SCRIPT_DOCKER_FILE}${NORMAL}"
	chown root:root ${PATH_CSF_POST}/${SCRIPT_DOCKER_FILE}

	echo -e "  ${WHITE}                Chmod           ${FUCHSIA}700${WHITE} > ${FUCHSIA}${PATH_CSF_POST}/${SCRIPT_DOCKER_FILE}${NORMAL}"
	chmod 700 ${PATH_CSF_POST}/${SCRIPT_DOCKER_FILE}
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

# #
#   STEP 2 > CLEAR CONSOLE
# #

clear

# #
#   STEP 3 > SCRIPT > OPENVPN
# #

SCRIPT_OPENVPN="openvpn.sh"

# #
#   STEP 3 > Header
# #

echo -e " ${BLUE}---------------------------------------------------------------------------------------------------${NORMAL}"
echo -e "  ${DEVGREY}${BOLD}${app_title} - v$(get_version)${NORMAL}${MAGENTA}"
echo -e
echo -e "  ${GREEN}${BOLD}Step 3 - Install OpenVPN Script${NORMAL}"
echo -e
echo -e "  ${MAGENTA}This installer will now copy the openvpn.sh script to:"
echo -e "  ${BOLD}${WHITE}    ${DEVGREY}${PATH_CSF_POST}${NORMAL}"
echo -e
echo -e "  Every time the services csf and lfd are started / restarted; firewall rules will be added so"
echo -e "  that OpenVPN can communicate through CSF"
echo -e " ${BLUE}---------------------------------------------------------------------------------------------------${NORMAL}"

sleep 1

# #
#	STEP 3:
#   	check if script has been ran before:
#		- csf-firewall\patch\install.sh
# #

if [ ! -d ${PATH_INCLUDE_CSF} ]; then
	echo -e "** 1-patch-pre has not been ran **"
	echo -e
	echo -e "You must first run the script"
	echo -e "    csf-firewall\patch\install.sh"
	echo -e
	echo -e "Download from https://github.com/Aetherinox/csf-firewall"

	exit 1
fi

PREFIX="None"
if [ "$1" == "-p" ] || [ "$1" == "--prefix" ]; then
	PREFIX=$2
	shift 2
fi

SCRIPT_OPENVPN_FILE="${SCRIPT_OPENVPN}"
if [ ${PREFIX} != "None" ]; then
	SCRIPT_OPENVPN_FILE="${PREFIX}_${SCRIPT_OPENVPN}"
fi

# #
#	STEP 3:
#   	check if file exists:
#		- /usr/local/include/csf/post.d/openvpn.sh
# #

if [ -f ${PATH_CSF_POST}/${SCRIPT_OPENVPN_FILE} ]; then
	md5_0=`md5sum openvpn.sh | awk '{ print $1 }'`
	md5_1=`md5sum ${PATH_CSF_POST}/${SCRIPT_OPENVPN_FILE} | awk '{ print $1 }'`

	echo -e
	echo -e "  ${BOLD}${DEVGREY}MD5             ${WHITE}Compare local ${DEVGREY}${app_dir}/openvpn.sh${WHITE} with ${FUCHSIA}${PATH_CSF_POST}/${SCRIPT_OPENVPN_FILE}${NORMAL}"
	printf '%-17s %-55s %-55s' " " "${DEVGREY}${app_dir}/openvpn.sh" "${FUCHSIA}${md5_0}${NORMAL}"
	echo -e
	printf '%-17s %-55s %-55s' " " "${DEVGREY}${PATH_CSF_POST}/${SCRIPT_OPENVPN_FILE}" "${FUCHSIA}${md5_1}${NORMAL}"
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
		echo -e "  ${BOLD}${YELLOW}NOTICE          ${WHITE}Script ${GREEN}${PATH_CSF_POST}/${SCRIPT_OPENVPN_FILE}${WHITE} is already up to date${NORMAL}"
		printf '%-17s %-55s %-55s' " " "${DEVGREY}skipping step ....${NORMAL}"
		echo -e

		STEP2_SKIP="true"
	else
		ok=0
		while [ ${ok} -eq 0 ]; do
			echo -e "  ${BOLD}${ORANGE}WARNING         ${WHITE}A different version of the script ${GREEN}${PATH_CSF_POST}/${SCRIPT_OPENVPN_FILE}${WHITE} is already present${NORMAL}"
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
#	STEP 3:
#   	Determine if step 3 should be skipped
# #

if [ -z ${STEP2_SKIP} ] || [ ${STEP2_SKIP} == "false" ]; then
	echo -e "  ${WHITE}                Copy            ${FUCHSIA}${SCRIPT_OPENVPN}${WHITE} > ${FUCHSIA}${PATH_CSF_POST}/${SCRIPT_OPENVPN_FILE}${NORMAL}"
	cp -f ${SCRIPT_OPENVPN} ${PATH_CSF_POST}/${SCRIPT_OPENVPN_FILE}

	echo -e "  ${WHITE}                Chown           ${FUCHSIA}root:root${WHITE} > ${FUCHSIA}${PATH_CSF_POST}/${SCRIPT_OPENVPN_FILE}${NORMAL}"
	chown root:root ${PATH_CSF_POST}/${SCRIPT_OPENVPN_FILE}

	echo -e "  ${WHITE}                Chmod           ${FUCHSIA}700${WHITE} > ${FUCHSIA}${PATH_CSF_POST}/${SCRIPT_OPENVPN_FILE}${NORMAL}"
	chmod 700 ${PATH_CSF_POST}/${SCRIPT_OPENVPN_FILE}
fi

# #
#	STEP 3:
#   	All steps skipped, no changes made
# #

if [ ${STEP1_SKIP} == "true" ] && [ ${STEP2_SKIP} == "true" ]; then
	echo -e
	echo -e "  ${BOLD}${GREEN}FINISH          ${WHITE}All of your configs were already up to date${NORMAL}"
	printf '%-17s %-55s %-55s' " " "${DEVGREY}No changes were made to CSF and OpenVPN${NORMAL}"
	echo -e
fi

# #
#	STEP 3:
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