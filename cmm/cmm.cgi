#!/usr/local/cpanel/3rdparty/bin/perl
#WHMADDON:addonupdates:ConfigServer Mail Manage
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

use Sys::Hostname qw(hostname);
use IPC::Open3;
use File::Basename;
use Fcntl qw(:DEFAULT :flock);

use lib '/usr/local/cpanel';
require Cpanel::Form;
require Cpanel::Config;
require Whostmgr::ACLS;
require Cpanel::Rlimit;
require Cpanel::Template;
require Cpanel::Version::Tiny;
###############################################################################
# start main

our ($class, $day, $hrs, $images, $min, $month, $myv, $script, $subdir, $used,
    $user, $versionfile, $x, $year, @localdomains, %FORM, $downloadserver);

%FORM = Cpanel::Form::parseform();

Whostmgr::ACLS::init_acls();
if (!Whostmgr::ACLS::hasroot()) {
	print "Content-type: text/html\r\n\r\n";
    print "You do not have access to this option.\n";
	exit();
}

Cpanel::Rlimit::set_rlimit_to_infinity();

$script = "cmm.cgi";
$images = "cmm";
$versionfile = "/usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmm/cmmversion.txt";

open (my $IN, "<", $versionfile) or die $!;
flock ($IN, LOCK_SH);
$myv = <$IN>;
close ($IN);
chomp $myv;

$downloadserver = &getdownloadserver;

my $thisapp = "cmm";
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
if ($Cpanel::Version::Tiny::major_version < 65) {
	$modalstyle = "style='top:120px'";
}

my $bootstrapcss = "<link rel='stylesheet' href='$images/bootstrap/css/bootstrap.min.css'>";
my $jqueryjs = "<script src='$images/jquery.min.js'></script>";
my $bootstrapjs = "<script src='$images/bootstrap/js/bootstrap.min.js'></script>";

