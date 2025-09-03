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
# start main
use strict;
use File::Find;
use Fcntl qw(:DEFAULT :flock);
use Sys::Hostname qw(hostname);
use IPC::Open3;
use File::Copy;
use Digest::MD5;

use lib '/etc/cmq/Modules';
use ConfigServer::cmqUI;

our ($script, $script_da, $images, %FORM, $myv, %daconfig, %ajaxsubs, %fullsubs);

my %session;
if ($ENV{SESSION_ID} =~ /^\w+$/) {
	open (my $SESSION, "<", "/usr/local/directadmin/data/sessions/da_sess_".$ENV{SESSION_ID}) or die "Security Error: No valid session key for [$ENV{SESSION_ID}]";
	flock ($SESSION, LOCK_SH);
	my @data = <$SESSION>;
	close ($SESSION);
	chomp @data;
	foreach my $line (@data) {
		my ($name, $value) = split(/\=/,$line);
		$session{$name} = $value;
	}
}
if (($session{key} eq "") or ($session{ip} eq "") or ($session{key} ne $ENV{SESSION_KEY})) {
	&loginfail("Security Error: No valid session key");
	exit;
}

my ($ppid, $pexe) = &getexe(getppid());
if ($pexe ne "/usr/local/directadmin/directadmin") {
	print "Security Error: Invalid parent";
	exit;
}

$script = "/CMD_PLUGINS_ADMIN/cmq/index.raw";
$script_da = "/CMD_PLUGINS_ADMIN/cmq/index.raw";
$images = "/CMD_PLUGINS_ADMIN/cmq/images";
my $buffer = $ENV{'QUERY_STRING'};
if ($buffer eq "") {$buffer = $ENV{POST}}
my @pairs = split(/&/, $buffer);
foreach my $pair (@pairs) {
	my ($name, $value) = split(/=/, $pair);
	$value =~ tr/+/ /;
	$value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
	$FORM{$name} = $value;
}

my $bootstrapcss = "<link rel='stylesheet' href='$images/bootstrap/css/bootstrap.min.css'>";
my $jqueryjs = "<script src='$images/jquery.min.js'></script>";
my $bootstrapjs = "<script src='$images/bootstrap/js/bootstrap.min.js'></script>";
my $fontawesome = "<link rel='stylesheet' href='https://use.fontawesome.com/releases/v5.0.10/css/all.css'>";

my $versionfile = "/etc/cmq/cmqversion.txt";
open (my $IN, "<", $versionfile) or die $!;
flock ($IN, LOCK_SH);
$myv = <$IN>;
close ($IN);
chomp $myv;

unless ($FORM{action} eq "tailcmd" or $FORM{action} eq "tracking_detail" or $FORM{format} ne "" or $FORM{action} eq "help") {
		print <<EOF;
<!doctype html>
<html lang='en'>
<head>
	<title>ConfigServer Mail Queues</title>
	<meta charset='utf-8'>
	<meta name='viewport' content='width=device-width, initial-scale=1'>
	$bootstrapcss
	$fontawesome
	<link href='$images/configserver.css' rel='stylesheet' type='text/css'>
	$jqueryjs
	$bootstrapjs
</head>
<body>
<div id="loader"></div>
<div class='container-fluid'>
<br>
<div class='panel panel-default'>
<h4><img src='$images/cmq.png' style='padding-left: 10px'> ConfigServer Mail Queues - cmq v$myv</h4>
</div>
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
<style>
pre {
	overflow: initial;
}
</style>
EOF
}

ConfigServer::cmqUI::displayUI(\%FORM,$script,$script_da,$images,$myv);

	print <<EOF;
<script>
	\$("#loader").hide();
	window.parent.parent.scrollTo(0,0);
	parent.resizeIframe(parent.document.getElementById("myiframe"));
</script>
</body>
</html>
EOF

sub getexe {
	my $thispid = shift;
	open (my $STAT, "<", "/proc/".$thispid."/stat");
	my $stat = <$STAT>;
	close ($STAT);
	chomp $stat;
	$stat =~ /\w\s+(\d+)\s+[^\)]*$/;
	my $ppid = $1;
	my $exe = readlink("/proc/".$ppid."/exe");
	return ($ppid, $exe);
}
1;
