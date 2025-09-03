#!/bin/sh
echo "Uninstalling osm..."
echo

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

rm -fv /etc/exim.acl_script.pre.osm.conf
rm -fv /etc/exim.acl_check_recipient.pre.osm.conf
rm -fv /etc/virtual/osm_disable
rm -fv /etc/virtual/osm_hold
rm -Rfv /usr/local/directadmin/plugins/osm
rm -Rfv /etc/osm
cd

echo
echo "...Done"
