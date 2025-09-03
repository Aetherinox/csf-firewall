#!/bin/sh

if [ -e "/usr/local/cpanel/bin/unregister_appconfig" ]; then
    cd /
    /usr/local/cpanel/bin/unregister_appconfig cmm
else
    if [ ! -e "/var/cpanel/apps/cmm.conf" ]; then
        /bin/rm -fv /var/cpanel/apps/cmm.conf
    fi
fi

/bin/rm -fv /usr/local/cpanel/whostmgr/docroot/cgi/addon_cmm.cgi
/bin/rm -fv /usr/local/cpanel/whostmgr/docroot/cgi/cmmversion.txt
/bin/rm -Rfv /usr/local/cpanel/whostmgr/docroot/cgi/cmm

/bin/rm -fv /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmm.cgi
/bin/rm -fv /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmmversion.txt
/bin/rm -Rfv /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmm

echo "ConfigServer Mail Manage has been uninstalled."
exit
