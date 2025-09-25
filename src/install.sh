#!/bin/sh
# #
#   Copyright (C) 2025 Aetherinox
#   Copyright (C) 2006-2025 Jonathan Michaelson
#   
#   https://github.com/Aetherinox/csf-firewall
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
# #

# #
#   args
# #

argDryrun="false"

# #
#   Parse arguments
# #

while [ "$#" -gt 0 ]; do
    case "$1" in
        -d|--dryrun)
            argDryrun="true"
            ;;
        *)
            echo "Unknown parameter: $1" 1>&2
            exit 1
            ;;
    esac
    shift
done

# #
#   start installer
# #

echo
echo "Selecting installer..."
echo

run_installer()
{
    installer="$1"
    description="$2"

    echo "Detected: $description"
    if [ "$argDryrun" = "true" ]; then
        echo "[DRY RUN] Would execute: sh $installer"
    else
        echo
        sh "$installer"
    fi
}

# #
#   determine which installation script to run
# #

if [ -e "/usr/local/cpanel/version" ]; then
    run_installer "install.cpanel.sh" "csf cPanel installer"
elif [ -e "/usr/local/directadmin/directadmin" ]; then
    run_installer "install.directadmin.sh" "csf DirectAdmin installer"
elif [ -e "/usr/local/interworx" ]; then
    run_installer "install.interworx.sh" "csf InterWorx installer"
elif [ -e "/usr/local/cwpsrv" ]; then
    run_installer "install.cwp.sh" "csf CentOS Web Panel installer"
elif [ -e "/usr/local/vesta" ]; then
    run_installer "install.vesta.sh" "csf VestaCP installer"
elif [ -e "/usr/local/CyberCP" ]; then
    run_installer "install.cyberpanel.sh" "csf CyberPanel installer"
else
    run_installer "install.generic.sh" "csf generic installer"
fi
