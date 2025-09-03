#!/bin/sh

if [ -e "/usr/local/cpanel/bin/register_appconfig" ]; then
    if [ -e "/usr/local/cpanel/whostmgr/docroot/cgi/addon_cmm.cgi" ]; then
        /usr/local/cpanel/bin/register_appconfig /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmm/cmm.conf

        /bin/rm -f /usr/local/cpanel/whostmgr/docroot/cgi/addon_cmm.cgi
        /bin/rm -f /usr/local/cpanel/whostmgr/docroot/cgi/cmmversion.txt
        /bin/rm -Rf /usr/local/cpanel/whostmgr/docroot/cgi/cmm
    fi
fi
