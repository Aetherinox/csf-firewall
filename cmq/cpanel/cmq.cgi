#!/usr/bin/perl
#WHMADDON:addonupdates:ConfigServer Mail Queues
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
use Sys::Hostname qw(hostname);
use IPC::Open3;
use Fcntl qw(:DEFAULT :flock);
use Storable();
use lib '/etc/cmq/Modules';
use ConfigServer::cmqUI;

use lib '/usr/local/cpanel';
require Cpanel::Form;
require Cpanel::Config;
require Whostmgr::ACLS;
require Cpanel::Template;
require Cpanel::Rlimit;
require Cpanel::Version::Tiny;
#
###############################################################################
# start main

our ($images, $myv, $script, %FORM, %queue, $expcnt, %cookie, $script_da);

%FORM = Cpanel::Form::parseform();

Whostmgr::ACLS::init_acls();
if (!Whostmgr::ACLS::hasroot()) {
	print "Content-type: text/html\r\n\r\n";
    print "You do not have access to this option.\n";
	exit();
}

Cpanel::Rlimit::set_rlimit_to_infinity();

$script = "cmq.cgi";
$script_da = "cmq.cgi";
$images = "cmq";

my $config = "";
my @config;
my $viewqueue = "Pending Queue";
if (-e "/etc/exim_outgoing.conf" and $FORM{config} !~ /^exim/) {
	$config = "-C /etc/exim_outgoing.conf";
	push @config, "-C", "/etc/exim_outgoing.conf";
	$viewqueue = "Delivery Queue";
}

open (my $IN, "<", "/etc/cmq/cmqversion.txt") or die $!;
$myv = <$IN>;
close ($IN);
chomp $myv;

my $thisapp = "cmq";

print "Content-type: text/html\r\n\r\n";

my $bootstrapcss = "<link rel='stylesheet' href='$images/bootstrap/css/bootstrap.min.css'>";
my $jqueryjs = "<script src='$images/jquery.min.js'></script>";
my $bootstrapjs = "<script src='$images/bootstrap/js/bootstrap.min.js'></script>";

my $templatehtml;
unless ($FORM{action} eq "view" or $FORM{action} eq "viewdelivery" or $FORM{action} eq "deliver" or $FORM{action} eq "delete") {
	open SCRIPTOUT, '>', \$templatehtml;
	select SCRIPTOUT;

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
<h4><img src='$images/cmq.png' style='padding-left: 10px'> ConfigServer Mail Queues - cmq v$myv</h4></div>
EOF

ConfigServer::cmqUI::displayUI(\%FORM,$script,$script_da,$images,$myv);

print <<EOF;
<script>
	\$("#loader").hide();
	\$("#docs-link").hide();
</script>
EOF
unless ($FORM{action} eq "view" or $FORM{action} eq "viewdelivery" or $FORM{action} eq "deliver" or $FORM{action} eq "delete") {
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

1;
