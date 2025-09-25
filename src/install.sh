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
#   @script     ConfigServer Firewall Installer
#   @desc       determines the users distro and (if any) control panel, launches correct installer sub-script
#   @author     Aetherinox
#   @repo       https://github.com/Aetherinox/csf-firewall
#   
#   @usage      Normal install          sh install.sh
#               Dryrun install          sh install.sh --dryrun
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
            printf '%-28s %-65s\n' "  ${redl} ERROR ${end}" "${greym} Unknown parameter: ${redl}$1 ${greym}. Aborting${end}"
            exit 1
            ;;
    esac
    shift
done

# #
#   start installer
# #

printf '%-31s %-65s\n' "  ${bluel} STATUS ${end}" "${greym} determining which installer to run ${end}"

run_installer()
{
    installer="$1"
    description="$2"

    # #
    #   Resolve directory of the current install.sh script
    # #

    script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

    printf '%-31s %-65s\n' "  ${greenl} OK ${end}" "${greym} starting installer ${greenl}$description ${end}"
    if [ "$argDryrun" = "true" ]; then
        printf '%-31s %-65s\n' "  ${greenl} OK ${end}" "${greym} dry-run detected; skipped installer ${greenl}$script_dir/$installer ${end}"
    else
        echo
        sh "$script_dir/$installer"
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
