#!/usr/local/cpanel/3rdparty/bin/perl
#WHMADDON:addonupdates:ConfigServer ModSec Control
#ACLS:configserver
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
use strict;
use CGI::Carp qw(fatalsToBrowser);

use File::Basename;
use File::Path;
use File::Copy;
use File::Find;
use Fcntl qw(:DEFAULT :flock);
use IPC::Open3;

use lib '/usr/local/cpanel';
require Cpanel::Form;
require Cpanel::Config;
require Cpanel::Version::Tiny;
require Whostmgr::ACLS;
require Cpanel::Rlimit;
require Cpanel::Template;
###############################################################################
# start main

our ($images, $myv, $script, $versionfile, %FORM, $downloadserver);

%FORM = Cpanel::Form::parseform();

Whostmgr::ACLS::init_acls();
if (!Whostmgr::ACLS::hasroot()) {
	print "Content-type: text/html\r\n\r\n";
	print "You do not have access to ConfigServer ModSecurity Control.\n";
	exit();
}

Cpanel::Rlimit::set_rlimit_to_infinity();

$script = "cmc.cgi";
$images = "cmc";
$versionfile = "/usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmc/cmcversion.txt";
local $| = 1;

$downloadserver = &getdownloadserver;

my $thisapp = "cmc";
my $reregister;
my $modalstyle;
if ($Cpanel::Version::Tiny::major_version >= 65) {
	if (-e "/usr/local/cpanel/whostmgr/docroot/cgi/configserver/${thisapp}/${thisapp}.conf") {
		sysopen (my $CONF, "/usr/local/cpanel/whostmgr/docroot/cgi/configserver/${thisapp}/${thisapp}.conf", O_RDWR | O_CREAT);
		flock ($CONF, LOCK_EX);
		my @confdata = <$CONF>;
		chomp @confdata;
		for (0..scalar(@confdata)) {
			if ($confdata[$_] =~ /^target=mainFrame/) {
				$confdata[$_] = "target=_self";
				$reregister = 1;
			}
		}
		if ($reregister) {
			seek ($CONF, 0, 0);
			truncate ($CONF, 0);
			foreach (@confdata) {
				print $CONF "$_\n";
			}
			&printcmd("/usr/local/cpanel/bin/register_appconfig","/usr/local/cpanel/whostmgr/docroot/cgi/configserver/${thisapp}/${thisapp}.conf");
			$reregister = "<div class='bs-callout bs-callout-info'><h4>Updated application. The next time you login to WHM this will open within the native WHM main window instead of launching a separate window</h4></div>\n";
		}
		close ($CONF);
	}
}

print "Content-type: text/html\r\n\r\n";
#if ($Cpanel::Version::Tiny::major_version < 65) {$modalstyle = "style='top:120px'"}

our (@files);
open (my $IN, "<", $versionfile) or die $!;
flock ($IN, LOCK_SH);
$myv = <$IN>;
close ($IN);
chomp $myv;

my $bootstrapcss = "<link rel='stylesheet' href='$images/bootstrap/css/bootstrap.min.css'>";
my $jqueryjs = "<script src='$images/jquery.min.js'></script>";
my $bootstrapjs = "<script src='$images/bootstrap/js/bootstrap.min.js'></script>";

my $templatehtml;
my $SCRIPTOUT;
unless ($FORM{action} eq "help") {
	open ($SCRIPTOUT, '>', \$templatehtml);
	select $SCRIPTOUT;

	print <<EOF;
	<!-- $bootstrapcss -->
	<link href='$images/configserver.css' rel='stylesheet' type='text/css'>
	$jqueryjs
	$bootstrapjs
EOF
} else {
	print <<EOF;
<!doctype html>
<html lang='en'>
<head>
	$bootstrapcss
	<link href='$images/configserver.css' rel='stylesheet' type='text/css'>
	$jqueryjs
	$bootstrapjs
</head>
<body>
<div class='container-fluid'>
EOF
}

print <<EOF;
<div id="loader"></div><br />
<div class='panel panel-default'>
<h4><img src='$images/cmc.png' style='padding-left: 10px'> ConfigServer ModSecurity Control - cmc v$myv</h4></div>
EOF
if ($reregister ne "") {print $reregister}

print "<div class='bs-callout bs-callout-warning'><h4>This script creates and rewrites modsec2.whitelist.conf and userdata modsec.conf files</h4>\n";
print "<p>Do not use cmc if you have made manual modifications to these files as they will be removed by cmc</p></div>\n";

my $is_ea4 = 0;
my $apachepath = "/usr/local/apache/conf";
my $modsecpath = "/usr/local/apache/conf";
my $apachebin = "/usr/local/apache/bin/httpd";
my $apachectl = "/usr/local/apache/bin/apachectl";
my $apachelogs = "/usr/local/apache/logs";
if (-e "/usr/local/cpanel/version" and -e "/etc/cpanel/ea4/is_ea4" and -e "/etc/cpanel/ea4/paths.conf") {
	$is_ea4 = 1;
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
	$modsecpath = $apachepath."/modsec";
}

my $httpv = "2";
my $mypid;
my ($childin, $childout);
$mypid = open3($childin, $childout, $childout, "$apachebin","-v");
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
my $oldstdpath;
my $oldsslpath;
if ($httpv eq "2.2") {
	$oldstdpath = $stdpath;
	$oldsslpath = $sslpath;
	$stdpath = "$apachepath/userdata/std/2_2";
	$sslpath = "$apachepath/userdata/ssl/2_2";
}
if ($httpv eq "2.4") {
	$oldstdpath = $stdpath;
	$oldsslpath = $sslpath;
	$stdpath = "$apachepath/userdata/std/2_4";
	$sslpath = "$apachepath/userdata/ssl/2_4";
}

my $truefile;
if ($FORM{template} ne "") {
	my ($tfile, $tdir) = fileparse("$apachepath/$FORM{template}");
	$truefile = "$tdir$tfile";
}

