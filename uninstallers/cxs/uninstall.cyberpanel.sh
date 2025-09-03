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

rm -fv /usr/sbin/cxs
rm -fv /etc/cron.d/cxs-cron
rm -fv /etc/cron.d/cxsdb-cron
rm -Rfv /etc/cxs
rm -fv /usr/local/csf/lib/ConfigServer/cxs.pm

rm -Rfv /usr/local/CyberCP/configservercxs
rm -fv /home/cyberpanel/plugins/configservercxs
rm -Rfv /usr/local/CyberCP/public/static/configservercxs

sed -i "/configservercxs/d" /usr/local/CyberCP/CyberCP/settings.py
sed -i "/configservercxs/d" /usr/local/CyberCP/CyberCP/urls.py
if [ ! -e /etc/csf/csf.pl ]; then
    sed -i "/configserver/d" /usr/local/CyberCP/baseTemplate/templates/baseTemplate/index.html
fi

service lscpd restart

echo
echo "...Done"