my $templatehtml;
unless ($FORM{action} eq "viewmail") {
	open SCRIPTOUT, '>', \$templatehtml;
	select SCRIPTOUT;

	print <<EOF;
	$bootstrapcss
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
<h4><img src='$images/cmm.png' style='padding-left: 10px'> ConfigServer Mail Manage - cmm v$myv</h4></div>
EOF
if ($reregister ne "") {print $reregister}

$| = 1; ## no critic

my $mailscanner = 0;
if (-e "/usr/mscpanel/version.txt") {$mailscanner = 1}

if ($FORM{domain} ne "" and $FORM{domain} =~ /[^\w\-\.]/) {
	print "Invalid domain name [$FORM{domain}]";
}
elsif ($FORM{account} ne "" and $FORM{account} =~ /[^a-zA-Z0-9\-\_\.\@\+]/) {
	print "Invalid account name [$FORM{account}]";
}
elsif ($FORM{action} eq "Manage Mail Forwarders") {
	my %userdomains;
	open (my $IN, "<","/etc/userdomains");
	flock ($IN, LOCK_SH);
	my @localusers = <$IN>;
	close ($IN);
	chomp @localusers;
	foreach my $line (@localusers) {
		my ($domain,$user) = split(/\:\s*/,$line,2);
		$userdomains{$domain} = $user;
	}
	print "<p><form action='$script' method='post'><input type='hidden' name='domain' value='$FORM{domain}'><input type='submit' class='btn btn-default' name='action' value='Manage Mail Accounts'>&nbsp;&nbsp;<input type='submit' class='btn btn-default' name='action' value='Manage Mail Filters'>&nbsp;&nbsp;<input type='submit' class='btn btn-default' name='action' value='Manage Mail Hourly Limits'></form></p>\n";
	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th colspan='2'>Mail Forwarders for $FORM{domain}</th></tr></thead>";
	print "<thead><tr><th>Forwarder</th><th>Recipient</th></tr></thead>";

	my $total = 0;
	open (my $VALIASES, "<", "/etc/valiases/$FORM{domain}");
	flock ($VALIASES, LOCK_SH);
	my @forwarders = <$VALIASES>;
	close ($VALIASES);
	chomp @forwarders;
	foreach my $aliases (@forwarders) {
		my ($alias,$recipient) = split(/: /,$aliases,2);
		if ($alias eq "*") {$alias .= " (Default Address)"}
		print "<tr><td>$alias</td><td>$recipient</td></tr>\n";
		$total++;
	}
	unless ($total) {print "<tr><td colspan='2'>No entries found</td></tr>\n"}
	print "<tr><td colspan='2'>";
	my ($childin, $childout);
	my $cmdpid = open3($childin, $childout, $childout, "/usr/bin/quota", "-qlu", $userdomains{$FORM{domain}});
	my @data = <$childout>;
	waitpid ($cmdpid, 0);
	chomp @data;
	if ($data[0] =~ /Block limit reached/) {
		print "<p>cPanel account over quota - editing disabled</p>";
	} else {
		print "<br><form action='$script' method='post'><input type='hidden' name='domain' value='$FORM{domain}'><input type='submit' class='btn btn-default' name='action' value='Edit Mail Forwarders'></form>";
	}
	print "</td></tr>\n";
	print "</table>\n";
	print "<p>Total Accounts: $total</p>\n";
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "Edit Mail Forwarders") {
	open (my $IN,"<","/etc/valiases/$FORM{domain}");
	flock ($IN, LOCK_SH);
	my @confdata = <$IN>;
	close ($IN);
	chomp @confdata;
	my $max = 80;
	foreach my $line (@confdata) {if (length($line) > $max) {$max = length($line) + 1}}

	print "<form action='$script' method='post'><input type='hidden' name='domain' value='$FORM{domain}'>\n";
	print "<input type='hidden' name='action' value='saveforwarders'>\n";
	print "<b>Edit /etc/valiases/$FORM{domain}</b>\n";
	print "<table class='table table-bordered table-striped'>\n";
	print "<tr><td><textarea style='width:100%;' name='formdata' cols='80' rows='24'>\n";
	foreach my $line (@confdata) {
		print $line."\n";;
	}
	print "</textarea></td></tr></table>\n";
	print "<p class='text-center'><input type='submit' class='btn btn-default' value='Change'></p>\n";
	print "</form>\n";
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "saveforwarders") {
	$FORM{formdata} =~ s/\r//g;
	sysopen(my $OUT,"/etc/valiases/$FORM{domain}", O_WRONLY | O_CREAT | O_TRUNC);
	flock ($OUT, LOCK_EX);
	print $OUT $FORM{formdata};
	close ($OUT);

	my %userdomains;
	open (my $IN, "<","/etc/userdomains");
	flock ($IN, LOCK_SH);
	my @localusers = <$IN>;
	close ($IN);
	chomp @localusers;
	foreach my $line (@localusers) {
		my ($domain,$user) = split(/\: /,$line,2);
		$userdomains{$domain} = $user;
	}
	chown ((getpwnam($userdomains{$FORM{domain}}))[2],(getgrnam("mail"))[2],"/etc/valiases/$FORM{domain}");

	print "<p>Changes saved.</p>\n";
	print "<p><form action='$script' method='post'><input type='hidden' name='domain' value='$FORM{domain}'><input type='hidden' name='action' value='Manage Mail Forwarders'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "Manage Mail Filters") {
	my %userdomains;
	open (my $IN,"<","/etc/userdomains");
	flock ($IN, LOCK_SH);
	my @localusers = <$IN>;
	close ($IN);
	chomp @localusers;
	foreach my $line (@localusers) {
		my ($domain,$user) = split(/\: /,$line,2);
		$userdomains{$domain} = $user;
	}
	print "<p><form action='$script' method='post'><input type='hidden' name='domain' value='$FORM{domain}'><input type='submit' class='btn btn-default' name='action' value='Manage Mail Forwarders'>&nbsp;&nbsp;<input type='submit' class='btn btn-default' name='action' value='Manage Mail Accounts'>&nbsp;&nbsp;<input type='submit' class='btn btn-default' name='action' value='Manage Mail Hourly Limits'></form></p>\n";
	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th>Mail Filters for $FORM{domain}</th></tr></thead>";
	my $class = "tdshade2_noborder";
	if (-z "/etc/vfilters/$FORM{domain}") {
		print "<tr><td>No entries found</td></tr>\n";
	} else {
		print "<tr><td><pre>\n";
		open (my $IN, "<", "/etc/vfilters/$FORM{domain}");
		flock ($IN, LOCK_SH);
		my @data = <$IN>;
		close ($IN);
		foreach my $line (@data) {
			$line =~ s/&/&amp;/g;
			$line =~ s/>/&gt;/g;
			$line =~ s/</&lt;/g;
			print $line;
		}
	}
	print "</pre></td></tr>\n";
	print "<thead><tr><th>\n";
	my ($childin, $childout);
	my $cmdpid = open3($childin, $childout, $childout, "/usr/bin/quota", "-qlu", $userdomains{$FORM{domain}});
	my @data = <$childout>;
	waitpid ($cmdpid, 0);
	chomp @data;
	if ($data[0] =~ /Block limit reached/) {
		print "<p>cPanel account over quota - editing disabled</p>";
	} else {
		print "<br><form action='$script' method='post'><input type='hidden' name='domain' value='$FORM{domain}'><input type='submit' class='btn btn-default' name='action' value='Edit Mail Filters'></form>\n";
	}
	print "</th></tr></thead>\n";
	print "</table>\n";
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "Edit Mail Filters") {
	open (my $IN, "<","/etc/vfilters/$FORM{domain}");
	flock ($IN, LOCK_SH);
	my @confdata = <$IN>;
	close ($IN);
	chomp @confdata;
	my $max = 80;
	foreach my $line (@confdata) {if (length($line) > $max) {$max = length($line) + 1}}

	print "<form action='$script' method='post'><input type='hidden' name='domain' value='$FORM{domain}'>\n";
	print "<input type='hidden' name='action' value='savefilters'>\n";
	print "<div class='panel panel-default'>\n";
	print "<div class='panel-heading panel-heading-cxs'>Edit <code>/etc/vfilters/$FORM{domain}</code></div>\n";
	print "<div class='panel-body'><table class='table table-bordered table-striped'>\n";
	print "<tr><td><textarea style='width:100%;' name='formdata' cols='80' rows='24'>\n";
	foreach my $line (@confdata) {
		print $line."\n";;
	}
	print "</textarea></td></tr></table>\n";
	print "</div><div class='panel-footer text-center'><input type='submit' class='btn btn-default' value='Change'></div></div>\n";
	print "</form>\n";
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "savefilters") {
	$FORM{formdata} =~ s/\r//g;
	open(my $OUT,">","/etc/vfilters/$FORM{domain}");
	print $OUT $FORM{formdata};
	close($OUT);

	my %userdomains;
	open(my $IN,"<","/etc/userdomains");
	my @localusers = <$IN>;
	close($IN);
	chomp @localusers;
	foreach my $line (@localusers) {
		my ($domain,$user) = split(/\: /,$line,2);
		$userdomains{$domain} = $user;
	}
	chown ((getpwnam($userdomains{$FORM{domain}}))[2],(getgrnam("mail"))[2],"/etc/vfilters/$FORM{domain}");

	print "<p>Changes saved.</p>\n";
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "Manage Mail Hourly Limits") {
	if ($FORM{domain} ne "") {
		my $cpconf = Cpanel::Config::loadcpconf();
		my $maxemails = $cpconf->{maxemailsperhour};
		my $account;
		my %userdomains;
		my $usermaxemails;
		my $domainmaxemails;
		open(my $IN,"<","/etc/userdomains");
		my @localusers = <$IN>;
		close($IN);
		chomp @localusers;
		foreach my $line (@localusers) {
			my ($domain,$user) = split(/\: /,$line,2);
			$userdomains{$domain} = $user;
		}
		$account = $userdomains{$FORM{domain}};

		open(my $DOMAIN,"<","/var/cpanel/users/$userdomains{$FORM{domain}}");
		my @confdata = <$DOMAIN>;
		close($DOMAIN);
		chomp @confdata;

		foreach my $line (@confdata) {
			if ($line =~ /^MAX_EMAIL_PER_HOUR=(\d+)/) {$usermaxemails = $1}
			if ($line =~ /^MAX_EMAIL_PER_HOUR-$FORM{domain}=(\d+)/) {$domainmaxemails = $1}
		}
		if ($usermaxemails > 0) {$maxemails = $usermaxemails}
		if ($domainmaxemails > 0) {$maxemails = $domainmaxemails}
		if ($maxemails eq "") {$maxemails = 0}

		print "<p><form action='$script' method='post'><input type='hidden' name='domain' value='$FORM{domain}'><input type='submit' class='btn btn-default' name='action' value='Manage Mail Accounts'>&nbsp;&nbsp;<input type='submit' class='btn btn-default' name='action' value='Manage Mail Filters'>&nbsp;&nbsp;<input type='submit' class='btn btn-default' name='action' value='Manage Mail Accounts'></form></p>\n";
		print "<form action='$script' method='post'><input type='hidden' name='domain' value='$FORM{domain}'>\n";
		print "<input type='hidden' name='action' value='savelimits'>\n";
		print "<div class='panel panel-default'>\n";
		print "<div class='panel-heading panel-heading-cxs'>Edit Mail Hourly limits for $FORM{domain}</div>\n";
		print "<div class='panel-body'><table class='table table-bordered table-striped'>\n";
		print "<tr><td>$FORM{domain} can send a maximum of <input type='text' value='$maxemails' name='maxemails'> per hour [0 = unlimited]</td></tr>\n";
		print "</table>\n";
		print "</div><div class='panel-footer text-center'><input type='submit' class='btn btn-default' value='Change'></div></div>\n";
		print "</form>\n";
	} else {
		print "<div class='bs-callout bs-callout-danger'>You must select a domain first</div>\n";
	}
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "savelimits") {
	my %userdomains;
	open (my $IN,"<","/etc/userdomains");
	flock ($IN, LOCK_SH);
	my @localusers = <$IN>;
	close ($IN);
	chomp @localusers;
	foreach my $line (@localusers) {
		my ($domain,$user) = split(/\: /,$line,2);
		$userdomains{$domain} = $user;
	}

	open (my $USERS, "<","/var/cpanel/users/$userdomains{$FORM{domain}}");
	flock ($USERS, LOCK_SH);
	my @confdata = <$USERS>;
	close ($USERS);
	chomp @confdata;

	my @newconfdata;
	foreach my $line (@confdata) {
		if ($line =~ /^MAX_EMAIL_PER_HOUR-$FORM{domain}=(\d+)/) {next}
		push @newconfdata,$line;
	}
	push @newconfdata, "MAX_EMAIL_PER_HOUR-$FORM{domain}=$FORM{maxemails}";

	sysopen (my $OUT, "/var/cpanel/users/$userdomains{$FORM{domain}}", O_WRONLY | O_CREAT | O_TRUNC);
	flock ($OUT, LOCK_EX);
	foreach my $line (@newconfdata) {print $OUT "$line\n"}
	close ($OUT);

	my $cmd = "/scripts/updateuserdomains";
	my ($childin, $childout);
	my $cmdpid = open3($childin, $childout, $childout, $cmd);
	my @data = <$childout>;
	waitpid ($cmdpid, 0);
	chomp @data;
	print "<p>$cmd</p>\n";
	foreach my $line (@data) {
		print "$line<br />\n";
	}
	print "<p>Changes saved.</p>\n";
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "viewmail") {
	if (-f $FORM{file}) {
		my %userdomains;
		open (my $IN,"<","/etc/userdomains");
		flock ($IN, LOCK_SH);
		my @localusers = <$IN>;
		close ($IN);
		chomp @localusers;
		foreach my $line (@localusers) {
			my ($domain,$user) = split(/\: /,$line,2);
			$userdomains{$domain} = $user;
		}
		my ($file, $filedir) = fileparse($FORM{file});
		my $homedir = ( getpwnam($userdomains{$FORM{domain}}) )[7];
		if ($homedir eq "" or $filedir !~ /^$homedir/) {
			print "Invalid file [$FORM{file}]";
		} else {
			print "<table class='table table-bordered table-striped'>\n";
			print "<thead><tr><th>View Email</th></tr></thead>";
			print "<tr><td><pre style='white-space:pre-wrap;'>\n";
			my @mail;
			open (my $IN, "<", $FORM{file});
			unless ($FORM{f}) {
				my $x;
				for ($x = 0; $x < 500;$x++) {
					my $line  = <$IN>;
					$line =~ s/&/&amp;/g;
					$line =~ s/>/&gt;/g;
					$line =~ s/</&lt;/g;
					print $line;
				}
				unless (eof ($IN)) {
					my $size = int((stat("$FORM{file}"))[7] / 1024);
					print "</pre>\n";
					print "...[truncated to 500 lines] <b><a href=\"$script?action=viewmail&f=1&domain=$FORM{domain}&file=$FORM{file}\">View full ($size KB) email</a></b>\n";
				} else {
					print "</pre>";
				}
			} else {
				while (my $line = <$IN>) {
					$line =~ s/&/&amp;/g;
					$line =~ s/>/&gt;/g;
					$line =~ s/</&lt;/g;
					print $line;
				}
				print "</pre>";
			}
			close ($IN);
			print "</td></tr>\n";
			print "</table>\n";
		}
	} else {
		print "File [$FORM{file}] not found";
	}
}
elsif ($FORM{action} eq "empty") {
	print "<form action='$script' method='post'>\n";
	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th colspan='2'>Empty Mailbox $FORM{account}\@$FORM{domain}</th></tr></thead>";
	print "<tr><td><b>Are you sure that you want to irretrievably delete all email and associated files within this mailbox?</b></td></tr>\n";
	print "<tr><td><input type='submit' class='btn btn-default' name='action' value='Empty Mailbox'></td></tr>\n";
	print "</table>\n";
	print "<input type='hidden' name='account' value='$FORM{account}'><input type='hidden' name='domain' value='$FORM{domain}'><input type='hidden' name='top' value='$FORM{top}'></form>\n";
	print "<p><form action='$script' method='post'><input type='hidden' name='domain' value='$FORM{domain}'><input type='hidden' name='action' value='Manage Mail Accounts'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "Empty Mailbox") {
	my %userdomains;
	open (my $IN,"<","/etc/userdomains");
	flock ($IN, LOCK_SH);
	my @localusers = <$IN>;
	close ($IN);
	chomp @localusers;
	foreach my $line (@localusers) {
		my ($domain,$user) = split(/\: /,$line,2);
		$userdomains{$domain} = $user;
	}
	my $dir;
	my $title;
	if ($FORM{top}) {
		my $homedir = ( getpwnam($FORM{account}) )[7];
		$dir = "$homedir/mail";
		$title = "$FORM{account} (cPanel user)";
	} else {
		my $homedir = ( getpwnam($userdomains{$FORM{domain}}) )[7];
		$dir = "$homedir/mail/$FORM{domain}/$FORM{account}";
		$title = "$FORM{account}\@$FORM{domain}";
	}

	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th>$title</th></tr></thead>";
	print "<tr><td>\n";

	my @maildirs;
	push @maildirs, $dir;
	opendir (my $DIR, $dir);
	while (my $file = readdir($DIR)) {
		if ($file eq ".") {next}
		if ($file eq "..") {next}
		if (readlink "$dir/$file") {next}
		if ((-d "$dir/$file") and (-d "$dir/$file/cur") and (-d "$dir/$file/new") and (-d "$dir/$file/tmp")) {push @maildirs, "$dir/$file"}
	}
	closedir ($DIR);
	my $total = 0;
	foreach my $line (@maildirs) {
		foreach my $subdir ("/","/cur","/new","/tmp") {
			opendir (my $DIR, "$line$subdir");
			while (my $file = readdir($DIR)) {
				if ((-f "$line$subdir/$file") and ($file =~ /^\d+\./)) {
					print ". ";
					unlink ("$line$subdir/$file");
					$total++;
				}
			}
			closedir ($DIR);
		}
		if (-e "$line$subdir/maildirsize") {unlink "$line$subdir/maildirsize"}
	}
	print "<p>Total emails removed: $total</p></td></tr>\n";
	print "</table>\n";
	print "<p><form action='$script' method='post'><input type='hidden' name='domain' value='$FORM{domain}'><input type='hidden' name='action' value='Manage Mail Accounts'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "view") {
	my %userdomains;
	open (my $IN,"<","/etc/userdomains");
	flock ($IN, LOCK_SH);
	my @localusers = <$IN>;
	close ($IN);
	chomp @localusers;
	foreach my $line (@localusers) {
		my ($domain,$user) = split(/\: /,$line,2);
		$userdomains{$domain} = $user;
	}
	my $dir;
	my $title;
	if ($FORM{top}) {
		my $homedir = ( getpwnam($FORM{account}) )[7];
		$dir = "$homedir/mail";
		$title = "$FORM{account} (cPanel user)";
	} else {
		my $homedir = ( getpwnam($userdomains{$FORM{domain}}) )[7];
		$dir = "$homedir/mail/$FORM{domain}/$FORM{account}";
		$title = "$FORM{account}\@$FORM{domain}";
	}

	my $topdir = $FORM{topdir};
	if ($topdir eq "") {$topdir = "/"}
	print "<script>\n";
	print "function confirmSubmit() {\n";
	print "var agree=confirm('Are you sure you wish to empty the directory?');\n";
	print "if (agree)\n	return true ;\nelse\n	return false ;\n";
	print "}\n";
	print "</script>\n";

	print "<div style='min-height: 450px'>\n";
	if ($topdir eq "/") {
		print "<table class='table table-bordered table-striped'>\n";
		print "<thead><tr><th colspan='6'>$title</th></tr></thead>";
		print "<thead><tr><th>&nbsp;</th><th>Directory</th><th>Mail Count</th><th colspan='3'>Size</th></tr></thead>\n";
	} else {
		my $showdir = "$topdir";
		$showdir =~ s/\/+/\//g;
		print "<script>\n";
		print "function checkme() {\n";
		print "	for (var x = 0; x < document.listmail.elements.length; x++) {\n";
		print "		var check = document.listmail.elements[x];\n";
		print "	    if (document.listmail.elements[x].name != 'checkall') {\n";
		print "			check.checked = document.listmail.checkall.checked;\n";
		print "		}\n";
		print "	}\n";
		print "}\n";
		print "RegExp.escape = function(text) {\n";
		print "		if (!arguments.callee.sRE) {\n";
		print "			var specials = ['/', '.', '*', '+', '?', '|','(', ')', '[', ']', '{', '}', '\\\\'];\n";
		print "				arguments.callee.sRE = new RegExp('(\\\\' + specials.join('|\\\\') + ')', 'g');\n";
		print "			}\n";
		print "	 	return text.replace(arguments.callee.sRE, '\\\\\$1');\n";
		print "}\n";
		print "function selectSearch(){\n";
		print "		var reg = new RegExp(RegExp.escape(document.listmail.searchFor.value), 'i');\n";
		print "		for (var x = 0; x < document.listmail.elements.length; x++) {\n";
		print "			if (document.listmail.elements[x].type == 'checkbox' && document.listmail.elements[x].name != 'checkall') {\n";
		print "				var trPai = document.listmail.elements[x].parentNode.parentNode;\n";
		print "				var allTds = trPai.getElementsByTagName('TD');\n";
		print "				var theLink = allTds[2].getElementsByTagName('A');\n";
		print "				if( reg.test(theLink[0].innerHTML) ){\n";
		print "					document.listmail.elements[x].checked = true;\n";
		print "				}\n";
		print "			}\n";
		print "		}\n";
		print "}\n</script>\n";
		print "<form action='$script' method='post' name='listmail'><input type='hidden' name='domain' value='$FORM{domain}'><input type='hidden' name='account' value='$FORM{account}'><input type='hidden' name='action' value='bulkdelete'><input type='hidden' name='topdir' value='$topdir'><input type='hidden' name='top' value='$FORM{top}'>\n";
		print "<table class='table table-bordered table-striped'>\n";
		print "<thead><tr><th colspan='6'>$title</th></tr></thead>";
		print "<tr><td colspan='6'><code>$showdir</code> <a class='btn btn-primary glyphicon glyphicon-level-up' href=\"$script?action=view&domain=$FORM{domain}&account=$FORM{account}&top=$FORM{top}\" data-tooltip='tooltip' title='Go Up'></a> <a class='btn btn-warning glyphicon glyphicon-trash' href=\"$script?action=emptydir&domain=$FORM{domain}&account=$FORM{account}&file=$dir$showdir\" data-tooltip='tooltip' title='Empty Directory' target='_blank' onClick='return confirmSubmit()'></a>";
		if ($mailscanner) {print " <a class='btn btn-success glyphicon glyphicon-flag' href=\"$script?action=salearn&domain=$FORM{domain}&account=$FORM{account}&file=$dir$showdir\" data-tooltip='tooltip' title='Run SA Learn for spam' target='_blank'></a>"}
		print "</td></tr>\n";
		print "<thead><tr><th>\#</th><th>Del</th><th>Subject</th><th>Date</th><th>Size</th><th>&nbsp;</th></tr></thead>\n";
	}

	my @maildirs;
	push @maildirs, "/";
	opendir (my $DIR, $dir);
	while (my $file = readdir($DIR)) {
		if ($file eq ".") {next}
		if ($file eq "..") {next}
		if (readlink "$dir/$file") {next}
		if ((-d "$dir/$file") and (-d "$dir/$file/cur") and (-d "$dir/$file/new") and (-d "$dir/$file/tmp")) {push @maildirs, "/$file"}
	}
	closedir ($DIR);
	my $total = 0;
	my $class = "tdshade2_noborder";
	foreach my $line (@maildirs) {
		foreach my $subdir ("/cur","/new","/tmp") {
			opendir (my $DIR, "$dir$line$subdir");
			my @files = readdir($DIR);
			closedir ($DIR);

			my $dirtot = 0;
			my $dirsize = 0;
			foreach my $file (sort @files) {
				if ((-f "$dir$line$subdir/$file") and ($file =~ /^(\d+)\./)) {
					if ("$line$subdir" ne $topdir) {
						$dirtot++;
						$dirsize += (stat("$dir$line$subdir/$file"))[7];
						next;
					}

					my $date = $1;

					my @mail;
					open (my $IN, "<", "$dir$line$subdir/$file");
					flock ($IN, LOCK_SH);
					for (my $x = 0; $x < 200;$x++) {
						my $line  = <$IN>;
						if ($line eq "\n") {last;}
						push (@mail, $line);
					}
					close ($IN);
					chomp @mail;

					my @tmp = grep {$_ =~ /^subject:/i} @mail;
					my $subject;
					if ($tmp[0]) {$subject = $tmp[0]}
					if (length($subject) > 50) {$subject = substr($subject,0,47)."..."}
					$subject =~ s/subject://ig;
					$subject =~ s/>/&gt;/g;
					$subject =~ s/</&lt;/g;
					if ($subject =~ /^\s*$/) {$subject = "[no subject]"}

					($min, $hrs, $day, $month, $year) = (localtime($date)) [1,2,3,4,5];
					$date = sprintf("%04d-%02d-%02d %02d:%02d\n", $year+1900, $month+1, $day, $hrs, $min);

					my $size = int((stat("$dir$line$subdir/$file"))[7] / 1024);
					$total++;

					print "<tr id='tr$total'><td>$total</td>";
					print "<td><input type='checkbox' name='cmmdel_$total' value='$dir$line$subdir/$file'></td>";
					print "<td><a class='btn btn-default modalButton' data-toggle='modal' data-src='$script?action=viewmail&domain=$FORM{domain}&account=$FORM{account}&file=".&uri_escape($dir.$line.$subdir)."/$file' data-height='500px' data-width='100%' data-target='#myModal' href='#'>$subject</a></td><td>$date</td><td>$size KB</td>\n";
					print "<td><a class='btn btn-danger glyphicon glyphicon-remove modalButton' data-toggle='modal' data-src='$script?action=deletemail&domain=$FORM{domain}&account=$FORM{account}&file=".&uri_escape($dir.$line.$subdir)."/$file' data-height='500px' data-width='100%' data-target='#myModal' href='#' data-tooltip='tooltip' title='Delete Email' onclick='\$(\"#tr$total\").hide()'></a></td></tr>\n";
				}
			}
			if (($topdir eq "/") and ($dirtot > 0)) {
				my $showdir = "$line/$subdir";
				$showdir =~ s/\/+/\//g;
				my $emptydir = "<a class='btn btn-warning glyphicon glyphicon-trash' href=\"$script?action=emptydir&domain=$FORM{domain}&account=$FORM{account}&file=".uri_escape($dir.$showdir)."\" data-tooltip='tooltip' title='Empty Directory' target='_blank' onClick='return confirmSubmit()'></a>";
				if ($mailscanner) {$emptydir .= " <a class='btn btn-success glyphicon glyphicon-flag' href=\"$script?action=salearn&domain=$FORM{domain}&account=$FORM{account}&file=".uri_escape($dir.$showdir)."\" data-tooltip='tooltip' title='Run SA Learn for spam' target='_blank'></a>"}
				$used = $dirsize / (1024 * 1024);
				if ($used == 0) {$emptydir = "&nbsp;"}
				$used = sprintf("%.02f",$used);
				print "<tr><td>$emptydir</td><td><code>$showdir</code></td><td><a class='btn btn-default' href=\"$script?action=view&domain=$FORM{domain}&account=$FORM{account}&topdir=".&uri_escape($line.$subdir)."&top=$FORM{top}\">View <span class='label label-pill label-info'>$dirtot</span> emails</a></td><td colspan='3'>$used MB</td></tr>\n";
			}
		}
	}
	if ($topdir ne "/") {
		print "<tr><td>&nbsp;</td><td><input type='checkbox' name='checkall' OnClick='checkme()'><br>All</td><td colspan='4'><input type='hidden' name='total' value='$total'><input type='submit' class='btn btn-default' value='Delete Selected'></td></tr>\n";
		print "<tr><td>&nbsp;</td><td>&nbsp;</td><td colspan='4'><input type='text' name='searchFor' /> <input type='button' class='btn btn-default' value='Select by search' onclick='javascript:selectSearch();' /></td></tr>\n";
		print "</table>\n";
		print "</form>";
	} else {
		print "</table>\n";
	}
	print "</div>\n";
	print "<p><form action='$script' method='post'><input type='hidden' name='domain' value='$FORM{domain}'><input type='hidden' name='action' value='Manage Mail Accounts'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
	print  "<div class='modal fade' id='myModal' tabindex='-1' role='dialog'  aria-labelledby='myModalLabel' aria-hidden='true' data-backdrop='false' style='background-color: rgba(0, 0, 0, 0.5)'>\n";
	print  "<div class='modal-dialog modal-lg' $modalstyle>\n";
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
elsif ($FORM{action} eq "deletemail") {
	if (-f $FORM{file}) {
		my %userdomains;
		open (my $IN,"<","/etc/userdomains");
		flock ($IN, LOCK_SH);
		my @localusers = <$IN>;
		close ($IN);
		chomp @localusers;
		foreach my $line (@localusers) {
			my ($domain,$user) = split(/\: /,$line,2);
			$userdomains{$domain} = $user;
		}
		my ($file, $filedir) = fileparse($FORM{file});
		my $homedir = ( getpwnam($userdomains{$FORM{domain}}) )[7];
		if ($homedir eq "" or $filedir !~ /^$homedir/) {
			print "Invalid file [$FORM{file}]";
		} else {
			print "<table class='table table-bordered table-striped'>\n";
			print "<thead><tr><th>Delete Email</th></tr></thead>";
			unlink $FORM{file};
			my ($file, $filedir) = fileparse($FORM{file});
			if (-e "$filedir/../maildirsize") {unlink "$filedir/../maildirsize"}
			print "<tr><td>Email deleted</td></tr>\n";
			print "</table>\n";
		}
	} else {
		print "File [$FORM{file}] not found";
	}
}
elsif ($FORM{action} eq "emptydir") {
	if (-d $FORM{file}) {
		my %userdomains;
		open (my $IN,"<","/etc/userdomains");
		flock ($IN, LOCK_SH);
		my @localusers = <$IN>;
		close ($IN);
		chomp @localusers;
		chomp @localusers;
		foreach my $line (@localusers) {
			my ($domain,$user) = split(/\: /,$line,2);
			$userdomains{$domain} = $user;
		}
		my ($file, $filedir) = fileparse($FORM{file});
		my $homedir = ( getpwnam($userdomains{$FORM{domain}}) )[7];
		if ($homedir eq "" or $filedir !~ /^$homedir/) {
			print "Invalid directory [$FORM{file}]";
		} else {
			my $total = 0;
			print "<table class='table table-bordered table-striped'>\n";
			print "<thead><tr><th>Empty Directory [$FORM{file}]</th></tr></thead>";
			print "<tr><td>";
			opendir (my $DIR, $FORM{file});
			while (my $file = readdir($DIR)) {
				if (readlink "$FORM{file}/$file") {next}
				if ((-f "$FORM{file}/$file") and ($file =~ /^\d+\./)) {
					print ". ";
					unlink ("$FORM{file}/$file");
					$total++;
				}
			}
			if (-e "$FORM{file}/../maildirsize") {unlink "$FORM{file}/../maildirsize"}
			closedir ($DIR);
			print "<p>Total emails removed: $total</td></tr>\n";
			print "<tr><td>Directory emptied</td></tr>\n";
			print "</table>\n";
		}
	} else {
		print "Directory [$FORM{file}] not found";
	}
}
elsif ($FORM{action} eq "salearn") {
	if (-d $FORM{file}) {
		my %userdomains;
		open (my $IN,"<","/etc/userdomains");
		flock ($IN, LOCK_SH);
		my @localusers = <$IN>;
		close ($IN);
		chomp @localusers;
		foreach my $line (@localusers) {
			my ($domain,$user) = split(/\: /,$line,2);
			$userdomains{$domain} = $user;
		}
		my ($file, $filedir) = fileparse($FORM{file});
		my $homedir = ( getpwnam($userdomains{$FORM{domain}}) )[7];
		if ($homedir eq "" or $filedir !~ /^$homedir/) {
			print "Invalid file [$FORM{file}]";
		} else {
			$| = 1; ## no critic
			print "<table class='table table-bordered table-striped'>\n";
			print "<thead><tr><th>Running sa-learn for spam against [$FORM{file}]</th></tr></thead>";
			print "<tr><td><p>This may take some time depending on the number of emails and the speed of SpamAssassin:</p>\n<pre>\n\# /usr/local/cpanel/3rdparty/bin/sa-learn --spam --showdots $FORM{file}\n";
			my ($childin, $childout);
			my $cmdpid = open3($childin, $childout, $childout, "/usr/local/cpanel/3rdparty/bin/sa-learn", "--spam", "--showdots", $FORM{file});
			while (<$childout>) {print $_}
			waitpid ($cmdpid, 0);
			print "</pre>\n</td></tr>\n";
			print "</table>\n";
			print "<script>window.opener.location.reload()</script>\n";
		}
	} else {
		print "File [$FORM{file}] not found";
	}
}
elsif ($FORM{action} eq "bulkdelete") {
	my $total = 0;
	my $anyfile;
	my %userdomains;
	open (my $IN,"<","/etc/userdomains");
	flock ($IN, LOCK_SH);
	my @localusers = <$IN>;
	close ($IN);
	chomp @localusers;
	foreach my $line (@localusers) {
		my ($domain,$user) = split(/\: /,$line,2);
		$userdomains{$domain} = $user;
	}
	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th>Delete Selected Mails</th></tr></thead>";
	print "<tr><td>";
	for ($x = 1; $x <= $FORM{total} ;$x++) {
		my $delfile = $FORM{"cmmdel_$x"};
		if (-f $delfile) {
			my ($file, $filedir) = fileparse($delfile);
			my $homedir = ( getpwnam($userdomains{$FORM{domain}}) )[7];
			if ($homedir eq "" or $filedir !~ /^$homedir/) {
				print "Invalid file [$delfile]";
			} else {
				unlink ($delfile);
				$total++;
				$anyfile = $delfile;
			}
		}
	}
	my ($file, $filedir) = fileparse($anyfile);
	if (-d $filedir) {
		my $homedir = ( getpwnam($userdomains{$FORM{domain}}) )[7];
		if ($homedir eq "" or $filedir !~ /^$homedir/) {
			print "Invalid directory [$filedir]";
		} else {
			if (-e "$filedir/../maildirsize") {unlink "$filedir/../maildirsize"}
		}
	}
	print "<p>Total emails removed: $total</td></tr>\n";
	print "</table>\n";
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "changequota") {
	my %userdomains;
	open (my $IN,"<","/etc/userdomains");
	flock ($IN, LOCK_SH);
	my @localusers = <$IN>;
	close ($IN);
	chomp @localusers;
	foreach my $line (@localusers) {
		my ($domain,$user) = split(/\: /,$line,2);
		$userdomains{$domain} = $user;
	}

	if (($FORM{quota} =~ /[^\d\.]/) or ($FORM{quota} == 0)) {$FORM{quota} = "unlimited"}

	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th>Change Quota for $FORM{account}\@$FORM{domain}</th></tr></thead>";
	print "<tr><td>";
	eval {
		local $) = local $(; ## no critic
		local $> = local $<; ## no critic
		local $ENV{'REMOTE_USER'} = $user;
		&drop($userdomains{$FORM{domain}});
		my ($childin, $childout);
		my $cmdpid = open3($childin, $childout, $childout, "/usr/local/cpanel/cpanel-email", "editquota", $FORM{account}, $FORM{domain}, $FORM{quota});
		my @data = <$childout>;
		waitpid ($cmdpid, 0);
		chomp @data;
		my $cnt = 0;
		foreach my $line (@data) {
			if ($line =~ /^stdin: is not a tty/) {next}
			if ($line =~ /^[\r\n]/) {next}
			if ($line =~ /^<br \/>/) {next}
			print "<pre>$line</pre>\n";
			$cnt++;
		}
		unless ($cnt) {print "<p>Quota changed to $FORM{quota} MB</p>\n"}
	};
	print "</td></tr>\n";

	print "</table>\n";
	print "<p><form action='$script' method='post'><input type='hidden' name='domain' value='$FORM{domain}'><input type='hidden' name='action' value='Manage Mail Accounts'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "password") {
	print "<form action='$script' method='post'>\n";
	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th colspan='2'>Change Password for $FORM{account}\@$FORM{domain}</th></tr></thead>";
	print "<tr><td><input type='password' size=20 name='password'> New password</td></tr>\n";
	print "<tr><td><input type='password' size=20 name='confirmpassword'> Confirm password</td></tr>\n";
	print "<tr><td colspan='2'><input type='submit' class='btn btn-default' name='action' value='Change Password'></td></tr>\n";
	print "</table>\n";
	print "<input type='hidden' name='account' value='$FORM{account}'><input type='hidden' name='domain' value='$FORM{domain}'></form>\n";
	print "<p><form action='$script' method='post'><input type='hidden' name='domain' value='$FORM{domain}'><input type='hidden' name='action' value='Manage Mail Accounts'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "Change Password") {
	my %userdomains;
	open (my $IN,"<","/etc/userdomains");
	flock ($IN, LOCK_SH);
	my @localusers = <$IN>;
	close ($IN);
	chomp @localusers;
	foreach my $line (@localusers) {
		my ($domain,$user) = split(/\: /,$line,2);
		$userdomains{$domain} = $user;
	}

	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th colspan='2'>Change Password for $FORM{account}\@$FORM{domain}</th></tr></thead>";
	if ($FORM{password} eq "") {
		print "<tr><td>Failed: Empty password field</td></tr>\n";
	}
	elsif ($FORM{password} ne $FORM{confirmpassword}) {
		print "<tr><td>Failed: Passwords do not match</td></tr>\n";
	}
	elsif ($FORM{password} =~ /\"/) {
		print "<tr><td>Failed: password must not contain quotes</td></tr>\n";
	}
	else {
		print "<tr><td>\n";
		eval {
			local $) = local $(; ## no critic
			local $> = local $<; ## no critic
			local $ENV{'REMOTE_USER'} = $user;
			&drop($userdomains{$FORM{domain}});
			my ($childin, $childout);
			my $cmdpid = open3($childin, $childout, $childout, "/usr/local/cpanel/cpanel-email", "passwdpop", $FORM{account}, "$FORM{password}", "0", $FORM{domain});
			my @data = <$childout>;
			waitpid ($cmdpid, 0);
			chomp @data;
			my $cnt = 0;
			foreach my $line (@data) {
				if ($line =~ /^stdin: is not a tty/) {next}
				print "<div>$line</div>\n";
				$cnt++;
			}
			unless ($cnt) {print "<p>Password changed</p>\n"}
		};
	}
	print "</table>\n";
	print "<p><form action='$script' method='post'><input type='hidden' name='domain' value='$FORM{domain}'><input type='hidden' name='action' value='Manage Mail Accounts'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "delete") {
	print "<form action='$script' method='post'>\n";
	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th colspan='2'>Delete Mailbox $FORM{account}\@$FORM{domain}</th></tr></thead>";
	print "<tr><td><b>Are you sure that you want to irretrievably delete all email and associated files within this mailbox?</b></td></tr>\n";
	print "<tr><td colspan='2'><input type='submit' class='btn btn-default' name='action' value='Delete Mailbox'></td></tr>\n";
	print "</table>\n";
	print "<input type='hidden' name='account' value='$FORM{account}'><input type='hidden' name='domain' value='$FORM{domain}'></form>\n";
	print "<p><form action='$script' method='post'><input type='hidden' name='domain' value='$FORM{domain}'><input type='hidden' name='action' value='Manage Mail Accounts'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "Delete Mailbox") {
	my %userdomains;
	open (my $IN,"<","/etc/userdomains");
	flock ($IN, LOCK_SH);
	my @localusers = <$IN>;
	close ($IN);
	chomp @localusers;
	foreach my $line (@localusers) {
		my ($domain,$user) = split(/\: /,$line,2);
		$userdomains{$domain} = $user;
	}

	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th>Delete Mailbox $FORM{account}\@$FORM{domain}</th></tr></thead>";
	print "<tr><td>\n";
	eval {
		local $) = local $(; ## no critic
		local $> = local $<; ## no critic
		local $ENV{'REMOTE_USER'} = $user;
		&drop($userdomains{$FORM{domain}});
		my ($childin, $childout);
		my $cmdpid = open3($childin, $childout, $childout, "/usr/local/cpanel/cpanel-email", "delpop", $FORM{account}, "0", $FORM{domain});
		my @data = <$childout>;
		waitpid ($cmdpid, 0);
		chomp @data;
		my $cnt = 0;
		foreach my $line (@data) {
			if ($line =~ /^stdin: is not a tty/) {next}
			print "<div>$line</div>\n";
			$cnt++;
		}
		print "<p>Account deleted</p>\n";
	};
	print "</table>\n";
	print "<p><form action='$script' method='post'><input type='hidden' name='domain' value='$FORM{domain}'><input type='hidden' name='action' value='Manage Mail Accounts'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "Add Mailbox") {
	my %userdomains;
	open (my $IN,"<","/etc/userdomains");
	flock ($IN, LOCK_SH);
	my @localusers = <$IN>;
	close ($IN);
	chomp @localusers;
	foreach my $line (@localusers) {
		my ($domain,$user) = split(/\: /,$line,2);
		$userdomains{$domain} = $user;
	}

	if (($FORM{quota} =~ /[^\d\.]/) or ($FORM{quota} == 0)) {$FORM{quota} = "unlimited"}

	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th>Add Mailbox $FORM{account}\@$FORM{domain}</th></tr></thead>";
	if ($FORM{password} eq "") {
		print "<tr><td>Failed: Empty password field</td></tr>\n";
	}
	elsif ($FORM{password} ne $FORM{confirmpassword}) {
		print "<tr><td>Failed: Passwords do not match</td></tr>\n";
	}
	elsif ($FORM{password} =~ /\"/) {
		print "<tr><td>Failed: password must not contain quotes</td></tr>\n";
	}
	else {
		print "<tr><td>\n";
		eval {
			local $) = local $(; ## no critic
			local $> = local $<; ## no critic
			local $ENV{'REMOTE_USER'} = $user;
			&drop($userdomains{$FORM{domain}});
			my ($childin, $childout);
			my $cmdpid = open3($childin, $childout, $childout, "/usr/local/cpanel/cpanel-email", "addpop", $FORM{account}, "$FORM{password}", $FORM{quota}, $FORM{domain});
			my @data = <$childout>;
			waitpid ($cmdpid, 0);
			chomp @data;
			my $cnt = 0;
			foreach my $line (@data) {
				if ($line =~ /^stdin: is not a tty/) {next}
				print "<div>$line</div>\n";
				$cnt++;
			}
			print "<p>Account created</p>\n";
		};
		print "</td></tr>\n";
	}
	print "</table>\n";
	print "<p><form action='$script' method='post'><input type='hidden' name='domain' value='$FORM{domain}'><input type='hidden' name='action' value='Manage Mail Accounts'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif (($FORM{action} =~ /^Mail Quota Report \((.*)\)/) or ($FORM{action} eq "Manage Mail Accounts")) {
	my $report = $1;
	my $total = 0;
	my $colspan = 5;
	my $extracol = "<th>&nbsp;</th>";
	my ($tot_accounts, $tot_mails, $tot_space);

	if ($FORM{action} eq "Manage Mail Accounts") {
		$FORM{dospace} = 0;
		$FORM{dopercent} = 1;
		$FORM{percent} = 99;
		$FORM{doall} = 1;
		$report = "Selected";
		$colspan = 5;
		$extracol = "<th>Action</th>";
		print "<p><form action='$script' method='post'><input type='hidden' name='domain' value='$FORM{domain}'><input type='submit' class='btn btn-default' name='action' value='Manage Mail Forwarders'>&nbsp;&nbsp;<input type='submit' class='btn btn-default' name='action' value='Manage Mail Filters'>&nbsp;&nbsp;<input type='submit' class='btn btn-default' name='action' value='Manage Mail Hourly Limits'></form></p>\n";
	}

	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th colspan='$colspan'>Mail Account Quotas</th></tr></thead>";
	print "<thead><tr><th>Account</th><th>Mails</th><th>Used (MB)</th><th>Quota (MB)</th>$extracol</tr>";

	my @users;
	my %userdomains;
	open (my $IN,"<","/etc/userdomains");
	flock ($IN, LOCK_SH);
	my @localusers = <$IN>;
	close ($IN);
	chomp @localusers;
	foreach my $line (@localusers) {
		my ($domain,$user) = split(/\: /,$line,2);
		$userdomains{$domain} = $user;
	}

	my @domains;
	if ($report eq "Selected") {
		push @domains, $FORM{domain};
	} else {
		open (my $IN,"<","/etc/userdomains");
		flock ($IN, LOCK_SH);
		while (my $entry = <$IN>) {
			chomp $entry;
			my ($domain,$user) = split(/:\s*/,$entry);
			if ($user eq "nobody") {next}
			push @domains, $domain;
		}
		close ($IN);
		@domains = sort @domains;
	}

	foreach my $domain (@domains) {
		unless ($domain) {next}
		if ($domain =~ /^\#/) {next}
        my $homedir = ( getpwnam($userdomains{$domain}) )[7];
		unless (-e "$homedir/etc/$domain/passwd") {next}
#		unless (-e "$homedir/etc/$domain/quota") {next}

		my @accounts;
		open (my $IN,"<","$homedir/etc/$domain/passwd");
		flock ($IN, LOCK_SH);
		my @localusers = <$IN>;
		close ($IN);
		chomp @localusers;
		foreach my $line (@localusers) {
			($user,undef) = split(/\:/,$line,2);
			if ($user) {push @accounts,$user}
		}
		@accounts = sort @accounts;
		unshift @accounts,$userdomains{$domain};

		open (my $QUOTA,"<","$homedir/etc/$domain/quota");
		flock ($QUOTA, LOCK_SH);
		my @localquota = <$QUOTA>;
		close ($QUOTA);
		chomp @localquota;

		my %quotas;
		foreach my $line (@localquota) {
			my ($user,$quota) = split(/\:/,$line,2);
			$quotas{$user} = $quota;
		}

		my $first = 1;
		my $lines = 0;
		foreach my $key (@accounts) {
			my $dir;
			my $topdomain = "\@$domain";
			my $account = "${key}\@${domain}";
			my $quota = $quotas{$key};
			my $used = 0;
			my $files = 0;
			my $mdbox = 0;

			if ($first == -1) {$first = 0}
			if ($first) {
				$first = -1;
				open (my $IN,"<","/var/cpanel/users/$userdomains{$domain}");
				my @userdata = <$IN>;
				close ($IN);
				chomp @userdata;
				my $maindomain;
				foreach my $line (@userdata) {
					if ($line =~ /^DNS=(.*)/) {$maindomain = $1}
				}
				if ($maindomain ne $domain) {next}
				$dir = "$homedir/mail";
				$topdomain = " (<b>$domain</b> cPanel user)";
				$account = "${key}";
				$quota = 0;
			} else {
				$dir = "$homedir/mail/$domain/$key";
			}

			if (-e "$dir/storage") {
				$mdbox = 1;
				$topdomain .= " <span class='label label-warning'>mdbox</span>";

				my ($childin, $childout);
				my $cmdpid = open3($childin, $childout, $childout, "/usr/bin/doveadm", "mailbox", "status", "-u", "$account", "-t", "messages vsize", "*");
				my @data = <$childout>;
				waitpid ($cmdpid, 0);
				chomp @data;
				if ($data[0] =~ /messages=(\d+)/) {$files = $1}
				if ($data[0] =~ /vsize=(\d+)/) {$used = $1}
			} else {
				my @maildirs;
				push @maildirs, $dir;
				opendir (my $DIR, $dir);
				while (my $file = readdir($DIR)) {
					if ($file eq ".") {next}
					if ($file eq "..") {next}
					if (readlink "$dir/$file") {next}
					if ((-d "$dir/$file") and (-d "$dir/$file/cur") and (-d "$dir/$file/new") and (-d "$dir/$file/tmp")) {push @maildirs, "$dir/$file"}
				}
				closedir ($DIR);
				if (-e "$dir/storage") {
					$mdbox = 1;
				} else {
					foreach my $line (@maildirs) {
						foreach my $subdir ("/","/cur","/new","/tmp") {
							opendir (my $DIR, "$line$subdir");
							while (my $file = readdir($DIR)) {
								if ((-f "$line$subdir/$file") and ($file =~ /^\d+\./)) {
									$used += (stat("$line$subdir/$file"))[7];
									$files++;
								}
							}
							closedir ($DIR);
						}
					}
				}
			}

			my $uclass = "";
			if (($FORM{dospace}) and ($used > $FORM{space} * 1024 * 1024)) {$uclass = "warning"}
			if (($FORM{dopercent}) and (($used >= $quota) or ($used / $quota >= ($FORM{percent} / 100))) and ($quota > 0)) {$uclass = "danger"}

			unless ($FORM{doall}) {
				if ($uclass eq "") {next}
				if ($uclass eq "") {next}
			}
			my $uquota = 0;
			if ($quota > 0) {$uquota = int(($used / $quota) * 100)}

			$used = $used / (1024 * 1024);

			my $tused = $used;
			$used = sprintf("%.02f",$used);

			$used .= " ($uquota\%)";

			if ($quota < 1) {
				$quota = "unlimited";
			} else {
				$quota = int($quota / (1024 * 1024));
			}
			
			if ($FORM{action} eq "Manage Mail Accounts") {
				$tot_accounts++;
				$tot_mails+=$files;
				$tot_space+=$tused;
				print "<tr class='$uclass'><form action='$script' method='post'><td>$key$topdomain</td><td>$files</td><td>$used</td><td>";
				if ($first == -1) {
					print "$quota</td><td>";
					if ($files > 0 and !$mdbox) {
						print " <a class='btn btn-primary glyphicon glyphicon-folder-open' href='$script?action=view&account=$key&domain=$domain&top=1' data-tooltip='tooltip' title='View MailBox Contents'></a>";
						print " <a class='btn btn-warning glyphicon glyphicon-trash' href='$script?action=empty&account=$key&domain=$domain&top=1' data-tooltip='tooltip' title='Empty Mailbox'></a>";
					}
				} else {
					print "<input type='text' size='10' name='quota' value='$quota' style='text-align: right; padding-right: 2px'><input type='hidden' name='domain' value='$domain'><input type='hidden' name='account' value='$key'><input type='hidden' name='action' value='changequota'></td><td><button type='submit' class='btn btn-info glyphicon glyphicon-hdd' data-tooltip='tooltip' title='Change Quota'></button>";
					print " <a class='btn btn-success glyphicon glyphicon-lock' href='$script?action=password&domain=$domain&account=$key' data-tooltip='tooltip' title='Change Mailbox Password'></a>";
					if ($files > 0 and !$mdbox) {
						print " <a class='btn btn-primary glyphicon glyphicon-folder-open' href='$script?action=view&account=$key&domain=$domain' data-tooltip='tooltip' title='View MailBox Contents'></a>";
						print " <a class='btn btn-warning glyphicon glyphicon-trash' href='$script?action=empty&account=$key&domain=$domain' data-tooltip='tooltip' title='Empty Mailbox'></a>";
					} else {print "";}
					print " <a class='btn btn-danger glyphicon glyphicon-remove' href='$script?action=delete&domain=$domain&account=$key' data-tooltip='tooltip' title='Delete Mailbox'></a>";
				}
				print "</td></form></tr>\n";
			} else {
				print "<tr class='$uclass'><td>$key$topdomain</td><td>$files</td><td>$used</td><td>$quota</td><td>\n";
				print " <a class='btn btn-primary glyphicon glyphicon-cog' href='$script?action=Manage\%20Mail\%20Accounts&account=$key&domain=$domain&space=$FORM{space}&percent=$FORM{percent}' data-tooltip='tooltip' title='Manage Mail Accounts'></td></tr>\n";
			}
			if ($class eq "tdshade2_noborder") {$class = "tdshade1_noborder"} else {$class = "tdshade2_noborder"}
			$total++;
			$lines++;
		}
		my $info = "<th colspan='$colspan'>&nbsp;</th>";
		$tot_space = sprintf("%.02f",$tot_space);
		if ($FORM{action} eq "Manage Mail Accounts") {$info = "<th>$tot_accounts account(s)</th><th>$tot_mails</th><th>$tot_space</th><th colspan='2'>&nbsp;</th>"}
		if ($FORM{doall} and $lines) {print "<tr>$info</tr>\n"}
	}
	print "</table>\n";
	if ($FORM{action} eq "Manage Mail Accounts") {
		print "<div class='row'><div class='col-md-4 col-md-offset-2'>\n";
		print "<table class='table table-bordered table-striped'>\n";
		print "<form action='$script' method='post'><input type='hidden' name='domain' value='$FORM{domain}'>\n";
		print "<thead><tr><th colspan='2'>Add Mailbox</th></tr></thead>";
		my ($childin, $childout);
		my $cmdpid = open3($childin, $childout, $childout, "/usr/bin/quota", "-qlu", $userdomains{$FORM{domain}});
		my @data = <$childout>;
		waitpid ($cmdpid, 0);
		chomp @data;
		if ($data[0] =~ /Block limit reached/) {
			print "<tr><td colspan='2'><p>cPanel account over quota - add mailbox disabled</p></td></tr>\n";
		} else {
			print "<tr><td>Account</td><td><input type='text' size='10' name='account'>\@$FORM{domain}</td></tr>\n";
			print "<tr><td>Password</td><td><input type='password' size='10' name='password'></td></tr>\n";
			print "<tr><td>Confirm</td><td><input type='password' size='10' name='confirmpassword'></td></tr>\n";
			print "<tr><td>Quota</td><td><input type='text' size='10' name='quota' value='10'>MB</td></tr>\n";
			print "<tr><td colspan='2'><input type='submit' class='btn btn-default' name='action' value='Add Mailbox'></td></tr>\n";
		}
		print "</form></table></div>\n";

		print "<div class='col-md-4'><table class='table table-bordered table-striped'>\n";
		print "<thead><tr><th colspan='2'>Button Key</th></tr></thead>";
		print "<tr><td><span class='btn btn-info glyphicon glyphicon-hdd'></span></td><td>Change mailbox quota</td></tr>\n";
		print "<tr><td><span class='btn btn-success glyphicon glyphicon-lock'></span></td><td>Change mailbox password</td></tr>\n";
		print "<tr><td><span class='btn btn-primary glyphicon glyphicon-folder-open'></span></td><td>View mailbox contents</td></tr>\n";
		print "<tr><td><span class='btn btn-warning glyphicon glyphicon-trash'></span></td><td>Empty mailbox/Directory</td></tr>\n";
		print "<tr><td><span class='btn btn-danger glyphicon glyphicon-remove'></span></td><td>Delete mailbox/Mail</td></tr>\n";
		if ($mailscanner) {print "<tr><td><span class='btn btn-success glyphicon glyphicon-flag'></span></td><td>sa-learn spam Directory</td></tr>\n"}
		print "</table>\n";
		print "</div><div class='col-md-2'></div></div>\n";
	}
	print "<div class='bs-callout bs-callout-info'>Total Accounts: $total</div>\n";
	print "<div class='bs-callout bs-callout-warning'><span class='label label-warning'>mdbox</span> - Mailboxes using the cPanel v11.58+ mdbox format have limited support in this script</div>\n";
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "Bulk Enable GreyListing") {
	require Cpanel::GreyList::Client;

	print "<table class='table table-bordered table-striped'>\n";
	print "<tr><td>Enabled GreyListing on all domains</td></tr>\n";
	print "</table>\n";
	my @localdomains;
	open (my $IN,"<","/etc/userdomains");
	flock ($IN, LOCK_SH);
	while (my $entry = <$IN>) {
		chomp $entry;
		my ($domain,$user) = split(/:\s*/,$entry);
		if ($user eq "nobody") {next}
		if ($domain eq "") {next}
		if ($domain eq "*") {next}
		push @localdomains, $domain;
	}
	close($IN);
	my $client = Cpanel::GreyList::Client->new();
	$client->disable_opt_out_for_domains(\@localdomains);
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "Bulk Show GreyListing") {
	require Cpanel::GreyList::Client;

	print "<table class='table table-bordered table-striped'>\n";
	my @localdomains;
	open (my $IN,"<","/etc/userdomains");
	flock ($IN, LOCK_SH);
	my @entries = <$IN>;
	close ($IN);
	chomp @entries;
	foreach my $entry (sort @entries) {
		chomp $entry;
		my ($domain,$user) = split(/:\s*/,$entry);
		if ($user eq "nobody") {next}
		if ($domain eq "") {next}
		if ($domain eq "*") {next}
		my $client = Cpanel::GreyList::Client->new();
		if ($client->is_greylisting_enabled($domain)) {
			print "<tr><td>GreyListing is <b>enabled</b> for $domain</td></tr>\n";
		} else {
			print "<tr><td>GreyListing is disabled for $domain</td></tr>\n";
		}
	}
	print "</table>\n";
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "Bulk Disable GreyListing") {
	require Cpanel::GreyList::Client;

	print "<table class='table table-bordered table-striped'>\n";
	print "<tr><td>Disabled GreyListing on all domains</td></tr>\n";
	print "</table>\n";
	my @localdomains;
	open (my $IN,"<","/etc/userdomains");
	flock ($IN, LOCK_SH);
	while (my $entry = <$IN>) {
		chomp $entry;
		my ($domain,$user) = split(/:\s*/,$entry);
		if ($user eq "nobody") {next}
		if ($domain eq "") {next}
		if ($domain eq "*") {next}
		push @localdomains, $domain;
	}
	close ($IN);
	my $client = Cpanel::GreyList::Client->new();
	$client->enable_opt_out_for_domains(\@localdomains);
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "Show GreyListing") {
	unless ($FORM{domain}) {
		print "<p>You must select a domain!</p>\n";
	} else {
		require Cpanel::GreyList::Client;

		print "<table class='table table-bordered table-striped'>\n";
		my $client = Cpanel::GreyList::Client->new();
		if ($client->is_greylisting_enabled($FORM{domain})) {
			print "<tr><td>GreyListing is <b>enabled</b> for $FORM{domain}</td></tr>\n";
		} else {
			print "<tr><td>GreyListing is disabled for $FORM{domain}</td></tr>\n";
		}
		print "</table>\n";
	}
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "Enable GreyListing") {
	unless ($FORM{domain}) {
		print "<p>You must select a domain!</p>\n";
	} else {
		require Cpanel::GreyList::Client;

		print "<table class='table table-bordered table-striped'>\n";
		print "<tr><td>Enabled GreyListing on $FORM{domain}</td></tr>\n";
		print "</table>\n";
		my @domains;
		my $client = Cpanel::GreyList::Client->new();
		@domains = ($FORM{domain});
		$client->disable_opt_out_for_domains(\@domains);
	}
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "Disable GreyListing") {
	unless ($FORM{domain}) {
		print "<p>You must select a domain!</p>\n";
	} else {
		require Cpanel::GreyList::Client;

		print "<table class='table table-bordered table-striped'>\n";
		print "<tr><td>Disabled GreyListing on $FORM{domain}</td></tr>\n";
		print "</table>\n";
		my @domains;
		my $client = Cpanel::GreyList::Client->new();
		@domains = ($FORM{domain});
		$client->enable_opt_out_for_domains(\@domains);
	}
	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "upgrade") {
	$| = 1; ## no critic

	print "<pre>";

	if (-e "/usr/src/cmm.tgz") {unlink ("/usr/src/cmm.tgz") or die $!}
	print "Retrieving new cmm package...\n";

	my ($status, $text) = &urlget("https://$downloadserver/cmm.tgz","/usr/src/cmm.tgz");
	if ($status) {print "Oops: $text\n"}

	if (! -z "/usr/src/cmm.tgz") {
		print "Unpacking new cmm package...\n";
		print "<pre>";
		&printcmd("cd /usr/src ; tar -xzf cmm.tgz ; cd cmm ; sh install.sh 2>&1");
		print "</pre>";
		print "Tidying up...\n";
		print "<pre>";
		&printcmd("rm -Rfv /usr/src/cmm*");
		print "</pre>";
		print "...All done.\n";
	}
	print "</pre>";

	open (my $IN, "<",$versionfile) or die $!;
	flock ($IN, LOCK_SH);
	$myv = <$IN>;
	close ($IN);
	chomp $myv;

	print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
}
else {
	open (my $IN, "<","/etc/userdomains");
	flock ($IN, LOCK_SH);
	while (my $entry = <$IN>) {
		chomp $entry;
		my ($domain,$user) = split(/:\s*/,$entry);
		if ($user eq "nobody") {next}
		push @localdomains, $domain;
	}
	close ($IN);
	@localdomains = sort @localdomains;

	my $domainlist;
	my $domaincnt;
	foreach my $domain (@localdomains) {
		$domainlist .= "<option>$domain</option>\n";
		$domaincnt ++;
	}

	print "<form action='$script' method='post'>\n";
	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th colspan='2'>Mail Manage</th></tr></thead>";
	print "<tr><td valign='top'><select name='domain' size='20'>$domainlist\n";
	print "</td><td valign='top'>\n";
	print "<p><input type='submit' class='btn btn-default' name='action' value='Manage Mail Accounts'></p>\n";
	print "<p><input type='submit' class='btn btn-default' name='action' value='Manage Mail Forwarders'></p>\n";
	print "<p><input type='submit' class='btn btn-default' name='action' value='Manage Mail Filters'></p>\n";
	print "<p><input type='submit' class='btn btn-default' name='action' value='Manage Mail Hourly Limits'></p>\n";
	if (-e "/var/cpanel/greylist/enabled") {
		print "<p><input type='submit' class='btn btn-default' name='action' value='Show GreyListing'></p>\n";
		print "<p><input type='submit' class='btn btn-default' name='action' value='Enable GreyListing'></p>\n";
		print "<p><input type='submit' class='btn btn-default' name='action' value='Disable GreyListing'> <span class='label label-warning'>WARNING:</span> If you disable GreyListing on a main domain cPanel forces all subdomains to be disabled until the main domain is enabled</p>\n";
	}
	print "<p>Mail Domains: $domaincnt</p>\n";
	print "</td></tr>\n";

	print "<thead><tr><th colspan='2'>Mail Reports</th></tr></thead>";
	print "<tr><td colspan='2'>\n";
	print "<input type='checkbox' name='dospace' value='1' checked> Identify accounts using over <input type='text' size='3' value='10' name='space'>MB of mailbox space<br>\n";
	print "<input type='checkbox' name='dopercent' value='1' checked> Identify accounts using within or over <input type='text' size='3' value='99' name='percent'>% of the mailbox quota<br>\n";
	print "<input type='checkbox' name='doall' value='1' checked> Show all accounts\n";
	print "<p>Note: These reports may take some time to run</p></td></tr>\n";
	print "<tr><td><input type='submit' class='btn btn-default' name='action' value='Mail Quota Report (Selected)'></td><td>View email account usage for the domain selected above</td></tr>\n";
	print "<tr><td><input type='submit' class='btn btn-default' name='action' value='Mail Quota Report (All)'></td><td>View email account usage for all domains</td></tr>\n";
	print "<tr><td><input type='reset' class='btn btn-default' name='action' value='Reset Form'></td><td>&nbsp;</td></tr>\n";

	print "</table>\n";
	print "<div class='bs-callout bs-callout-warning'><span class='label label-warning'>mdbox</span> - Mailboxes using the cPanel v11.58+ mdbox format have limited support in this script</div>\n";

	if (-e "/var/cpanel/greylist/enabled") {
		print "<table class='table table-bordered table-striped'>\n";
		print "<thead><tr><th colspan='2'>GreyListing</th></tr></thead>";
		print "<tr><td><input type='submit' class='btn btn-default' name='action' value='Bulk Show GreyListing'></td><td>Display GreyListing for all domains</td></tr>\n";
		print "<tr><td><input type='submit' class='btn btn-default' name='action' value='Bulk Enable GreyListing'></td><td>Configure GreyListing so that all domains are enabled</td></tr>\n";
		print "<tr><td><input type='submit' class='btn btn-default' name='action' value='Bulk Disable GreyListing'></td><td>Configure GreyListing so that all domains are disabled</td></tr>\n";
		print "</table>\n";
		print "<div class='bs-callout bs-callout-danger'><h4>WARNING: Using GreyListing can and will lead to lost legitimate emails. It can also cause significant problems with Password Verification systems. See <a href='https://en.wikipedia.org/wiki/Greylisting#Disadvantages' target='_blank'>this article</a> for more information</h4></div>\n";
	}

	my $retry = 0;
	my $retrytime = 300;
	print "<table class='table table-bordered table-striped'>\n";
	print "<thead><tr><th colspan='2'>Upgrade</th></tr></thead>";
	if (-e "/usr/local/cpanel/whostmgr/docroot/cgi/cmmnocheck") {
		open (my $IN, "<", "/usr/local/cpanel/whostmgr/docroot/cgi/cmmnocheck");
		flock ($IN, LOCK_SH);
		my $time = <$IN>;
		close ($IN);
		chomp $time;
		$retry = time - $time;
		if ($retry > $retrytime) {unlink ("/usr/local/cpanel/whostmgr/docroot/cgi/cmmnocheck")}
	}
	unless (-e "/usr/local/cpanel/whostmgr/docroot/cgi/cmmnocheck") {
		my ($status, $text) = &urlget("https://$downloadserver/cmm/cmmversion.txt");
		my $actv = $text;
		my $up = 0;

		if ($actv ne "") {
			if ($actv =~ /^[\d\.]*$/) {
				if ($actv > $myv) {
					print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='upgrade'><input type='submit' class='btn btn-default' value='Upgrade cmm'></td><td width='100%'><b>A new version of cmm (v$actv) is available. Upgrading will retain your settings<br><a href='https://$downloadserver/cmm/CHANGELOG.txt' target='_blank'>View ChangeLog</a></b></td></form></tr>\n";
				} else {
					print "<tr><td colspan='2'>You are running the latest version of cmm.<br>An Upgrade button will appear here if a new version becomes available</td></tr>\n";
				}
				$up = 1;
			}
		}
		unless ($up) {
			sysopen (my $OUT, "/usr/local/cpanel/whostmgr/docroot/cgi/cmmnocheck", O_WRONLY | O_CREAT);
			flock ($OUT, LOCK_EX);
			print $OUT time;
			close ($OUT);
			print "<tr><td colspan='2'>Unable to connect to http://www.configserver.com, retry in $retrytime seconds.<br>An Upgrade button will appear here if new version is detected</td></tr>\n";
		}
	} else {
			print "<tr><td colspan='2'>Unable to connect to http://www.configserver.com, retry in ".($retrytime - $retry)." seconds.<br>An Upgrade button will appear here if new version is detected</td></tr>\n";
	}

	print "</table></form>\n";
}

print "<pre>cmm: v$myv</pre>";
print "<p>&copy;2006-2019, <a href='http://www.configserver.com' target='_blank'>ConfigServer Services</a> (Jonathan Michaelson)</p>\n";
print <<EOF;
<script>
	\$("#loader").hide();
	\$("#docs-link").hide();
</script>
EOF
unless ($FORM{action} eq "viewmail") {
	close SCRIPTOUT;
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
# start drop
sub drop {
	my $user = shift;
	my (undef,undef,$uid,$gid,undef,undef,undef,$home) = getpwnam($user);
	if ($> == 0) {
		chdir($home);
		$) = $( = $gid; ## no critic
		$> = $< = $uid; ## no critic
		if (($) != $gid) or ($> != $uid) or ($( != $gid) or ($< != $uid)) {print "Failed to drop privileges ($uid:$gid)\n";exit} ## no critic
		$ENV{'REMOTE_USER'} = $user; ## no critic
	}
	return
}
# end drop
###############################################################################
sub uri_escape {
	my $string = shift;
	$string =~ s/([^^A-Za-z0-9\-_.!~*'()])/ sprintf "%%%0x", ord $1 /eg;
	return $string;
}

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
			$|=1; ## no critic
			my $expected_length;
			my $bytes_received = 0;
			my $per = 0;
			my $oldper = 0;
			open (my $OUT, ">", "$file\.tmp") or return (1, "Unable to open $file\.tmp: $!");
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
## start printcmd
sub printcmd {
	my @command = @_;
	my ($childin, $childout);
	my $pid = open3($childin, $childout, $childout, @command);
	while (<$childout>) {print $_}
	waitpid ($pid, 0);
	return;
}
## end printcmd
###############################################################################
## start getdownloadserver
sub getdownloadserver {
	my @servers;
	my $downloadservers = "/usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmm/downloadservers";
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
