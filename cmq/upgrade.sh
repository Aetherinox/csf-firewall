#!/bin/sh

if [ -e "/usr/local/cpanel/bin/register_appconfig" ]; then
    if [ -e "/usr/local/cpanel/whostmgr/docroot/cgi/addon_cmq.cgi" ]; then
        /usr/local/cpanel/bin/register_appconfig /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmq/cmq.conf

        /bin/rm -f /usr/local/cpanel/whostmgr/docroot/cgi/addon_cmq.cgi
        /bin/rm -f /usr/local/cpanel/whostmgr/docroot/cgi/cmqversion.txt
        /bin/rm -Rf /usr/local/cpanel/whostmgr/docroot/cgi/cmq
    fi
fi
