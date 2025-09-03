#!/bin/sh
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

if [ -e "/usr/local/cpanel/bin/unregister_appconfig" ]; then
    cd /
    /usr/local/cpanel/bin/unregister_appconfig cse
else
    if [ ! -e "/var/cpanel/apps/cse.conf" ]; then
        /bin/rm -fv /var/cpanel/apps/cse.conf
    fi
fi

/bin/rm -fv /usr/local/cpanel/whostmgr/docroot/cgi/addon_cse.cgi
/bin/rm -fv /usr/local/cpanel/whostmgr/docroot/cgi/cseversion.txt
/bin/rm -Rfv /usr/local/cpanel/whostmgr/docroot/cgi/cse

/bin/rm -fv /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cse.cgi
/bin/rm -fv /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cseversion.txt
/bin/rm -Rfv /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cse

echo "ConfigServer Explorer has been uninstalled."
exit
