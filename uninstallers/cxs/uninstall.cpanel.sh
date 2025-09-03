#!/bin/sh
echo "Uninstalling cxs..."
echo

rm -fv /var/run/chkservd/cxswatch
sed -i '/^cxswatch:/d' /etc/chkserv.d/chkservd.conf
/scripts/restartsrv_chkservd

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
    /etc/init.d/cxswatch stop
    /sbin/chkconfig cxswatch off
    /sbin/chkconfig cxswatch --del
    rm -fv /etc/init.d/cxswatch

    /etc/init.d/pure-uploadscript stop
    chkconfig pure-uploadscript off
    chkconfig pure-uploadscript --del
    rm -fv /etc/init.d/pure-uploadscript
fi

sed -i "s/^CallUploadScript/\#CallUploadScript/" /etc/pure-ftpd.conf
sed -i "/^CallUploadScript/d" /var/cpanel/conf/pureftpd/main
sed -i "/^CallUploadScript/d" /var/cpanel/conf/pureftpd/local
/scripts/restartsrv_ftpserver

if [ -e "/usr/local/cpanel/bin/unregister_appconfig" ]; then
    cd /
	/usr/local/cpanel/bin/unregister_appconfig cxs
fi

rm -fv /usr/sbin/cxs
rm -fv /etc/cron.d/cxs-cron
rm -fv /etc/cron.d/cxsdb-cron
rm -fv /etc/cron.daily/cxsdaily.sh
rm -fv /scripts/postftpup

/bin/rm -fv /usr/local/cpanel/whostmgr/docroot/cgi/addon_cxs.cgi
/bin/rm -Rfv /usr/local/cpanel/whostmgr/docroot/cgi/cxs

/bin/rm -fv /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cxs.cgi
/bin/rm -Rfv /usr/local/cpanel/whostmgr/docroot/cgi/configserver/cxs

/scripts/modsec_vendor remove configserver
/usr/local/cpanel/bin/manage_hooks delete module ConfigServer::CXS::FTPHook > /dev/null 2>&1
/usr/local/cpanel/bin/manage_hooks delete module ConfigServer::CXS::AccountHook > /dev/null 2>&1

rm -Rfv /etc/cxs
rm -fv /usr/local/csf/lib/ConfigServer/cxs.pm
cd

echo
echo "...Done"
