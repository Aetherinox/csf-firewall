#!/bin/sh
echo "Uninstalling cxs..."
echo

if test `cat /proc/1/comm` = "systemd"
then
    systemctl disable cxswatch.service
    systemctl disable pure-uploadscript.service
    systemctl stop cxswatch.service
    systemctl stop pure-uploadscript.service
    rm -fv /usr/lib/systemd/system/cxswatch.service
    rm -fv /usr/lib/systemd/system/pure-uploadscript.service
    systemctl daemon-reload
else
    if [ -f /etc/redhat-release ]; then
        /etc/init.d/pure-uploadscript stop
        chkconfig pure-uploadscript off
        chkconfig pure-uploadscript --del
        rm -fv /etc/init.d/pure-uploadscript

        /etc/init.d/cxswatch stop
        /sbin/chkconfig cxswatch off
        /sbin/chkconfig cxswatch --del
        rm -fv /etc/init.d/cxswatch
    elif [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
        /etc/init.d/pure-uploadscript stop
        update-rc.d -f pure-uploadscript remove
        rm -fv /etc/init.d/pure-uploadscript
    elif [ -f /etc/gentoo-release ]; then
        /etc/init.d/pure-uploadscript stop
        rc-update del pure-uploadscript default
        rm -fv /etc/init.d/pure-uploadscript
    else
        /etc/init.d/pure-uploadscript stop
        chkconfig pure-uploadscript off
        chkconfig pure-uploadscript --del
        rm -fv /etc/init.d/pure-uploadscript

        /etc/init.d/cxswatch stop
        /sbin/chkconfig cxswatch off
        /sbin/chkconfig cxswatch --del
        rm -fv /etc/init.d/cxswatch
    fi
fi

rm -fv /usr/local/cwpsrv/htdocs/resources/admin/modules/cxs.php
rm -fv /usr/local/cwpsrv/htdocs/resources/admin/modules/cxs.pl
rm -fv /usr/local/cwpsrv/htdocs/resources/admin/addons/ajax/ajax_cxsframe.php
rm -Rfv /etc/cxs /usr/local/cwpsrv/htdocs/admin/design/cxs/
#sed -i "/configserver/d" /usr/local/cwpsrv/htdocs/resources/admin/include/3rdparty.php

rm -fv /etc/cron.d/cxs-cron
rm -fv /etc/cron.d/cxsdb-cron
rm -fv /usr/local/csf/lib/ConfigServer/cxs.pm

echo
echo "...Done"
