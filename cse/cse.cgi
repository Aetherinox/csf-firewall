#!/usr/bin/perl
#WHMADDON:addonupdates:ConfigServer Explorer
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
use IPC::Open3;
use Fcntl qw(:DEFAULT :flock);
use File::Find;
use File::Copy;
use CGI::Carp qw(fatalsToBrowser);

use lib '/usr/local/cpanel';
require Cpanel::Form;
require Whostmgr::ACLS;
require Cpanel::Template;
require Cpanel::Rlimit;
require Cpanel::Version::Tiny;
###############################################################################
# start main

our ($myv, $images, $versionfile, $script, %form, $webpath, $demo, $message,
	 $thisdir, @months, @thisdirs, @thisfiles, $tgid, $tuid, $storepath,
	 @passrecs, $act, $origpath, $destpath, $dir, @dirs, @files, @splitme,
	 $extra, $extramessage, $fileno, $wwwpath, @userfiles, $downloadserver);

%form = Cpanel::Form::parseform();

Whostmgr::ACLS::init_acls();
if (!Whostmgr::ACLS::hasroot()) {
	print "Content-type: text/html\r\n\r\n";
	print "You do not have access to access the ConfigServer Explorer.\n";
	exit();
}

Cpanel::Rlimit::set_rlimit_to_infinity();


$script = "cse.cgi";
$images = "cse";
$versionfile = "/usr/local/cpanel/whostmgr/docroot/cgi/configserver/cse/cseversion.txt";

$webpath = '/';
$demo = 0;

if ($form{do} eq "view") {
	&view;
	exit;
}

my $thisapp = "cse";
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

open (IN, "<", $versionfile) or die $!;
$myv = <IN>;
close (IN);
chomp $myv;

$downloadserver = &getdownloadserver;

my $bootstrapcss = "<link rel='stylesheet' href='$images/bootstrap/css/bootstrap.min.css'>";
my $jqueryjs = "<script src='$images/jquery.min.js'></script>";
my $bootstrapjs = "<script src='$images/bootstrap/js/bootstrap.min.js'></script>";

