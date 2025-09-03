#!/usr/bin/perl
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
# Example PT_DELETED_ACTION script
use strict;

my $exe = $ARGV[0];
my $pid = $ARGV[1];
my $user = $ARGV[2];
my $ppid = $ARGV[3];

if ($exe =~ m[^/usr/libexec/dovecot/imap-login]) {exec("/etc/init.d/dovecot restart")}
elsif ($exe =~ m[^/usr/libexec/dovecot/pop3-login]) {exec("/etc/init.d/dovecot restart")}
elsif ($exe =~ m[^/usr/sbin/pure-ftpd]) {exec("/etc/init.d/pure-ftpd restart")}
elsif ($exe =~ m[^/usr/sbin/pure-authd]) {exec("/etc/init.d/pure-ftpd restart")}
elsif ($exe =~ m[^/bin/dbus-daemon]) {exec("/etc/init.d/messagebus restart")}
elsif ($exe =~ m[^/usr/sbin/hald]) {exec("/etc/init.d/haldaemon restart")}
elsif ($exe =~ m[^/usr/sbin/mysqld]) {exec("/etc/init.d/mysql restart")}
elsif ($exe =~ m[^/usr/sbin/exim]) {exec("/etc/init.d/exim restart")}

exit;

###############################################################################
