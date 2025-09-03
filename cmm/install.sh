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

if [ ! -e "install.sh" ]; then
	echo "You must cd to the package directory that you expanded"
	exit
fi

#First replace:
if [ -e "/usr/local/cpanel/3rdparty/bin/perl" ]; then
    find ./ -type f -exec sed -i 's%^#\!/usr/bin/perl%#\!/usr/local/cpanel/3rdparty/bin/perl%' {} \;
fi

mkdir /usr/local/cpanel/whostmgr/docroot/cgi/configserver
chmod 700 /usr/local/cpanel/whostmgr/docroot/cgi/configserver
mkdir /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmm
chmod 700 /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmm

cp -avf cmm.cgi /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmm.cgi
chmod -v 700 /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmm.cgi

cp -avf cmmversion.txt /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmm/cmmversion.txt
cp -avf cmm/ /usr/local/cpanel/whostmgr/docroot/cgi/configserver/
cp -avf downloadservers /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmm/downloadservers

VERSION=`cat /usr/local/cpanel/version | cut -d '.' -f2`
if [ "$VERSION" -lt "65" ]; then
    sed -i "s/^target=.*$/target=mainFrame/" cmm.conf
    echo "cPanel v$VERSION, target set to mainFrame"
else
    sed -i "s/^target=.*$/target=_self/" cmm.conf
    echo "cPanel v$VERSION, target set to _self"
fi

cp -avf cmm.conf /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmm/cmm.conf
cp -avf upgrade.sh /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmm/upgrade.sh
chmod 700 /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmm/upgrade.sh
cp -af cmm/cmm.png /usr/local/cpanel/whostmgr/docroot/addon_plugins/
cp -af cmm.tmpl /usr/local/cpanel/whostmgr/docroot/templates/

if [ -e "/usr/local/cpanel/bin/register_appconfig" ]; then
    /usr/local/cpanel/bin/register_appconfig /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmm/cmm.conf

    /bin/rm -f /usr/local/cpanel/whostmgr/docroot/cgi/addon_cmm.cgi
    /bin/rm -f /usr/local/cpanel/whostmgr/docroot/cgi/cmmversion.txt
    /bin/rm -Rf /usr/local/cpanel/whostmgr/docroot/cgi/cmm
else
    cp -avf cmm.cgi /usr/local/cpanel/whostmgr/docroot/cgi/addon_cmm.cgi
    chmod -v 700 /usr/local/cpanel/whostmgr/docroot/cgi/addon_cmm.cgi
    cp -avf cmmversion.txt /usr/local/cpanel/whostmgr/docroot/cgi/cmmversion.txt
    cp -avf cmm/ /usr/local/cpanel/whostmgr/docroot/cgi/
    if [ ! -d "/var/cpanel/apps" ]; then
        mkdir /var/cpanel/apps
        chmod 755 /var/cpanel/apps
    fi
    /bin/cp -avf cmm.conf.old /var/cpanel/apps/cmm.conf
    chmod 600 /var/cpanel/apps/cmm.conf
fi

#Second replace
if [ -e "/usr/local/cpanel/3rdparty/bin/perl" ]; then
	find ./ -type f -exec sed -i 's%^#\!/usr/local/cpanel/3rdparty/bin/perl%#\!/usr/bin/perl%' {} \;
fi

echo "ConfigServer Mail Manage has been installed."
exit
