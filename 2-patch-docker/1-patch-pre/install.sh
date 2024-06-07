#!/bin/bash

CSF_BIN_PATH="/usr/local/csf/bin"
CSFPRESH_SCRIPT="${CSF_BIN_PATH}/csfpre.sh"
CSFPOSTSH_SCRIPT="${CSF_BIN_PATH}/csfpost.sh"

CSFPRED_PATH="/usr/local/include/csf/pre.d"
CSFPOSTD_PATH="/usr/local/include/csf/post.d"

function copy_script {
	local csf_script=$1
	local csf_dst_path=$2

	if [ -f ${csf_dst_path} ]; then
		md5_0=`md5sum ${csf_script} | awk '{ print $1 }'`
		md5_1=`md5sum ${csf_dst_path} | awk '{ print $1 }'`

		if [ ${md5_0} == ${md5_1} ]; then
			echo "The script ${csf_script} already exists and is up to date"
			exit 0
		else
			ok=0
			while [ ${ok} -eq 0 ]; do
				clear

				echo "** Warning! **"
				echo "A different version of the script ${csf_script} is already present"
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

	cp -f ${csf_script} ${csf_dst_path}
	chown root:root ${csf_dst_path}
	chmod 700 ${csf_dst_path}
}

# Create directories needed for custom csf{pre,post}
if [ ! -d ${CSFPRED_PATH} ]; then
	mkdir -p ${CSFPRED_PATH}
fi

if [ ! -d ${CSFPOSTD_PATH} ]; then
	mkdir -p ${CSFPOSTD_PATH}
fi

# Copy scripts
copy_script "csfpre.sh" ${CSFPRESH_SCRIPT}
copy_script "csfpost.sh" ${CSFPOSTSH_SCRIPT}

exit 0
