#!/bin/sh
###############################################################################
# Copyright (C) 2006-2025 Jonathan Michaelson
#
# https://github.com/waytotheweb/scripts
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, see <https://www.gnu.org/licenses>.
###############################################################################
PATH=$PATH:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

if [ ! -e "msuninstall.pl" ]; then
	echo "Download msuninstall.pl here first"
    exit
fi

if [ -e "/usr/local/cpanel/version" ]; then
    sed -i 's%/usr/bin/perl%/usr/local/cpanel/3rdparty/bin/perl%' msuninstall.pl
else
    sed -i 's%/usr/local/cpanel/3rdparty/bin/perl%/usr/bin/perl%' msuninstall.pl
fi

if [ -e "/usr/msfe/uninstall.msfe.sh" ]; then
    sh /usr/msfe/uninstall.msfe.sh
fi

rm -Rfv /usr/msfe
rm -f /etc/cron.daily/mailscanner_daily.cron

if test `cat /proc/1/comm` = "systemd"
then
    systemctl disable MailScanner.service
    systemctl stop MailScanner.service

    rm -f /usr/lib/systemd/system/MailScanner.service
    systemctl daemon-reload
else
    service MailScanner stop
    chkconfig MailScanner off
    chkconfig MailScanner --del
    rm -f /etc/init.d/MailScanner
fi

if [ -e "/usr/local/cpanel/version" ]; then
    rm -f /etc/chkservd.d/mailscanner
    rm -f /var/run/chkservd/mailscanner
fi

chmod +x msuninstall.pl
./msuninstall.pl 3

echo
echo "All done."
