#!/bin/sh
###############################################################################
# Copyright (C) 2006-2025 Jonathan Michaelson
#
# https://github.com/waytotheweb/scripts
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, see <https://www.gnu.org/licenses>.
###############################################################################
PATH=$PATH:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

if [ -e "/usr/local/cpanel/version" ]; then

    echo "Running cmq cPanel uninstaller"
	echo

    if [ -e "/usr/local/cpanel/bin/unregister_appconfig" ]; then
        cd /
        /usr/local/cpanel/bin/unregister_appconfig cmq
    else
        if [ ! -e "/var/cpanel/apps/cmq.conf" ]; then
            /bin/rm -fv /var/cpanel/apps/cmq.conf
        fi
    fi

    /bin/rm -fv /usr/local/cpanel/whostmgr/docroot/cgi/addon_cmq.cgi
    /bin/rm -fv /usr/local/cpanel/whostmgr/docroot/cgi/cmqversion.txt
    /bin/rm -Rfv /usr/local/cpanel/whostmgr/docroot/cgi/cmq

    /bin/rm -fv /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmq.cgi
    /bin/rm -fv /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmqversion.txt
    /bin/rm -Rfv /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmq

elif [ -e "/usr/local/directadmin/directadmin" ]; then

    echo "Running cmq DirectAdmin uninstaller"
	echo

    /bin/rm -Rfv /usr/local/directadmin/plugins/cmq

fi

/bin/rm -Rfv /etc/cmq

echo "ConfigServer Mail Queues has been uninstalled."
exit
