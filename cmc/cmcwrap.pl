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
## no critic (RequireUseWarnings, ProhibitExplicitReturnUndef, ProhibitMixedBooleanOperators, RequireBriefOpen)
# start main
use strict;
use File::Basename;
use File::Path;
use Fcntl qw(:DEFAULT :flock);
use IPC::Open3;

my $apachepath = "/usr/local/apache/conf";
my $apachebin = "/usr/local/apache/bin/httpd";
my $apachectl = "/usr/local/apache/bin/apachectl";
my $apachelogs = "/usr/local/apache/logs";
if (-e "/usr/local/cpanel/version" and -e "/etc/cpanel/ea4/is_ea4" and -e "/etc/cpanel/ea4/paths.conf") {
	$apachepath = "/etc/apache2/conf.d";
	$apachebin = "/usr/sbin/httpd";
	$apachectl = "/usr/sbin/apachectl";
	$apachelogs = "/etc/apache2/logs";
	open (my $IN, "<", "/etc/cpanel/ea4/paths.conf");
	flock ($IN, LOCK_SH);
	my @file = <$IN>;
	close ($IN);
	chomp @file;
	foreach my $line (@file) {
		if ($line =~ /^(\s|\#|$)/) {next}
		if ($line !~ /=/) {next}
		my ($name,$value) = split (/=/,$line,2);
		$value =~ s/^\s+//g;
		$value =~ s/\s+$//g;
		if ($name eq "dir_conf") {$apachepath = $value}
		if ($name eq "bin_httpd") {$apachebin = $value}
		if ($name eq "bin_apachectl") {$apachectl = $value}
		if ($name eq "dir_logs") {$apachelogs = $value}
	}
}

my $httpv = "2";
my $mypid;
my ($childin, $childout);
$mypid = open3($childin, $childout, $childout, $apachebin,"-v");
my @version = <$childout>;
waitpid ($mypid, 0);
chomp @version;
$version[0] =~ /Apache\/(\d+)\.(\d+)\.(\d+)/;
my $mas = $1;
my $maj = $2;
my $min = $3;
$httpv = "$mas.$maj";

my $stdpath = "$apachepath/userdata/std/2";
my $sslpath = "$apachepath/userdata/ssl/2";
if ($httpv eq "2.2") {
	$stdpath = "$apachepath/userdata/std/2_2";
	$sslpath = "$apachepath/userdata/ssl/2_2";
}
if ($httpv eq "2.4") {
	$stdpath = "$apachepath/userdata/std/2_4";
	$sslpath = "$apachepath/userdata/ssl/2_4";
}

my $mod = 0;
print "Checking that modsec.conf files are wrapped in <IfModule mod_security2.c>...</IfModule>:\n";
foreach my $userdir (glob "$stdpath/*") {
	if (-d $userdir) {
		my ($user, $filedir) = fileparse($userdir);
		my $ssldir = $sslpath."/".$user;
		if (-f "$userdir/modsec.conf") {
			open (my $FH, "<", "$userdir/modsec.conf");
			flock ($FH, LOCK_SH);
			my @data = <$FH>;
			close ($FH);
			unless (grep {$_ =~ /<IfModule mod_security2\.c>/} @data) {
				open (my $OUT, ">", "$userdir/modsec.conf");
				flock ($OUT, LOCK_EX);
				print $OUT "<IfModule mod_security2.c>\n";
				print $OUT @data;
				print $OUT "</IfModule>\n";
				close ($OUT);
				$mod = 1;
			}
		}
		if (-f "$ssldir/modsec.conf") {
			open (my $FH, "<", "$ssldir/modsec.conf");
			flock ($FH, LOCK_SH);
			my @data = <$FH>;
			close ($FH);
			unless (grep {$_ =~ /<IfModule mod_security2\.c>/} @data) {
				open (my $OUT, ">", "$ssldir/modsec.conf");
				flock ($OUT, LOCK_EX);
				print $OUT "<IfModule mod_security2.c>\n";
				print $OUT @data;
				print $OUT "</IfModule>\n";
				close ($OUT);
				$mod = 1;
			}
		}
		foreach my $domaindir (glob "$userdir/*") {
			if (-d $domaindir) {
				my ($domain, $filedir) = fileparse($domaindir);
				my $ssldomaindir = $ssldir."/".$domain;
				if (-f "$domaindir/modsec.conf") {
					open (my $FH, "<", "$domaindir/modsec.conf");
					flock ($FH, LOCK_SH);
					my @data = <$FH>;
					close ($FH);
					unless (grep {$_ =~ /<IfModule mod_security2\.c>/} @data) {
						open (my $OUT, ">", "$domaindir/modsec.conf");
						flock ($OUT, LOCK_EX);
						print $OUT "<IfModule mod_security2.c>\n";
						print $OUT @data;
						print $OUT "</IfModule>\n";
						close ($OUT);
						$mod = 1;
					}
				}
				if (-f "$ssldomaindir/modsec.conf") {
					open (my $FH, "<", "$ssldomaindir/modsec.conf");
					flock ($FH, LOCK_SH);
					my @data = <$FH>;
					close ($FH);
					unless (grep {$_ =~ /<IfModule mod_security2\.c>/} @data) {
						open (my $OUT, ">", "$ssldomaindir/modsec.conf");
						flock ($OUT, LOCK_EX);
						print $OUT "<IfModule mod_security2.c>\n";
						print $OUT @data;
						print $OUT "</IfModule>\n";
						close ($OUT);
						$mod = 1;
					}
				}
			}
		}
	}
}

if ($mod) {
	print "Modifications made, restarting apache:\n";
	system ("/scripts/restartsrv_httpd");
}

print "Done.\n";