if (($FORM{template} ne "") and ($truefile !~ m[^$apachepath/])) {
	print "[$FORM{template}] is not a valid file";
}
elsif (($FORM{domain} ne "") and ($FORM{domain} !~ /^[a-zA-Z0-9\-\_\.]+$/)) {
	print "[$FORM{domain}] is not a valid domain";
}
elsif (($FORM{user} ne "") and ($FORM{user} !~ /^[a-zA-Z0-9\-\_\.\@\%\+]+$/)) {
	print "[$FORM{user}] is not a valid user";
}
elsif ($FORM{action} eq "upgrade") {
	print "Retrieving new cmc package...\n";
	print "<pre style='white-space:pre-wrap;'>";
	&printcmd("rm -Rfv /usr/src/cmc* ; cd /usr/src ; wget -q https://$downloadserver/cmc.tgz 2>&1");
	print "</pre>";
	if (! -z "/usr/src/cmc.tgz") {
		print "Unpacking new cmc package...\n";
		print "<pre style='white-space:pre-wrap;'>";
		&printcmd("cd /usr/src ; tar -xzf cmc.tgz ; cd cmc ; sh install.sh 2>&1");
		print "</pre>";
		print "Tidying up...\n";
		print "<pre style='white-space:pre-wrap;'>";
		&printcmd("rm -Rfv /usr/src/cmc*");
		print "</pre>";
		print "...All done.\n";
	}

	open (my $IN, "<",$versionfile) or die $!;
	flock ($IN, LOCK_SH);
	$myv = <$IN>;
	close ($IN);
	chomp $myv;

	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "ms_list") {
	&modsec;
}
elsif ($FORM{action} eq "ms_config") {
	sysopen (my $IN, "$apachepath/$FORM{template}", O_RDWR | O_CREAT);
	flock ($IN, LOCK_SH);
	my @confdata = <$IN>;
	close ($IN);
	chomp @confdata;

	print "<form action='$script' method='post'>\n";
	print "<input type='hidden' name='action' value='savems_config'>\n";
	print "<input type='hidden' name='template' value='$FORM{template}'>\n";
	print "<fieldset><legend><b>Edit $FORM{template}</b></legend>\n";
	print "<table class='table table-bordered table-striped'>\n";
	print "<tr><td><textarea style='width:100%;' name='formdata' cols='80' rows='40' wrap='off'>\n";
	foreach my $line (@confdata) {
		$line =~ s/\&/\&amp\;/g;
		$line =~ s/>/\&gt\;/g;
		$line =~ s/</\&lt\;/g;
		print $line."\n";
	}
	print "</textarea></td></tr></table></fieldset>\n";
	print "<p class='text-center'><input type='submit' class='btn btn-default' value='Change'></p>\n";
	print "</form>\n";
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "savems_config") {
	$FORM{formdata} =~ s/\r//g;
	sysopen (my $OUT, "$apachepath/$FORM{template}", O_WRONLY | O_CREAT);
	flock ($OUT, LOCK_EX);
	seek ($OUT, 0, 0);
	truncate ($OUT, 0);
	if ($FORM{formdata} !~ /\n$/) {$FORM{formdata} .= "\n"}
	print $OUT $FORM{formdata};
	close ($OUT);

	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th  style='text-align:left'>ModSecurity save $FORM{template}</th></tr></thead>";
	print "<tr><td>Rebuilding and restarting Apache:<br>";
	print "<pre style='white-space:pre-wrap;'>";
	&printcmd("/usr/local/cpanel/bin/build_apache_conf");
	&printcmd("$apachectl","graceful");
	print "\n..Done</pre>";
	print "</td></tr>\n";
	print "</table>\n";
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "Modify user whitelist") {
	if ($FORM{user}) {
		my %ids;
		my $off = 0;
		if (-d "$stdpath/$FORM{user}/") {
			if (-e "$stdpath/$FORM{user}/modsec.conf") {
				open (my $FH, "<", "$stdpath/$FORM{user}/modsec.conf");
				flock ($FH, LOCK_SH);
				my @data = <$FH>;
				close ($FH);
				chomp @data;
				foreach my $line (@data) {
					if ($line =~ /SecRuleRemoveById\s+(\d*)/) {$ids{$1} = 1}
					if ($line =~ /SecRuleEngine\s+Off/) {$off = 1}
				}
			}
		} else {
			mkpath("$stdpath/$FORM{user}");
		}
		unless (-d "$sslpath/$FORM{user}") {mkpath("$sslpath/$FORM{user}")}
		my @domains;
		open (my $IN, "<","/var/cpanel/users/$FORM{user}");
		flock ($IN, LOCK_SH);
		my @userdata = <$IN>;
		close ($IN);
		chomp @userdata;
		foreach my $line (@userdata) {
			if ($line =~ /^DNS(\d*)=(.*)$/) {
				my $domain = $2;
				$domain =~ s/\s//g;
				push @domains,$domain;
				unless (-d "$stdpath/$FORM{user}/$domain") {
					mkdir ("$stdpath/$FORM{user}/$domain");
				}
				unless (-d "$sslpath/$FORM{user}/$domain") {
					mkdir ("$sslpath/$FORM{user}/$domain");
				}
			}
		}
		@domains = sort @domains;

		if ($off) {
			print "<table class='table table-bordered table-striped'>\n";
			print "<thead><tr><th colspan='2'>ModSecurity whitelist for $FORM{user}</th></tr></thead>";
			print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='onoff'><input type='hidden' name='user' value='$FORM{user}'><input type='radio' name='choose' checked value='0'>Off <input type='radio' name='choose' value='1'>On</td><td width='100%'><p>You can completely disable ModSecurity for all domains owned by this user by setting this to Off and clicking the <i>Select</i> button:</p><p><input type='submit' class='btn btn-default' value='Select'></td></form></tr>\n";
			print "</table>\n";
		} else {
			print "<table class='table table-bordered table-striped'>\n";
			print "<thead><tr><th colspan='2'>ModSecurity whitelist for $FORM{user}</th></tr></thead>";
			print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='onoff'><input type='hidden' name='user' value='$FORM{user}'><input type='radio' name='choose' value='0'>Off <input type='radio' name='choose' value='1' checked>On</td><td width='100%'><p>You can completely disable ModSecurity for all domains owned by this user by setting this to Off and clicking the <i>Select</i> button:</p><p><input type='submit' class='btn btn-default' value='Select'></td></form></tr>\n";
			print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='thisuser'><input type='hidden' name='user' value='$FORM{user}'>ModSecurity rule ID list:<br /><textarea style='width:100%;' name='ids' rows='10' cols='10'>";
			foreach my $id (sort keys %ids) {print "$id\n"}
			print "</textarea></td><td width='100%'><p>You can add ModSecurity rule ID numbers that you want to be disabled for all domains owned by this user.</p><p>You should place one ID number per line. When you have clicked the <i>Save whitelist for all $FORM{user} domains</i> button: the relevant lines will be added to:</p><p>$stdpath/$FORM{user}/modsec.conf<br>$sslpath/$FORM{user}/modsec.conf</p><p>Then httpd.conf will be rebuilt and apache will be gracefully restarted.</p><p><input type='submit' class='btn btn-default' value='Save whitelist for all $FORM{user} domains'></td></form></tr>\n";
			print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='domain'><input type='hidden' name='user' value='$FORM{user}'><select name='domain' size='10'>";
			foreach my $domain (@domains) {print "<option>$domain</option>\n"}
			print "</select></td><td width='100%'><p>Alternatively, you can disable rules on a per domain basis by selecting a domain and then clicking:</p><p><input type='submit' class='btn btn-default' value='Modify domain whitelist'></td></form></tr>\n";
			print "</table>\n";
		}
	} else {
		print "<p>No user selected<p>\n";
	}
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "onoff") {
	&onoff("$stdpath/$FORM{user}/modsec.conf");
	&onoff("$sslpath/$FORM{user}/modsec.conf");

	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th  style='text-align:left'>ModSecurity whitelist for $FORM{user}: ";
	if ($FORM{choose}) {
		print "On";
	} else {
		print "Off";
	}
	print "</th></tr></thead>";
	print "<tr><td>Rebuilding and restarting Apache:<br>";
	print "<pre style='white-space:pre-wrap;'>";
	&printcmd("/usr/local/cpanel/bin/build_apache_conf");
	&printcmd("$apachectl","graceful");
	print "\n..Done</pre>";
	print "</td></tr>\n";
	print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='Modify user whitelist'><input type='hidden' name='user' value='$FORM{user}'><input type='submit' class='btn btn-default' value='Go back'></td></form></tr>\n";
	print "</table>\n";
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "thisuser") {
	&ids("$stdpath/$FORM{user}/modsec.conf");
	&ids("$sslpath/$FORM{user}/modsec.conf");

	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th  style='text-align:left'>ModSecurity whitelist for $FORM{user} saved";
	print "</th></tr></thead>";
	print "<tr><td>Rebuilding and restarting Apache:<br>";
	print "<pre style='white-space:pre-wrap;'>";
	&printcmd("/usr/local/cpanel/bin/build_apache_conf");
	&printcmd("$apachectl","graceful");
	print "\n..Done</pre>";
	print "</td></tr>\n";
	print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='Modify user whitelist'><input type='hidden' name='user' value='$FORM{user}'><input type='submit' class='btn btn-default' value='Go back'></td></form></tr>\n";
	print "</table>\n";
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "domain") {
	if ($FORM{user} and $FORM{domain}) {
		my %ids;
		my $off = 0;
		if (-d "$stdpath/$FORM{user}/$FORM{domain}/") {
			if (-e "$stdpath/$FORM{user}/$FORM{domain}/modsec.conf") {
				open (my $FH, "<", "$stdpath/$FORM{user}/$FORM{domain}/modsec.conf");
				flock ($FH, LOCK_SH);
				my @data = <$FH>;
				close ($FH);
				chomp @data;
				foreach my $line (@data) {
					if ($line =~ /SecRuleRemoveById\s+(\d*)/) {$ids{$1} = 1}
					if ($line =~ /SecRuleEngine\s+Off/) {$off = 1}
				}
			}
		}
		if ($off) {
			print "<table class='table table-bordered table-striped'>\n";
			print "<thead><tr><th colspan='2'>ModSecurity whitelist for $FORM{domain}</th></tr></thead>";
			print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='donoff'><input type='hidden' name='domain' value='$FORM{domain}'><input type='hidden' name='user' value='$FORM{user}'><input type='radio' name='choose' value='0' checked>Off <input type='radio' name='choose' value='1'>On</td><td width='100%'><p>You can completely disable ModSecurity on this domain by setting this to Off and clicking the <i>Select</i> button:</p><p><input type='submit' class='btn btn-default' value='Select'></td></form></tr>\n";
			print "<tr><form action='$script' method='post'><td colspan='2'><input type='hidden' name='action' value='Modify user whitelist'><input type='hidden' name='user' value='$FORM{user}'><input type='submit' class='btn btn-default' value='Go back'></td></form></tr>\n";
			print "</table>\n";
		} else {
			print "<table class='table table-bordered table-striped'>\n";
			print "<thead><tr><th colspan='2'>ModSecurity whitelist for $FORM{domain}</th></tr></thead>";
			print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='donoff'><input type='hidden' name='domain' value='$FORM{domain}'><input type='hidden' name='user' value='$FORM{user}'><input type='radio' name='choose' value='0'>Off <input type='radio' name='choose' checked value='1'>On</td><td width='100%'><p>You can completely disable ModSecurity on this domain by setting this to Off and clicking the <i>Select</i> button:</p><p><input type='submit' class='btn btn-default' value='Select'></td></form></tr>\n";
			print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='thisdomain'><input type='hidden' name='domain' value='$FORM{domain}'><input type='hidden' name='user' value='$FORM{user}'>ModSecurity rule ID list:<br /><textarea style='width:100%;' name='ids' rows='10' cols='10'>";
			foreach my $id (sort keys %ids) {print "$id\n"}
			print "</textarea></td><td width='100%'><p>You can add ModSecurity rule ID numbers that you want to be disabled for this domain.</p><p>You should place one ID number per line. When you have clicked the <i>Save whitelist for $FORM{domain}</i> button: the relevant lines will be added to:</p><p>$stdpath/$FORM{user}/$FORM{domain}/modsec.conf<br>$sslpath/$FORM{user}/$FORM{domain}/modsec.conf</p><p> Then httpd.conf will be rebuilt and apache will be gracefully restarted.</p><p><input type='submit' class='btn btn-default' value='Save whitelist for $FORM{domain}'></td></form></tr>\n";
			print "<tr><form action='$script' method='post'><td colspan='2'><input type='hidden' name='action' value='Modify user whitelist'><input type='hidden' name='user' value='$FORM{user}'><input type='submit' class='btn btn-default' value='Go back'></td></form></tr>\n";
			print "</table>\n";
		}
	} else {
		print "<p>No domain selected<p>\n";
	}
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "donoff") {
	&onoff("$stdpath/$FORM{user}/$FORM{domain}/modsec.conf");
	&onoff("$sslpath/$FORM{user}/$FORM{domain}/modsec.conf");

	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th  style='text-align:left'>ModSecurity whitelist for $FORM{domain}: ";
	if ($FORM{choose}) {
		print "On";
	} else {
		print "Off";
	}
	print "</th></tr></thead>";
	print "<tr><td>Rebuilding and restarting Apache:<br>";
	print "<pre style='white-space:pre-wrap;'>";
	&printcmd("/usr/local/cpanel/bin/build_apache_conf");
	&printcmd("$apachectl","graceful");
	print "\n..Done</pre>";
	print "</td></tr>\n";
	print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='domain'><input type='hidden' name='domain' value='$FORM{domain}'><input type='hidden' name='user' value='$FORM{user}'><input type='submit' class='btn btn-default' value='Go back'></td></form></tr>\n";
	print "</table>\n";
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "thisdomain") {
	&ids("$stdpath/$FORM{user}/$FORM{domain}/modsec.conf");
	&ids("$sslpath/$FORM{user}/$FORM{domain}/modsec.conf");

	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th  style='text-align:left'>ModSecurity whitelist for $FORM{domain} saved";
	print "</th></tr></thead>";
	print "<tr><td>Rebuilding and restarting Apache:<br>";
	print "<pre style='white-space:pre-wrap;'>";
	&printcmd("/usr/local/cpanel/bin/build_apache_conf");
	&printcmd("$apachectl","graceful");
	print "\n..Done</pre>";
	print "</td></tr>\n";
	print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='domain'><input type='hidden' name='domain' value='$FORM{domain}'><input type='hidden' name='user' value='$FORM{user}'><input type='submit' class='btn btn-default' value='Go back'></td></form></tr>\n";
	print "</table>\n";
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "gonoff") {
	&onoff("$apachepath/modsec2.whitelist.conf");

	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th  style='text-align:left'>ModSecurity global whitelist: ";
	if ($FORM{choose}) {
		print "On";
	} else {
		print "Off";
	}
	print "</th></tr></thead>";
	print "<tr><td>Restarting Apache:<br>";
	print "<pre style='white-space:pre-wrap;'>";
	&printcmd("$apachectl","graceful");
	print "\n..Done</pre>";
	print "</td></tr>\n";
	print "</table>\n";
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "dironoff") {
	my $file = "$apachepath/modsec2.whitelist.conf";
	open (my $FH, "<", $file);
	flock ($FH, LOCK_SH);
	my @data = <$FH>;
	close ($FH);
	chomp @data;
	my $start = 0;
	my $done = 0;
	my $directorymatch = quotemeta($FORM{directorymatch});
	open (my $OUT, ">", $file);
	flock ($OUT, LOCK_EX);
	print $OUT "<IfModule mod_security2.c>\n";
	foreach my $line (@data) {
		if ($line =~ /^\s*<IfModule mod_security2\.c>/) {next}
		if ($line =~ /^\s*<\/IfModule>/) {next}
		if ($line =~ /<DirectoryMatch\s+\'$directorymatch\'>/) {$start = 1}
		if ($start and $line =~ /SecRuleEngine\s/) {next}
		if ($line =~ /<\/DirectoryMatch>/ and $start) {
			$start = 0;
			if ($FORM{choose}) {
			} else {
				print $OUT "\tSecRuleEngine Off\n";
			}
			$done = 1;
		}
		print $OUT "$line\n";
	}
	unless ($done) {
		print $OUT "<DirectoryMatch \'$FORM{directorymatch}\'>\n";
		if ($FORM{choose}) {
		} else {
			print $OUT "\tSecRuleEngine Off\n";
		}
		print $OUT "</DirectoryMatch>\n";
	}
	print $OUT "</IfModule>\n";
	close ($OUT);

	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th  style='text-align:left'>ModSecurity DirectoryMatch ($FORM{directorymatch}) whitelist: ";
	if ($FORM{choose}) {
		print "On";
	} else {
		print "Off";
	}
	print "</th></tr></thead>";
	print "<tr><td>Restarting Apache:<br>";
	print "<pre style='white-space:pre-wrap;'>";
	&printcmd("$apachectl","graceful");
	print "\n..Done</pre>";
	print "</td></tr>\n";
	print "</table>\n";
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "global") {
	&ids("$apachepath/modsec2.whitelist.conf");

	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th  style='text-align:left'>ModSecurity global whitelist saved";
	print "</th></tr></thead>";
	print "<tr><td>Restarting Apache:<br>";
	print "<pre style='white-space:pre-wrap;'>";
	&printcmd("$apachectl","graceful");
	print "\n..Done</pre>";
	print "</td></tr>\n";
	print "</table>\n";
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "thisdirectorymatch") {
	my $file = "$apachepath/modsec2.whitelist.conf";
	my @ids = split(/\n|\r/,$FORM{ids});
	chomp @ids;
	open (my $FH, "<", $file);
	flock ($FH, LOCK_SH);
	my @data = <$FH>;
	close ($FH);
	chomp @data;
	my $start = 0;
	my $done = 0;
	my $directorymatch = quotemeta($FORM{directorymatch});
	open (my $OUT, ">", $file);
	flock ($OUT, LOCK_EX);
	print $OUT "<IfModule mod_security2.c>\n";
	foreach my $line (@data) {
		if ($line =~ /^\s*<IfModule mod_security2\.c>/) {next}
		if ($line =~ /^\s*<\/IfModule>/) {next}
		if ($line =~ /<\/DirectoryMatch>/ and $start) {
			$start = 0;
			foreach my $id (@ids) {
				if ($id =~ /^\d+$/) {print $OUT "\tSecRuleRemoveById $id\n"}
			}
			$done = 1;
		}
		if ($start) {next}
		if ($line =~ /<DirectoryMatch\s+\'$directorymatch\'>/) {$start = 1}
		print $OUT "$line\n";
	}
	unless ($done) {
		print $OUT "<DirectoryMatch \'$FORM{directorymatch}\'>\n";
		foreach my $id (@ids) {
			if ($id =~ /^\d+$/) {print $OUT "\tSecRuleRemoveById $id\n"}
		}
		print $OUT "</DirectoryMatch>\n";
	}
	print $OUT "</IfModule>\n";
	close ($OUT);

	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th  style='text-align:left'>ModSecurity DirectoryMatch ($FORM{directorymatch}) whitelist saved";
	print "</th></tr></thead>";
	print "<tr><td>Restarting Apache:<br>";
	print "<pre style='white-space:pre-wrap;'>";
	&printcmd("$apachectl","graceful");
	print "\n..Done</pre>";
	print "</td></tr>\n";
	print "</table>\n";
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "Remove DirectoryMatch") {
	my $file = "$apachepath/modsec2.whitelist.conf";
	my @ids = split(/\n|\r/,$FORM{ids});
	chomp @ids;
	open (my $FH, "<", $file);
	flock ($FH, LOCK_SH);
	my @data = <$FH>;
	close ($FH);
	chomp @data;
	my $start = 0;
	my $done = 0;
	my $directorymatch = quotemeta($FORM{directorymatch});
	open (my $OUT, ">", $file);
	flock ($OUT, LOCK_EX);
	print $OUT "<IfModule mod_security2.c>\n";
	foreach my $line (@data) {
		if ($line =~ /^\s*<IfModule mod_security2\.c>/) {next}
		if ($line =~ /^\s*<\/IfModule>/) {next}
		if ($line =~ /<\/DirectoryMatch>/ and $start) {next}
		if ($start) {next}
		if ($line =~ /<DirectoryMatch\s+\'$directorymatch\'>/) {
			$start = 1;
			next;
		}
		print $OUT "$line\n";
	}
	print $OUT "</IfModule>\n";
	close ($OUT);

	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th  style='text-align:left'>ModSecurity DirectoryMatch ($FORM{directorymatch}) whitelist removed";
	print "</th></tr></thead>";
	print "<tr><td>Restarting Apache:<br>";
	print "<pre style='white-space:pre-wrap;'>";
	&printcmd("$apachectl","graceful");
	print "\n..Done</pre>";
	print "</td></tr>\n";
	print "</table>\n";
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "Modify by DirectoryMatch") {
	if ($FORM{directorymatch} eq "" or $FORM{directorymatch} eq "New DirectoryMatch") {
		print "<table class='table table-bordered table-striped'>\n";
		print "<thead><tr><th colspan='2'>ModSecurity DirectoryMatch whitelist</th></tr></thead>";
		print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='Modify by DirectoryMatch'><input type='text' name='directorymatch' value='' size='50'></td><td width='100%'><p>Add a DirectoryMatch <a href='http://httpd.apache.org/docs/2.2/mod/core.html#directorymatch' target='_blank'>Apache directive</a> (do not use quotes). This should be a regular expression. Examples:<br>^/home/someuser/public_html/ignore/me/index\\.php<br>^/home/someuser/public_html/ignore/path/</br>/wp-admin/index\\.php</p><p><input type='submit' class='btn btn-default' value='Add DirectoryMatch'></td></form></tr>\n";
		print "</table>\n";
	} else {
		my %ids;
		my $off = 0;
		if (-e "$apachepath/modsec2.whitelist.conf") {
			open (my $FH, "<", "$apachepath/modsec2.whitelist.conf");
			flock ($FH, LOCK_SH);
			my @data = <$FH>;
			close ($FH);
			chomp @data;
			my $start = 0;
			my $directorymatch = quotemeta($FORM{directorymatch});
			foreach my $line (@data) {
				if ($line =~ /<DirectoryMatch\s+\'$directorymatch\'>/) {$start = 1}
				if ($start and $line =~ /SecRuleRemoveById\s+(\d*)/) {$ids{$1} = 1}
				if ($start and $line =~ /SecRuleEngine\s+Off/) {$off = 1}
				if ($line =~ /<\/DirectoryMatch>/) {$start = 0}
			}
		}

		if ($off) {
			print "<table class='table table-bordered table-striped'>\n";
			print "<thead><tr><th colspan='2'>ModSecurity whitelist for DirectoryMatch: $FORM{directorymatch}</th></tr></thead>";
			print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='dironoff'><input type='hidden' name='directorymatch' value='$FORM{directorymatch}'><input type='radio' name='choose' checked value='0'>Off <input type='radio' name='choose' value='1'>On</td><td width='100%'><p>You can completely disable ModSecurity for this DirectoryMatch by setting this to Off and clicking the <i>Select</i> button:</p><p><input type='submit' class='btn btn-default' value='Select'></td></form></tr>\n";
			print "</table>\n";
		} else {
			print "<table class='table table-bordered table-striped'>\n";
			print "<thead><tr><th colspan='2'>ModSecurity whitelist for DirectoryMatch: $FORM{directorymatch}</th></tr></thead>";
			print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='dironoff'><input type='hidden' name='directorymatch' value='$FORM{directorymatch}'><input type='radio' name='choose' value='0'>Off <input type='radio' name='choose' value='1' checked>On</td><td width='100%'><p>You can completely disable ModSecurity for this DirectoryMatch by setting this to Off and clicking the <i>Select</i> button:</p><p><input type='submit' class='btn btn-default' value='Select'></td></form></tr>\n";
			print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='thisdirectorymatch'><input type='hidden' name='directorymatch' value='$FORM{directorymatch}'>ModSecurity rule ID list:<br /><textarea style='width:100%;' name='ids' rows='10' cols='10'>";
			foreach my $id (sort keys %ids) {print "$id\n"}
			print "</textarea></td><td width='100%'><p>You can add ModSecurity rule ID numbers that you want to be disabled for this DirectoryMatch.</p><p>You should place one ID number per line. When you have clicked the <i>Save Whitelist</i> button:</p><p>Then apache will be gracefully restarted.</p><p><input type='submit' class='btn btn-default' value='Save Whitelist'></td></form></tr>\n";
			print "<tr><form action='$script' method='post'><td colspan='2'><input type='submit' class='btn btn-default' value='Go back'></td></form></tr>\n";
			print "</table>\n";
		}
	}
	print "<p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Remove DirectoryMatch' name='action'><input type='hidden' name='directorymatch' value='$FORM{directorymatch}'></form></p>\n";
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "map") {
	print "<table class='table table-bordered table-striped'>\n";
	&showmap;
	print "</table>\n";
	print "<p class='bs-callout bs-callout-info'>Note: Only users or domain with a modsec.conf containing cmc exceptions will be listed here</p>\n";
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "help") {
	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th  style='text-align:left'>ConfigServer ModSecurity Help</th></tr></thead>";
	print "<tr><td>";
	print <<EOH;
<p>This utility allows you to:
<ul>
<li>Disable ModSecurity rules that have unique ID numbers on a global, per cPanel user or per hosted domain level.</li>
<li>Disable ModSecurity entirely, also on a global, per cPanel user or per hosted domain level.</li>
<li>Edit files containing ModSecurity configuration settings in $apachepath</li>
<li>View the latest ModSecurity log entries</li>
</ul>
</p>
<p>The requirements for this utility are:
<ul>
<li>Apache v2+</li>
<li>ModSecurity v2.5+ installed via Easyapache</li>
<li>A set of ModSecurity rules each of which uses a unique ID</li>
<li>ModSecurity logging that uses "SecAuditLogParts A...Z"</li>
</ul>
</p>
<p>ModSecurity logs will be detected in the following order, the last found being the one that will be used. If the wrong logs are being shown the other logs should be removed:
<ul>
<li>$apachelogs/audit_log</li>
<li>$apachelogs/modsec_audit.log</li>
<li>$apachelogs/modsec_audit/ (used under mod_ruid2 and mpm_itk)</li>
</ul>
</p>
<p>This utility uses concepts explained in <u><a href="https://documentation.cpanel.net/display/EA4/Modify+Apache+Virtual+Hosts+with+Include+Files" target="_blank">this</a></u> section of the cPanel documentation.<p>
EOH
	print "</td></tr>\n";
	print "</table>\n";
}
else {
	my @modsecfiles;
	my @modsecdirfiles;

	my %ids;
	my @alt;
	my $off = 0;
	if (-e "$apachepath/modsec2.whitelist.conf") {
		open (my $FH, "<", "$apachepath/modsec2.whitelist.conf");
		flock ($FH, LOCK_SH);
		my @data = <$FH>;
		close ($FH);
		chomp @data;
		my $start = 0;
		foreach my $line (@data) {
			if ($line =~ /<DirectoryMatch\s+'(.*)'>/) {push @alt,$1; $start = 1}
			if (!$start and $line =~ /SecRuleRemoveById\s+(\d*)/) {$ids{$1} = 1}
			if (!$start and $line =~ /SecRuleEngine\s+Off/) {$off = 1}
			if ($line =~ /^\s*(<\/DirectoryMatch>)/) {$start = 0}
		}
	} else {
		open (my $FH,">","$apachepath/modsec2.whitelist.conf");
		flock ($FH, LOCK_SH);
		print $FH "\# ConfigServer ModSecurity whitelist file\n";
		close ($FH);
	}

	sysopen (my $FH, "$modsecpath/modsec2.user.conf", O_RDWR | O_CREAT);
	flock ($FH, LOCK_EX);
	my @data = <$FH>;
	chomp @data;
	if ($is_ea4) {
		if (grep {$_ =~ /^\s*Include\s+$apachepath\/modsec2\.whitelist\.conf/} @data) {
			seek ($FH, 0, 0);
			truncate ($FH, 0);
			foreach my $line (@data) {
				if ($line =~ /^\s*Include\s+$apachepath\/modsec2\.whitelist\.conf/) {next}
				if ($line =~ /^\# ConfigServer ModSecurity whitelist file/) {next}
				print $FH "$line\n";
			}
			print "<p>Removing modsec2.whitelist.conf in modsec2.user.conf (not needed in EA4) and gracefully restarting Apache...";
			&printcmd("$apachectl","graceful");
			print "Done</p>\n";
		}
	} else {
		unless ($data[-1] =~ /^\s*Include\s+$apachepath\/modsec2\.whitelist\.conf/) {
			seek ($FH, 0, 0);
			truncate ($FH, 0);
			foreach my $line (@data) {
				if ($line =~ /^\s*Include\s+$apachepath\/modsec2\.whitelist\.conf/) {next}
				if ($line =~ /^\# ConfigServer ModSecurity whitelist file/) {next}
				print $FH "$line\n";
			}
			print $FH "Include $apachepath/modsec2.whitelist.conf\n";
			print "<p>Adding/Relocating modsec2.whitelist.conf in modsec2.user.conf and gracefully restarting Apache...";
			&printcmd("$apachectl","graceful");
			print "Done</p>\n";
		}
	}
	close ($FH);

	opendir (DIR, "$apachepath/");
	while (my $file = readdir (DIR)) {
		if ($file =~ /^(mod_sec|modsec).*\.conf$/i) {
			push @modsecfiles, $file;
		}
		if (-d "$apachepath/$file" and ($file =~ /^(mod_sec|modsec)/i)) {
			opendir (MODDIR, "$apachepath/$file");
			while (my $modfile = readdir (MODDIR)) {
				if ($modfile =~ /^\.|\.\.$/) {next}
				push @modsecdirfiles, "$file/$modfile";
			}
			closedir (MODDIR);
		}
	}
	closedir (DIR);
	@modsecfiles = sort @modsecfiles;
	@modsecdirfiles = sort @modsecdirfiles;

	my @users;
	my %domains;
	opendir (DIR, "/var/cpanel/users") or die $!;
	while (my $user = readdir (DIR)) {
		if ($user =~ /^\./) {next}
		my (undef,undef,undef,undef,undef,undef,undef,$homedir,undef,undef) = getpwnam($user); 
		$homedir =~ /(.*)/;
		$homedir = $1;
		if ($homedir eq "") {next}
		if (not -d "$homedir") {next}
		open (my $IN, "<","/var/cpanel/users/$user");
		flock ($IN, LOCK_SH);
		my @userdata = <$IN>;
		close ($IN);
		chomp @userdata;
		my $domain;
		foreach my $line (@userdata) {
			if ($line =~ /^DNS=(.*)/) {
				$domains{$user} = $1;
				last;
			}
		}
		push (@users, $user);
	}
	closedir (DIR);
	@users = sort @users;

	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th colspan='2'>ConfigServer ModSecurity Control <a class='btn btn-info modalButton' data-toggle='modal' data-src='$script?action=help' data-height='500px' data-width='100%' data-target='#myModal' title='Help' target='_blank'>Help</a></th></tr></thead>\n";

	if ($off) {
		print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='gonoff'><input type='hidden' name='user' value='$FORM{user}'><input type='radio' name='choose' checked value='0'>Off <input type='radio' name='choose' value='1'>On</td><td width='100%'><p>You can completely disable ModSecurity on the server by setting this to Off and clicking the <i>Select</i> button:</p><p><input type='submit' class='btn btn-default' value='Select'></td></form></tr>\n";
	} else {
		print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='gonoff'><input type='hidden' name='user' value='$FORM{user}'><input type='radio' name='choose' value='0'>Off <input type='radio' name='choose' checked value='1'>On</td><td width='100%'><p>You can completely disable ModSecurity on the server by setting this to Off and clicking the <i>Select</i> button:</p><p><input type='submit' class='btn btn-default' value='Select'></td></form></tr>\n";
		print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='global'><input type='hidden' name='domain' value='$FORM{domain}'><input type='hidden' name='user' value='$FORM{user}'>ModSecurity rule ID list:<br /><textarea style='width:100%;' name='ids' rows='10' cols='10'>";
		foreach my $id (sort keys %ids) {print "$id\n"}
		print "</textarea></td><td width='100%'><p>You can add ModSecurity rule ID numbers that you want to be globally disabled.</p>\n";
		print "<p class='bs-callout bs-callout-info'>You should place one ID number per line. When you have clicked the <i>Save global whitelist</i> button: the relevant lines will be added to $apachepath/modsec2.whitelist.conf which has already been added to the top of $modsecpath/modsec2.user.conf. Then httpd.conf will be rebuilt and apache will be gracefully restarted.</p><p><input type='submit' class='btn btn-default' value='Save global whitelist'></td></form></tr>\n";
		print "<tr><form action='$script' method='post'><td><select name='user' size='10'>";
		foreach my $user (@users) {print "<option value='$user'>$user ($domains{$user})</option>\n"}
		print "</select></td><td width='100%'><p>Alternatively, you can disable rules on a per cPanel account or per domain basis by selecting a user and then clicking:</p><p><input type='submit' class='btn btn-default' name='action' value='Modify user whitelist'></td></form></tr>\n";
		print "<tr><form action='$script' method='post'><td><select name='directorymatch' size='10'>";
		print "<option>New DirectoryMatch</option>\n<option disabled>____________</option>\n";
		foreach my $directorymatch (@alt) {print "<option value='$directorymatch'>$directorymatch</option>\n"}
		print "</select></td><td width='100%'><p>You can disable rules by DirectoryMatch (e.g. ^/home/someuser/public_html/ignore/some/path/)</p><p><input type='submit' class='btn btn-default' name='action' value='Modify by DirectoryMatch'></td></form></tr>\n";
		print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='map'>Display cmc user/domain configuration map</td><td width='100%'><input type='submit' class='btn btn-default' value='Show Map'></td></form></tr>\n";
	}
	print "</table><br>\n";

	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th colspan='2'>ConfigServer ModSecurity Tools</th></tr></thead>";
	print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='ms_list'><input type='submit' class='btn btn-default' value='ModSecurity Log'></td><td width='100%'>View the last <input type='text' name='lines' value='20' size='3'> entries in the ModSecurity log file and <input type='checkbox' name='refresh' value='1'> auto-refresh the log view\n";
	print "<p class='bs-callout bs-callout-info'>Note: If your audit_log file is very large it may take some time to process it.</p></td></form></tr>\n";
	print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='ms_config'><select name='template' size='10'>\n";
	foreach my $file (@modsecfiles,@modsecdirfiles) {
		if (-f "$apachepath/$file") {print "<option>$file</option>\n"}
	}
	print "</select></td><td width='100%'><p>Edit files containing ModSecurity configuration settings in $apachepath/. After a file has been edited httpd.conf will be rebuilt and apache gracefully restarted.</p><p class='bs-callout bs-callout-info'>Note: Files or directories must be prefixed modsec* or mod_sec* to be detected.</p><p><input type='submit' class='btn btn-default' value='Edit'></td></form></tr>\n";
	print "</table><br>\n";

	print "<table class='table table-bordered table-striped'>\n";
	my ($status, $text) = &urlget("https://$downloadserver/cmc/cmcversion.txt");
	my $actv = $text;
	my $up = 0;

	print "<thead><tr><th colspan='2'>Upgrade</th></tr></thead>";
	if ($actv ne "") {
		if ($actv =~ /^[\d\.]*$/) {
			if ($actv > $myv) {
				print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='upgrade'><input type='submit' class='btn btn-default' value='Upgrade cmc'></td><td width='100%'><b>A new version of cmc (v$actv) is available. Upgrading will retain your settings<br><a href='https://$downloadserver/cmc/changelog.txt' target='_blank'>View ChangeLog</a></b></td></form></tr>\n";
			} else {
				print "<tr><td colspan='2'>You appear to be running the latest version of cmc. An Upgrade button will appear here if a new version becomes available</td></tr>\n";
			}
			$up = 1;
		}
	}
	unless ($up) {
		print "<tr><td colspan='2'>Failed to determine the latest version of cmc. An Upgrade button will appear here if new version is detected</td></tr>\n";
	}
	print "</table><br>\n";
	print  "<div class='modal fade' id='myModal' tabindex='-1' role='dialog' aria-labelledby='myModalLabel' aria-hidden='true' data-backdrop='false' style='background-color: rgba(0, 0, 0, 0.5)'>\n";
	print "<div class='modal-dialog modal-lg' $modalstyle>\n";
	print  "<div class='modal-content'>\n";
	print  "<div class='modal-body'>\n";
	print  "<iframe frameborder='0'></iframe>\n";
	print  "</div>\n";
	print  "<div class='modal-footer text-center'>\n";
	print  "<button type='button' id='ModalClose' class='btn btn-default' data-dismiss='modal'>Close</button>\n";
	print  "</div>\n";
	print  "</div><!-- /.modal-content -->\n";
	print  "</div><!-- /.modal-dialog -->\n";
	print  "</div><!-- /.modal -->\n";
	print  "<script>\n";
	print  "\$('a.modalButton').on('click', function(e) {\n";
	print  "var src = \$(this).attr('data-src');\n";
	print  "var height = \$(this).attr('data-height') || 500;\n";
	print  "var width = \$(this).attr('data-width') || 400;\n";
	print  "\$('#myModal iframe').attr({'src':src,\n";
	print  "'height': height,\n";
	print  "'width': width});\n";
	print  "});\n";
	print "\$('.modal').click(function(event){\n";
	print "  \$(event.target).modal('hide')\n";
	print "});\n";
	print  "</script>\n";
}

print "<pre style='white-space:pre-wrap;'>cmc: v$myv</pre>";
print "<p>&copy;2009-2019, <a href='http://www.configserver.com' target='_blank'>ConfigServer Services</a> (Jonathan Michaelson)</p>\n";
print <<EOF;
<script>
	\$("#loader").hide();
	\$("#docs-link").hide();
</script>
EOF
unless ($FORM{action} eq "help") {
	close $SCRIPTOUT;
	select STDOUT;
	Cpanel::Template::process_template(
		'whostmgr',
		{
			"template_file" => "${thisapp}.tmpl",
			"${thisapp}_output" => $templatehtml,
			"print"         => 1,
		}
	);
} else {
	print "</div>\n";
	print "</body>\n";
	print "</html>\n";
}

# end main
###############################################################################
# start showmap
sub showmap {
	if (-e "$apachepath/modsec2.whitelist.conf") {
		my %ids;
		open (my $FH, "<", "$apachepath/modsec2.whitelist.conf");
		flock ($FH, LOCK_SH);
		my @data = <$FH>;
		close ($FH);
		chomp @data;
		my $start = 0;
		foreach my $line (@data) {
			if ($line =~ /^\s*(<LocationMatch\s+\.\*>)|(# Start cmc block)/) {$start = 1}
			if ($start and $line =~ /SecRuleRemoveById\s+(\d*)/) {$ids{$1} = 1}
			if ($line =~ /^\s*(<\/LocationMatch>)|(# End cmc block)/) {$start = 0}
		}
		if (%ids) {
			print "<tr><td colspan='3'><b>Global Disabled ID:";
			foreach my $id (sort keys %ids) {print " $id"}
			print "</b></td></tr>\n";
		}
	}
	foreach my $userdir (glob "$stdpath/*") {
		if (-d $userdir) {
			my ($user, $filedir) = fileparse($userdir);
			unless (-f "/var/cpanel/users/$user") {next}
			my $off = 0;
			if (-f "$userdir/modsec.conf") {
				my $start = 0;
				my %ids;
				open (my $FH, "<", "$userdir/modsec.conf");
				flock ($FH, LOCK_SH);
				my @data = <$FH>;
				close ($FH);
				chomp @data;
				foreach my $line (@data) {
					if ($line =~ /^\s*(<LocationMatch\s+\.\*>)|(# Start cmc block)/) {$start = 1}
					if ($start and $line =~ /SecRuleRemoveById\s+(\d*)/) {$ids{$1} = 1}
					if ($start and $line =~ /SecRuleEngine\s+Off/) {$off = 1}
					if ($line =~ /^\s*(<\/LocationMatch>)|(# End cmc block)/) {$start = 0}
				}
				if ($off) {
					print "<tr><td>$user</td><td  style='text-align:left'><b>ModSecurity disabled</b><td width='100%'>&nbsp</td></tr>\n";
				}
				elsif (%ids) {
					print "<tr><td>$user</td><td  style='text-align:left'>ModSecurity enabled<td width='100%'>&nbsp</td></tr>\n";
					print "<tr><td>&nbsp;</td><td  style='text-align:left'><b>User Disabled ID:";
					foreach my $id (keys %ids) {print " $id"}
					print "</b><td width='100%'>&nbsp</td></tr>\n";
				}
			}
			unless ($off) {
				foreach my $domaindir (glob "$userdir/*") {
					if (-d $domaindir) {
						my ($domain, $filedir) = fileparse($domaindir);
						if (-f "$domaindir/modsec.conf") {
							my $start = 0;
							my $off = 0;
							my %ids;
							open (my $FH, "<", "$domaindir/modsec.conf");
							flock ($FH, LOCK_SH);
							my @data = <$FH>;
							close ($FH);
							chomp @data;
							foreach my $line (@data) {
								if ($line =~ /^\s*(<LocationMatch\s+\.\*>)|(# Start cmc block)/) {$start = 1}
								if ($start and $line =~ /SecRuleRemoveById\s+(\d*)/) {$ids{$1} = 1}
								if ($start and $line =~ /SecRuleEngine\s+Off/) {$off = 1}
								if ($line =~ /^\s*(<\/LocationMatch>)|(# End cmc block)/) {$start = 0}
							}
							if ($off) {
								print "<tr><td>&nbsp;</td><td>$domain</td><td width='100%'  style='text-align:left'><b>ModSecurity disabled</b></td></tr>\n";
							}
							elsif (%ids) {
								print "<tr><td>&nbsp;</td><td>$domain</td><td width='100%'  style='text-align:left'><b>Domain Disabled ID:";
								foreach my $id (sort keys %ids) {print " $id"}
								print "</b></td></tr>\n";
							}
						}
					}
				}
			}
		}
	}
	return;
}
# end showmap
###############################################################################
sub wanted {
	if (-f $File::Find::name) {push @files,$File::Find::name}
	return;
}
###############################################################################
sub modsec {
	my $start = 0;
	my $entry;
	my @requests;
	my $log = "$apachelogs/modsec_audit.log";
	my $ruid2_itk = 0;

	my ($childin, $childout);
	my $mypid = open3($childin, $childout, $childout, $apachebin,"-M");
	my @modules = <$childout>;
	waitpid ($mypid, 0);
	chomp @modules;
	if (my @ls = grep {$_ =~ /ruid2_module|mpm_itk_module/} @modules) {
		$ruid2_itk = 1;
		$log = "$apachelogs/modsec_audit/*";
	}

	if ($ruid2_itk) {
		print "<h3>Displaying logs from <code>$apachelogs/modsec_audit/</code></h3>\n";
		find(\&wanted, "$apachelogs/modsec_audit");
		@files = sort { -M $a <=> -M $b } @files;
		@files = reverse @files;
		foreach my $log (@files) {
			sysopen (my $IN, $log, O_RDWR | O_CREAT);
			flock ($IN, LOCK_SH);
			while (my $line = <$IN>) {
				chomp $line;
				if ($line =~ /^\=\=(\w*)\=*$/) {
					$start = $1;
					$entry = "";
				}
				elsif ($line =~ /^\-\-(\w*)\-A\-\-$/) {
					$start = $1;
					$entry = "";
				}
				elsif ($line =~ /^\-\-$start\-\-$/ and $start) {
					push @requests, $entry;
					$start = 0;
					$entry = "";
				}
				elsif ($line =~ /^\-\-$start-Z\-\-$/ and $start) {
					push @requests, $entry;
					$start = 0;
					$entry = "";
				}
				elsif ($start) {
					$entry .= "$line\n";
				}
			}
			close ($IN);
		}
	} else {
		print "<h3>Displaying logs from <code>$log</code></h3>\n";
		sysopen (my $IN, $log, O_RDWR | O_CREAT);
		flock ($IN, LOCK_SH);
		while (my $line = <$IN>) {
			chomp $line;
			if ($line =~ /^\=\=(\w*)\=*$/) {
				$start = $1;
				$entry = "";
			}
			elsif ($line =~ /^\-\-(\w*)\-A\-\-$/) {
				$start = $1;
				$entry = "";
			}
			elsif ($line =~ /^\-\-$start\-\-$/ and $start) {
				push @requests, $entry;
				$start = 0;
				$entry = "";
			}
			elsif ($line =~ /^\-\-$start-Z\-\-$/ and $start) {
				push @requests, $entry;
				$start = 0;
				$entry = "";
			}
			elsif ($start) {
				$entry .= "$line\n";
			}
		}
		close ($IN);
	}
	if ($FORM{refresh}) {
print <<EOF;
<script language="JavaScript">

//Refresh page script- By Brett Taylor (glutnix\@yahoo.com.au)
//Modified by Dynamic Drive for NS4, NS6+
//Visit http://www.dynamicdrive.com for this script

//configure refresh interval (in seconds)
var countDownInterval=10;
//configure width of displayed text, in px (applicable only in NS4)
var c_reloadwidth=200
var page_url = "$script?action=ms_list&lines=$FORM{lines}&refresh=$FORM{refresh}";
</script>


<ilayer id="c_reload" width=&{c_reloadwidth}; ><layer id="c_reload2" width=&{c_reloadwidth}; left=0 top=0></layer></ilayer>

<script>

var countDownTime=countDownInterval+1;
function countDown(){
countDownTime--;
if (countDownTime <0){
countDownTime=countDownInterval;
clearTimeout(counter);
window.location.href=page_url;
return
}
if (document.all) //if IE 4+
document.all.countDownText.innerText = countDownTime+" ";
else if (document.getElementById) //else if NS6+
document.getElementById("countDownText").innerHTML=countDownTime+" "
else if (document.layers){ //CHANGE TEXT BELOW TO YOUR OWN
document.c_reload.document.c_reload2.document.write('<p>This page will <b><u><a href="javascript:window.location.href=page_url">refresh</a></u></b> in <b id="countDownText">'+countDownTime+' </b> seconds</p>')
document.c_reload.document.c_reload2.document.close ()
}
counter=setTimeout("countDown()", 1000);
}

function startit(){
if (document.all||document.getElementById) //CHANGE TEXT BELOW TO YOUR OWN
document.write('<p>This page will <b><u><a href="javascript:window.location.href=page_url">refresh</a></u></b> in <b id="countDownText">'+countDownTime+' </b> seconds</p>')
countDown()
}

if (document.all||document.getElementById)
startit()
else
window.onload=startit

</script>
EOF
	}

	if (@requests > 0) {
		my $start = 0;
		if ($FORM{lines} < @requests) {$start = @requests - $FORM{lines}}
		my $divcnt = 0;
		my $expcnt = @requests - $start;

		print "<style>.submenu {display:none;}</style>\n";
		print "<table class='table table-bordered table-striped'>\n";
		print "<thead><tr><th colspan='4'>ConfigServer ModSecurity Log Entries\n";
		print "<button type='button' class='btn btn-primary glyphicon glyphicon-resize-vertical pull-right' onClick='\$(\".submenu\").toggle();'></button>\n";
		print "</th></tr></thead>\n";
		print "<tr><td>Domain</td><td>Source IP</td><td>Rule ID</td><td width='100%'>Date Stamp</td></tr>\n";
		for (my $x = @requests -1; $x > $start - 1; $x--) {
			$divcnt++;
			$requests[$x] =~ s/\&/\&amp\;/g;
			$requests[$x] =~ s/>/\&gt\;/g;
			$requests[$x] =~ s/</\&lt\;/g;
			my @lines = split(/\n/,$requests[$x]);
			my @data = split(/\s/,$lines[0],8);
			my $span = "<button type='button' class='btn btn-primary glyphicon glyphicon-resize-vertical pull-right' onClick='\$(\"#s$divcnt\").toggle();'></button>";

			my $host;
			my $id;
			if (my @ls = grep {$_ =~ /^Host: /} @lines) {
				if ($ls[0] =~ /^Host: (.*)$/) {$host = $1}
			}
			if ($host eq "") {$host = $data[5]}

			if (my @ls = grep {$_ =~ /\s\[id \"\d+\"\]\s/} @lines) {
				if ($ls[0] =~ /\s\[id \"(\d+)\"\]\s/) {$id = $1}
			}
			if ($id eq "") {$id = "unknown"}

			print "<tr><td><b>$host</b></td><td>$data[3]</td><td><b>$id</b></td><td>$data[0] $data[1] $span</td></tr>\n";

			my $entry = "<div class='submenu' id='s$divcnt'><p>\n";
			my $modsec = "";
			for (my $y = 0;$y < @lines;$y++) {
				if ($lines[$y] =~ /^mod_security-message: (.*)$/) {$modsec = $1}
				if ($lines[$y] =~ /^Message: (.*)$/) {$modsec = $1}
				$lines[$y] =~ s/^([\w\-\_]*):/<b>$1:<\/b>/;
				$entry .= &splitlines($lines[$y])."<br>\n";
				if ($y > 200) {
					$entry .= "... [truncated to 200 lines see audit_log for full entry] ...<br>\n";
					last;
				}
			}
			$entry .= "</p></div>\n";
			if ($modsec =~ /\w*\.\s(.*)$/) {$modsec = $1}
			$modsec = &splitlines($modsec);
			print "<tr><td colspan='4'>$modsec$entry</td></tr>\n";
		}
		print "</table>\n";
	} else {
		print "<p>No entries found in $log</p>\n";
	}
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
	return;
}
###############################################################################
# start printcmd
sub printcmd {
	my @command = @_;
	my ($childin, $childout);
	my $pid = open3($childin, $childout, $childout, @command);
	while (<$childout>) {print $_}
	waitpid ($pid, 0);
	return;
}
# end printcmd
###############################################################################
# start onoff
sub onoff {
	my $file = shift;

	open (my $FH, "<", $file);
	flock ($FH, LOCK_SH);
	my @data = <$FH>;
	close ($FH);
	chomp @data;

	my $start = 0;
	my $dmstart = 0;
	open (my $OUT, ">", $file);
	flock ($OUT, LOCK_EX);
	print $OUT "# Do not modify this file directly as it will be overwritten by cmc\n";
	print $OUT "<IfModule mod_security2.c>\n";

	unless ($FORM{choose}) {print $OUT "SecRuleEngine Off\n"}
	
	foreach my $line (@data) {
		if ($line =~ /^\#/) {next}
		if ($line =~ /^\s*<IfModule/) {$start = 1; next}
		if ($line =~ /^\s*<\/IfModule/) {$start = 0; last}
		if ($line =~ /^\s*<DirectoryMatch/) {$dmstart = 1}
		if ($line =~ /^\s*<\/DirectoryMatch/) {$dmstart = 0}
		if (!$dmstart and $line =~ /^\s*SecRuleEngine/) {next}
		if ($start) {print $OUT $line."\n";}
	}
	print $OUT "</IfModule>\n";

	close ($OUT);

	return;
}
# end onoff
###############################################################################
# start ids
sub ids {
	my $file = shift;
	my @ids = split(/\n|\r/,$FORM{ids});
	chomp @ids;

	open (my $FH, "<", $file);
	flock ($FH, LOCK_SH);
	my @data = <$FH>;
	close ($FH);
	chomp @data;

	my $start = 0;
	open (my $OUT, ">", $file);
	flock ($OUT, LOCK_EX);
	print $OUT "# Do not modify this file directly as it will be overwritten by cmc\n";
	print $OUT "<IfModule mod_security2.c>\n";
	
	foreach my $line (@data) {
		if ($line =~ /^\s*<DirectoryMatch/) {$start = 1}
		if ($start) {print $OUT $line."\n";}
		if ($line =~ /^\s*<\/DirectoryMatch/) {$start = 0}
	}
	
	foreach my $id (@ids) {
		if ($id =~ /^\d+$/) {print $OUT "SecRuleRemoveById $id\n"}
	}
	
	print $OUT "<LocationMatch .*>\n";
	foreach my $id (@ids) {
		if ($id =~ /^\d+$/) {print $OUT "\tSecRuleRemoveById $id\n"}
	}
	print $OUT "</LocationMatch>\n";
	
	print $OUT "</IfModule>\n";
	close ($OUT);

	return;
}
# end ids
###############################################################################
# start splitlines
sub splitlines {
	my $line = shift;
	my $cnt = 0;
	my $newline;
	for (my $x = 0;$x < length($line) ;$x++) {
		if ($cnt > 120) {
			$cnt = 0;
			$newline .= "<WBR>";
		}
		my $letter = substr($line,$x,1);
		if ($letter =~ /\s/) {
			$cnt = 0;
		} else {
			$cnt++;
		}
		$newline .= $letter;
	}

	return $newline;
}
# end splitlines
###############################################################################

###############################################################################
# start urlget (v1.3)
#
# Examples:
#my ($status, $text) = &urlget("http://prdownloads.sourceforge.net/clamav/clamav-0.92.tar.gz","/tmp/clam.tgz");
#if ($status) {print "Oops: $text\n"}
#
#my ($status, $text) = &urlget("http://www.configserver.com/free/msfeversion.txt");
#if ($status) {print "Oops: $text\n"} else {print "Version: $text\n"}
#
sub urlget {
	my $url = shift;
	my $file = shift;
	my $status = 0;
	my $timeout = 1200;
	local $SIG{PIPE} = 'IGNORE';

	use LWP::UserAgent;
	my $ua = LWP::UserAgent->new;
	$ua->timeout(30);
	my $req = HTTP::Request->new(GET => $url);
	my $res;
	my $text;

	($status, $text) = eval {
		local $SIG{__DIE__} = undef;
		local $SIG{'ALRM'} = sub {die "Download timeout after $timeout seconds"};
		alarm($timeout);
		if ($file) {
			local $|=1;
			my $expected_length;
			my $bytes_received = 0;
			my $per = 0;
			my $oldper = 0;
			open (my $OUT, ">", "$file\.tmp") or return (1, "Unable to open $file\.tmp: $!");
			flock ($OUT, LOCK_EX);
			binmode ($OUT);
			print "...0\%\n";
			$res = $ua->request($req,
				sub {
				my($chunk, $res) = @_;
				$bytes_received += length($chunk);
				unless (defined $expected_length) {$expected_length = $res->content_length || 0}
				if ($expected_length) {
					my $per = int(100 * $bytes_received / $expected_length);
					if ((int($per / 5) == $per / 5) and ($per != $oldper)) {
						print "...$per\%\n";
						$oldper = $per;
					}
				} else {
					print ".";
				}
				print $OUT $chunk;
			});
			close ($OUT);
			print "\n";
		} else {
			$res = $ua->request($req);
		}
		alarm(0);
		if ($res->is_success) {
			if ($file) {
				rename ("$file\.tmp","$file") or return (1, "Unable to rename $file\.tmp to $file: $!");
				return (0, $file);
			} else {
				return (0, $res->content);
			}
		} else {
			return (1, "Unable to download: ".$res->message);
		}
	};
	alarm(0);
	if ($@) {
		return (1, $@);
	}
	if ($text) {
		return ($status,$text);
	} else {
		return (1, "Download timeout after $timeout seconds");
	}
}
# end urlget
###############################################################################
## start getdownloadserver
sub getdownloadserver {
	my @servers;
	my $downloadservers = "/usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmc/downloadservers";
	my $chosen;
	if (-e $downloadservers) {
		open (my $DOWNLOAD, "<", $downloadservers);
		flock ($DOWNLOAD, LOCK_SH);
		my @data = <$DOWNLOAD>;
		close ($DOWNLOAD);
		chomp @data;
		foreach my $line (@data) {
			if ($line =~ /^download/) {push @servers, $line}
		}
##		foreach my $line (slurp($downloadservers)) {
##			$line =~ s/$cleanreg//g;
##			if ($line =~ /^download/) {push @servers, $line}
##		}
		$chosen = $servers[rand @servers];
	}
	if ($chosen eq "") {$chosen = "download.configserver.com"}
	return $chosen;
}
## end getdownloadserver
###############################################################################

1;
