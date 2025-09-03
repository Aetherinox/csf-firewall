#!/bin/bash
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

if [ ! -e "install.sh" ]; then
	echo "You must cd to the package directory that you expanded"
	exit
fi

mkdir /usr/local/cpanel/whostmgr/docroot/cgi/configserver
chmod 700 /usr/local/cpanel/whostmgr/docroot/cgi/configserver
mkdir /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmc
chmod 700 /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmc

cp -avf cmc.cgi /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmc.cgi
chmod -v 700 /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmc.cgi

cp -avf cmcversion.txt /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmc/cmcversion.txt
cp -avf cmc/ /usr/local/cpanel/whostmgr/docroot/cgi/configserver/
cp -avf downloadservers /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmc/downloadservers

VERSION=`cat /usr/local/cpanel/version | cut -d '.' -f2`
if [ "$VERSION" -lt "65" ]; then
    sed -i "s/^target=.*$/target=mainFrame/" cmc.conf
    echo "cPanel v$VERSION, target set to mainFrame"
else
    sed -i "s/^target=.*$/target=_self/" cmc.conf
    echo "cPanel v$VERSION, target set to _self"
fi

cp -avf cmc.conf /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmc/cmc.conf
cp -avf upgrade.sh /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmc/upgrade.sh
chmod 700 /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmc/upgrade.sh
cp -af cmc/cmc.png /usr/local/cpanel/whostmgr/docroot/addon_plugins/
cp -af cmc.tmpl /usr/local/cpanel/whostmgr/docroot/templates/

chmod +x cmcwrap.pl
./cmcwrap.pl

/usr/local/cpanel/bin/register_appconfig /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmc/cmc.conf

/bin/rm -f /usr/local/cpanel/whostmgr/docroot/cgi/addon_cmc.cgi
/bin/rm -f /usr/local/cpanel/whostmgr/docroot/cgi/cmcversion.txt
/bin/rm -Rf /usr/local/cpanel/whostmgr/docroot/cgi/cmc

echo "ConfigServer Mod Security has been installed."
exit
