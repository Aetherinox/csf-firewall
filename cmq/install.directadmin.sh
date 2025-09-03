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

mkdir /etc/cmq
chmod 700 /etc/cmq

mkdir /usr/local/cpanel/whostmgr/docroot/cgi/configserver
chmod 700 /usr/local/cpanel/whostmgr/docroot/cgi/configserver
mkdir /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmq
chmod 700 /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmq

cp -avf cpanel/cmq.cgi /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmq.cgi
chmod -v 700 /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmq.cgi

cp -avf Modules /etc/cmq/
cp -avf cmqversion.txt /etc/cmq/
cp -avf downloadservers /etc/cmq/
cp -avf INSTALL.txt /etc/cmq/
cp -avf uninstall.sh /etc/cmq/
chmod 700 /etc/cmq/uninstall.sh

mkdir -p /usr/local/directadmin/plugins/cmq/
chmod 711 /usr/local/directadmin/plugins/cmq/
chown diradmin:diradmin /usr/local/directadmin/plugins/cmq/
cp -avf da/* /usr/local/directadmin/plugins/cmq/
cp -avf cmq/* /usr/local/directadmin/plugins/cmq/images/

export PATH=$PATH;
gcc -o /usr/local/directadmin/plugins/cmq/exec/cmq cmq.c
find /usr/local/directadmin/plugins/cmq/ -type d -exec chmod -v 755 {} \;
find /usr/local/directadmin/plugins/cmq/ -type f -exec chmod -v 644 {} \;
chown -Rv diradmin:diradmin /usr/local/directadmin/plugins/cmq
chmod -v 755 /usr/local/directadmin/plugins/cmq/admin/index.html
chmod -v 755 /usr/local/directadmin/plugins/cmq/admin/index.raw
chmod -v 755 /usr/local/directadmin/plugins/cmq/exec/da_cmq.cgi
chmod -v 755 /usr/local/directadmin/plugins/cmq/scripts/*
chown -v root:root /usr/local/directadmin/plugins/cmq/exec/cmq
chmod -v 4755 /usr/local/directadmin/plugins/cmq/exec/cmq

echo "ConfigServer Mail Queues has been installed."
exit
