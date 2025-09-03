#!/bin/sh

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
