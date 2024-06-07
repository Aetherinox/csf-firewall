#!/bin/bash

SCRIPT_NAME="docker.sh"

CSF_CUSTOM_PATH="/usr/local/include/csf"
CSFPOSTD_PATH="${CSF_CUSTOM_PATH}/post.d"


if [ ! -d ${CSF_CUSTOM_PATH} ]; then
	echo "** CSF-PRE_POST_SH is not installed **"
	echo "Get it from https://github.com/juliengk/csf-pre_post_sh"

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

if [ -f ${CSFPOSTD_PATH}/${SCRIPT_NAME_FINAL} ]; then
	md5_0=`md5sum docker.sh | awk '{ print $1 }'`
	md5_1=`md5sum ${CSFPOSTD_PATH}/${SCRIPT_NAME_FINAL} | awk '{ print $1 }'`

	if [ ${md5_0} == ${md5_1} ]; then
		exit 0
	else
		ok=0
		while [ ${ok} -eq 0 ]; do
			clear

			echo "** Warning! **"
			echo "A different version of the script is already present"
			echo "Do you want to replace it (y/n)?"

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

cp -f ${SCRIPT_NAME} ${CSFPOSTD_PATH}/${SCRIPT_NAME_FINAL}
chown root:root ${CSFPOSTD_PATH}/${SCRIPT_NAME_FINAL}
chmod 700 ${CSFPOSTD_PATH}/${SCRIPT_NAME_FINAL}

exit 0
