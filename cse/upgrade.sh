#!/bin/sh

if [ -e "/usr/local/cpanel/bin/register_appconfig" ]; then
    if [ -e "/usr/local/cpanel/whostmgr/docroot/cgi/addon_cse.cgi" ]; then
        /usr/local/cpanel/bin/register_appconfig /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cse/cse.conf

        /bin/rm -f /usr/local/cpanel/whostmgr/docroot/cgi/addon_cse.cgi
        /bin/rm -f /usr/local/cpanel/whostmgr/docroot/cgi/cseversion.txt
        /bin/rm -Rf /usr/local/cpanel/whostmgr/docroot/cgi/cse
    fi
fi
