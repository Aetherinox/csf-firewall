#!/bin/sh
echo "Uninstalling osm..."
echo

rm -fv /var/run/chkservd/osmd
sed -i '/^osmd:/d' /etc/chkserv.d/chkservd.conf
/scripts/restartsrv_chkservd

if test `cat /proc/1/comm` = "systemd"
then
    systemctl disable osmd.service
    systemctl stop osmd.service
    rm -fv /usr/lib/systemd/system/osmd.service
    systemctl daemon-reload
else
    /etc/init.d/osmd stop
    /sbin/chkconfig osmd off
    /sbin/chkconfig osmd --del
    rm -fv /etc/init.d/osmd
fi

if [ -e "/usr/local/cpanel/bin/unregister_appconfig" ]; then
    cd /
	/usr/local/cpanel/bin/unregister_appconfig osm
fi

/bin/rm -Rfv /usr/local/cpanel/whostmgr/docroot/cgi/osm
/bin/rm -fv /usr/local/cpanel/whostmgr/docroot/cgi/configserver/osm.cgi
/bin/rm -Rfv /usr/local/cpanel/whostmgr/docroot/cgi/configserver/osm

rm -Rfv /etc/osm
cd

echo
echo "...Done"
