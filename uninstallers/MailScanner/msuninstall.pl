#!/usr/local/cpanel/3rdparty/bin/perl
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
# start main
use strict;
use Path::Tiny;
use IPC::Open3;
use Fcntl qw(:DEFAULT :flock);

our ($installed, $option, $cpanel);

$installed = 0;
if (-d "/usr/mailscanner/") {$installed = 1}

$cpanel = 1;
unless (-e "/usr/local/cpanel/version") {$cpanel = 0}

print "Removing MailScanner...\n\n";

if ($cpanel) {
	print "Updating Config and Restarting Exim...\n";
	unlink ("/etc/antivirus.empty");
	open (IN,"<", "/etc/exim.conf.localopts");
	flock (IN, LOCK_SH);
	my @localopts = <IN>;
	close (IN);
	chomp @localopts;
	sysopen (OUT, "/etc/exim.conf.localopts", O_WRONLY | O_CREAT | O_TRUNC);
	flock (OUT, LOCK_EX);
	foreach my $line (@localopts) {
		if ($line !~ /^systemfilter/) {print OUT "$line\n"}
	}
	print OUT "systemfilter=/etc/antivirus.exim\n";
	close OUT;
	
	unlink ("/etc/exim_outgoing.conf");
	unlink ("/etc/exiscandisable");

	open (IN, "<", "/etc/exim.conf.local");
	flock (IN, LOCK_SH);
	my @exim_conf_local = <IN>;
	close (IN);
	chomp @exim_conf_local;
	sysopen (OUT, "/etc/exim.conf.local", O_WRONLY | O_CREAT | O_TRUNC);
	flock (OUT, LOCK_EX);
	foreach my $line (@exim_conf_local) {
		if ($line =~ /message_logs = false/) {next}
		if ($line =~ /queue_only_override = false/) {next}
		if ($line =~ /\.include_if_exists \/usr\/msfe\/spambox\.conf/) {next}
		print OUT "$line\n";
	}
	close (OUT);

	foreach my $file ("/usr/local/cpanel/etc/exim/acls/ACL_MAIL_PRE_BLOCK/custom_begin_mail_pre", "/usr/local/cpanel/etc/exim/acls/ACL_MAIL_POST_BLOCK/custom_begin_mail_post") {
		open (my $ACL, "<", $file);
		flock ($ACL, LOCK_SH);
		my @acl_config = <$ACL>;
		close ($ACL);
		chomp @acl_config;
		sysopen (OUT, "$file", O_WRONLY | O_CREAT | O_TRUNC);
		flock (OUT, LOCK_EX);
		foreach my $line (@acl_config) {
			if ($line =~ /\.include_if_exists \/usr\/msfe\/mailscannerq\.conf/) {next}
			print OUT "$line\n";
		}
		close (OUT);
	}

	system("/scripts/buildeximconf");
	system("/scripts/restartsrv_exim");
	print "Done\n";

	open (IN,"<", "/etc/chkserv.d/chkservd.conf");
	flock (IN, LOCK_SH);
	my @chkservd = <IN>;
	close (IN);
	chomp @chkservd;
	sysopen (OUT, "/etc/chkserv.d/chkservd.conf", O_WRONLY | O_CREAT | O_TRUNC);
	flock (OUT, LOCK_EX);
	foreach my $line (@chkservd) {
		if ($line !~ /^mailscanner/) {print OUT "$line\n"}
	}
	close OUT;
}

unlink ("/usr/msfe/mailscannerq");

print "Stopping MailScanner and cron jobs...\n";
system ("killall", "-9", "MailScanner");
unlink ("/etc/cron.daily/clean.quarantine.cron");
unlink ("/etc/cron.daily/clean.incoming.cron");
unlink ("/etc/cron.hourly/update_virus_scanners");
unlink ("/etc/chkserv.d/mailscanner");
unlink ("/var/run/chkservd/mailscanner");
unlink "/etc/mail/spamassassin/mailscanner.cf";
print "Done\n";

print "Removing MailScanner directories...\n";
if (-d "/usr/mailscanner/") {system ("/bin/rm -Rf /usr/mailscanner/")}
if (-d "/var/spool/MailScanner/") {system ("/bin/rm -Rf /var/spool/MailScanner/")}
if (-d "/var/spool/exim_incoming/") {
	system ("/bin/cp -avf /var/spool/exim_incoming/input/* /var/spool/exim/input/");
	system ("/bin/rm -Rf /var/spool/exim_incoming/");
}
if (-d "/var/spool/exim/mailscanner/") {
	system ("/bin/cp -avf /var/spool/exim/mailscanner/input/* /var/spool/exim/input/");
	system ("/bin/rm -Rf /var/spool/exim/mailscanner/");
}
if (-d "/var/spool/mqueue/") {system ("/bin/rm -Rf /var/spool/mqueue/")}
print "Done\n";

print "All Done\n";

exit;