my $templatehtml;
unless ($form{do} eq "console") {
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
<h4><img src='$images/cse.png' style='padding-left: 10px'> ConfigServer Explorer - cse v$myv</h4></div>
EOF
if ($reregister ne "") {print $reregister}

$message = "";
my $uploadingfile = 0;
foreach my $key (keys %form) {
	if (($form{$key} =~ /\/tmp\/cpanel3upload\./) or ($form{$key} =~ /\/tmp\/cpanel\.TMP/) or ($form{$key} =~ /\/tmp\/Cpanel_Form_file\.upload\./)) {$uploadingfile = 1};
}

if ($uploadingfile) {&uploadfile}
elsif ($form{do} eq "") {&browse}
elsif ($form{do} eq "upgrade") {&upgrade}
elsif ($form{quit} == 2) {&browse}
elsif ($form{do} eq "b") {&browse}
elsif ($form{do} eq "p") {&browse}
elsif ($form{do} eq "o") {&browse}
elsif ($form{do} eq "c") {&browse}
elsif ($form{do} eq "m") {&browse}
elsif ($form{do} eq "pw") {&browse}
elsif ($form{do} eq "r") {&browse}
elsif ($form{do} eq "newf") {&browse}
elsif ($form{do} eq "newd") {&browse}
elsif ($form{do} eq "cnewf") {&cnewf}
elsif ($form{do} eq "cnewd") {&cnewd}
elsif ($form{do} eq "ren") {&ren}
elsif ($form{do} eq "del") {&del}
elsif ($form{do} eq "setp") {&setp}
elsif ($form{do} eq "seto") {&seto}
elsif ($form{do} eq "cd") {&cd}
elsif ($form{do} eq "console") {&console}
elsif ($form{do} eq "edit") {&edit}
elsif ($form{do} eq "Cancel") {&browse}
elsif ($form{do} eq "Save") {&save}
elsif ($form{do} eq "copyit") {&copyit}
elsif ($form{do} eq "moveit") {&moveit}
elsif ($form{do} eq "search") {&search}
else {print "Invalid action"};

unless ($form{do} eq "console") {
	print "<pre>cse: v$myv</pre>";
	print "<p>&copy;2006-2019, <a href='http://www.configserver.com' target='_blank'>ConfigServer Services</a> (Jonathan Michaelson)</p>\n";
}
print <<EOF;
<script>
	\$("#loader").hide();
	\$("#docs-link").hide();
	\$(document).ready(function(){
		\$('[data-tooltip="tooltip"]').tooltip();
	});
</script>
EOF
unless ($form{do} eq "console") {
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

exit;
# end main
###############################################################################
# start browse
sub browse {

my %htmlext;
#foreach my $img (split(/\,/,$wwwext)) {$htmlext{$img} = 1}
my $extra;
if ($form{c}) {
	if (-e "$webpath$form{c}") {
		$extra = "&c=$form{c}";
	} else {
		$form{c} = "";
	}
}
if ($form{m}) {
	if (-e "$webpath$form{m}") {
		$extra = "&m=$form{m}"
	} else {
		$form{m} = "";
	}
}

print "<script language='javascript'>\n";
print "	function check(file) {return confirm('Click OK to '+file)}\n";
print "</script>\n";

$thisdir = $webpath;
if ($thisdir !~ /\/$/) {$thisdir .= "/"}
$thisdir .= $form{p};
$thisdir =~ s/\/+/\//g;
@months = ("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");

my $errordir = 0;
opendir (DIR, "$thisdir") or $errordir = 1;
while (my $file = readdir(DIR)) {
	if (-d "$thisdir/$file") {
		if ($file !~ /^\.$|^\.\.$/) {push (@thisdirs, $file)}
	} else {
		push (@thisfiles, $file);
	}

}
closedir (DIR);

@thisdirs = sort @thisdirs;
@thisfiles = sort @thisfiles;

print "<div class='bs-callout bs-callout-danger'>\n";
print "<span class='label label-danger'>WARNING!</span> While this utility can be very useful it is also very dangerous indeed. You can easily render your server inoperable and unrecoverable by performing ill advised actions. No warranty or guarantee is provided with the product that protects against system damage.\n</td></tr>\n";
print "</div>\n";

if ($message) {print "<div class='bs-callout bs-callout-success'><h3 class='text-center'>$message</h3></div>\n";}
print "<table class='table table-bordered table-striped table-condensed'>\n";
print "<tr><td colspan='7'>";
print "[<a href=\"$script?do=b&p=$extra\">Home</a>]";
my $path = "";
my $cnt = 2;
my @path = split(/\//,$form{p});
foreach my $dir (@path) {
	if ($dir ne "" and ($dir ne "/")) {
		if ($cnt == @path) {
			print "<code>/$dir</code>";
		} else {
			print "<code>/</code><a href=\"$script?do=b&p=$path/$dir$extra\">$dir</a>";
		}
		$path .= "/$dir";
		$cnt++;
	}
}
if ($form{c}) {print "&nbsp;&nbsp;&nbsp;&nbsp;Copy buffer:<code>$form{c}</code> <a class='btn btn-default glyphicon glyphicon-paste' data-tooltip='tooltip' title='Paste Here' href='$script?do=c&p=$form{p}$extra\#new'></a>\n"}
if ($form{m}) {print "&nbsp;&nbsp;&nbsp;&nbsp;Move buffer:<code>$form{m}</code> <a class='btn btn-default glyphicon glyphicon-paste' data-tooltip='tooltip' title='Move Here' href='$script?do=m&p=$form{p}$extra\#new'></a>\n"}
print "</td></tr>\n";
if ($errordir) {
	print "<tr><td colspan='7'>Permission Denied</td></tr>";
} else {
	if (@thisdirs > 0) {
		print "<thead>\n";
		print "<tr>";
		print "<th>Directory Name</th>";
		print "<th>Size</th>";
		print "<th>Date</th>";
		print "<th>User(uid)/Group(gid)</th>";
		print "<th>Perms</th>";
		print "<th colspan='2'>Actions</th>";
		print "</tr></thead>\n";
	}
	foreach my $dir (@thisdirs) {
		if ($dir =~/'|"|\||\`/) {
			print "<td colspan='7'>".quotemeta($dir)."Invalid directory name - ignored</td>\n";
			next;
		}
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$thisdir/$dir");
		if ($size < 1024) {
		}
		elsif ($size < (1024 * 1024)) {
			$size = sprintf("%.1f",($size/1024));
			$size .= "k";
		}
		else {
			$size = sprintf("%.1f",($size/(1024 * 1024)));
			$size .= "M";
		}
		$mode = sprintf "%04o", $mode & 07777;
		$tgid = getgrgid($gid);
		if ($tgid eq "") {$tgid = $gid}
		$tuid = getpwuid($uid);
		if ($tuid eq "") {$tuid = $uid}
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($mtime);
		$year += 1900;
		my $time = sprintf "%02d:%02d:%02d", $hour, $min, $sec;
		$mday = sprintf "%02d", $mday;
		$mtime = "$mday-$months[$mon]-$year $time";
		my $pp = "";
		my $passfile = "$form{p}/$dir";
		$passfile =~ s/\//\_/g;
		$passfile =~ s/\\/\_/g;
		$passfile =~ s/\:/\_/g;
		if (-e "$storepath/$passfile.htpasswd") {
			open (PASSFILE, "<", "$storepath/$passfile.htpasswd") or die $!;
			@passrecs = <PASSFILE>;
			close (PASSFILE);
			chomp @passrecs;
			if (@passrecs > 0) {$pp = "**"}
		}

		print "<tr>";
		if ($form{do} eq "r" and ($form{f} eq $dir)) {
			print "<form action='$script' method='post'>\n";
			print "<td>";
			print "<input type='hidden' name='do' value='ren'>\n";
			print "<input type='hidden' name='p' value='$form{p}'>\n";
			print "<input type='hidden' name='c' value='$form{c}'>\n";
			print "<input type='hidden' name='m' value='$form{m}'>\n";
			print "<input type='hidden' name='f' value='$dir'>\n";
			print "<input type='text' size='10' name='newf' value='$dir'>\n";
			print "<input type='submit' class='btn btn-default' value='OK'>\n";
			print "$pp<a name='new'></a></td>\n";
			print "</form>\n";
		}
		elsif (-r "$webpath$form{p}/$dir") {
			print "<td><a data-tooltip='tooltip' title='Enter Directory' href='$script?do=b&p=$form{p}/$dir$extra\#new'>$dir</a>$pp</td>\n";
		}
		else {
			print "<td>$dir</td>\n";
		}
		print "<td align='right'>$size</td>\n";
		print "<td align='right'>$mtime</td>\n";
		if ($form{do} eq "o" and ($form{f} eq $dir)) {
			print "<form action='$script' method='post'>\n";
			print "<td align='right'>";
			print "<input type='hidden' name='do' value='seto'>\n";
			print "<input type='hidden' name='p' value='$form{p}'>\n";
			print "<input type='hidden' name='c' value='$form{c}'>\n";
			print "<input type='hidden' name='m' value='$form{m}'>\n";
			print "<input type='hidden' name='f' value='$dir'>\n";
			print "<input type='text' size='20' name='newo' value='$tuid:$tgid'>\n";
			print "<input type='submit' class='btn btn-default' value='OK'>\n";
			print "<a name='new'></a></td>\n";
			print "</form>\n";
		}
		else {
			print "<td align='right'><a data-tooltip='tooltip' title='Directory Owner' href='$script?do=o&p=$form{p}&f=$dir$extra\#new'>$tuid($uid)/$tgid($gid)</a></td>\n";
		}
		if ($form{do} eq "p" and ($form{f} eq $dir)) {
			print "<form action='$script' method='post'>\n";
			print "<td align='right'>";
			print "<input type='hidden' name='do' value='setp'>\n";
			print "<input type='hidden' name='p' value='$form{p}'>\n";
			print "<input type='hidden' name='c' value='$form{c}'>\n";
			print "<input type='hidden' name='m' value='$form{m}'>\n";
			print "<input type='hidden' name='f' value='$dir'>\n";
			print "<input type='text' size='3' name='newp' value='$mode'>\n";
			print "<input type='submit' class='btn btn-default' value='OK'>\n";
			print "<a name='new'></a></td>\n";
			print "</form>\n";
		}
		else {
			print "<td align='right'><a data-tooltip='tooltip' title='Permissions (CHMOD)' href='$script?do=p&p=$form{p}&f=$dir$extra\#new'>$mode</a></td>\n";
		}
		print "<td>&nbsp;</td>\n";
		print "<td><a class='btn btn-danger glyphicon glyphicon-trash' data-tooltip='tooltip' title='Delete Directory' href='$script?do=del&p=$form{p}&f=$dir$extra' onClick='return check(\"DELETE $dir\")'></a>\n";
		print " <a class='btn btn-primary glyphicon glyphicon-wrench' data-tooltip='tooltip' title='Rename Directory' href='$script?do=r&p=$form{p}&f=$dir$extra\#new'></a>\n";
		print " <a class='btn btn-success glyphicon glyphicon-copy' data-tooltip='tooltip' title='Copy Directory' href='$script?do=b&p=$form{p}&c=$form{p}/$dir\#new'></a>\n";
		print " <a class='btn btn-warning glyphicon glyphicon-move' data-tooltip='tooltip' title='Move Directory' href='$script?do=b&p=$form{p}&m=$form{p}/$dir\#new'></a></td>\n";
		print "</tr>\n";
	}
	if ($form{do} eq "newd") {
		print "<tr>";
		print "<form action='$script' method='post'>\n";
		print "<td>";
		print "<input type='hidden' name='do' value='cnewd'>\n";
		print "<input type='hidden' name='p' value='$form{p}'>\n";
		print "<input type='hidden' name='c' value='$form{c}'>\n";
		print "<input type='hidden' name='m' value='$form{m}'>\n";
		print "<input type='text' size='10' name='newf' value=''>\n";
		print "<input type='submit' class='btn btn-default' value='OK'>\n";
		print "<a name='new'></a></td>\n";
		print "</form>\n";
		print "<td>&nbsp;</td>\n";
		print "<td>&nbsp;</td>\n";
		print "<td>&nbsp;</td>\n";
		print "<td>&nbsp;</td>\n";
		print "<td colspan='5'>&nbsp;</td>\n";
		print "</tr>\n";
	}
	if (($form{do} eq "c") and (-d "$webpath$form{c}")) {
		my $newf = (split(/\//,$form{c}))[-1];
		print "<tr>";
		print "<form action='$script' method='post'>\n";
		print "<td>";
		print "<input type='hidden' name='do' value='copyit'>\n";
		print "<input type='hidden' name='p' value='$form{p}'>\n";
		print "<input type='hidden' name='c' value='$form{c}'>\n";
		print "<input type='hidden' name='m' value='$form{m}'>\n";
		print "<input type='text' size='10' name='newf' value='$newf'>\n";
		print "<input type='submit' class='btn btn-default' value='OK'>\n";
		print "<a name='new'></a></td>\n";
		print "</form>\n";
		print "<td>&nbsp;</td>\n";
		print "<td>&nbsp;</td>\n";
		print "<td>&nbsp;</td>\n";
		print "<td>&nbsp;</td>\n";
		print "<td colspan='2'>&nbsp;</td>\n";
		print "</tr>\n";
	}
	if (($form{do} eq "m") and (-d "$webpath$form{m}")) {
		my $newf = (split(/\//,$form{m}))[-1];
		print "<tr>";
		print "<form action='$script' method='post'>\n";
		print "<td>";
		print "<input type='hidden' name='do' value='moveit'>\n";
		print "<input type='hidden' name='p' value='$form{p}'>\n";
		print "<input type='hidden' name='c' value='$form{c}'>\n";
		print "<input type='hidden' name='m' value='$form{m}'>\n";
		print "<input type='text' size='10' name='newf' value='$newf'>\n";
		print "<input type='submit' class='btn btn-default' value='OK'>\n";
		print "<a name='new'></a></td>\n";
		print "</form>\n";
		print "<td>&nbsp;</td>\n";
		print "<td>&nbsp;</td>\n";
		print "<td>&nbsp;</td>\n";
		print "<td>&nbsp;</td>\n";
		print "<td colspan='2'>&nbsp;</td>\n";
		print "</tr>\n";
	}

	if (@thisfiles > 0) {
		print "<tr><td colspan='7'>&nbsp;</td></tr>\n";
		print "<thead><tr>";
		print "<th>File Name</th>";
		print "<th>Size</th>";
		print "<th>Date</th>";
		print "<th>User(uid)/Group(gid)</th>";
		print "<th>Perms</th>";
		print "<th colspan='2'>Actions</th>";
		print "</tr></thead>\n";
	}
	my $class = "tdshade2";
	foreach my $file (@thisfiles) {
		if ($file =~/'|"|\||\`/) {
			print "<td colspan='7'>".quotemeta($file)."Invalid file name - ignored</td>\n";
			next;
		}
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$thisdir/$file");
		if ($size < 1024) {
		}
		elsif ($size < (1024 * 1024)) {
			$size = sprintf("%.1f",($size/1024));
			$size .= "k";
		}
		else {
			$size = sprintf("%.1f",($size/(1024 * 1024)));
			$size .= "M";
		}
		$mode = sprintf "%03o", $mode & 00777;
		$tgid = getgrgid($gid);
		if ($tgid eq "") {$tgid = $gid}
		$tuid = getpwuid($uid);
		if ($tuid eq "") {$tuid = $uid}
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($mtime);
		$year += 1900;
		my $time = sprintf "%02d:%02d:%02d", $hour, $min, $sec;
		$mday = sprintf "%02d", $mday;
		$mtime = "$mday-$months[$mon]-$year $time";
		print "<tr>";
		if ($form{do} eq "r" and ($form{f} eq $file)) {
			print "<form action='$script' method='post'>\n";
			print "<td>";
			print "<input type='hidden' name='do' value='ren'>\n";
			print "<input type='hidden' name='p' value='$form{p}'>\n";
			print "<input type='hidden' name='c' value='$form{c}'>\n";
			print "<input type='hidden' name='m' value='$form{m}'>\n";
			print "<input type='hidden' name='f' value='$file'>\n";
			print "<input type='text' size='20' name='newf' value='$file'>\n";
			print "<input type='submit' class='btn btn-default' value='OK'>\n";
			print "<a name='new'></a></td>\n";
			print "</form>\n";
		}
		else {
			$act = "$script?do=view&p=$form{p}&f=$file$extra\#new";
			print "<td><a href='$act' data-tooltip='tooltip' title='Download File' target='_blank'>$file</a></td>\n";
		}
		print "<td align='right'>$size</td>\n";
		print "<td align='right'>$mtime</td>\n";
		if ($form{do} eq "o" and ($form{f} eq $file)) {
			print "<form action='$script' method='post'>\n";
			print "<td align='right'>";
			print "<input type='hidden' name='do' value='seto'>\n";
			print "<input type='hidden' name='p' value='$form{p}'>\n";
			print "<input type='hidden' name='c' value='$form{c}'>\n";
			print "<input type='hidden' name='m' value='$form{m}'>\n";
			print "<input type='hidden' name='f' value='$file'>\n";
			print "<input type='text' size='20' name='newo' value='$tuid:$tgid'>\n";
			print "<input type='submit' class='btn btn-default' value='OK'>\n";
			print "<a name='new'></a></td>\n";
			print "</form>\n";
		}
		else {
			print "<td align='right'><a data-tooltip='tooltip' title='File Owner' href='$script?do=o&p=$form{p}&f=$file$extra\#new'>$tuid($uid)/$tgid($gid)</a></td>\n";
		}
		if ($form{do} eq "p" and ($form{f} eq $file)) {
			print "<form action='$script' method='post'>\n";
			print "<td align='right'>";
			print "<input type='hidden' name='do' value='setp'>\n";
			print "<input type='hidden' name='p' value='$form{p}'>\n";
			print "<input type='hidden' name='c' value='$form{c}'>\n";
			print "<input type='hidden' name='m' value='$form{m}'>\n";
			print "<input type='hidden' name='f' value='$file'>\n";
			print "<input type='text' size='3' name='newp' value='$mode'>\n";
			print "<input type='submit' class='btn btn-default' value='OK'>\n";
			print "<a name='new'></a></td>\n";
			print "</form>\n";
		}
		else {
			print "<td align='right'><a data-tooltip='tooltip' title='Permissions (CHMOD)' href='$script?do=p&p=$form{p}&f=$file$extra\#new'>$mode</a></td>\n";
		}
		my $ext = (split(/\./,$file))[-1];
		if (-T "$webpath$form{p}/$file") {
			my $act = "";
			print "<td><a class='btn btn-info glyphicon glyphicon-edit' data-tooltip='tooltip' title='Edit File' href='$script?do=edit&p=$form{p}&f=$file$extra\#new'></a>$act</td>\n";
		} else {
			print "<td>&nbsp;</td>\n";
		}
		print "<td nowrap><a class='btn btn-danger glyphicon glyphicon-trash' data-tooltip='tooltip' title='Delete File' href='$script?do=del&p=$form{p}&f=$file$extra' onClick='return check(\"DELETE $file\")'></a>\n";
		print " <a class='btn btn-primary glyphicon glyphicon-wrench' data-tooltip='tooltip' title='Rename File' href='$script?do=r&p=$form{p}&f=$file$extra\#new'></a>\n";
		print " <a class='btn btn-success glyphicon glyphicon-copy' data-tooltip='tooltip' title='Copy File' href='$script?do=b&p=$form{p}&c=$form{p}/$file\#new'></a>\n";
		print " <a class='btn btn-warning glyphicon glyphicon-move' data-tooltip='tooltip' title='Move File' href='$script?do=b&p=$form{p}&m=$form{p}/$file\#new'></a></td>\n";
		print "</tr>\n";
	}
	if ($form{do} eq "newf") {
		print "<tr>";
		print "<form action='$script' method='post'>\n";
		print "<td>";
		print "<input type='hidden' name='do' value='cnewf'>\n";
		print "<input type='hidden' name='p' value='$form{p}'>\n";
		print "<input type='hidden' name='c' value='$form{c}'>\n";
		print "<input type='hidden' name='m' value='$form{m}'>\n";
		print "<input type='text' size='10' name='newf' value=''>\n";
		print "<input type='submit' class='btn btn-default' value='OK'>\n";
		print "<a name='new'></a></td>\n";
		print "</form>\n";
		print "<td>&nbsp;</td>\n";
		print "<td>&nbsp;</td>\n";
		print "<td>&nbsp;</td>\n";
		print "<td>&nbsp;</td>\n";
		print "<td colspan='2'>&nbsp;</td>\n";
		print "</tr>\n";
	}
	if (($form{do} eq "c") and (-f "$webpath$form{c}")) {
		my $newf = (split(/\//,$form{c}))[-1];
		print "<tr>";
		print "<form action='$script' method='post'>\n";
		print "<td>";
		print "<input type='hidden' name='do' value='copyit'>\n";
		print "<input type='hidden' name='p' value='$form{p}'>\n";
		print "<input type='hidden' name='c' value='$form{c}'>\n";
		print "<input type='hidden' name='m' value='$form{m}'>\n";
		print "<input type='text' size='10' name='newf' value='$newf'>\n";
		print "<input type='submit' class='btn btn-default' value='OK'>\n";
		print "<a name='new'></a></td>\n";
		print "</form>\n";
		print "<td>&nbsp;</td>\n";
		print "<td>&nbsp;</td>\n";
		print "<td>&nbsp;</td>\n";
		print "<td>&nbsp;</td>\n";
		print "<td colspan='2'>&nbsp;</td>\n";
		print "</tr>\n";
	}
	if (($form{do} eq "m") and (-f "$webpath$form{m}")) {
		my $newf = (split(/\//,$form{m}))[-1];
		print "<tr>";
		print "<form action='$script' method='post'>\n";
		print "<td>";
		print "<input type='hidden' name='do' value='moveit'>\n";
		print "<input type='hidden' name='p' value='$form{p}'>\n";
		print "<input type='hidden' name='c' value='$form{c}'>\n";
		print "<input type='hidden' name='m' value='$form{m}'>\n";
		print "<input type='text' size='10' name='newf' value='$newf'>\n";
		print "<input type='submit' class='btn btn-default' value='OK'>\n";
		print "<a name='new'></a></td>\n";
		print "</form>\n";
		print "<td>&nbsp;</td>\n";
		print "<td>&nbsp;</td>\n";
		print "<td>&nbsp;</td>\n";
		print "<td>&nbsp;</td>\n";
		print "<td colspan='2'>&nbsp;</td>\n";
		print "</tr>\n";
	}
}
print "</table>\n";

print "<div class='bs-callout bs-callout-warning'>All the following actions apply to the current directory</div>\n";
print "<form action='$script' method='post'>\n";
print "<input type='hidden' name='p' value='$form{p}'>\n";
print "<input type='hidden' name='c' value='$form{c}'>\n";
print "<input type='hidden' name='m' value='$form{m}'>\n";
print "<input type='hidden' name='do' value='search'>\n";
print "<table class='table table-bordered table-striped table-condensed'>\n";
print "<thead><tr><th colspan='2'>Search for filenames or directories</th></tr></thead>\n";
print "<tr><td colspan='2'>";
print "<input type='text' name='words' size='20'> <select name='type'>\n";
print "<option value='and'>AND words</option>\n";
print "<option value='or'>OR words</option>\n";
print "<option value='match'>MATCH words</option></select>\n";
print " <input type='submit' class='btn btn-default' value='Search'></td></tr>\n";
print "</form>\n";
print "<thead><tr><th colspan='2'>Create New...</th></tr></thead>\n";
print "<tr><td><a class='btn btn-default' href='$script?do=newd&p=$form{p}$extra\#new'>Create New Directory</a></td>\n<td><a class='btn btn-default' href='$script?do=newf&p=$form{p}$extra\#new'>Create Empty File</a></td></tr>\n";
print "<form action='$script' method='post' enctype='multipart/form-data'>\n";
print "<input type='hidden' name='p' value='$form{p}'>\n";
print "<input type='hidden' name='c' value='$form{c}'>\n";
print "<input type='hidden' name='m' value='$form{m}'>\n";
print "<thead><tr><th colspan='2'>Upload Files...</th></tr></thead>\n";
print "<tr><td colspan='2'><input type='file' class='btn btn-default' size='15' name='file0'><br>\n";
print "<input type='file' class='btn btn-default' size='15' name='file1'><br>\n";
print "<input type='file' class='btn btn-default' size='15' name='file2'><br>\n";
print "<input type='file' class='btn btn-default' size='15' name='file3'></td></tr>\n";
print "<tr><td colspan='2'>Mode: <label><input type='radio' name='type' value='ascii'><code>Ascii</code></label> <label><input type='radio' name='type' value='binary' checked><code>Binary</code></label> <input type='submit' class='btn btn-default' value='Upload'></td></tr>\n";
print "</form>\n";
print "<thead><tr><th colspan='2'>Change Directory...</th></tr></thead>\n";
print "<form action='$script' method='post'>\n";
print "<input type='hidden' name='p' value='$form{p}'>\n";
print "<input type='hidden' name='c' value='$form{c}'>\n";
print "<input type='hidden' name='m' value='$form{m}'>\n";
print "<input type='hidden' name='do' value='cd'>\n";
print "<tr><td colspan='2'>";
print "<input type='text' name='directory' value='$thisdir' size='40'>\n";
print " <input type='submit' class='btn btn-default' value='Change Directory'></td></tr>\n";
print "</table><br><br>\n";
print "</form>\n";

print "<form action='$script' method='post' target='WHMConsole'>\n";
print "<table class='table table-bordered table-striped table-condensed'>\n";
print "<thead><tr><th colspan='2'>Virtual Console <code>$thisdir</code></th></tr></thead>\n";
print "<input type='hidden' name='p' value='$form{p}'>\n";
print "<input type='hidden' name='c' value='$form{c}'>\n";
print "<input type='hidden' name='m' value='$form{m}'>\n";
print "<input type='hidden' name='do' value='console'>\n";
print "<tr><td colspan='2'>";
print "<iframe width='100%' height='500' name='WHMConsole' style='border: 1px black solid' border='0' frameborder='0' src='$script?do=console&cmd=ls%20-la&p=$form{p}'></iframe>\n";
print "<p>Command: <input type='text' name='cmd' value='' size='50' onFocus='this.value=\"\"'>\n";
print " <input type='submit' class='btn btn-default' value='Send'></p>\n";
print "<div class='bs-callout bs-callout-info'>Note: You cannot change directory within the console. Use the <em>Change Directory</em> feature above.</div>\n";
print "</td></tr>\n";
print "</table>\n";
print "</form>\n";

my $retry = 0;
my $retrytime = 300;
print "<table class='table table-bordered table-striped'>\n";
print "<thead><tr><th colspan='2'>Upgrade</th></tr></thead>";
if (-e "/usr/local/cpanel/whostmgr/docroot/cgi/csenocheck") {
	open (IN, "<", "/usr/local/cpanel/whostmgr/docroot/cgi/csenocheck");
	flock (IN, LOCK_SH);
	my $time = <IN>;
	close (IN);
	chomp $time;
	$retry = time - $time;
	if ($retry > $retrytime) {unlink ("/usr/local/cpanel/whostmgr/docroot/cgi/csenocheck")}
}
unless (-e "/usr/local/cpanel/whostmgr/docroot/cgi/csenocheck") {
	my ($status, $text) = &urlget("https://$downloadserver/cse/cseversion.txt");
	my $actv = $text;
	my $up = 0;

	if ($actv ne "") {
		if ($actv =~ /^[\d\.]*$/) {
			if ($actv > $myv) {
				print "<tr><form action='$script' method='post'><td><input type='hidden' name='do' value='upgrade'><input type='submit' class='btn btn-default' value='Upgrade cse'></td><td width='100%'><b>A new version of cse (v$actv) is available. Upgrading will retain your settings<br><a href='https://$downloadserver/cse/CHANGELOG.txt' target='_blank'>View ChangeLog</a></b></td></form></tr>\n";
			} else {
				print "<tr><td colspan='2'>You are running the latest version of cse.<br>An Upgrade button will appear here if a new version becomes available</td></tr>\n";
			}
			$up = 1;
		}
	}
	unless ($up) {
		sysopen (OUT, "/usr/local/cpanel/whostmgr/docroot/cgi/csenocheck", O_WRONLY | O_CREAT);
		flock (OUT, LOCK_EX);
		print OUT time;
		close (OUT);
		print "<tr><td colspan='2'>Unable to connect to http://www.configserver.com, retry in $retrytime seconds.<br>An Upgrade button will appear here if new version is detected</td></tr>\n";
	}
} else {
		print "<tr><td colspan='2'>Unable to connect to http://www.configserver.com, retry in ".($retrytime - $retry)." seconds.<br>An Upgrade button will appear here if new version is detected</td></tr>\n";
}
print "</table></form>\n";
return;
}
# end browse
###############################################################################
# start setp
sub setp {

if ($demo) {
	$message = "This action is disabled in the demonstration";
} else {
	my $status = 0;
	chmod (oct("0$form{newp}"),"$webpath$form{p}/$form{f}") or $status = $!;
	if ($status) {$message = "Operation Failed - $status"} else {$message = ""}
}
&browse;
return;
}
# end setp
###############################################################################
# start seto
sub seto {

if ($demo) {
	$message = "This action is disabled in the demonstration";
} else {
	my $status = "";
	my ($uid,$gid) = split (/\:/,$form{newo});
	if ($uid !~ /^\d/) {$uid = (getpwnam($uid))[2]}
	if ($gid !~ /^\d/) {$gid = (getgrnam($gid))[2]}
	if ($uid eq "") {$message .= "No such user<br>\n"}
	if ($gid eq "") {$message .= "No such group<br>\n"}

	if ($message eq "") {
		chown ($uid,$gid,"$webpath$form{p}/$form{f}") or $status = $!;
		if ($status) {$message = "Operation Failed - $status"} else {$message = ""}
	}
}
&browse;
return;
}
# end seto
###############################################################################
# start ren
sub ren {

if ($demo) {
	$message = "This action is disabled in the demonstration";
} else {
	my $status = 0;
	rename ("$webpath$form{p}/$form{f}","$webpath$form{p}/$form{newf}") or $status = $!;
	if ($status) {$message = "Operation Failed - $status"} else {$message = ""}
}
&browse;
return;
}
# end ren
###############################################################################
# start moveit
sub moveit {

if ($demo) {
	$form{m} = "";
	$message = "This action is disabled in the demonstration";
} else {
	if ("$webpath$form{m}" eq "$webpath$form{p}/$form{newf}") {
		$message = "Move Failed - Cannot overwrite original";
	}
	elsif ((-d "$webpath$form{m}") and ("$webpath$form{p}/$form{newf}" =~ /^$webpath$form{m}\//)) {
		$message = "Move Failed - Cannot move inside original";
	}
	else {
		my $status = 0;
		rename ("$webpath$form{m}","$webpath$form{p}/$form{newf}") or $status = $!;
		if ($status) {$message = "Operation Failed - $status"} else {$message = ""}
	}
	if ($message eq "") {$form{m} = ""}
}
&browse;
return;
}
# end moveit
###############################################################################
# start copyit
sub copyit {

if ($demo) {
	$form{c} = "";
	$message = "This action is disabled in the demonstration";
} else {
	if ("$webpath$form{c}" eq "$webpath$form{p}/$form{newf}") {
		$message = "Copy Failed - Cannot overwrite original";
	}
	elsif ((-d "$webpath$form{c}") and ("$webpath$form{p}/$form{newf}" =~ /^$webpath$form{c}\//)) {
		$message = "Copy Failed - Cannot copy inside original";
	}
	else {
		if (-d "$webpath$form{c}") {
			use File::Copy;
			$origpath = "$webpath$form{c}";
			$destpath = "$webpath$form{p}/$form{newf}";
			find(\&mycopy, $origpath);
		} else {
			use File::Copy;
			copy ("$webpath$form{c}","$webpath$form{p}/$form{newf}") or $message = "Copy Failed - $!";
			if ($message eq "") {
				my $mode = sprintf "%04o", (stat("$webpath$form{c}"))[2] & 00777;
				chmod (oct($mode),"$webpath$form{p}/$form{newf}") or $message = "Permission Change Failed - $!";
			}
		}
	}
	if ($message eq "") {$form{c} = ""}
}
&browse;
return;
}
# end copyit
###############################################################################
# start mycopy
sub mycopy {

if ($demo) {
	$message = "This action is disabled in the demonstration";
} else {
	my $file  = $File::Find::name;
	(my $dest = $file) =~ s/^\Q$origpath/$destpath/;
	my $status = "";
	if (-d $file) {
		my $err = (split(/\//,$dest))[-1];
		mkpath ($dest) or $status = "Copy Failed Making New Dir [$err] - $!<br>\n";
	} elsif (-f $file) {
		my $err = (split(/\//,$file))[-1];
		copy ($file,$dest) or $status = "Copy Failed [$err] - $!<br>\n";
	}
	if ($status eq "") {
		my $err = (split(/\//,$file))[-1];
		my $mode = sprintf "%04o", (stat("$file"))[2] & 00777;
		chmod (oct($mode),"$dest") or $message .= "Copy Failed Setting Perms [$err] - $!<br>\n";
	} else {
		$message .= $status;
	}
}
return;
}
# end mycopy
###############################################################################
# start cnewd
sub cnewd {

if ($demo) {
	$message = "This action is disabled in the demonstration";
} else {
	my $status = 0;
	if ($form{newf} ne "") {
		mkdir ("$webpath$form{p}/$form{newf}",0777) or $status = $!;
	}
	if ($status) {$message = "Operation Failed - $status"} else {$message = ""}
}
&browse;
return;
}
# end cnewd
###############################################################################
# start cnewf
sub cnewf {

if ($demo) {
	$message = "This action is disabled in the demonstration";
} else {
	my $status = 0;
	if ($form{newf} ne "") {
		if (-f ">$webpath$form{p}/$form{newf}") {
			$status = "File exists";
		} else {
			open (OUT, ">", "$webpath$form{p}/$form{newf}") or $status = $!;
			close (OUT);
		}
	}
	if ($status) {$message = "Operation Failed - $status"} else {$message = ""}
}
&browse;
return;
}
# end cnewf
###############################################################################
# start del
sub del {

if ($demo) {
	$message = "This action is disabled in the demonstration";
} else {
	my $status = 0;
	if (-d "$webpath$form{p}/$form{f}") {
		use File::Path;
		rmtree("$webpath$form{p}/$form{f}", 0, 0) or $status = $!;
	} else {
		unlink ("$webpath$form{p}/$form{f}") or $status = $!;
	}
	if ($status) {$message = "Operation Failed - $status"} else {$message = ""}
}
&browse;
return;
}
# end del
###############################################################################
# start view
sub view {
	if (-e "$webpath$form{p}/$form{f}" ) {
		if (-T "$webpath$form{p}/$form{f}") {
			print "content-type: text/plain\r\n";
		} else {
			print "content-type: application/octet-stream\r\n";
		}
		print "content-disposition: attachment; filename=$form{f}\r\n\r\n";

		open(IN,"<","$webpath$form{p}/$form{f}") or die $!;
		while (<IN>) {print}
		close(IN);
	}else{
		print "content-type: text/html\r\n\r\n";
		print "File [$webpath$form{p}/$form{f}] not found!";
	}
	return;
}
# end view
###############################################################################
# start console
sub console {
	my $thisdir = "$webpath$form{p}";
	$thisdir =~ s/\/+/\//g;

	print "<p><pre>\n";
	print "root [$thisdir]# $form{cmd}\n";
	chdir $thisdir;

	local $| = 1;
	my ($childin, $childout);
	my $cmdpid = open3($childin, $childout, $childout, $form{cmd});
	while (my $line = <$childout>) {
		$line =~ s/\</\&lt\;/g;
		$line =~ s/\>/\&gt\;/g;
		print $line;
	}
	waitpid ($cmdpid, 0);
	print "root [$thisdir]# _</pre></p>\n";
	print "<script>window.scrollTo(0,10000000);</script>";
	return;
}
# end console
###############################################################################
# start cd
sub cd {

if (-d $form{directory}) {
	$form{p} = $form{directory};
} else {
	$message = "No such directory [$form{directory}]";
}

&browse;
return;
}
# end cd
###############################################################################
# start edit
sub edit {

	open (IN, "<", "$webpath$form{p}/$form{f}") or die $!;
	my @data = <IN>;
	close (IN);

	my $filedata;
	foreach my $line (@data) {
		$line =~ s/\</&lt;/g;
		$line =~ s/\>/&gt;/g;
		$filedata .= $line;
	}

	my $lf = 0;
	if ($filedata =~ /\r/) {$lf = 1}

	print "<script language='javascript'>\n";
	print "	function check(file) {return confirm('Click OK to '+file)}\n";
	print "</script>\n";
	print "<form action='$script' method='post'>\n";
	print "<table class='table table-bordered table-striped'>\n";
	print "<tr><td>";
	print "<input type='hidden' name='p' value='$form{p}'>\n";
	print "<input type='hidden' name='f' value='$form{f}'>\n";
	print "<input type='hidden' name='lf' value='$lf'>\n";
	print "<textarea cols='100' rows='25' name='newf' style='width:100%'>$filedata</textarea>\n";
	print "</td></tr>\n";
	print "<tr><td>";
	print "<input type='submit' class='btn btn-default' name='do' value='Save'> \n";
	print "<input type='submit' class='btn btn-default' name='do' value='Cancel'>\n";
	print "</td>\n";
	print "</table>\n";
	print "</form>\n";
	return;
}
# end edit
###############################################################################
# start save
sub save {

if ($demo) {
	$message = "This action is disabled in the demonstration";
} else {
	unless ($form{lf}) {$form{newf} =~ s/\r//g}
	my $status = 0;
	open (OUT, ">", "$webpath$form{p}/$form{f}") or $status = $!;
	print OUT $form{newf};
	close (OUT);

	if ($status) {$message = "Operation Failed - $status"} else {$message = ""}
}
&browse;
return;
}
# end save
###############################################################################
# start search
sub search {

my $words = $form{words};
$words =~ s/\s+/ /g;
if (($words eq "") or ($words eq " ")) {&browse; exit;}
my @words = split(/ /,$words);

if ($form{c}) {$extra = "&c=$form{c}"}
if ($form{m}) {$extra = "&m=$form{m}"}

undef @dirs;
undef @files;
find(\&countfiles, "$webpath$form{p}");
@dirs = sort {lc($a) cmp lc($b)} @dirs;
@files = sort {lc($a) cmp lc($b)} @files;
my @dirmatches;
my @filematches;
foreach my $dir (@dirs) {
	if (($dir eq $webpath) or ("$dir/" eq $webpath) or ($dir eq "$webpath/")) {next}
	my $this = (split(/\//,$dir))[-1];
	my $score = 0;
	my $hit = 0;
	if ($form{type} eq "match") {
		if ($this eq $form{words}) {
			$hit++;
			$score += 5;
		}
		elsif ($this =~ /\b$form{words}\b/i) {
			$hit++;
			$score += 4;
		}
		elsif ($this =~ /\b$form{words}/i) {
			$hit++;
			$score += 3;
		}
		elsif ($this =~ /$form{words}\b/i) {
			$hit++;
			$score += 2;
		}
		elsif ($this =~ /$form{words}/i) {
			$hit++;
			$score += 1;
		}
	} else {
		foreach my $word (@words) {
			if ($this eq $word) {
				$hit++;
				$score += 5;
			}
			elsif ($this =~ /\b$word\b/i) {
				$hit++;
				$score += 4;
			}
			elsif ($this =~ /\b$word/i) {
				$hit++;
				$score += 3;
			}
			elsif ($this =~ /$word\b/i) {
				$hit++;
				$score += 2;
			}
			elsif ($this =~ /$word/i) {
				$hit++;
				$score += 1;
			}
		}
		if ($form{type} eq "and") {
			if ($hit < @words) {$score = 0}
		}
	}
	if ($score > 0) {
		my $score = sprintf "%04d", $score;
		push (@dirmatches,"$score,$dir");
	}
}
@dirmatches = sort {$a <=> $b} @dirmatches;
@dirmatches = reverse @dirmatches;
foreach my $file (@files) {
	my $this = (split(/\//,$file))[-1];
	my $score = 0;
	my $hit = 0;
	if ($form{type} eq "match") {
		if ($this eq $form{words}) {
			$hit++;
			$score += 5;
		}
		elsif ($this =~ /\b$form{words}\b/i) {
			$hit++;
			$score += 4;
		}
		elsif ($this =~ /\b$form{words}/i) {
			$hit++;
			$score += 3;
		}
		elsif ($this =~ /$form{words}\b/i) {
			$hit++;
			$score += 2;
		}
		elsif ($this =~ /$form{words}/i) {
			$hit++;
			$score += 1;
		}
	} else {
		foreach my $word (@words) {
			if ($this eq $word) {
				$hit++;
				$score += 5;
			}
			elsif ($this =~ /\b$word\b/i) {
				$hit++;
				$score += 4;
			}
			elsif ($this =~ /\b$word/i) {
				$hit++;
				$score += 3;
			}
			elsif ($this =~ /$word\b/i) {
				$hit++;
				$score += 2;
			}
			elsif ($this =~ /$word/i) {
				$hit++;
				$score += 1;
			}
		}
		if ($form{type} eq "and") {
			if ($hit < @words) {$score = 0}
		}
	}
	if ($score > 0) {
		my $score = sprintf "%04d", $score;
		push (@filematches,"$score,$file");
	}
}
@filematches = sort {$a <=> $b} @filematches;
@filematches = reverse @filematches;

print "<tr><td>\n";
print "<table class='table table-bordered table-striped'>\n";
print "<tr><td>";
print "[<a class='btn btn-default' href=\"$script?do=b&p=$extra\">Home</a>]";
my $path = "";
my $cnt = 1;
my @path = split(/\//,$form{p});
foreach my $dir (@path) {
	if ($dir ne "" and ($dir ne "/")) {
		if ($cnt == @path) {
			print "/$dir";
		} else {
			print "/<a class='btn btn-default' href=\"$script?do=b&p=$path/$dir$extra\">$dir</a>";
		}
		$path .= "/$dir";
		$cnt++;
	}
}
print "</td></tr>\n";
print "<tr><td>";
print "<b>Search results for [$form{words}] (".uc($form{type})." words)</b></td></tr>\n";

my @skipath = split(/\//,$webpath);
my $class = "tdshade2";
if (@dirmatches > 0) {
	foreach my $match (@dirmatches) {
		my ($score,$dir) = split(/\,/,$match);
		my $view = "";
		@splitme = split(/\//,$dir);
		for (my $x = @skipath + 1;$x < (@splitme - 1);$x++) {
			$view .= "/$splitme[$x]";
		}
		$view .= "/<b><a class='btn btn-default' href=\"$script?do=b&p=$view/$splitme[-1]$extra\">$splitme[-1]</a></b>";
		if ($class eq "tdshade2") {$class = "tdshade1"} else {$class = "tdshade2"}
		print "<tr><td>Score: $score Directory: [Home]$view</td></tr>\n";
	}
} else {
	print "<tr><td>No directory matches found</td><tr>\n";
}
print "<tr><td>&nbsp;</td></tr>\n";
$class = "tdshade2";
if (@filematches > 0) {
	foreach my $match (@filematches) {
		my ($score,$file) = split(/\,/,$match);
		my $view = "";
		@splitme = split(/\//,$file);
		if ((@skipath + 2) > @splitme) {
			$view = "[<a class='btn btn-default' href=\"$script?do=b&p=$extra\">Home</a>]/<b>$splitme[-1]</b>";
		} else {
			for (my $x = @skipath + 1;$x < (@splitme - 2);$x++) {
				$view .= "/$splitme[$x]";
			}
			$view = "[Home]$view/<a class='btn btn-default' href=\"$script?do=b&p=$view/$splitme[-2]$extra\">$splitme[-2]</a>/<b>$splitme[-1]</b>";
		}
		if ($class eq "tdshade2") {$class = "tdshade1"} else {$class = "tdshade2"}
		print "<tr><td>Score: $score File: $view</td></tr>\n";
	}
} else {
	print "<tr><td>No file matches found</td><tr>\n";
}

print "</table>\n";
return;
}
# end search
###############################################################################
# start process_form
sub process_form {

my $buffer = $ENV{'QUERY_STRING'};
if ($buffer eq "") {
	binmode (STDIN);
	read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
	if (($buffer =~ /Content-Disposition: form-data/) and ($buffer =~ /^--/))  {
		&upload($buffer);
		exit;
	}
}

my @pairs = split(/&/, $buffer);
foreach my $pair (@pairs) {
	my ($name, $value) = split(/=/, $pair);
	$value =~ tr/+/ /;
	$value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
	$value =~ s/\|//g;
	$value =~ s/\`//g;
	$value =~ s/\0//g;
	$value =~ s/\.\.//g;
	$value =~ s/~!/ ~!/g;
	$form{$name} = $value;
}

return;
}
# end process_form
###############################################################################
# start uploadfile
sub uploadfile {

$form{p} =~ s/\r//g;
$form{p} =~ s/\n//g;
$form{p} = &validate_upload_vars($form{p});
$form{type} =~ s/\r//g;
$form{type} =~ s/\n//g;
$form{type} = &validate_upload_vars($form{type});
$form{c} =~ s/\r//g;
$form{c} =~ s/\n//g;
$form{c} = &validate_upload_vars($form{c});
$form{m} =~ s/\r//g;
$form{m} =~ s/\n//g;
$form{m} = &validate_upload_vars($form{m});
$form{caller} =~ s/\r//g;
$form{caller} =~ s/\n//g;

my @filenames;
my @filebodies;
foreach my $key (keys %form) {
	if (($form{$key} =~ /\/tmp\/cpanel3upload\./) or ($form{$key} =~ /\/tmp\/cpanel\.TMP/) or ($form{$key} =~ /\/tmp\/Cpanel_Form_file\.upload\./)) {
		push (@filenames, $key);
		push (@filebodies, $form{$key});
	}
}

if ($demo) {
	$message = "This action is disabled in the demonstration";
} else {
	for (my $x = 0;$x < @filenames ;$x++) {
		$filenames[$x] = &validate_upload_vars($filenames[$x]);
		$filenames[$x] =~ s/\r//g;
		$filenames[$x] =~ s/\n//g;
		$filenames[$x] =~ s/^file-//g;
		$filenames[$x] = (split (/\\/,$filenames[$x]))[-1];
		$filenames[$x] = (split (/\//,$filenames[$x]))[-1];
		if ($form{type} eq "ascii") {$filebodies[$x] =~ s/\r//g}
		if (-e "$webpath$form{p}/$filenames[$x]") {
			$extramessage .= "<br>$filenames[$x] - Already exists, delete the original first";
			$fileno--;
			next;
		}
		my $openok = 1;
		&printcmd("mv -f $filebodies[$x] $webpath$form{p}/$filenames[$x]");
		$extramessage .= "<br>$filenames[$x] - Uploaded";
	}

	$message = "$fileno File(s) Uploaded".$extramessage;
}

&browse;
return;
}
# end upload
###############################################################################
# start validate_upload_vars
sub validate_upload_vars {

my $value = shift;
return $value;

}
# end validate_upload_vars
###############################################################################
# start countfiles
sub countfiles {

if (-d $File::Find::name) {push (@dirs, $File::Find::name)} else {push (@files, $File::Find::name)}

return;
}
# end countfiles
###############################################################################
# start wantedfiles
sub wantedfiles {

unless (-f $File::Find::name) {return}
if ($File::Find::name =~ /\_vti\_/) {return}
if ($File::Find::dir =~ /^$wwwpath/) {$dir = $';} else {return}
if ($dir =~ /^\//) {$dir = $';}
if ($dir ne "") {$dir = $dir."/";}
push (@userfiles,$dir.$_);

return;
}
# end wantedfiles
###############################################################################
# start upgrade
sub upgrade {

$| = 1;

print "<pre>";

if (-e "/usr/src/cse.tgz") {unlink ("/usr/src/cse.tgz") or die $!}
print "Retrieving new cse package...\n";

my ($status, $text) = &urlget("https://$downloadserver/cse.tgz","/usr/src/cse.tgz");
if ($status) {print "Oops: $text\n"}

if (! -z "/usr/src/cse.tgz") {
	print "Unpacking new cse package...\n";
	print "<pre>";
	&printcmd("cd /usr/src ; tar -xzf cse.tgz ; cd cse ; sh install.sh 2>&1");
	print "</pre>";
	print "Tidying up...\n";
	print "<pre>";
	&printcmd("rm -Rfv /usr/src/cse*");
	print "</pre>";
	print "...All done.\n";
}
print "</pre>";

open (IN, "<", $versionfile) or die $!;
$myv = <IN>;
close (IN);
chomp $myv;

print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";

return;
}
# end upgrade
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
			$|=1;
			my $expected_length;
			my $bytes_received = 0;
			my $per = 0;
			my $oldper = 0;
			open (OUT, ">", "$file\.tmp") or return (1, "Unable to open $file\.tmp: $!");
			binmode (OUT);
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
				print OUT $chunk;
			});
			close (OUT);
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
	my $downloadservers = "/usr/local/cpanel/whostmgr/docroot/cgi/configserver/cse/downloadservers";
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
